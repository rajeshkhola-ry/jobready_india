import * as vscode from 'vscode';
import * as path from 'path';
import { AgentRunner, FileOpsHooks, ModelInfo } from './agentRunner';
import { BudgetGuardService } from './budgetGuard';
import { JobHistoryService } from './jobHistory';
import { ProjectQuoteStatsService } from './projectQuoteStats';
import { getChatReply, ChatTurn } from './chatAssistant';
import { ApiKeyManager, ApiKeyProvider, PROVIDER_LABELS } from './apiKeyManager';
import { stopPreviewServer } from './previewServer';
import { BackupManager, BackupFileEntry } from './backupManager';
import { FileOpsGuard, createFileOpsHooks } from './fileOpsGuard';
import { buildAcceptancePrompt, buildCompactDiff, parseAcceptanceReply, describeVerdict, type AcceptanceEvidence } from './acceptanceReview';
import { buildAgentReport, type AgentRow } from './agentReport';
import { PricingSyncService } from './pricingSync';
import { estimateAllProviders, applyPricingOverrides, decomposeAndRouteTasks, buildTaskBreakdown, estimateJobCostUsd, RetryAttemptsConfig, DEFAULT_RETRY_ATTEMPTS, ToolLoopOptions } from './agentRunner';
import { BatchProcessor, parseIntoTaskItems, BatchProgressSnapshot } from './batchProcessor';
import { AdminAnalyticsService } from './adminAnalytics';
import { PricingHistoryService } from './pricingHistory';
import { AdminApiExportService } from './adminApiExport';
import { LeadOrchestrator, MAX_REVIEW_ITERATIONS } from './orchestrator';
import { QualityGateRunner, QualityGateReport } from './qualityGates';
import { parseSafeCommand, runSafeCommand, readWorkspaceScripts } from './agentShell';
import { AdminGate, ADMIN_BUILD, DISTRIBUTION_CHANNEL } from './adminGate';
import { AgentMetricsService } from './agentMetrics';
import { MetricsSyncService } from './metricsSync';
import { MODELS } from './agentRunner';
import { ProjectQuoteEngine, ProjectQuoteMode } from './projectQuoteEngine';

const output = vscode.window.createOutputChannel('DAI-Flash');

function log(msg: string) {
  console.log(msg);
  output.appendLine(msg);
}

// Random per-load token so the webview's CSP can allow exactly this one inline
// <script> block and nothing else an injected/agent-controlled string could add.
function getNonce(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  let text = '';
  for (let i = 0; i < 32; i++) {
    text += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return text;
}

const CHECKPOINT_KEY = 'daiFlash.jobCheckpoint';

let activeProvider: DaiFlashViewProvider | undefined;

interface JobCheckpoint {
  prompt: string;
  model?: string;
  lastCompletedStep: number;
  selectedModelId?: string;
  pendingFiles: Array<{ path: string; additions: number; deletions: number }>;
  timestamp: number;
}

export class DaiFlashViewProvider implements vscode.WebviewViewProvider {
  public static readonly viewType = 'daiFlashView';
  private _view?: vscode.WebviewView;
  private _runner: AgentRunner;
  private _apiKeyManager: ApiKeyManager;
  private _sessionCostUsd: number = 0;
  private _sessionInputTokens: number = 0;
  private _sessionOutputTokens: number = 0;
  private _lastCostUsd: number = 0;
  private _lastInputTokens: number = 0;
  private _lastOutputTokens: number = 0;
  private _pendingFiles: Map<string, { additions: number; deletions: number; snapshotId?: string }> = new Map();
  private _checkpoint: JobCheckpoint | undefined;
  private _isJobRunning: boolean = false;
  private _taskQueue: Array<{ prompt: string; model?: string }> = [];
  private _backupManager: BackupManager;
  private _fileOpsGuard: FileOpsGuard;
  private _pricingSync: PricingSyncService;
  private _batchProcessor: BatchProcessor;
  private _adminAnalytics: AdminAnalyticsService;
  private _pricingHistory: PricingHistoryService;
  private _adminApiExport: AdminApiExportService;
  private _orchestrator: LeadOrchestrator;
  private _agentMetrics: AgentMetricsService;
  private _metricsSync: MetricsSyncService;
  private _budgetGuard: BudgetGuardService;
  private _jobHistory: JobHistoryService;
  private _projectQuoteStats: ProjectQuoteStatsService;
  /** Conversation memory for the separate "💬 Chat" assistant - never touched by real job execution. */
  private _chatHistory: ChatTurn[] = [];
  private _activeRunId: string | undefined;
  /** Agent output captured for the current run - the evidence the four-eye reviewer judges. */
  private _runTranscript: string[] = [];
  /** Outcome of the last pre-commit gate, recorded against the plan before review. */
  private _lastGateReport: QualityGateReport | undefined;
  private _lastGateAttempts = 0;
  /** Set when the tool loop's agent ran a build/test itself - this job's real gate evidence. */
  private _lastToolVerification: { ran: boolean; passed: boolean; summary: string } | undefined;
  /** Commands the tool loop ran, kept as hard evidence for the acceptance review. */
  private _lastCommands: Array<{ command: string; exitCode: number | null }> = [];
  /** Set when the acceptance reviewer said the work is NOT what was asked for. */
  private _acceptanceFailed = false;
  /** Label of the agent that DID the work - so the reviewer can be someone else. */
  private _lastExecutorLabel = '';
  /** What the acceptance review itself cost, folded into the job card rather than hidden. */
  private _acceptanceCostUsd = 0;
  /** Spend and rounds from corrective iterations, so the job card stops under-reporting. */
  private _correctiveCostUsd = 0;
  private _correctiveInputTokens = 0;
  private _correctiveOutputTokens = 0;
  private _correctiveRounds = 0;
  private _lastPrompt: string = '';
  private _hadUncleanShutdown: boolean = false;
  /** The throwaway runner driving an in-flight four-eye corrective iteration, if any - kept
   *  only so the "stop" command can actually cancel it too, not just the main `_runner`. */
  private _activeCorrectiveRunner: AgentRunner | undefined;

  constructor(private readonly _context: vscode.ExtensionContext, private readonly _gate: AdminGate) {
    this._runner = new AgentRunner();
    this._apiKeyManager = new ApiKeyManager(_context.secrets);
    this._checkpoint = this._context.workspaceState.get<JobCheckpoint>(CHECKPOINT_KEY);
    this._backupManager = new BackupManager(_context.globalState, _context.globalStorageUri);
    this._fileOpsGuard = new FileOpsGuard();
    this._hadUncleanShutdown = !this._backupManager.wasLastShutdownClean();
    this._backupManager.markCleanShutdown(false);
    this._adminAnalytics = new AdminAnalyticsService(_context.globalState, () => this._isAdminMode());
    this._pricingHistory = new PricingHistoryService(_context.globalState, () => this._isAdminMode());
    this._adminApiExport = new AdminApiExportService(_context, () => this._isAdminMode());
    this._orchestrator = new LeadOrchestrator(_context.globalState);
    this._agentMetrics = new AgentMetricsService(_context.globalState);
    this._budgetGuard = new BudgetGuardService(_context.globalState);
    this._jobHistory = new JobHistoryService(_context.globalState);
    this._projectQuoteStats = new ProjectQuoteStatsService(_context.globalState);
    this._metricsSync = new MetricsSyncService(_context, this._agentMetrics, (msg) => this._onLog(msg));
    this._metricsSync.start();
    void this._pricingHistory.snapshot(MODELS, 'startup');
    this._pricingSync = new PricingSyncService(
      _context,
      (overrides) => {
        const applied = applyPricingOverrides(overrides);
        if (applied.length > 0) {
          this._onLog(`💱 Pricing sync: applied updated rates for ${applied.join(', ')}`);
        }
        void this._pricingHistory.snapshot(MODELS, 'pricing-sync');
      },
      (msg) => this._onLog(msg)
    );
    this._pricingSync.start();
    this._runner.events.on('log', (msg) => {
      this._runTranscript.push(msg);
      this._onLog(msg);
    });
    this._runner.events.on('summary', (summary) => this._onSummary(summary));
    this._runner.events.on('todo', (items) => this._onTodo(items));
    this._runner.events.on('fileChanged', (files) => this._onFileChanged(files));
    this._runner.events.on('usage', (data) => this._onUsage(data));
    this._runner.events.on('modelSelected', (modelId) => this._onModelSelected(modelId));
    this._runner.events.on('progress', (data) => this._onProgress(data));
    this._runner.events.on('jobComplete', (data) => this._onJobComplete(data));
    this._runner.events.on('preview', (data) => this._onPreview(data));
    this._batchProcessor = new BatchProcessor(
      _context,
      this._runner,
      (provider) => this._apiKeyManager.ensureKey(provider),
      (msg) => this._onLog(msg),
      (snapshot) => this._onBatchProgress(snapshot),
      this._orchestrator,
      this._fileOpsGuard
    );
  }

  public resolveWebviewView(
    webviewView: vscode.WebviewView,
    context: vscode.WebviewViewResolveContext,
    _token: vscode.CancellationToken,
  ) {
    this._view = webviewView;
    log('[DAI-Flash] 🔧 Resolving webview view...');
    
    try {
      webviewView.webview.options = {
        enableScripts: true,
        localResourceRoots: [this._context.extensionUri],
      };
      log('[DAI-Flash] ✅ Webview options configured (enableScripts: true)');
      
      const html = this._getHtmlForWebview(webviewView.webview);
      log('[DAI-Flash] ✅ HTML generated, length: ' + html.length + ' bytes');
      
      webviewView.webview.html = html;
      log('[DAI-Flash] ✅ HTML assigned to webview');

      webviewView.webview.onDidReceiveMessage((message) => {
        log('[DAI-Flash] 📬 WebviewMessage received: ' + (message.command || message.type));
        this._handleWebviewMessage(message);
      });
      log('[DAI-Flash] ✅ Message listener attached');

      setTimeout(async () => {
        log('[DAI-Flash] ✅ Posting ready signal to webview');
        webviewView.webview.postMessage({ type: 'ready' });
        this._postSessionsList();
        this._sendProjectQuoteSettings();
        if (this._checkpoint && this._checkpoint.lastCompletedStep < 5) {
          log('[DAI-Flash] 🔁 Interrupted job checkpoint found, offering resume');
          webviewView.webview.postMessage({
            type: 'recoveryAvailable',
            prompt: this._checkpoint.prompt,
            lastCompletedStep: this._checkpoint.lastCompletedStep,
          });
        }
        if (this._hadUncleanShutdown) {
          const latestBackup = await this._backupManager.getLatestBackup();
          if (latestBackup && !this._backupManager.wasAlreadyRestored(latestBackup.id)) {
            log('[DAI-Flash] 🗄️ Previous session ended unexpectedly - silently restoring latest intelligent backup');
            void this._restoreLatestBackup();
          } else if (latestBackup) {
            log('[DAI-Flash] ℹ️ Unclean shutdown detected, but this backup was already restored once - not re-applying it.');
          }
        }
      }, 500);
      
      log('[DAI-Flash] ✅ Webview view resolved successfully');
    } catch (err) {
      log('[DAI-Flash] ❌ Error resolving webview view: ' + err);
      throw err;
    }
  }

  private _getHtmlForWebview(webview: vscode.Webview): string {
    const nonce = getNonce();
    return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src ${webview.cspSource} 'unsafe-inline'; img-src ${webview.cspSource} https: data:; script-src 'nonce-${nonce}';">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>DAI Flash</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html { width: 100%; height: 100%; background-color: #1a1a1e; overflow: hidden; }
    body {
      width: 100%; 
      height: 100%;
      font-family: 'Segoe UI Variable', 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      color: #e6e6e6;
      font-size: 13px;
      line-height: 1.5;
      display: flex;
      flex-direction: column;
      background-color: #1a1a1e;
      overflow: hidden;
      margin: 0;
      padding: 0;
      visibility: visible;
      -webkit-font-smoothing: antialiased;
    }
    .container {
      /* This used to scroll as a whole (overflow-y: auto), with the prompt textarea and
         footer living INSIDE that same scroll region. That's what caused the input box to
         visibly jump up/down/sideways while typing or backspacing: the browser auto-scrolls
         the nearest scrollable ancestor to keep the caret in view, and with the textarea
         nested inside this container's own scrollbar AND its own internal scrollbar, the two
         fought each other on every keystroke. Fix: this container no longer scrolls at all -
         only .logs-container (flex: 1 below) does. Everything else (header, banners, the
         prompt box, the footer) is flex-shrink: 0 and stays pinned in place; only the log/
         session history above the prompt box scrolls, exactly like a normal chat UI. */
      display: flex;
      flex-direction: column;
      flex: 1;
      min-height: 0;
      width: 100%;
      padding: 0;
      gap: 6px;
      background-color: #1a1a1e;
      overflow: visible;
      visibility: visible;
      /* Belt-and-suspenders on top of removing this container's own scroll above: CSS
         containment tells the browser "nothing that changes inside here (e.g. every keystroke
         in the textarea, which reflows for its own caret/text) can possibly change this box's
         own size or anything outside it" - so it never has a reason to recompute this box's
         layout while you type. layout+style only (no paint/size) so nothing visual clips. */
      contain: layout style;
    }
    .container h1 {
      flex-shrink: 0;
      margin: 0;
      padding: 6px 10px;
      font-size: 12px;
      font-weight: 500;
      background-color: #1e1e1e;
      color: #e6e6e6;
      border-bottom: 1px solid #3e3e42;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 8px;
      letter-spacing: 0.1px;
    }
    .status-badge {
      display: inline-flex;
      align-items: center;
      gap: 5px;
      flex-shrink: 0;
      padding: 2px 8px;
      border-radius: 10px;
      font-size: 10.5px;
      font-weight: 500;
      letter-spacing: 0.2px;
      background-color: #2a2a30;
      border: 1px solid #3e3e42;
      color: #b0b0b8;
    }
    .chat-toggle-btn {
      flex-shrink: 0;
      padding: 2px 8px;
      border-radius: 10px;
      font-size: 10.5px;
      font-weight: 500;
      letter-spacing: 0.2px;
      background-color: #2a2a30;
      border: 1px solid #3e3e42;
      color: #b0b0b8;
      cursor: pointer;
      width: auto;
      box-shadow: none;
    }
    .chat-toggle-btn:hover { background-color: #34343c; border-color: #4a4a52; }
    .chat-toggle-btn.active {
      background-color: #1f3a52;
      border-color: #4fc1ff88;
      color: #9cdcff;
    }
    .chat-bubble-assistant {
      background-color: #1c2b38;
      border: 1px solid #2c4558;
      border-left: 3px solid #4fc1ff;
      color: #dfefff;
      padding: 8px 10px;
      border-radius: 8px;
      margin-bottom: 6px;
      font-size: 12.5px;
      white-space: pre-wrap;
      word-wrap: break-word;
    }
    .chat-bubble-user {
      background-color: #232733;
      border: 1px solid #33394a;
      border-left: 3px solid #8a5cf6;
      color: #ffffff;
      padding: 8px 10px;
      border-radius: 8px;
      margin-bottom: 6px;
      font-size: 12.5px;
      white-space: pre-wrap;
      word-wrap: break-word;
    }
    .chat-thinking {
      color: #8a8a94;
      font-size: 11.5px;
      font-style: italic;
      padding: 4px 2px;
      margin-bottom: 6px;
    }
    .send-to-agent-btn {
      width: auto;
      display: inline-flex;
      margin-bottom: 8px;
      padding: 5px 10px;
      font-size: 11px;
      background: linear-gradient(135deg, #0e639c, #0a4d7a);
      border-color: #0a3a63;
    }
    .status-dot {
      width: 7px;
      height: 7px;
      border-radius: 50%;
      background-color: #6a6a72;
      flex-shrink: 0;
    }
    .status-badge.running {
      color: #7ee787;
      border-color: #2ea04366;
      background-color: #12261a;
    }
    .status-badge.running .status-dot {
      background-color: #3fb950;
      animation: statusGlow 1.4s ease-in-out infinite;
    }
    .status-badge.error {
      color: #ff8a8a;
      border-color: #f8514966;
      background-color: #2a1416;
    }
    .status-badge.error .status-dot {
      background-color: #f85149;
      animation: statusFlash 0.85s ease-in-out infinite;
    }
    @keyframes statusGlow {
      0%, 100% { box-shadow: 0 0 0 0 rgba(63,185,80,0.7); opacity: 1; }
      50% { box-shadow: 0 0 7px 3px rgba(63,185,80,0.35); opacity: 0.75; }
    }
    @keyframes statusFlash {
      0%, 100% { box-shadow: 0 0 0 0 rgba(248,81,73,0.8); opacity: 1; }
      50% { box-shadow: 0 0 8px 3px rgba(248,81,73,0.45); opacity: 0.3; }
    }
    .chat-box {
      position: relative;
      flex-shrink: 0;
      margin: 0 8px;
      padding: 10px;
      border-radius: 10px;
      background-color: #1f1f24;
      border: 1px solid #33333a;
      box-shadow: 0 2px 10px rgba(0,0,0,0.3);
      /* No more resize/overflow here on purpose: every child (model row, the 72px-fixed
         textarea, the button row) already has a fixed height, so this box's own height never
         needs to be recalculated from its content - a manual resize handle had nothing real to
         do and, combined with overflow:auto, was one more thing the browser had to re-check on
         every keystroke inside the textarea. contain: layout+style (not paint, so the ::before
         glow border's -2px bleed still shows) makes that recheck structurally impossible. */
      contain: layout style;
    }
    .chat-box::before {
      content: '';
      position: absolute;
      inset: -2px;
      border-radius: 12px;
      padding: 2px;
      background: linear-gradient(120deg, #0e639c, #4fc1ff, #8a5cf6, #0e639c);
      -webkit-mask: linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0);
      -webkit-mask-composite: xor;
      mask-composite: exclude;
      opacity: 0;
      transition: opacity 0.4s ease;
      pointer-events: none;
    }
    .chat-box.active-glow::before {
      opacity: 0.45;
      animation: chatGlowBreathe 2.6s ease-in-out infinite;
    }
    @keyframes chatGlowBreathe {
      0%, 100% { opacity: 0.4; }
      50% { opacity: 1; }
    }
    .model-select {
      flex: 1 1 auto;
      min-width: 0;
      padding: 7px 8px;
      background-color: #2b2b31;
      color: #ffffff;
      border: 1px solid #3d3d44;
      border-radius: 6px;
      font-size: 12px;
      display: block;
    }
    .model-select:focus { outline: none; border-color: #4fc1ff; }
    .model-row {
      display: flex;
      align-items: center;
      gap: 6px;
      flex-shrink: 0;
      visibility: visible;
    }
    .task-pills {
      display: flex;
      align-items: center;
      gap: 4px;
      flex-shrink: 0;
      visibility: visible;
    }
    .task-pill {
      background-color: #2d2d2d;
      padding: 4px 8px;
      border-radius: 10px;
      cursor: pointer;
      user-select: none;
      font-weight: 500;
      font-size: 10px;
      color: #ffffff;
      border: 1px solid #3e3e42;
      white-space: nowrap;
      visibility: visible;
    }
    .task-pill:hover { background-color: #383838; }
    .prompt-area {
      display: flex;
      flex-direction: column;
      gap: 8px;
      flex-shrink: 0;
      visibility: visible;
      padding: 0;
      margin: 0;
    }
    .textarea-wrap {
      position: relative;
      display: block;
      border-radius: 10px;
      contain: layout style;
    }
    textarea {
      /* Fixed size (auto-grow-while-typing was removed - it caused visible layout shaking
         in this panel). Slightly smaller than the original 110px; long text scrolls inside
         the box (use the scrollbar/side arrows) instead of the box changing size.
         overflow-y is always "scroll" (not "auto") and scrollbar-gutter reserves the
         scrollbar's space up front - otherwise the scrollbar popping in/out as a line wraps
         shrinks the usable width and the text visibly reflows/wobbles while typing. */
      height: 72px;
      min-height: 72px;
      max-height: 72px;
      padding: 8px 34px 8px 10px;
      background-color: #2b2b31;
      color: #ffffff;
      border: 1.5px solid rgba(79, 193, 255, 0.4);
      border-radius: 8px;
      font-family: 'Cascadia Code', Consolas, monospace;
      font-size: 12px;
      resize: none;
      overflow-y: scroll;
      scrollbar-gutter: stable;
      transition: border-color 0.15s ease;
      visibility: visible;
      display: block;
      width: 100%;
      /* Strongest guarantee: this box's own size can now ONLY come from the height/min-height/
         max-height above, never from what's typed inside it, so there is nothing left for a
         keystroke to trigger outside this element. */
      contain: layout style;
    }
    textarea::placeholder {
      color: #6f6f78;
      font-style: normal;
      font-weight: 400;
    }
    textarea:focus { outline: none; border-color: #4fc1ff; background-color: #303038; }
    .enter-icon {
      position: absolute;
      right: 10px;
      bottom: 10px;
      width: 20px;
      height: 20px;
      border-radius: 5px;
      background: rgba(79, 193, 255, 0.12);
      border: 1px solid rgba(79, 193, 255, 0.35);
      color: #4fc1ff;
      font-size: 11px;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      user-select: none;
      transition: background-color 0.15s ease, border-color 0.15s ease, transform 0.1s ease;
    }
    .enter-icon:hover {
      background: rgba(79, 193, 255, 0.28);
      border-color: #4fc1ff;
    }
    .enter-icon:active { transform: scale(0.9); }
    .button-group {
      display: flex;
      flex-wrap: wrap;
      gap: 4px;
      width: 100%;
      visibility: visible;
    }
    .button-group button {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 4px;
      flex: 1 1 auto;
      width: auto;
      min-width: 34px;
      padding: 5px 8px;
      background-color: #2a2a2e;
      color: #ffffff;
      border: 1px solid #3c3c3c;
      border-radius: 4px;
      font-size: 11px;
      font-weight: 400;
      box-shadow: none;
    }
    .button-group button:hover { background-color: #383840; border-color: #4a4a52; box-shadow: none; }
    .button-group button:active { background-color: #2f2f36; }
    button {
      padding: 7px 4px;
      background: linear-gradient(135deg, #0e639c, #0a4d7a);
      color: #ffffff;
      border: 1px solid #0a3a63;
      border-radius: 6px;
      cursor: pointer;
      font-size: 11.5px;
      font-weight: 500;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      transition: all 0.15s ease;
      width: 100%;
      box-sizing: border-box;
      visibility: visible;
      display: block;
      box-shadow: 0 1px 3px rgba(0,0,0,0.3);
    }
    button:hover { background: linear-gradient(135deg, #1177bb, #0d5299); box-shadow: 0 2px 6px rgba(0,0,0,0.35); }
    button:active { background-color: #0d4a82; }
    button:disabled { opacity: 0.5; cursor: not-allowed; }

    .logs-container {
      flex: 1;
      overflow-y: auto;
      overflow-x: hidden;
      scrollbar-gutter: stable;
      scroll-behavior: smooth;
      resize: vertical;
      background-color: #17171b;
      border: 1px solid #33333a;
      border-radius: 8px;
      padding: 10px;
      margin: 0 8px;
      color: #ffffff;
      min-height: 160px;
      visibility: visible;
      display: block;
      box-shadow: inset 0 1px 4px rgba(0,0,0,0.25);
      contain: layout style;
    }
    .log-line {
      margin-bottom: 3px;
      font-size: 12px;
      color: #ffffff;
      font-family: monospace;
      visibility: visible;
    }
    .log-line.info { color: #4fc1ff; }
    .log-line.success { color: #89d185; }
    .log-line.error { color: #f48771; }
    .log-line.warn { color: #dcdcaa; }
    .summary-card {
      background-color: #26262c;
      border-left: 3px solid #0e639c;
      padding: 10px;
      border-radius: 8px;
      margin-top: 6px;
      color: #ffffff;
      border: 1px solid #33333a;
      visibility: visible;
    }
    .progress-bubble {
      background-color: #26262c;
      border-left: 3px solid #dcdcaa;
      padding: 8px 10px;
      border-radius: 8px;
      margin-bottom: 6px;
      color: #ffffff;
      border: 1px solid #33333a;
      font-family: 'Cascadia Code', Consolas, monospace;
      font-size: 12px;
      visibility: visible;
    }
    .job-complete-card {
      background-color: #1e4620;
      border-left: 3px solid #89d185;
      padding: 10px;
      border-radius: 8px;
      margin-bottom: 6px;
      color: #ffffff;
      border: 1px solid #33333a;
      visibility: visible;
      box-shadow: 0 2px 8px rgba(0,0,0,0.25);
    }
    .job-complete-card .job-title { font-weight: 600; color: #89d185; display: block; margin-bottom: 4px; }
    .job-complete-card .job-footer { font-size: 11px; color: #c9c9c9; margin-top: 4px; display: block; }
    .job-complete-card.job-failed-card {
      background-color: #4a1e1e;
      border-left: 3px solid #f14c4c;
    }
    .job-complete-card.job-failed-card .job-title { color: #f48771; }
    .copy-btn {
      display: block;
      width: 100%;
      margin-top: 8px;
      flex: none;
    }
    .quote-section {
      margin-top: 10px;
      padding-top: 8px;
      border-top: 1px dashed #33333a;
    }
    .quote-section .quote-heading { font-weight: 600; color: #4fc1ff; display: block; margin-bottom: 6px; }
    .quote-margin-row { display: flex; align-items: center; gap: 6px; margin-bottom: 8px; }
    .quote-margin-row label { font-size: 11px; color: #c9c9c9; }
    .quote-margin-input {
      width: 70px;
      padding: 4px 6px;
      background-color: #2b2b31;
      color: #ffffff;
      border: 1.5px solid rgba(79, 193, 255, 0.4);
      border-radius: 6px;
      font-family: 'Cascadia Code', Consolas, monospace;
      font-size: 12px;
    }
    .quote-margin-input:focus { outline: none; border-color: #4fc1ff; background-color: #303038; }
    .quote-settings-panel {
      /* A fixed max-height here was wrong: .container/body/html never scroll (see .container
         above), so on a short/narrow docked sidebar the panel's own siblings (logs, chat box,
         etc.) could push the Back button below the visible area with literally no way to reach
         it. Fix: while open, .qs-active (below) hides those siblings so this panel becomes the
         ONLY thing taking up .container's remaining flex space (flex:1, sized to whatever room
         actually exists) - its own internal scroll (.qs-scroll) plus a Back button pinned
         OUTSIDE that scroll (.qs-actions, flex-shrink:0) means Back is always visible no matter
         how tall the content is or how short the sidebar is. */
      display: none;
      flex-direction: column;
      margin: 0 8px;
      padding: 10px;
      background-color: #1f1f24;
      border: 1px solid #3d3d44;
      border-radius: 8px;
      box-shadow: 0 4px 14px rgba(0,0,0,0.35);
      contain: layout style;
    }
    .quote-settings-panel.visible {
      display: flex;
      flex: 1 1 auto;
      min-height: 0;
    }
    /* Set on .container together with .quote-settings-panel's .visible class - reclaims all
       the vertical space those sections were using so the settings panel (and its Back button)
       always fits, however short the actual webview viewport is. */
    .container.qs-active .logs-container,
    .container.qs-active .accordion-body,
    .container.qs-active .activity-strip,
    .container.qs-active .review-bar,
    .container.qs-active .tip-banner,
    .container.qs-active .chat-box,
    .container.qs-active .recovery-banner {
      display: none !important;
    }
    .quote-settings-panel .qs-scroll {
      display: flex;
      flex-direction: column;
      gap: 7px;
      flex: 1 1 auto;
      min-height: 0;
      overflow-y: auto;
      overflow-x: hidden;
      scrollbar-gutter: stable;
      padding-right: 2px;
      contain: layout style;
    }
    /* This is the scroller; nothing inside it may be squeezed to make things "fit". Without
       this, a flex column silently shrinks its children when the panel is short - which is
       exactly how the agent checklist ended up 0px tall and appeared to have vanished. Anything
       that does not fit now pushes the panel taller and .qs-scroll scrolls, which is visible
       and recoverable, instead of quietly deleting a control from view. */
    .quote-settings-panel .qs-scroll > * { flex-shrink: 0; }
    .quote-settings-panel .qs-title { font-size: 11.5px; font-weight: 600; color: #9cc7e8; }
    .quote-settings-panel .qs-row { display: flex; align-items: center; justify-content: space-between; gap: 8px; }
    .quote-settings-panel .qs-row label { font-size: 11.5px; color: #d8d8de; }
    .quote-settings-panel .qs-row .quote-margin-input { width: 90px; text-align: right; }
    .quote-settings-panel .qs-hint { font-size: 10px; color: #8a8a94; font-style: italic; line-height: 1.4; }
    .quote-settings-panel .qs-stats-box {
      font-size: 10.5px;
      color: #b8d8b0;
      line-height: 1.5;
      background-color: #202a20;
      border: 1px solid #35452f;
      border-radius: 6px;
      padding: 6px 8px;
    }
    .quote-settings-panel .qs-divider { border-top: 1px solid #33333a; margin: 2px 0; }
    .quote-settings-panel .qs-title-hint { font-weight: 400; color: #8a8a94; font-size: 10px; }
    .quote-settings-panel .qs-mode-row { display: flex; flex-direction: column; gap: 4px; }
    .quote-settings-panel .qs-tier-rates {
      display: none;
      flex-direction: column;
      gap: 7px;
      margin-top: 2px;
      padding: 8px;
      background-color: #26262c;
      border: 1px solid #33333a;
      border-radius: 6px;
    }
    .quote-settings-panel .qs-tier-rates.visible { display: flex; }
    .quote-settings-panel .qs-radio {
      display: flex;
      align-items: center;
      gap: 6px;
      font-size: 11px;
      color: #d8d8de;
      cursor: pointer;
    }
    .quote-settings-panel .qs-radio input { accent-color: #4fc1ff; cursor: pointer; }
    .quote-settings-panel .qs-agent-row {
      display: flex;
      align-items: center;
      gap: 6px;
      font-size: 11px;
      color: #d8d8de;
      cursor: pointer;
      padding: 2px 0;
    }
    .quote-settings-panel .qs-agent-row input { accent-color: #4fc1ff; cursor: pointer; }
    .quote-settings-panel .qs-agent-all {
      font-weight: 600;
      color: #9cc7e8;
      border-bottom: 1px dashed #33333a;
      padding-bottom: 5px;
      margin-bottom: 1px;
    }
    /* The agent list is NOT its own scroller any more - .qs-scroll above already scrolls the
       whole panel, and a scroll box inside a scroll box is both awkward to use and what made
       this list disappear: an element with overflow:auto is fully shrinkable inside a flex
       column, so as this panel gained content (AI cost stats, pricing-mode radios, four tier
       inputs) flexbox squeezed the agent list down to zero height. It was still in the DOM,
       just 0px tall, which reads as "the agents are gone". Letting it size to its content and
       protecting every panel child from shrinking (rule above) keeps all ten agents reachable
       however short the sidebar gets. */
    .quote-settings-panel .qs-agent-list {
      padding-right: 2px;
    }
    .quote-settings-panel .qs-actions {
      display: flex;
      gap: 6px;
      flex-shrink: 0;
      margin-top: 8px;
      padding-top: 8px;
      border-top: 1px solid #33333a;
    }
    .quote-settings-panel .qs-actions button { width: auto; flex: 1 1 auto; padding: 6px 0; font-size: 11px; }
    .quote-settings-panel .qs-back-btn { background: linear-gradient(135deg, #5a5a63, #45454c); border-color: #45454c; }
    .quote-settings-panel .qs-back-btn:hover { background: linear-gradient(135deg, #6b6b75, #45454c); }
    .quote-block { margin-bottom: 8px; }
    .quote-block .quote-block-title { font-weight: 600; color: #dcdcaa; display: block; margin-bottom: 2px; }
    .quote-row { font-size: 11px; color: #c9c9c9; display: block; margin-top: 2px; }
    .quote-final { color: #89d185; font-weight: 600; }
    .quote-rate-compare {
      color: #dcdcaa;
      font-weight: 600;
      background-color: #2a2a1e;
      border: 1px solid #45452f;
      border-radius: 4px;
      padding: 3px 6px;
      margin-top: 2px;
    }
    .quote-note { font-size: 10px; color: #8a8a92; font-style: italic; display: block; margin: 6px 0; line-height: 1.4; }
    .quote-actions { display: flex; gap: 6px; margin-top: 8px; }
    .quote-actions button { flex: 1; margin-top: 0; }
    .footer {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 6px;
      padding: 5px 8px;
      margin: 0 8px 8px 8px;
      background: linear-gradient(135deg, #1f1f24, #17171b);
      border-top: 1px solid #33333a;
      border-radius: 6px;
      font-size: 10px;
      flex-shrink: 0;
      flex-wrap: nowrap;
      color: #ffffff;
      visibility: visible;
      box-shadow: 0 2px 6px rgba(0,0,0,0.25);
      contain: layout style;
    }
    .footer-info {
      display: flex;
      align-items: center;
      gap: 6px;
      flex: 1 1 auto;
      min-width: 0;
      overflow: hidden;
    }
    .footer-item {
      white-space: nowrap;
      color: #ffffff;
      overflow: hidden;
      text-overflow: ellipsis;
      min-width: 0;
    }
    .footer-controls {
      display: flex;
      align-items: center;
      justify-content: flex-end;
      flex-wrap: nowrap;
      gap: 5px;
      flex-shrink: 0;
    }
    .yolo-badge, .estimate-btn-footer {
      background-color: #2a2a2e;
      color: #ffffff;
      border: 1px solid #3c3c3c;
    }
    .stop-btn-footer {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      width: 28px;
      height: 28px;
      flex-shrink: 0;
      padding: 0;
      background-color: #d32f2f;
      color: #ffffff;
      border: 1px solid #a1272f;
      border-radius: 50%;
      cursor: pointer;
      font-size: 7.5px;
      font-weight: 700;
      letter-spacing: 0.2px;
      white-space: nowrap;
      box-shadow: 0 0 0 2px rgba(211,47,47,0.25);
    }
    .stop-btn-footer:hover { background-color: #f44336; border-color: #d32f2f; }
    .stop-btn-footer:disabled { opacity: 0.4; cursor: not-allowed; box-shadow: none; }
    .estimate-btn-footer {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      height: 18px;
      padding: 0 6px;
      border-radius: 4px;
      cursor: pointer;
      font-size: 9px;
      font-weight: 400;
      white-space: nowrap;
      box-shadow: none;
    }
    .estimate-btn-footer:hover { background-color: #383840; border-color: #4a4a52; }
    .estimate-btn-footer:active { background-color: #2f2f36; }
    .yolo-badge {
      display: inline-flex;
      align-items: center;
      height: 18px;
      padding: 0 5px;
      border-radius: 4px;
      font-size: 8px;
      font-weight: 600;
      white-space: nowrap;
      visibility: visible;
    }
    #taskPanel { 
      margin: 0 8px; 
      visibility: visible; 
      flex-shrink: 0;
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    .accordion-header {
      background-color: #2d2d2d;
      padding: 6px 8px;
      border-radius: 3px;
      cursor: pointer;
      user-select: none;
      font-weight: 500;
      font-size: 12px;
      color: #ffffff;
      border: 1px solid #3e3e42;
      visibility: visible;
      display: none;
    }
    .accordion-header:hover { background-color: #383838; }
    .accordion-body {
      display: none;
      padding: 6px 8px;
      background-color: #1e1e1e;
      border-radius: 3px;
      font-size: 11px;
      margin-top: 3px;
      border: 1px solid #3e3e42;
      color: #ffffff;
      visibility: visible;
    }
    .accordion-body.active { display: block; max-height: 40vh; overflow-y: auto; }
    .todo-head {
      font-weight: 600;
      color: #ffffff;
      padding-bottom: 4px;
      margin-bottom: 4px;
      border-bottom: 1px solid #3e3e42;
    }
    .todo-row { padding: 2px 0; color: #cccccc; }
    .todo-row.todo-done { color: #6a9955; }
    .session-refresh {
      float: right;
      cursor: pointer;
      font-size: 11px;
      color: #9d9d9d;
      padding: 0 4px;
      border-radius: 3px;
      user-select: none;
    }
    .session-refresh:hover { color: #ffffff; background-color: #333338; }

    /* Tier-mix summary table inside a Project Quote card. */
    .quote-tier-table {
      width: 100%;
      border-collapse: collapse;
      margin: 8px 0 6px 0;
      font-size: 11px;
      color: #d4d4d4;
    }
    .quote-tier-table th {
      text-align: left;
      font-weight: 600;
      color: #ffffff;
      padding: 4px 6px;
      border-bottom: 1px solid #4a4a50;
      white-space: nowrap;
    }
    .quote-tier-table td {
      padding: 4px 6px;
      border-bottom: 1px solid #303035;
      white-space: nowrap;
    }
    .quote-tier-table td.num { text-align: right; font-variant-numeric: tabular-nums; }
    .quote-tier-table tr.tier-empty td { color: #6f6f76; }

    /* Live activity strip - only rendered while a job is actually running. */
    .activity-strip {
      display: none;
      align-items: center;
      gap: 8px;
      flex-shrink: 0;
      margin-top: 4px;
      padding: 6px 10px;
      border-radius: 4px;
      background: linear-gradient(90deg, #1e2a1e 0%, #24352a 50%, #1e2a1e 100%);
      background-size: 200% 100%;
      border: 1px solid #2f4a35;
      font-size: 11px;
      color: #cfe8d4;
      /* The sweep is what sells "still working" during a long silent model call. */
      animation: activitySweep 2.4s linear infinite;
    }
    .activity-strip.visible { display: flex; }
    @keyframes activitySweep {
      0%   { background-position: 200% 0; }
      100% { background-position: -200% 0; }
    }
    .activity-dots { display: inline-flex; gap: 3px; flex-shrink: 0; }
    .activity-dots i {
      width: 5px; height: 5px; border-radius: 50%;
      background-color: #4ec96a;
      display: inline-block;
      animation: activityBounce 1.2s ease-in-out infinite;
    }
    .activity-dots i:nth-child(2) { animation-delay: 0.15s; }
    .activity-dots i:nth-child(3) { animation-delay: 0.3s; }
    @keyframes activityBounce {
      0%, 80%, 100% { opacity: 0.25; transform: translateY(0); }
      40%           { opacity: 1;    transform: translateY(-3px); }
    }
    .activity-text {
      flex: 1 1 auto;
      min-width: 0;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    .activity-time {
      flex-shrink: 0;
      color: #8fbf9a;
      font-variant-numeric: tabular-nums;
    }
    .file-badge {
      display: flex;
      align-items: center;
      gap: 6px;
      background-color: #2d2d2d;
      padding: 4px 5px 4px 8px;
      border-radius: 4px;
      margin-right: 4px;
      margin-bottom: 5px;
      font-size: 11px;
      border: 1px solid #3e3e42;
      color: #ffffff;
      visibility: visible;
    }
    .file-badge .file-path { flex: 1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .file-agent { color: #8a8a94; font-size: 10px; font-weight: 400; }
    .file-badge .file-diff { color: #89d185; white-space: nowrap; }
    .file-badge .file-diff .del { color: #f48771; }
    .file-actions { display: flex; gap: 4px; flex-shrink: 0; }
    .file-actions button {
      width: auto;
      padding: 2px 7px;
      font-size: 10.5px;
      border-radius: 4px;
    }
    .file-actions .keep-file-btn { background: linear-gradient(135deg, #109244, #0c6f33); border-color: #0c6f33; }
    .file-actions .keep-file-btn:hover { background: linear-gradient(135deg, #14a84e, #0c6f33); }
    .file-actions .undo-file-btn { background: linear-gradient(135deg, #5a5a63, #45454c); border-color: #45454c; }
    .file-actions .undo-file-btn:hover { background: linear-gradient(135deg, #6b6b75, #45454c); }
    .file-badge.kept { opacity: 0.65; }
    .file-badge.kept .file-actions button { display: none; }
    .file-badge.reverted { opacity: 0.5; text-decoration: line-through; }
    .file-badge.reverted .file-actions button { display: none; }
    .review-bar {
      display: none;
      align-items: center;
      gap: 8px;
      flex-shrink: 0;
      margin: 6px 8px 0 8px;
      padding: 6px 8px;
      background-color: #252529;
      border: 1px solid #3e3e42;
      border-radius: 6px;
      font-size: 11px;
      color: #d8d8de;
    }
    .review-bar.visible { display: flex; }
    .review-summary { flex: 1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .review-summary .add { color: #89d185; }
    .review-summary .del { color: #f48771; }
    .review-bar .review-actions { display: flex; gap: 5px; flex-shrink: 0; }
    .review-bar button { width: auto; padding: 3px 12px; font-size: 10.5px; border-radius: 4px; }
    .review-bar .review-keep-btn { background: linear-gradient(135deg, #109244, #0c6f33); border-color: #0c6f33; }
    .review-bar .review-keep-btn:hover { background: linear-gradient(135deg, #14a84e, #0c6f33); }
    .review-bar .review-undo-btn { background: linear-gradient(135deg, #5a5a63, #45454c); border-color: #45454c; }
    .review-bar .review-undo-btn:hover { background: linear-gradient(135deg, #6b6b75, #45454c); }
    .recovery-banner {
      display: none;
      margin: 0 8px 8px 8px;
      padding: 10px;
      background: linear-gradient(135deg, #2b2410, #1f1c10);
      border: 1px solid #dcdcaa;
      border-radius: 8px;
      color: #f0e6b8;
      font-size: 12px;
      flex-shrink: 0;
    }
    .recovery-banner.visible { display: block; }
    .recovery-banner .recovery-text { display: block; margin-bottom: 8px; }
    .recovery-banner .recovery-actions { display: flex; gap: 8px; }
    .recovery-banner .recovery-actions button { width: auto; padding: 5px 12px; }
    .recovery-banner .resume-btn { background: linear-gradient(135deg, #0e639c, #0a4d7a); border-color: #0a3a63; }
    .recovery-banner .fresh-btn { background: linear-gradient(135deg, #5a5a63, #45454c); border-color: #45454c; }
    .chat-msg-user {
      background-color: #2d2d2d;
      color: #ffffff;
      padding: 8px 10px;
      border-radius: 3px;
      margin-bottom: 6px;
      word-wrap: break-word;
      border-left: 3px solid #007acc;
      border: 1px solid #3e3e42;
      visibility: visible;
    }
    .status-message {
      background-color: transparent;
      color: #9a9aa2;
      padding: 10px 2px;
      margin-bottom: 6px;
      font-weight: 400;
      font-size: 12.5px;
      letter-spacing: 0.1px;
      visibility: visible;
    }
    .tip-banner {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 8px;
      margin: 0 8px;
      padding: 6px 10px;
      border-radius: 8px;
      background-color: #17202b;
      border: 1px solid #274357;
      color: #9cc7e8;
      font-size: 11px;
      flex-shrink: 0;
    }
    .tip-banner.hidden { display: none; }
    .tip-banner .tip-close {
      cursor: pointer;
      color: #6c93ab;
      font-size: 13px;
      line-height: 1;
      flex-shrink: 0;
      padding: 0 2px;
      user-select: none;
    }
    .tip-banner .tip-close:hover { color: #9cc7e8; }
    .session-list-heading {
      font-size: 10.5px;
      font-weight: 600;
      color: #7c7c86;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      margin: 2px 2px 8px 2px;
    }
    .session-list {
      display: flex;
      flex-direction: column;
      gap: 6px;
    }
    .session-item {
      padding: 8px 10px;
      border-radius: 8px;
      background-color: #202024;
      border: 1px solid #2e2e34;
    }
    .session-title {
      font-size: 12px;
      color: #e6e6e6;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      margin-bottom: 4px;
    }
    .session-meta {
      display: flex;
      align-items: center;
      gap: 8px;
      font-size: 10.5px;
      color: #8a8a94;
    }
    .session-diff .add { color: #89d185; }
    .session-diff .del { color: #f48771; margin-left: 3px; }
    .session-time { margin-left: auto; white-space: nowrap; }
    .session-fail {
      color: #ff8a8a;
      font-weight: 600;
      font-size: 9.5px;
      text-transform: uppercase;
      letter-spacing: 0.3px;
    }
    .icon-toolbar {
      display: flex;
      align-items: center;
      gap: 5px;
      width: 100%;
    }
    .icon-toolbar .icon-btn {
      flex: 0 0 auto;
      width: 24px;
      height: 24px;
      min-width: 24px;
      padding: 0;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      background-color: #2a2a2e;
      color: #d8d8de;
      border: 1px solid #3c3c3c;
      border-radius: 6px;
      font-size: 11px;
      box-shadow: none;
    }
    .icon-toolbar .icon-btn:hover { background-color: #383840; border-color: #4a4a52; }
    .icon-toolbar .icon-btn:active { background-color: #2f2f36; }
    .icon-toolbar .spacer { flex: 1 1 auto; }
    .icon-toolbar .send-btn {
      width: 26px;
      height: 26px;
      min-width: 26px;
      border-radius: 50%;
      background: linear-gradient(135deg, #0e639c, #0a4d7a);
      color: #ffffff;
      border: 1px solid #0a3a63;
      font-size: 12px;
      box-shadow: 0 1px 3px rgba(0,0,0,0.3);
    }
    .icon-toolbar .send-btn:hover { background: linear-gradient(135deg, #1177bb, #0d5299); }
    .icon-toolbar .send-btn:active { background-color: #0d4a82; }
  </style>
</head>
<body>
  <div class="container" style="background-color: #1a1a1e;">
    <h1>DAI Flash Agent<span style="display:flex; align-items:center; gap:6px; flex-shrink:0;"><button id="chatToggleBtn" class="chat-toggle-btn" title="Toggle Chat mode - talk to Sonnet without starting a job">💬 Chat</button><span class="status-badge" id="statusBadge" title="Agent status"><span class="status-dot" id="statusDot"></span><span id="statusText">Idle</span></span></span></h1>

    <div class="recovery-banner" id="recoveryBanner">
      <span class="recovery-text" id="recoveryText">⚠️ An interrupted job was detected.</span>
      <div class="recovery-actions">
        <button class="resume-btn" id="resumeJobBtn">▶️ Resume Previous Job</button>
        <button class="fresh-btn" id="startFreshBtn">🆕 Start Fresh</button>
      </div>
    </div>

    <div class="logs-container" id="logs">
      <div class="status-message">Agent progress and live execution logs will appear here.</div>
    </div>

    <!-- Live activity strip. The panel used to go completely still while a model was thinking -
         a single reply can take 30-60s with nothing logged in between - so a running job looked
         indistinguishable from a hung one. This stays pinned above the review bar, names the
         current step, and ticks a timer every second so there is always visible motion. -->
    <div class="activity-strip" id="activityStrip">
      <span class="activity-dots"><i></i><i></i><i></i></span>
      <span class="activity-text" id="activityText">Working…</span>
      <span class="activity-time" id="activityTime"></span>
    </div>

    <div class="accordion-body" id="todoBody"></div>
    <div class="accordion-body" id="filesBody"></div>

    <div class="review-bar" id="reviewBar">
      <span class="review-summary" id="reviewSummary">0 files changed</span>
      <span class="review-actions">
        <button class="review-keep-btn" id="reviewKeepBtn" title="Accept all pending file changes">Keep</button>
        <button class="review-undo-btn" id="reviewUndoBtn" title="Revert all pending file changes">Undo</button>
      </span>
    </div>

    <div class="tip-banner" id="tipBanner">
      <span id="tipText">💡 Tip: describe one file or feature per prompt for the most reliable results.</span>
      <span class="tip-close" id="tipClose" title="Dismiss">×</span>
    </div>

    <div class="chat-box" id="chatBox">
      <div class="prompt-area">
        <div class="model-row">
          <select id="modelSelect" class="model-select" title="Choose AI routing model">
            <option value="auto">✨ Auto</option>
            <option value="deepseek-flash">[Low] DeepSeek V4 Flash | 1M Context | Low Cost ($)</option>
            <option value="deepseek-pro">[High] DeepSeek V4 Pro | 1M Context | High Performance ($$$)</option>
            <option value="haiku">[Low] Claude Haiku | 200K Context | Low Cost ($)</option>
            <option value="gpt-luna">[Low] ChatGPT (GPT-5.6 Luna) | 1M Context | Low Cost ($)</option>
            <option value="sonnet">[Medium] Claude Sonnet | 1M Context | Medium Cost ($$)</option>
            <option value="gpt-terra">[Medium] ChatGPT (GPT-5.6 Terra) | 1M Context | Medium Cost ($$)</option>
            <option value="o4-mini">[High] ChatGPT (o4-mini) | 200K Context | High Reasoning ($$$)</option>
            <option value="opus">[High] Claude Opus | 1M Context | High Cost ($$$)</option>
            <option value="gpt-astra">[Advanced] ChatGPT (GPT-6 Astra) | 1M Context | Advanced Reasoning ($$$$)</option>
            <option value="fable">[Max] Claude Fable | 1M Context | Maximum Cost ($$$$)</option>
          </select>
          <!-- No inline onclick handlers here: this webview's CSP is script-src 'nonce-...',
               which blocks inline event attributes outright. The pills used to carry
               onclick="..." and so silently did nothing when clicked - the counter still
               updated (that runs from the nonce'd script), which made it look like a dead
               button rather than a blocked one. Listeners are attached in the script below. -->
          <div id="taskPanel" class="task-pills" style="display: none;">
            <span class="task-pill" id="todoHeader" title="Click to show the steps in this job">📋 0/3</span>
            <span class="task-pill" id="filesHeader" title="Click to show the files this job touched">📄 0</span>
          </div>
        </div>
        <div class="textarea-wrap">
          <textarea id="promptInput" placeholder="Describe what to build" spellcheck="false"></textarea>
          <span class="enter-icon" id="enterIcon" title="Press Enter to send">⏎</span>
        </div>
        <div class="button-group icon-toolbar">
          <button id="attachBtn" class="icon-btn" title="Attach a large task-list file (5MB+ supported)">➕</button>
          <button id="undoBtn" class="icon-btn" title="Undo last action">↩️</button>
          <button id="clearBtn" class="icon-btn" title="Clear chat history">🗑️</button>
          <span class="spacer"></span>
          <button id="sendBtn" class="icon-btn send-btn" title="Send prompt to agent">➤</button>
        </div>
      </div>
    </div>

    <div class="quote-settings-panel" id="quoteSettingsPanel">
      <div class="qs-scroll" id="qsScroll">
        <div class="qs-title">⚙️ Quote settings</div>
        <div class="qs-row"><label for="qsRate">Rate/hr (INR)</label><input type="number" id="qsRate" class="quote-margin-input" min="0" step="50" /></div>
        <div class="qs-row"><label for="qsProfit">Profit %</label><input type="number" id="qsProfit" class="quote-margin-input" min="0" step="1" /></div>
        <div class="qs-row"><label for="qsGst">GST %</label><input type="number" id="qsGst" class="quote-margin-input" min="0" step="1" /></div>
        <div class="qs-hint" id="qsHint">These 3 values are what "Quote" uses for Base Cost → Fee → GST → Final Quote. Saved automatically as you change them.</div>
        <div class="qs-stats-box" id="qsAiCostStats">📊 Run "Quote" with 0 agents ticked (Auto) at least once to see your real AI cost/hour here.</div>

        <div class="qs-divider"></div>
        <div class="qs-title">Pricing mode</div>
        <div class="qs-mode-row">
          <label class="qs-radio"><input type="radio" name="qsPricingMode" id="qsPricingFlat" value="flat" checked /> 💰 Flat rate (same Rate/hr above for every module)</label>
          <label class="qs-radio"><input type="radio" name="qsPricingMode" id="qsPricingTiered" value="tiered" /> 🎚️ Tier-wise rate (Low/Medium/High/Advanced)</label>
        </div>
        <div class="qs-tier-rates" id="qsTierRatesBlock">
          <div class="qs-row"><label for="qsTierLow">Low tier (₹/hr)</label><input type="number" id="qsTierLow" class="quote-margin-input" min="0" step="50" /></div>
          <div class="qs-row"><label for="qsTierMedium">Medium tier (₹/hr)</label><input type="number" id="qsTierMedium" class="quote-margin-input" min="0" step="50" /></div>
          <div class="qs-row"><label for="qsTierHigh">High tier (₹/hr)</label><input type="number" id="qsTierHigh" class="quote-margin-input" min="0" step="50" /></div>
          <div class="qs-row"><label for="qsTierAdvanced">Advanced tier (₹/hr)</label><input type="number" id="qsTierAdvanced" class="quote-margin-input" min="0" step="50" /></div>
          <div class="qs-hint">Each module is billed at ITS OWN tier's rate (hours × that rate) instead of one flat Rate/hr - so a mix of light/medium/heavy modules genuinely changes the total, like real junior/senior developer rates.</div>
        </div>

        <div class="qs-divider"></div>
        <div class="qs-title">Estimation method</div>
        <div class="qs-mode-row">
          <label class="qs-radio"><input type="radio" name="qsMode" id="qsModeManual" value="manual" checked /> 🧑‍💻 Manual (traditional dev hours)</label>
          <label class="qs-radio"><input type="radio" name="qsMode" id="qsModeAi" value="ai-assisted" /> 🤖 AI-Agent Assisted (fewer hours)</label>
        </div>

        <div class="qs-divider"></div>
        <div class="qs-title">Agent(s) to estimate with <span class="qs-title-hint">(none ticked = Auto)</span></div>
        <label class="qs-agent-row qs-agent-all"><input type="checkbox" id="qsAgentAll" /> Tick all</label>
        <div class="qs-agent-list" id="qsAgentList">
          <label class="qs-agent-row"><input type="checkbox" class="qs-agent-cb" value="haiku" /> Claude Haiku ($)</label>
          <label class="qs-agent-row"><input type="checkbox" class="qs-agent-cb" value="gpt-luna" /> ChatGPT (GPT-5.6 Luna) ($)</label>
          <label class="qs-agent-row"><input type="checkbox" class="qs-agent-cb" value="deepseek-flash" /> DeepSeek V4 Flash ($)</label>
          <label class="qs-agent-row"><input type="checkbox" class="qs-agent-cb" value="sonnet" /> Claude Sonnet ($$)</label>
          <label class="qs-agent-row"><input type="checkbox" class="qs-agent-cb" value="gpt-terra" /> ChatGPT (GPT-5.6 Terra) ($$)</label>
          <label class="qs-agent-row"><input type="checkbox" class="qs-agent-cb" value="deepseek-pro" /> DeepSeek V4 Pro ($$$)</label>
          <label class="qs-agent-row"><input type="checkbox" class="qs-agent-cb" value="o4-mini" /> ChatGPT (o4-mini) ($$$)</label>
          <label class="qs-agent-row"><input type="checkbox" class="qs-agent-cb" value="opus" /> Claude Opus ($$$)</label>
          <label class="qs-agent-row"><input type="checkbox" class="qs-agent-cb" value="gpt-astra" /> ChatGPT (GPT-6 Astra) ($$$$)</label>
          <label class="qs-agent-row"><input type="checkbox" class="qs-agent-cb" value="fable" /> Claude Fable ($$$$)</label>
        </div>
        <div class="qs-hint" id="qsAgentHint">0 agents ticked → Quote uses 1 auto-picked capable model (1 real AI call).</div>
      </div>

      <div class="qs-actions">
        <button id="qsBackBtn" class="qs-back-btn">← Back</button>
      </div>
    </div>

    <div class="footer">
      <div class="footer-info">
        <span class="footer-item" title="This extension runs entirely on your machine">🖥️ Local</span>
        <span class="footer-item">💰 Cost: $<span id="costLabel">0.0000</span></span>
        <span class="footer-item">📊 Tokens: <span id="tokenLabel">0 in / 0 out</span></span>
      </div>
      <div class="footer-controls">
        <span class="yolo-badge">🟢 Auto-Approve: ON</span>
        <button id="reportBtn" class="estimate-btn-footer" title="Which agent actually does the work first time, and at what cost">📊 Report</button>
        <button id="estimateBtn" class="estimate-btn-footer" title="Estimate AI API cost of running this prompt as a job">Estimate</button>
        <button id="projectQuoteBtn" class="estimate-btn-footer" title="Estimate a client-billable project quote from engineering hours (makes one real AI call)">Quote</button>
        <button id="quoteSettingsBtn" class="estimate-btn-footer" title="Set the Rate/hr, Profit % and GST % that Quote uses">⚙️</button>
        <button id="stopBtn" class="stop-btn-footer" title="Stop current execution">STOP</button>
      </div>
    </div>
  </div>

  <script nonce="${nonce}">
    try {
      console.log('[DAI-Flash] ✅ Webview loading...');
      console.log('[DAI-Flash] Document ready state:', document.readyState);
      console.log('[DAI-Flash] Body element:', !!document.body);
      
      let vscode;
      try {
        vscode = acquireVsCodeApi();
        console.log('[DAI-Flash] ✅ VS Code API acquired successfully');
      } catch (err) {
        console.error('[DAI-Flash] ❌ Failed to acquire VS Code API:', err);
        vscode = null;
      }

      function extLog(msg) {
        console.log(msg);
        try {
          if (vscode) vscode.postMessage({ command: 'clientLog', text: msg });
        } catch (e) {}
      }

      let isRunning = false;
      // Kept for the job report. Neither of these survives in the jobComplete payload, and a
      // report that cannot say what was asked or how long it took is not much of a report.
      let lastSubmittedPrompt = '';
      let jobStartedAt = 0;
      let lastEstimateUsd = 0;
      let lastEstimateAgent = '';

      // Verify DOM elements exist
      const promptInput = document.getElementById('promptInput');
      const sendBtn = document.getElementById('sendBtn');
      const enterIcon = document.getElementById('enterIcon');
      const attachBtn = document.getElementById('attachBtn');
      const estimateBtn = document.getElementById('estimateBtn');
      const projectQuoteBtn = document.getElementById('projectQuoteBtn');
      const quoteSettingsBtn = document.getElementById('quoteSettingsBtn');
      const quoteSettingsPanel = document.getElementById('quoteSettingsPanel');
      const qsRate = document.getElementById('qsRate');
      const qsProfit = document.getElementById('qsProfit');
      const qsGst = document.getElementById('qsGst');
      const qsHint = document.getElementById('qsHint');
      const qsAgentAll = document.getElementById('qsAgentAll');
      const qsAgentList = document.getElementById('qsAgentList');
      const qsAgentHint = document.getElementById('qsAgentHint');
      const qsBackBtn = document.getElementById('qsBackBtn');
      const qsTierRatesBlock = document.getElementById('qsTierRatesBlock');
      const qsTierLow = document.getElementById('qsTierLow');
      const qsTierMedium = document.getElementById('qsTierMedium');
      const qsTierHigh = document.getElementById('qsTierHigh');
      const qsTierAdvanced = document.getElementById('qsTierAdvanced');

      function getQuoteMode() {
        const checked = document.querySelector('input[name="qsMode"]:checked');
        return checked && checked.value === 'ai-assisted' ? 'ai-assisted' : 'manual';
      }
      function getPricingMode() {
        const checked = document.querySelector('input[name="qsPricingMode"]:checked');
        return checked && checked.value === 'tiered' ? 'tiered' : 'flat';
      }
      function updateTierRatesVisibility() {
        if (!qsTierRatesBlock) return;
        qsTierRatesBlock.classList.toggle('visible', getPricingMode() === 'tiered');
      }
      document.querySelectorAll('input[name="qsPricingMode"]').forEach((el) => {
        el.addEventListener('change', () => {
          updateTierRatesVisibility();
          autoSaveQuoteSettings();
        });
      });
      function getTickedAgentIds() {
        if (!qsAgentList) return [];
        return Array.from(qsAgentList.querySelectorAll('.qs-agent-cb:checked')).map((cb) => cb.value);
      }
      function updateAgentHint() {
        if (!qsAgentHint) return;
        const n = getTickedAgentIds().length;
        qsAgentHint.textContent = n === 0
          ? '0 agents ticked → Quote uses 1 auto-picked capable model (1 real AI call).'
          : n === 1
            ? '1 agent ticked → Quote forces that exact agent to scope the whole project (1 real AI call).'
            : n + ' agents ticked → 1 real AI call scopes the project, then each module is routed (🔀 light→cheap, heavy→top) to the cheapest capable ticked agent - one combined quote.';
      }
      if (qsAgentList) {
        qsAgentList.querySelectorAll('.qs-agent-cb').forEach((cb) => {
          cb.addEventListener('change', () => {
            const all = qsAgentList.querySelectorAll('.qs-agent-cb');
            const checked = qsAgentList.querySelectorAll('.qs-agent-cb:checked');
            if (qsAgentAll) qsAgentAll.checked = all.length > 0 && all.length === checked.length;
            updateAgentHint();
          });
        });
      }
      if (qsAgentAll) {
        qsAgentAll.addEventListener('change', () => {
          if (!qsAgentList) return;
          qsAgentList.querySelectorAll('.qs-agent-cb').forEach((cb) => { cb.checked = qsAgentAll.checked; });
          updateAgentHint();
        });
      }
      const undoBtn = document.getElementById('undoBtn');
      const clearBtn = document.getElementById('clearBtn');
      const stopBtn = document.getElementById('stopBtn');
      const logsContainer = document.getElementById('logs');
      const modelSelect = document.getElementById('modelSelect');
      const chatBox = document.getElementById('chatBox');
      const recoveryBanner = document.getElementById('recoveryBanner');
      const recoveryText = document.getElementById('recoveryText');
      const resumeJobBtn = document.getElementById('resumeJobBtn');
      const startFreshBtn = document.getElementById('startFreshBtn');
      const tipBanner = document.getElementById('tipBanner');
      const tipText = document.getElementById('tipText');
      const tipClose = document.getElementById('tipClose');
      const chatToggleBtn = document.getElementById('chatToggleBtn');

      // Chat mode: OFF by default - the describe box behaves exactly as before (Enter starts
      // a real agent job). Toggling this ON redirects the SAME box to a plain conversation
      // with Sonnet instead; toggling it back OFF returns to the normal agent-job behavior.
      let chatMode = false;
      if (chatToggleBtn) {
        chatToggleBtn.addEventListener('click', () => {
          chatMode = !chatMode;
          chatToggleBtn.classList.toggle('active', chatMode);
          if (promptInput) {
            promptInput.placeholder = chatMode ? 'Ask Sonnet anything...' : 'Describe what to build';
          }
          extLog('[DAI-Flash] 💬 Chat mode ' + (chatMode ? 'ON' : 'OFF'));
        });
      }

      function sendChatMessage(prompt) {
        try {
          if (!logsContainer) return;
          const div = document.createElement('div');
          div.className = 'chat-bubble-user';
          div.textContent = '💬 ' + prompt;
          logsContainer.appendChild(div);
          logsContainer.scrollTop = logsContainer.scrollHeight;
        } catch (err) {
          console.error('[DAI-Flash] Error appending chat message:', err);
        }
        if (vscode) vscode.postMessage({ command: 'chatSend', prompt });
      }

      function appendChatThinking() {
        if (!logsContainer) return;
        const div = document.createElement('div');
        div.className = 'chat-thinking';
        div.id = 'chatThinkingIndicator';
        div.textContent = '💬 Sonnet is thinking...';
        logsContainer.appendChild(div);
        logsContainer.scrollTop = logsContainer.scrollHeight;
      }

      function appendChatReply(data) {
        try {
          if (!logsContainer) return;
          const thinking = document.getElementById('chatThinkingIndicator');
          if (thinking) thinking.remove();

          if (data.error) {
            const errDiv = document.createElement('div');
            errDiv.className = 'log-line error';
            errDiv.textContent = '⚠️ Chat failed: ' + data.error;
            logsContainer.appendChild(errDiv);
            logsContainer.scrollTop = logsContainer.scrollHeight;
            return;
          }

          const div = document.createElement('div');
          div.className = 'chat-bubble-assistant';
          div.textContent = '🧠 ' + (data.reply || '(empty reply)');
          logsContainer.appendChild(div);

          if (data.agentTask) {
            const btn = document.createElement('button');
            btn.className = 'send-to-agent-btn';
            btn.textContent = '➡️ Send to Agent: ' + (data.agentTask.length > 50 ? data.agentTask.slice(0, 50) + '…' : data.agentTask);
            btn.title = data.agentTask;
            btn.addEventListener('click', () => {
              btn.disabled = true;
              btn.textContent = '✅ Sent to Agent';
              if (!isRunning) {
                isRunning = true;
                if (stopBtn) stopBtn.disabled = false;
                setRunningGlow(true);
                setAgentStatus('running');
              }
              if (vscode) vscode.postMessage({ command: 'run', prompt: data.agentTask, model: 'auto' });
            });
            logsContainer.appendChild(btn);
          }

          logsContainer.scrollTop = logsContainer.scrollHeight;
        } catch (err) {
          console.error('[DAI-Flash] Error appending chat reply:', err);
        }
      }

      const TIPS = [
        '💡 Tip: describe one file or feature per prompt for the most reliable results.',
        '💡 Tip: mention the exact file path if you want an existing file edited instead of a new one created.',
        '💡 Tip: use Estimate to see the cost across providers before running a prompt.',
        '💡 Tip: pick a specific model from the dropdown to override Auto routing for this one prompt.',
        '💡 Tip: set a monthly budget cap in Settings → DAI Flash to get a warning before overspending.',
      ];
      if (tipText) {
        tipText.textContent = TIPS[Math.floor(Math.random() * TIPS.length)];
      }
      if (tipClose && tipBanner) {
        tipClose.addEventListener('click', () => tipBanner.classList.add('hidden'));
      }

      // ---- Live activity strip -------------------------------------------------------------
      // Driven off the log stream rather than new backend events: every meaningful step the
      // runner takes already emits a log line, so the strip re-labels itself for free and keeps
      // working for any future step without needing a matching change here.
      let activityTicker = null;
      let activityStepStart = 0;
      let activityJobStart = 0;

      function formatDuration(ms) {
        const s = Math.max(0, Math.floor(ms / 1000));
        if (s < 60) return s + 's';
        const m = Math.floor(s / 60);
        return m + 'm ' + (s % 60) + 's';
      }

      function paintActivityTime() {
        const el = document.getElementById('activityTime');
        if (!el) return;
        const now = Date.now();
        el.textContent = formatDuration(now - activityStepStart) + ' · total ' + formatDuration(now - activityJobStart);
      }

      // Turns a raw runner log line into a plain "what is happening now" phrase. Anything it
      // does not recognise is shown as-is, so an unmapped step still reads sensibly.
      function activityLabelFor(raw) {
        const t = String(raw || '').trim();
        if (!t) return null;
        // Parsed with plain string ops, deliberately not a regex: this whole script lives inside
        // a TypeScript template literal, where a backslash is an escape sequence, so an escaped
        // bracket in a pattern is silently emitted as a bare bracket - changing the pattern's
        // capture groups with no compile error to warn you. Plain indexOf also handles model
        // labels that themselves contain brackets, such as ChatGPT (GPT-6 Astra), which a naive
        // pattern would split in the wrong place.
        const cIdx = t.indexOf('Calling ');
        const aIdx = t.indexOf('(attempt ');
        if (cIdx !== -1 && aIdx > cIdx) {
          const who = t.slice(cIdx + 8, aIdx).trim();
          const rest = t.slice(aIdx + 9);
          const close = rest.indexOf(')');
          const att = (close === -1 ? rest : rest.slice(0, close)).trim();
          if (who) return '✍️ ' + who + ' is writing the code — attempt ' + att;
        }
        if (t.indexOf('responded') !== -1) return '📥 Reading the reply and checking it…';
        if (t.indexOf('SEARCH/REPLACE block') !== -1) return '🩹 Applying the edit to the file…';
        if (t.indexOf('restate the task') !== -1) return '🧑‍🏫 Team lead is simplifying the instructions…';
        if (t.indexOf('rewrote the instructions') !== -1) return '📝 Handing clearer instructions back…';
        if (t.indexOf('escalating') !== -1 || t.indexOf('Escalat') !== -1) return '⬆️ Moving up to a stronger agent…';
        if (t.indexOf('quality gate') !== -1 || t.indexOf('Quality gate') !== -1) return '🧪 Running compile, lint and tests…';
        if (t.indexOf('Writing') !== -1 || t.indexOf('writing') !== -1) return '💾 Saving the file…';
        return t.length > 90 ? t.slice(0, 89) + '…' : t;
      }

      function setActivity(raw) {
        const strip = document.getElementById('activityStrip');
        const text = document.getElementById('activityText');
        if (!strip || !text || !strip.classList.contains('visible')) return;
        const label = activityLabelFor(raw);
        if (!label) return;
        text.textContent = label;
        activityStepStart = Date.now(); // each new step restarts its own clock
        paintActivityTime();
      }

      function startActivity() {
        const strip = document.getElementById('activityStrip');
        const text = document.getElementById('activityText');
        if (!strip) return;
        activityJobStart = Date.now();
        activityStepStart = activityJobStart;
        if (text) text.textContent = '🚀 Starting up — picking the right agent…';
        strip.classList.add('visible');
        paintActivityTime();
        if (activityTicker) clearInterval(activityTicker);
        activityTicker = setInterval(paintActivityTime, 1000);
      }

      function stopActivity() {
        const strip = document.getElementById('activityStrip');
        if (strip) strip.classList.remove('visible');
        if (activityTicker) {
          clearInterval(activityTicker);
          activityTicker = null;
        }
      }

      // Single hook: every start and every stop in this webview already routes through here,
      // so the strip can never be left running after a job ends.
      function setRunningGlow(running) {
        if (chatBox) chatBox.classList.toggle('active-glow', running);
        if (running) startActivity();
        else stopActivity();
      }

      // Header live status badge: 'idle' | 'running' | 'error'
      function setAgentStatus(state, detail) {
        const badge = document.getElementById('statusBadge');
        const text = document.getElementById('statusText');
        if (!badge || !text) return;
        badge.classList.remove('running', 'error');
        if (state === 'running') {
          badge.classList.add('running');
          text.textContent = 'In Progress';
        } else if (state === 'error') {
          badge.classList.add('error');
          text.textContent = 'Error';
        } else {
          text.textContent = 'Idle';
        }
        badge.title = detail || ('Agent status: ' + text.textContent);
      }

      console.log('[DAI-Flash] 📋 DOM elements verification:');
      console.log('[DAI-Flash]   ✓ promptInput:', !!promptInput, promptInput?.id);
      console.log('[DAI-Flash]   ✓ sendBtn:', !!sendBtn, sendBtn?.id);
      console.log('[DAI-Flash]   ✓ estimateBtn:', !!estimateBtn, estimateBtn?.id);
      console.log('[DAI-Flash]   ✓ undoBtn:', !!undoBtn, undoBtn?.id);
      console.log('[DAI-Flash]   ✓ clearBtn:', !!clearBtn, clearBtn?.id);
      console.log('[DAI-Flash]   ✓ stopBtn:', !!stopBtn, stopBtn?.id);
      console.log('[DAI-Flash]   ✓ logsContainer:', !!logsContainer, logsContainer?.id);

      if (!promptInput || !sendBtn || !logsContainer) {
        console.error('[DAI-Flash] ❌ Critical DOM element missing! UI may not work correctly.');
        extLog('[DAI-Flash] ❌ Critical DOM element missing! UI may not work correctly.');
      } else {
        console.log('[DAI-Flash] ✅ All critical DOM elements found');
        extLog('[DAI-Flash] ✅ All critical DOM elements found');
      }

      // Send Button - allowed even while a job is running; the extension host queues it automatically
      if (sendBtn) {
        sendBtn.addEventListener('click', () => {
          console.log('[DAI-Flash] 🚀 Send button clicked');
          const prompt = promptInput?.value?.trim();
          if (!prompt) {
            console.log('[DAI-Flash] ⚠️  Send blocked: empty prompt');
            return;
          }

          // Chat mode: talk to Sonnet only - no job starts, isRunning/queue untouched.
          // The "thinking..." indicator is added when the 'chatThinking' message comes back
          // from the extension host (not here) so there's only ever one of it in the DOM.
          if (chatMode) {
            sendChatMessage(prompt);
            if (promptInput) promptInput.value = '';
            return;
          }

          if (!isRunning) {
            isRunning = true;
            if (stopBtn) stopBtn.disabled = false;
            setRunningGlow(true);
            setAgentStatus('running');
          }
          if (recoveryBanner) recoveryBanner.classList.remove('visible');

          appendUserMessage(prompt);
          if (promptInput) promptInput.value = '';
          // Remembered for the job report: what was asked is the one thing that makes the rest
          // of the numbers mean anything, and it is nowhere in the jobComplete payload.
          lastSubmittedPrompt = prompt;
          jobStartedAt = Date.now();
          if (vscode) {
            console.log('[DAI-Flash] 📤 Posting run message to extension');
            vscode.postMessage({ command: 'run', prompt, model: modelSelect ? modelSelect.value : 'auto' });
          }
        });
      }

      // Enter (without Shift) submits, mirroring the enter-icon hint inside the textarea
      if (promptInput && sendBtn) {
        promptInput.addEventListener('keydown', (e) => {
          if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            sendBtn.click();
          }
        });
      }

      // Clicking the enter-icon arrow submits, same as the Send button
      if (enterIcon && sendBtn) {
        enterIcon.addEventListener('click', () => {
          console.log('[DAI-Flash] ⏎ Enter-icon arrow clicked');
          sendBtn.click();
        });
      }

      // Estimate Button
      if (estimateBtn) {
        estimateBtn.addEventListener('click', () => {
          console.log('[DAI-Flash] 📊 Estimate button clicked');
          const prompt = promptInput?.value?.trim();
          if (!prompt) {
            console.log('[DAI-Flash] ⚠️  Estimate blocked: empty prompt');
            return;
          }
          appendUserMessage(prompt);
          if (promptInput) promptInput.value = '';
          if (vscode) {
            vscode.postMessage({ command: 'estimate', prompt });
          }
        });
      }

      // Project Quote Button - unlike Estimate above (a free, local AI-token cost calc), this
      // makes one real AI call to break the pasted spec into engineering modules/hours, so it
      // has an actual (small) cost and can take a few seconds - the button is disabled and
      // "projectQuoteThinking" clears it again once the host replies.
      if (projectQuoteBtn) {
        projectQuoteBtn.addEventListener('click', () => {
          console.log('[DAI-Flash] 📐 Project Quote button clicked');
          const prompt = promptInput?.value?.trim();
          if (!prompt) {
            console.log('[DAI-Flash] ⚠️  Project Quote blocked: empty prompt');
            return;
          }
          appendUserMessage(prompt);
          if (promptInput) promptInput.value = '';
          if (vscode) {
            vscode.postMessage({ command: 'estimateProject', prompt, mode: getQuoteMode(), agentIds: getTickedAgentIds() });
          }
        });
      }

      // Quote Settings (gear) - opens a small inline panel to change Rate/hr, Profit % and
      // GST % without leaving the panel or hunting through VS Code Settings. Asks the host for
      // the current values every time it opens, so it never shows stale numbers. Each field
      // auto-saves on change (no separate Save step) - "← Back" just closes the panel.
      const containerEl = document.querySelector('.container');
      if (quoteSettingsBtn) {
        quoteSettingsBtn.addEventListener('click', () => {
          if (vscode) vscode.postMessage({ command: 'getProjectQuoteSettings' });
          if (quoteSettingsPanel) quoteSettingsPanel.classList.add('visible');
          if (containerEl) containerEl.classList.add('qs-active');
        });
      }
      if (qsBackBtn) {
        qsBackBtn.addEventListener('click', () => {
          if (quoteSettingsPanel) quoteSettingsPanel.classList.remove('visible');
          if (containerEl) containerEl.classList.remove('qs-active');
        });
      }
      function autoSaveQuoteSettings() {
        const rate = Number(qsRate && qsRate.value);
        const profit = Number(qsProfit && qsProfit.value);
        const gst = Number(qsGst && qsGst.value);
        const valid = [rate, profit, gst].every((n) => Number.isFinite(n) && n >= 0);
        if (!valid) {
          if (qsHint) qsHint.textContent = '⚠️ All three values must be non-negative numbers - not saved.';
          return;
        }
        const pricingMode = getPricingMode();
        const tierLow = Number(qsTierLow && qsTierLow.value);
        const tierMedium = Number(qsTierMedium && qsTierMedium.value);
        const tierHigh = Number(qsTierHigh && qsTierHigh.value);
        const tierAdvanced = Number(qsTierAdvanced && qsTierAdvanced.value);
        if (pricingMode === 'tiered' && ![tierLow, tierMedium, tierHigh, tierAdvanced].every((n) => Number.isFinite(n) && n >= 0)) {
          if (qsHint) qsHint.textContent = '⚠️ All 4 tier rates must be non-negative numbers - not saved.';
          return;
        }
        if (vscode) {
          vscode.postMessage({
            command: 'saveProjectQuoteSettings',
            ratePerHour: rate,
            profitPercent: profit,
            gstPercent: gst,
            pricingMode,
            tierRateLow: tierLow,
            tierRateMedium: tierMedium,
            tierRateHigh: tierHigh,
            tierRateAdvanced: tierAdvanced,
          });
        }
        if (qsHint) qsHint.textContent = pricingMode === 'tiered'
          ? '✅ Saved. Quote will bill each module at its own tier rate (Low/Medium/High/Advanced above).'
          : '✅ Saved. These 3 values are what "Quote" uses for Base Cost → Fee → GST → Final Quote.';
      }
      [qsRate, qsProfit, qsGst, qsTierLow, qsTierMedium, qsTierHigh, qsTierAdvanced].forEach((el) => {
        if (el) el.addEventListener('change', autoSaveQuoteSettings);
      });

      // Attach Button - large file / multi-task batch (5MB+ supported, chunked host-side)
      if (attachBtn) {
        attachBtn.addEventListener('click', () => {
          console.log('[DAI-Flash] 📎 Attach button clicked');
          if (vscode) {
            vscode.postMessage({ command: 'attachFile', model: modelSelect ? modelSelect.value : 'auto' });
          }
        });
      }

      // Undo Button
      if (undoBtn) {
        undoBtn.addEventListener('click', () => {
          console.log('[DAI-Flash] ↩️ Undo button clicked');
          if (vscode) {
            vscode.postMessage({ command: 'undo' });
          }
        });
      }

      // Clear Button
      if (clearBtn) {
        clearBtn.addEventListener('click', () => {
          console.log('[DAI-Flash] 🗑️ Clear button clicked');
          if (logsContainer) {
            logsContainer.innerHTML = '<div class="status-message">Chat cleared. Ready for a new prompt.</div>';
          }
          resetTaskPanel();
          if (vscode) {
            vscode.postMessage({ command: 'clearChat' });
          }
        });
      }

      // Per-file Keep / Undo buttons (event delegation - badges are re-rendered on every fileChanged message)
      const filesBody = document.getElementById('filesBody');
      if (filesBody) {
        filesBody.addEventListener('click', (e) => {
          const target = e.target;
          if (!(target instanceof HTMLElement)) return;
          const action = target.getAttribute('data-action');
          const path = target.getAttribute('data-path');
          if (!action || !path || !vscode) return;
          vscode.postMessage({ command: action === 'keep' ? 'keepFile' : 'undoFile', path });
        });
      }

      // Aggregate Keep / Undo review bar - acts on every still-pending file at once
      const reviewKeepBtn = document.getElementById('reviewKeepBtn');
      const reportBtn = document.getElementById('reportBtn');
      if (reportBtn) {
        reportBtn.addEventListener('click', () => {
          if (vscode) vscode.postMessage({ command: 'showAgentReport' });
        });
      }

      const reviewUndoBtn = document.getElementById('reviewUndoBtn');
      if (reviewKeepBtn) {
        reviewKeepBtn.addEventListener('click', () => {
          if (vscode) vscode.postMessage({ command: 'keepAllFiles' });
        });
      }
      if (reviewUndoBtn) {
        reviewUndoBtn.addEventListener('click', () => {
          if (vscode) vscode.postMessage({ command: 'undoAllFiles' });
        });
      }

      // Replaces the CSP-blocked inline onclick attributes the two pills used to carry. Each
      // pill opens its own panel and closes the other, so the two can never overlap in the
      // narrow docked sidebar.
      function wirePillToggle(pillId, bodyId, otherBodyId) {
        const pill = document.getElementById(pillId);
        const body = document.getElementById(bodyId);
        if (!pill || !body) return;
        pill.addEventListener('click', () => {
          const other = otherBodyId ? document.getElementById(otherBodyId) : null;
          if (other) other.classList.remove('active');
          body.classList.toggle('active');
        });
      }
      wirePillToggle('todoHeader', 'todoBody', 'filesBody');
      wirePillToggle('filesHeader', 'filesBody', 'todoBody');

      function renderReviewBar(data) {
        const bar = document.getElementById('reviewBar');
        const summary = document.getElementById('reviewSummary');
        if (!bar || !summary) return;
        const count = data.count || 0;
        if (count === 0) {
          bar.classList.remove('visible');
          return;
        }
        summary.innerHTML = count + ' file' + (count === 1 ? '' : 's') + ' changed ' +
          '<span class="add">+' + (data.additions || 0) + '</span> ' +
          '<span class="del">-' + (data.deletions || 0) + '</span>';
        bar.classList.add('visible');
      }

      // Recovery banner - offered when an interrupted job checkpoint is detected on load
      if (resumeJobBtn) {
        resumeJobBtn.addEventListener('click', () => {
          if (recoveryBanner) recoveryBanner.classList.remove('visible');
          isRunning = true;
          if (sendBtn) sendBtn.disabled = true;
          if (stopBtn) stopBtn.disabled = false;
          setRunningGlow(true);
          if (vscode) vscode.postMessage({ command: 'resumeJob' });
        });
      }
      if (startFreshBtn) {
        startFreshBtn.addEventListener('click', () => {
          if (recoveryBanner) recoveryBanner.classList.remove('visible');
          if (vscode) vscode.postMessage({ command: 'discardCheckpoint' });
        });
      }

      // Stop Button
      if (stopBtn) {
        stopBtn.disabled = true;
        stopBtn.addEventListener('click', () => {
          console.log('[DAI-Flash] ⛔ Stop button clicked');
          isRunning = false;
          if (sendBtn) sendBtn.disabled = false;
          stopBtn.disabled = true;
          setRunningGlow(false);
          appendLog('⛔ Execution stopped by user', 'warn');
          if (vscode) {
            vscode.postMessage({ command: 'stop' });
          }
        });
      }

      function appendLog(message, type = 'info') {
        try {
          if (!logsContainer) {
            console.error('[DAI-Flash] ❌ Logs container not available');
            return;
          }
          const div = document.createElement('div');
          div.className = 'log-line ' + type;
          div.textContent = message;
          logsContainer.appendChild(div);
          logsContainer.scrollTop = logsContainer.scrollHeight;
          // Mirror the newest line into the live strip so it always names the current step.
          setActivity(message);
        } catch (err) {
          console.error('[DAI-Flash] Error appending log:', err);
        }
      }

      // Builds the text behind "Copy Full Report".
      //
      // The old version copied reportLines alone - the two or three summary lines already on
      // screen - which answered nothing anybody actually asks after a run. What matters is what
      // was asked, which agent took it, what it cost, which files moved, and the full log,
      // because the log is the only place the real sequence of events is written down.
      function buildJobReport(data, reportLines) {
        var rule = '='.repeat(60);
        var thin = '-'.repeat(60);
        var out = [];
        out.push(rule);
        out.push('DAI FLASH - JOB REPORT');
        out.push(rule);
        out.push('Time      : ' + new Date().toLocaleString());
        if (jobStartedAt) out.push('Duration  : ' + ((Date.now() - jobStartedAt) / 1000).toFixed(1) + 's');
        out.push('Requested : ' + (lastSubmittedPrompt || '(not recorded)'));
        out.push('Status    : ' + (data.model === 'none' ? 'FAILED' : 'Completed'));
        out.push('Agent     : ' + (data.model || 'unknown'));

        var logLines = logsContainer
          ? Array.from(logsContainer.querySelectorAll('.log-line')).map(function (el) { return el.textContent; })
          : [];
        var toolMode = logLines.some(function (l) { return l.indexOf('Tool mode') !== -1; });
        out.push('Mode      : ' + (toolMode ? 'Tool loop (agent calls tools)' : 'Classic (single generate-and-paste)'));

        out.push(thin);
        out.push('HOW MANY TRIES IT TOOK');
        var count = data.totalAttempts || 1;
        var rounds = data.correctiveRounds || 0;
        var escalations = (data.fallbackHistory || []).length;

        // The same number means two different things in the two modes, and reporting it with
        // one word would be a lie in one of them.
        //
        // Classic path: totalAttempts counts RETRIES. "2" means the first attempt failed.
        // Tool loop:    it counts STEPS. "2" means the agent called a tool, then answered -
        //               one clean pass, nothing went wrong. Calling that "needed 2 attempts"
        //               reports a success as a struggle.
        //
        // What actually signals trouble in tool mode is an escalation or a corrective round,
        // so those - not the step count - decide whether this reads as a clean run.
        var struggled = escalations > 0 || rounds > 0 || (!toolMode && count > 1);
        if (!struggled) {
          out.push(toolMode
            ? '  CLEAN RUN - finished in ' + count + ' step(s), no retries, no corrections.'
            : '  FIRST TRY - done in one go, no retries, no corrections.');
        } else {
          if (!toolMode && count > 1) out.push('  Succeeded on attempt ' + count + ' - earlier attempt(s) failed.');
          if (escalations > 0) out.push('  Escalated to a stronger agent ' + escalations + ' time(s) - the first one(s) could not do it.');
          if (rounds > 0) out.push('  Sent back by the reviewer ' + rounds + ' time(s) and re-run.');
        }
        out.push(toolMode ? '  Tool steps       : ' + count : '  Attempts         : ' + count);
        out.push('  Corrective rounds: ' + rounds);

        out.push(thin);
        out.push('COST AND USAGE');
        out.push('  TOTAL cost   : $' + (data.costUsd || 0).toFixed(4));
        // Broken out whenever anything beyond the first run was paid for. A single total that
        // quietly folds in a review or a re-run reads as if the job were cheaper than it was.
        if (rounds > 0 || (data.acceptanceCostUsd || 0) > 0) {
          out.push('    the work itself  : $' + (data.firstRunCostUsd || 0).toFixed(4));
          if (rounds > 0) out.push('    corrective runs  : $' + (data.correctiveCostUsd || 0).toFixed(4) + '  (' + rounds + ' round(s))');
          if ((data.acceptanceCostUsd || 0) > 0) out.push('    acceptance review: $' + (data.acceptanceCostUsd || 0).toFixed(4));
        }
        out.push('  Input tokens : ' + (data.inputTokens || 0).toLocaleString());
        out.push('  Output tokens: ' + (data.outputTokens || 0).toLocaleString());

        var fallbacks = data.fallbackHistory || [];
        if (fallbacks.length > 0) {
          out.push(thin);
          out.push('AGENT ESCALATION (' + fallbacks.length + ')');
          fallbacks.forEach(function (fb) {
            out.push('  ' + fb.fromModel + ' -> ' + fb.toModel + '  after ' + fb.attemptsUsed + ' failed attempt(s): ' + fb.reason);
          });
        }

        var files = data.files || [];
        out.push(thin);
        out.push('FILES CHANGED (' + files.length + ')');
        if (files.length === 0) {
          out.push('  none');
        } else {
          files.forEach(function (f) {
            out.push('  ' + (f.path || 'unknown'));
            out.push('      agent  : ' + (f.modelLabel || data.model || 'unknown'));
            out.push('      change : +' + (f.additions || 0) + ' / -' + (f.deletions || 0) +
                     '   (attempt ' + (f.attempts || 1) + ', ' + (f.status || 'success') + ')');
          });
        }

        out.push(thin);
        out.push('FULL LOG (' + logLines.length + ' lines)');
        if (logLines.length === 0) out.push('  (empty)');
        else logLines.forEach(function (l) { out.push('  ' + l); });

        out.push(rule);
        out.push('SUMMARY CARD');
        reportLines.forEach(function (l) { out.push('  ' + l); });

        // Estimate against reality, last, because it is the line worth acting on. An estimate
        // that is never put beside the real figure stays wrong forever - nobody finds out.
        out.push(rule);
        out.push('ESTIMATE vs ACTUAL');
        var actual = data.costUsd || 0;
        if (!lastEstimateUsd) {
          out.push('  No estimate was shown for this job, so there is nothing to compare.');
        } else {
          out.push('  Estimated before running : $' + lastEstimateUsd.toFixed(4) +
                   (lastEstimateAgent ? '   (assumed ' + lastEstimateAgent + ')' : ''));
          out.push('  Actually cost            : $' + actual.toFixed(4) +
                   '   (ran on ' + (data.model || 'unknown') + ')');
          var diff = actual - lastEstimateUsd;
          var sign = diff >= 0 ? '+' : '-';
          out.push('  Difference              : ' + sign + '$' + Math.abs(diff).toFixed(4) +
                   (lastEstimateUsd > 0 ? '   (' + (actual / lastEstimateUsd).toFixed(1) + 'x the estimate)' : ''));
          // A ratio on a near-zero base is arithmetic, not a finding: 23x of one-hundredth of a
          // cent is still one-fiftieth of a cent. Saying so here stops a scary-looking multiple
          // being read as a scary amount of money.
          if (Math.abs(diff) < 0.01) {
            out.push('  Note: the amounts here are fractions of a cent, so the multiple looks');
            out.push('        large while the real gap is tiny. Judge it by the $ figure.');
          }
          if (toolMode) {
            out.push('  Note: tool mode sends the tool descriptions and the whole conversation');
            out.push('        again on every step. The estimator does not yet count that, so it');
            out.push('        under-estimates tool-mode jobs - most on short ones.');
          }
        }
        out.push(rule);
        return out.join('\\n');
      }

      function appendPreviewLink(url) {
        try {
          if (!logsContainer) return;
          const div = document.createElement('div');
          div.className = 'log-line success';
          const label = document.createElement('span');
          label.textContent = '🌐 Live preview ready: ';
          const link = document.createElement('a');
          link.href = '#';
          link.textContent = url;
          link.style.color = '#4fc1ff';
          link.style.textDecoration = 'underline';
          link.addEventListener('click', (e) => {
            e.preventDefault();
            if (vscode) vscode.postMessage({ command: 'openExternal', url });
          });
          div.appendChild(label);
          div.appendChild(link);
          logsContainer.appendChild(div);
          logsContainer.scrollTop = logsContainer.scrollHeight;
        } catch (err) {
          console.error('[DAI-Flash] Error appending preview link:', err);
        }
      }

      function appendUserMessage(text) {
        try {
          if (!logsContainer) return;
          const div = document.createElement('div');
          div.className = 'chat-msg-user';
          div.textContent = text;
          logsContainer.appendChild(div);
          logsContainer.scrollTop = logsContainer.scrollHeight;
        } catch (err) {
          console.error('[DAI-Flash] Error appending user message:', err);
        }
      }

      function appendSummaryCard(summary) {
        try {
          if (!logsContainer) return;
          const div = document.createElement('div');
          div.className = 'summary-card';
          div.innerHTML = summary;
          logsContainer.appendChild(div);
          logsContainer.scrollTop = logsContainer.scrollHeight;
        } catch (err) {
          console.error('[DAI-Flash] Error appending summary:', err);
        }
      }

      function relativeTime(ts) {
        const diffMs = Date.now() - (ts || 0);
        const mins = Math.floor(diffMs / 60000);
        if (mins < 1) return 'just now';
        if (mins < 60) return mins + ' min ago';
        const hrs = Math.floor(mins / 60);
        if (hrs < 24) return hrs + ' hr' + (hrs === 1 ? '' : 's') + ' ago';
        const days = Math.floor(hrs / 24);
        return days + ' day' + (days === 1 ? '' : 's') + ' ago';
      }

      // Shows recent past jobs in place of the plain idle placeholder - only while the logs
      // panel is still showing that original placeholder untouched, so it never overwrites
      // an active or just-finished run's real output.
      function displaySessions(sessions, forced) {
        try {
          if (!logsContainer) return;
          const onlyChild = logsContainer.children.length === 1 ? logsContainer.children[0] : null;
          const isPlaceholder = onlyChild && onlyChild.classList && onlyChild.classList.contains('status-message');
          // The "forced" flag is set when the USER asked for this redraw (the Clear button).
          // Without it the guard below wins - by then the panel is showing the session list
          // itself, not the placeholder - so the rows the user just cleared stayed on screen
          // and Clear looked like it had done nothing.
          // (No backticks in this comment: the whole script sits inside a template literal,
          //  so a stray backtick here terminates it and breaks the entire webview.)
          if (!isPlaceholder && !forced) return;

          // An empty history has to be handled explicitly rather than by returning early:
          // after the user clears the list, returning would leave the OLD rows sitting on
          // screen, making the refresh look broken. Put the idle placeholder back instead.
          if (!sessions || sessions.length === 0) {
            logsContainer.innerHTML = '';
            const empty = document.createElement('div');
            empty.className = 'status-message';
            empty.textContent = 'Agent progress and live execution logs will appear here.';
            logsContainer.appendChild(empty);
            return;
          }

          logsContainer.innerHTML = '';
          const heading = document.createElement('div');
          heading.className = 'session-list-heading';
          heading.textContent = 'Recent sessions';

          const refresh = document.createElement('span');
          refresh.className = 'session-refresh';
          refresh.textContent = '↻ Clear';
          refresh.title = 'Clear this list of past sessions';
          refresh.addEventListener('click', () => {
            if (vscode) vscode.postMessage({ command: 'clearSessions' });
          });
          heading.appendChild(refresh);

          logsContainer.appendChild(heading);

          const list = document.createElement('div');
          list.className = 'session-list';
          for (const s of sessions) {
            const item = document.createElement('div');
            item.className = 'session-item';

            const title = document.createElement('div');
            title.className = 'session-title';
            title.textContent = (s.success === false ? '⚠️ ' : '') + (s.title || '(untitled)');

            const meta = document.createElement('div');
            meta.className = 'session-meta';
            if (s.success === false) {
              const failBadge = document.createElement('span');
              failBadge.className = 'session-fail';
              failBadge.textContent = 'rolled back';
              meta.appendChild(failBadge);
            }
            const diff = document.createElement('span');
            diff.className = 'session-diff';
            diff.innerHTML = '<span class="add">+' + (s.additions || 0) + '</span><span class="del">-' + (s.deletions || 0) + '</span>';
            meta.appendChild(diff);
            const time = document.createElement('span');
            time.className = 'session-time';
            time.textContent = relativeTime(s.timestamp);
            meta.appendChild(time);

            item.appendChild(title);
            item.appendChild(meta);
            list.appendChild(item);
          }
          logsContainer.appendChild(list);
        } catch (err) {
          console.error('[DAI-Flash] Error rendering session list:', err);
        }
      }

      function upsertProgressBubble(step, total, label) {
        try {
          if (!logsContainer) return;
          let bubble = document.getElementById('progressBubble');
          if (!bubble) {
            bubble = document.createElement('div');
            bubble.id = 'progressBubble';
            bubble.className = 'progress-bubble';
            logsContainer.appendChild(bubble);
          }
          bubble.textContent = '⏳ Step ' + step + '/' + total + ': ' + label;
          logsContainer.scrollTop = logsContainer.scrollHeight;
        } catch (err) {
          console.error('[DAI-Flash] Error updating progress bubble:', err);
        }
      }

      function appendJobCompleteCard(data) {
        try {
          if (!logsContainer) return;
          const oldBubble = document.getElementById('progressBubble');
          if (oldBubble) oldBubble.remove();

          // The runner reports a failed/aborted job (workspace lock refused, every tier
          // exhausted, quality gate never passed, post-execution validation failed, or an
          // uncaught error) with model:'none' - it is NOT a successful completion, and must
          // never render with the same green checkmark/title as a real success (that was a
          // real bug: "✅ Job Completed (none)" with $0 cost read as a free successful run).
          const failed = data.model === 'none';
          const card = document.createElement('div');
          card.className = failed ? 'job-complete-card job-failed-card' : 'job-complete-card';

          const title = document.createElement('span');
          title.className = 'job-title';
          title.textContent = failed
            ? '❌ Job Failed - no model produced usable output (see logs above for why)'
            : '✅ Job Completed (' + (data.model || 'unknown model') + ')';
          card.appendChild(title);

          const reportLines = [title.textContent];

          const fallbackHistory = data.fallbackHistory || [];
          if (fallbackHistory.length > 0) {
            const fbHeader = document.createElement('div');
            fbHeader.className = 'job-footer';
            fbHeader.textContent = '🔀 Fallback transitions:';
            card.appendChild(fbHeader);
            reportLines.push('Fallback transitions:');
            fallbackHistory.forEach((fb) => {
              const line = document.createElement('div');
              line.className = 'job-footer';
              const text = '  ↳ ' + fb.fromModel + ' → ' + fb.toModel + ' (after ' + fb.attemptsUsed + ' failed attempts: ' + fb.reason + ')';
              line.textContent = text;
              card.appendChild(line);
              reportLines.push(text);
            });
          }

          const files = data.files || [];
          if (files.length > 0) {
            const filesHeader = document.createElement('div');
            filesHeader.className = 'job-footer';
            filesHeader.textContent = '📄 Files (' + files.length + '):';
            card.appendChild(filesHeader);
            reportLines.push('Files (' + files.length + '):');
            files.forEach((f) => {
              const line = document.createElement('div');
              line.className = 'job-footer';
              const text = '  ↳ ' + (f.path || 'unknown') + ' — ' + (f.modelLabel || data.model || 'unknown model') +
                ' (attempt ' + (f.attempts || 1) + '/3, ' + (f.status || 'success') + ') — +' + (f.additions || 0) + '/-' + (f.deletions || 0);
              line.textContent = text;
              card.appendChild(line);
              reportLines.push(text);
            });
          }

          const footer = document.createElement('span');
          footer.className = 'job-footer';
          const cost = (data.costUsd || 0).toFixed(4);
          const inTok = (data.inputTokens || 0).toLocaleString();
          const outTok = (data.outputTokens || 0).toLocaleString();
          const totalAttempts = data.totalAttempts || 1;
          footer.textContent = 'Cost: $' + cost + ' | Tokens: ' + inTok + ' in / ' + outTok + ' out | Iterations: ' + totalAttempts;
          card.appendChild(footer);
          reportLines.push(footer.textContent);

          const copyBtn = document.createElement('button');
          copyBtn.className = 'copy-btn';
          copyBtn.textContent = '📋 Copy Full Report';
          copyBtn.title = 'Copy the full structured job report to clipboard';
          copyBtn.addEventListener('click', () => {
            const text = buildJobReport(data, reportLines);
            try {
              navigator.clipboard.writeText(text).then(() => {
                copyBtn.textContent = '✅ Copied';
                setTimeout(() => { copyBtn.textContent = '📋 Copy Full Report'; }, 1500);
              });
            } catch (err) {
              console.error('[DAI-Flash] Copy failed:', err);
            }
          });
          card.appendChild(copyBtn);

          logsContainer.appendChild(card);
          logsContainer.scrollTop = logsContainer.scrollHeight;
        } catch (err) {
          console.error('[DAI-Flash] Error appending job-complete card:', err);
        }
      }

      function appendEstimateCard(data) {
        try {
          if (!logsContainer) return;

          const card = document.createElement('div');
          card.className = 'job-complete-card';

          const title = document.createElement('span');
          title.className = 'job-title';
          title.textContent = '📊 Cost Estimate (~' + (data.inputTokens || 0).toLocaleString() + ' in / ~' + (data.outputTokens || 0).toLocaleString() + ' out tokens)';
          card.appendChild(title);

          const reportLines = [title.textContent];

          (data.providers || []).forEach((p) => {
            const row = document.createElement('div');
            row.className = 'job-footer';
            const econ = p.economy || {};
            const flag = p.flagship || {};
            const text = '  ' + (p.providerLabel || p.provider) + ' — Economy: ' + (econ.modelLabel || '?') +
              ' $' + (econ.costUsd || 0).toFixed(4) + '  |  Flagship: ' + (flag.modelLabel || '?') +
              ' $' + (flag.costUsd || 0).toFixed(4);
            row.textContent = text;
            card.appendChild(row);
            reportLines.push(text);
          });

          const copyBtn = document.createElement('button');
          copyBtn.className = 'copy-btn';
          copyBtn.textContent = '📋 Copy';
          copyBtn.title = 'Copy the full cost estimate breakdown to clipboard';
          copyBtn.addEventListener('click', () => {
            const text = buildJobReport(data, reportLines);
            try {
              navigator.clipboard.writeText(text).then(() => {
                copyBtn.textContent = '✅ Copied';
                setTimeout(() => { copyBtn.textContent = '📋 Copy'; }, 1500);
              });
            } catch (err) {
              console.error('[DAI-Flash] Copy failed:', err);
            }
          });
          card.appendChild(copyBtn);

          // Client Quote Calculator - turns the raw per-provider token cost above into a
          // client-facing quote: cheapest economy-tier cost overall becomes "Medium AI Agent",
          // priciest flagship-tier cost overall becomes "Top AI Agent", then a user-editable
          // profit margin plus a flat 18% GST (this is an internal costing helper, not a
          // formal tax invoice, so a flat rate is used rather than round-tripping through
          // IndiaGstEngine on the host) produce the final all-in quote.
          const providersForQuote = data.providers || [];
          let mediumAgent = null;
          let topAgent = null;
          providersForQuote.forEach((p) => {
            const econ = p.economy;
            const flag = p.flagship;
            const label = p.providerLabel || p.provider;
            if (econ && typeof econ.costUsd === 'number' && (!mediumAgent || econ.costUsd < mediumAgent.costUsd)) {
              mediumAgent = { costUsd: econ.costUsd, modelLabel: econ.modelLabel || '?', providerLabel: label };
            }
            if (flag && typeof flag.costUsd === 'number' && (!topAgent || flag.costUsd > topAgent.costUsd)) {
              topAgent = { costUsd: flag.costUsd, modelLabel: flag.modelLabel || '?', providerLabel: label };
            }
          });

          if (mediumAgent && topAgent) {
            const USD_TO_INR = 87;
            const fmtUsd = (n) => '$' + n.toFixed(4);
            const fmtInr = (n) => '₹' + (n * USD_TO_INR).toFixed(2);

            const quoteSection = document.createElement('div');
            quoteSection.className = 'quote-section';

            const quoteHeading = document.createElement('span');
            quoteHeading.className = 'quote-heading';
            quoteHeading.textContent = '💼 Client Quote Calculator';
            quoteSection.appendChild(quoteHeading);

            const marginRow = document.createElement('div');
            marginRow.className = 'quote-margin-row';
            const marginLabel = document.createElement('label');
            marginLabel.textContent = 'Profit Margin %:';
            marginLabel.htmlFor = 'quoteMarginInput-' + Date.now();
            const marginInput = document.createElement('input');
            marginInput.type = 'number';
            marginInput.id = marginLabel.htmlFor;
            marginInput.className = 'quote-margin-input';
            marginInput.min = '0';
            marginInput.step = '5';
            marginInput.value = '200';
            marginRow.appendChild(marginLabel);
            marginRow.appendChild(marginInput);
            quoteSection.appendChild(marginRow);

            const buildAgentBlock = (icon, label) => {
              const block = document.createElement('div');
              block.className = 'quote-block';
              const blockTitle = document.createElement('span');
              blockTitle.className = 'quote-block-title';
              blockTitle.textContent = icon + ' ' + label;
              block.appendChild(blockTitle);
              const baseRow = document.createElement('div');
              baseRow.className = 'quote-row';
              const feeRow = document.createElement('div');
              feeRow.className = 'quote-row';
              const gstRow = document.createElement('div');
              gstRow.className = 'quote-row';
              const finalRow = document.createElement('div');
              finalRow.className = 'quote-row quote-final';
              block.appendChild(baseRow);
              block.appendChild(feeRow);
              block.appendChild(gstRow);
              block.appendChild(finalRow);
              quoteSection.appendChild(block);
              return { baseRow, feeRow, gstRow, finalRow };
            };

            const mediumRows = buildAgentBlock('🟡', 'Medium AI Agent (' + mediumAgent.providerLabel + ' — ' + mediumAgent.modelLabel + ')');
            const topRows = buildAgentBlock('🔴', 'Top AI Agent (' + topAgent.providerLabel + ' — ' + topAgent.modelLabel + ')');

            const referenceNote = document.createElement('span');
            referenceNote.className = 'quote-note';
            referenceNote.textContent = 'Reference: solo/freelance operators typically run 40-65% net margin, agencies 15-35%, software-dev industry average ~43% net margin. Since your base cost here is just AI token cost (not labor), a much higher markup (200%+) is normal and reasonable - this is a guide, not a rule.';
            quoteSection.appendChild(referenceNote);

            const inrNote = document.createElement('span');
            inrNote.className = 'quote-note';
            inrNote.textContent = 'INR figures use an approximate rate of 1 USD = ₹' + USD_TO_INR + ' - approximate, check the live rate before invoicing.';
            quoteSection.appendChild(inrNote);

            const quoteActions = document.createElement('div');
            quoteActions.className = 'quote-actions';
            const copyQuoteBtn = document.createElement('button');
            copyQuoteBtn.textContent = '📋 Copy Quote';
            copyQuoteBtn.title = 'Copy the full client quote breakdown to clipboard';
            const downloadQuoteBtn = document.createElement('button');
            downloadQuoteBtn.textContent = '⬇️ Download Report';
            downloadQuoteBtn.title = 'Download the full client quote breakdown as a .txt file';
            quoteActions.appendChild(copyQuoteBtn);
            quoteActions.appendChild(downloadQuoteBtn);
            quoteSection.appendChild(quoteActions);

            // Single source of truth for both the on-screen numbers and the copy/download
            // text, so all three can never drift out of sync with each other.
            const calcQuote = (baseCostUsd, profitPercent) => {
              const fee = baseCostUsd * (1 + profitPercent / 100);
              const gst = fee * 0.18;
              const finalQuote = fee + gst;
              return { baseCostUsd, fee, gst, finalQuote };
            };

            const safeProfitPercent = () => {
              const parsed = parseFloat(marginInput.value);
              return isFinite(parsed) && parsed >= 0 ? parsed : 0;
            };

            const renderAgentRows = (rows, calc) => {
              rows.baseRow.textContent = '  Base Cost: ' + fmtUsd(calc.baseCostUsd) + '  (~' + fmtInr(calc.baseCostUsd) + ')';
              rows.feeRow.textContent = '  Your Fee (Taxable Value): ' + fmtUsd(calc.fee) + '  (~' + fmtInr(calc.fee) + ')';
              rows.gstRow.textContent = '  GST (18%): ' + fmtUsd(calc.gst) + '  (~' + fmtInr(calc.gst) + ')';
              rows.finalRow.textContent = '  Final All-In Quote: ' + fmtUsd(calc.finalQuote) + '  (~' + fmtInr(calc.finalQuote) + ')';
            };

            const buildQuoteReportText = () => {
              const profitPercent = safeProfitPercent();
              const mediumCalc = calcQuote(mediumAgent.costUsd, profitPercent);
              const topCalc = calcQuote(topAgent.costUsd, profitPercent);
              const lines = [];
              lines.push('DAI Flash - Client Quote');
              lines.push('Generated: ' + new Date().toLocaleString());
              lines.push('Profit Margin: ' + profitPercent + '%');
              lines.push('');
              lines.push('Medium AI Agent (' + mediumAgent.providerLabel + ' — ' + mediumAgent.modelLabel + ')');
              lines.push('  Base Cost (USD): ' + fmtUsd(mediumCalc.baseCostUsd) + '  (~' + fmtInr(mediumCalc.baseCostUsd) + ')');
              lines.push('  Your Fee (Taxable Value): ' + fmtUsd(mediumCalc.fee) + '  (~' + fmtInr(mediumCalc.fee) + ')');
              lines.push('  GST (18%): ' + fmtUsd(mediumCalc.gst) + '  (~' + fmtInr(mediumCalc.gst) + ')');
              lines.push('  Final All-In Quote to Client: ' + fmtUsd(mediumCalc.finalQuote) + '  (~' + fmtInr(mediumCalc.finalQuote) + ')');
              lines.push('');
              lines.push('Top AI Agent (' + topAgent.providerLabel + ' — ' + topAgent.modelLabel + ')');
              lines.push('  Base Cost (USD): ' + fmtUsd(topCalc.baseCostUsd) + '  (~' + fmtInr(topCalc.baseCostUsd) + ')');
              lines.push('  Your Fee (Taxable Value): ' + fmtUsd(topCalc.fee) + '  (~' + fmtInr(topCalc.fee) + ')');
              lines.push('  GST (18%): ' + fmtUsd(topCalc.gst) + '  (~' + fmtInr(topCalc.gst) + ')');
              lines.push('  Final All-In Quote to Client: ' + fmtUsd(topCalc.finalQuote) + '  (~' + fmtInr(topCalc.finalQuote) + ')');
              lines.push('');
              lines.push('(Approximate INR conversion at 1 USD = ₹' + USD_TO_INR + ' - check the live rate before invoicing.)');
              return lines.join('\\n');
            };

            const recalculate = () => {
              const profitPercent = safeProfitPercent();
              renderAgentRows(mediumRows, calcQuote(mediumAgent.costUsd, profitPercent));
              renderAgentRows(topRows, calcQuote(topAgent.costUsd, profitPercent));
            };
            marginInput.addEventListener('input', recalculate);
            recalculate();

            copyQuoteBtn.addEventListener('click', () => {
              const text = buildQuoteReportText();
              try {
                navigator.clipboard.writeText(text).then(() => {
                  copyQuoteBtn.textContent = '✅ Copied';
                  setTimeout(() => { copyQuoteBtn.textContent = '📋 Copy Quote'; }, 1500);
                });
              } catch (err) {
                console.error('[DAI-Flash] Copy quote failed:', err);
              }
            });

            downloadQuoteBtn.addEventListener('click', () => {
              try {
                const text = buildQuoteReportText();
                const blob = new Blob([text], { type: 'text/plain' });
                const url = URL.createObjectURL(blob);
                const a = document.createElement('a');
                const now = new Date();
                const y = now.getFullYear();
                const m = String(now.getMonth() + 1).padStart(2, '0');
                const d = String(now.getDate()).padStart(2, '0');
                a.href = url;
                a.download = 'quote-' + y + '-' + m + '-' + d + '.txt';
                document.body.appendChild(a);
                a.click();
                document.body.removeChild(a);
                URL.revokeObjectURL(url);
                downloadQuoteBtn.textContent = '✅ Downloaded';
                setTimeout(() => { downloadQuoteBtn.textContent = '⬇️ Download Report'; }, 1500);
              } catch (err) {
                console.error('[DAI-Flash] Download quote failed:', err);
              }
            });

            card.appendChild(quoteSection);
          }

          logsContainer.appendChild(card);
          logsContainer.scrollTop = logsContainer.scrollHeight;
        } catch (err) {
          console.error('[DAI-Flash] Error appending estimate card:', err);
        }
      }

      // Renders the Project Quote result: a real AI call already broke the pasted client spec
      // into engineering modules/hours host-side (see _sendProjectQuote), and the host also
      // already ran those hours through Base Cost -> Fee -> GST -> Final Quote using the
      // daiFlash.projectQuote.* settings - this function only displays the numbers it was sent,
      // same "single source of truth" pattern as the Client Quote Calculator above.
      // data.quotes: [{ agentLabel, quote }, ...] - one entry per ticked agent (or one entry
      // for the auto-picked model when no agent was ticked). Each renders as its own card, so
      // multiple agents' independent hour estimates can be compared side by side, exactly like
      // the AI-token Estimate button already shows a Medium-agent vs Top-agent quote together.
      function appendProjectQuoteCard(data) {
        try {
          if (!logsContainer) return;
          const quotes = Array.isArray(data.quotes) ? data.quotes : (data.quote ? [{ agentLabel: data.modelLabel || '?', quote: data.quote }] : []);
          if (quotes.length === 0) return;
          const modeLabel = data.mode === 'ai-assisted' ? '🤖 AI-Agent Assisted' : '🧑‍💻 Manual/Traditional';

          const fmtHrs = (n) => n.toFixed(1) + ' hrs';
          const fmtMoney = (n) => n.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });

          quotes.forEach(({ agentLabel, quote, routed }) => {
            if (!quote) return;
            const card = document.createElement('div');
            card.className = 'job-complete-card';

            const title = document.createElement('span');
            title.className = 'job-title';
            title.textContent = '📐 Project Quote [' + modeLabel + '] (' + quote.modules.length + ' module' + (quote.modules.length === 1 ? '' : 's') + ', ' + quote.totalHours.toFixed(1) + ' hrs, via ' + (agentLabel || '?') + ')';
            card.appendChild(title);

            const reportLines = [title.textContent];

            const tiered = quote.pricingMode === 'tiered';
            const TIER_LABEL = { low: 'Low', medium: 'Medium', high: 'High', advanced: 'Advanced' };

            quote.modules.forEach((m) => {
              const row = document.createElement('div');
              row.className = 'job-footer';
              const tierBit = tiered && m.tier ? ' [' + TIER_LABEL[m.tier] + ' ₹' + fmtMoney(m.tierRate) + '/hr]' : '';
              const costBit = tiered && typeof m.moduleCost === 'number' ? ' = ₹' + fmtMoney(m.moduleCost) : '';
              const text = '  ' + m.module + ' - ' + fmtHrs(m.hours) + tierBit + costBit + (m.routedAgentLabel ? ' → 🔀 ' + m.routedAgentLabel : '');
              row.textContent = text;
              card.appendChild(row);
              reportLines.push(text);
            });

            // Tier-mix summary table. Forty module lines are hard to read as a shape; four rows
            // answer "where did the money actually go" at a glance, which is the question the
            // per-line list cannot answer. Only meaningful for tiered pricing - in flat mode
            // every hour costs the same and the table would say nothing.
            if (tiered) {
              const TIER_ORDER = ['low', 'medium', 'high', 'advanced'];
              const agg = {};
              TIER_ORDER.forEach((t) => { agg[t] = { modules: 0, hours: 0, cost: 0 }; });
              quote.modules.forEach((m) => {
                if (!m.tier || !agg[m.tier]) return;
                agg[m.tier].modules += 1;
                agg[m.tier].hours += m.hours;
                agg[m.tier].cost += (typeof m.moduleCost === 'number' ? m.moduleCost : 0);
              });

              const table = document.createElement('table');
              table.className = 'quote-tier-table';
              const headRow = document.createElement('tr');
              ['Tier', 'Modules', 'Hours', '% hrs', 'Cost', '% cost'].forEach((h) => {
                const th = document.createElement('th');
                th.textContent = h;
                headRow.appendChild(th);
              });
              table.appendChild(headRow);

              reportLines.push('  --- Tier mix ---');
              TIER_ORDER.forEach((t) => {
                const a = agg[t];
                const pctH = quote.totalHours > 0 ? (a.hours / quote.totalHours * 100) : 0;
                const pctC = quote.baseCost > 0 ? (a.cost / quote.baseCost * 100) : 0;
                const cells = [
                  TIER_LABEL[t] + ' ₹' + fmtMoney(quote.tierRates[t]),
                  String(a.modules),
                  a.hours.toFixed(1),
                  pctH.toFixed(1) + '%',
                  '₹' + fmtMoney(a.cost),
                  pctC.toFixed(1) + '%',
                ];
                const tr = document.createElement('tr');
                // A tier nothing landed in is dimmed rather than hidden - "zero Low" is itself
                // a finding about the project, and dropping the row would hide it.
                if (a.modules === 0) tr.className = 'tier-empty';
                cells.forEach((c, i) => {
                  const td = document.createElement('td');
                  td.textContent = c;
                  if (i > 0) td.className = 'num';
                  tr.appendChild(td);
                });
                table.appendChild(tr);
                reportLines.push('  ' + cells.join('  |  '));
              });
              card.appendChild(table);
            }

            const summaryLines = [
              ['Total Hours', fmtHrs(quote.totalHours)],
              ...(tiered
                ? [['Pricing', 'Tier-wise (Low ₹' + fmtMoney(quote.tierRates.low) + ', Medium ₹' + fmtMoney(quote.tierRates.medium) + ', High ₹' + fmtMoney(quote.tierRates.high) + ', Advanced ₹' + fmtMoney(quote.tierRates.advanced) + ')']]
                : [['Rate/hr', fmtMoney(quote.ratePerHour)]]),
              ['Base Cost (' + (tiered ? 'Σ hours × each module tier rate' : 'hours × rate') + ')', fmtMoney(quote.baseCost)],
              ['Your Fee (Taxable Value, +' + quote.profitPercent + '% profit)', fmtMoney(quote.fee)],
              ['GST (' + quote.gstPercent + '%)', fmtMoney(quote.gst)],
              ['Final All-In Quote', fmtMoney(quote.finalQuote)],
            ];
            summaryLines.forEach(([label, value], idx) => {
              const row = document.createElement('div');
              row.className = idx === summaryLines.length - 1 ? 'job-footer quote-final' : 'job-footer';
              const text = '  ' + label + ': ' + value;
              row.textContent = text;
              card.appendChild(row);
              reportLines.push(text);
            });

            // The user's actual ask: "how was this rate arrived at" - show the ONE blended
            // ₹/hr this tiered quote works out to (Base Cost / Total Hours) right next to the
            // flat Rate/hr, so the two are directly comparable at a glance.
            if (tiered && typeof quote.effectiveAvgRate === 'number') {
              const compareRow = document.createElement('div');
              compareRow.className = 'job-footer quote-rate-compare';
              const compareText = '  ⚖️ Effective Avg Rate (blended tiers): ₹' + fmtMoney(quote.effectiveAvgRate) + '/hr   vs   Manual Flat Rate/hr: ₹' + fmtMoney(quote.ratePerHour) + '/hr';
              compareRow.textContent = compareText;
              card.appendChild(compareRow);
              reportLines.push(compareText);
            }

            const note = document.createElement('span');
            note.className = 'quote-note';
            const routingBit = routed ? ' Each module is also routed (🔀) to the cheapest ticked agent capable of it - that label never changes the price, only the pricing tier (above) does.' : '';
            note.textContent = (tiered
              ? 'Each module is billed at its own tier rate (shown per line above), so a different mix of light/medium/heavy modules changes the total.'
              : 'Every hour is billed at the same flat Rate/hr, whichever agent a module is routed to.') + routingBit + ' Pricing mode, Rate/hr, tier rates, profit % and GST % all come from ⚙️ Quote settings.';
            card.appendChild(note);
            reportLines.push(note.textContent);

            const copyBtn = document.createElement('button');
            copyBtn.className = 'copy-btn';
            copyBtn.textContent = '📋 Copy';
            copyBtn.title = 'Copy this quote breakdown to clipboard';
            copyBtn.addEventListener('click', () => {
              const text = reportLines.join('\\n');
              try {
                navigator.clipboard.writeText(text).then(() => {
                  copyBtn.textContent = '✅ Copied';
                  setTimeout(() => { copyBtn.textContent = '📋 Copy'; }, 1500);
                });
              } catch (err) {
                console.error('[DAI-Flash] Copy failed:', err);
              }
            });
            card.appendChild(copyBtn);

            logsContainer.appendChild(card);
          });

          if (Array.isArray(data.errors) && data.errors.length > 0) {
            appendLog('⚠️ ' + data.errors.length + ' agent(s) failed to return a quote: ' + data.errors.join(' | '), 'error');
          }

          logsContainer.scrollTop = logsContainer.scrollHeight;
        } catch (err) {
          console.error('[DAI-Flash] Error appending project quote card:', err);
        }
      }

      // Admin-only: renders the pre-execution sub-task decomposition + model routing +
      // per-task cost preview. Only ever invoked when the host has explicitly sent a
      // 'taskBreakdown' message (gated server-side by the adminMode setting), so this
      // never appears for standard users. Purely inline in the logs - no modal, no
      // interruption to the normal send/estimate flow.
      function appendTaskBreakdownCard(data) {
        try {
          if (!logsContainer) return;
          const subtasks = data.subtasks || [];
          if (subtasks.length === 0) return;

          const card = document.createElement('div');
          card.className = 'job-complete-card task-breakdown-card';

          const title = document.createElement('span');
          title.className = 'job-title';
          title.textContent = '🧭 Admin: Task Routing Preview (' + subtasks.length + ' sub-task' + (subtasks.length > 1 ? 's' : '') + ')';
          card.appendChild(title);

          const complexityIcon = { light: '🟢', medium: '🟡', tough: '🔴' };

          subtasks.forEach((t, i) => {
            const row = document.createElement('div');
            row.className = 'job-footer';
            row.textContent = '  ' + (i + 1) + '. ' + (complexityIcon[t.complexity] || '⚪') + ' [' + t.complexity + '] ' +
              t.label + ' → ' + t.modelLabel + ' ($' + (t.costUsd || 0).toFixed(4) + ')';
            card.appendChild(row);

            const candidates = t.candidates || [];
            if (candidates.length > 0) {
              const altRow = document.createElement('div');
              altRow.className = 'job-footer';
              altRow.textContent = '       considered: ' + candidates.map((c) =>
                (c.selected ? '✅ ' : '') + c.modelLabel + ' $' + (c.costUsd || 0).toFixed(4)
              ).join('  |  ');
              card.appendChild(altRow);
            }
          });

          const totalRow = document.createElement('span');
          totalRow.className = 'job-title';
          totalRow.textContent = '💰 Total Estimated Cost: $' + (data.totalCostUsd || 0).toFixed(4);
          card.appendChild(totalRow);
          // Held for the job report, so the estimate can be put next to what the job actually
          // cost. An estimate nobody ever compares against reality never gets better.
          lastEstimateUsd = data.totalCostUsd || 0;
          lastEstimateAgent = (data.items && data.items.length === 1 && data.items[0].modelLabel) ? data.items[0].modelLabel : '';

          logsContainer.appendChild(card);
          logsContainer.scrollTop = logsContainer.scrollHeight;
        } catch (err) {
          console.error('[DAI-Flash] Error appending task breakdown card:', err);
        }
      }

      let batchCardEl = null;

      function ensureBatchCard(sourceFile) {
        if (batchCardEl && document.body.contains(batchCardEl)) return batchCardEl;
        if (!logsContainer) return null;
        const card = document.createElement('div');
        card.className = 'job-complete-card';
        card.innerHTML = '';

        const title = document.createElement('span');
        title.className = 'job-title';
        title.textContent = '📦 Batch: ' + (sourceFile || 'attached file');
        card.appendChild(title);

        const status = document.createElement('div');
        status.className = 'job-footer';
        status.id = 'batchStatusLine';
        card.appendChild(status);

        logsContainer.appendChild(card);
        logsContainer.scrollTop = logsContainer.scrollHeight;
        batchCardEl = card;
        return card;
      }

      function renderBatchProgress(snapshot) {
        try {
          const card = ensureBatchCard(snapshot.sourceFile);
          if (!card) return;
          const status = card.querySelector('#batchStatusLine');
          if (!status) return;
          const pct = snapshot.total > 0 ? Math.round(((snapshot.completed + snapshot.failed) / snapshot.total) * 100) : 0;
          status.textContent = '⏳ ' + (snapshot.currentIndex + 1) + '/' + snapshot.total + ' (' + pct + '%) — ✅ ' +
            snapshot.completed + ' done, ⚠️ ' + snapshot.failed + ' failed';
        } catch (err) {
          console.error('[DAI-Flash] Error rendering batch progress:', err);
        }
      }

      function renderBatchComplete(snapshot) {
        try {
          const card = ensureBatchCard(snapshot.sourceFile);
          if (!card) return;
          const status = card.querySelector('#batchStatusLine');
          if (status) {
            status.textContent = '✅ Batch finished: ' + snapshot.completed + '/' + snapshot.total + ' succeeded, ' +
              snapshot.failed + ' failed';
          }
          batchCardEl = null;
        } catch (err) {
          console.error('[DAI-Flash] Error rendering batch completion:', err);
        }
      }

      function resetTaskPanel() {
        try {
          const taskPanel = document.getElementById('taskPanel');
          if (taskPanel) {
            taskPanel.style.display = 'none';
          }
          const todoBody = document.getElementById('todoBody');
          if (todoBody) {
            todoBody.innerHTML = '';
          }
          const filesBody = document.getElementById('filesBody');
          if (filesBody) {
            filesBody.innerHTML = '';
          }
          const reviewBar = document.getElementById('reviewBar');
          if (reviewBar) {
            reviewBar.classList.remove('visible');
          }
        } catch (err) {
          console.error('[DAI-Flash] Error resetting task panel:', err);
        }
      }

      // Message listener
      window.addEventListener('message', (event) => {
        try {
          const message = event.data;
          console.log('[DAI-Flash] 📨 Message received from extension:', message.type || 'unknown');
          
          if (message.type === 'ready') {
            console.log('[DAI-Flash] ✅ Extension is ready, webview fully initialized');
          } else if (message.type === 'sessionsList') {
            displaySessions(message.sessions || [], message.forced === true);
          } else if (message.type === 'chatThinking') {
            appendChatThinking();
          } else if (message.type === 'chatReply') {
            appendChatReply(message);
          } else if (message.type === 'agentStatus') {
            setAgentStatus(message.state, message.detail);
          } else if (message.type === 'recoveryAvailable') {
            if (message.available === false) {
              if (recoveryBanner) recoveryBanner.classList.remove('visible');
            } else {
              console.log('[DAI-Flash] 🔁 Recovery banner shown for interrupted job');
              if (recoveryBanner && recoveryText) {
                const shortPrompt = (message.prompt || '').slice(0, 80);
                recoveryText.textContent = '⚠️ Interrupted job found (stopped after step ' + message.lastCompletedStep + '/5): "' + shortPrompt + (message.prompt && message.prompt.length > 80 ? '…' : '') + '"';
                recoveryBanner.classList.add('visible');
              }
            }
          } else if (message.type === 'log') {
            appendLog(message.text, message.level || 'info');
          } else if (message.type === 'previewReady') {
            appendPreviewLink(message.url);
          } else if (message.type === 'progress') {
            console.log('[DAI-Flash] ⏳ Progress:', message.step + '/' + message.total, message.label);
            if (message.step === 1) {
              isRunning = true;
              if (stopBtn) stopBtn.disabled = false;
              setRunningGlow(true);
            }
            upsertProgressBubble(message.step, message.total, message.label);
          } else if (message.type === 'jobComplete') {
            console.log('[DAI-Flash] ✅ Job complete received');
            appendJobCompleteCard(message);
            isRunning = false;
            if (sendBtn) sendBtn.disabled = false;
            if (stopBtn) stopBtn.disabled = true;
            setRunningGlow(false);
          } else if (message.type === 'estimateResult') {
            console.log('[DAI-Flash] 📊 Estimate result received');
            appendEstimateCard(message);
          } else if (message.type === 'projectQuoteThinking') {
            console.log('[DAI-Flash] 📐 Project quote: calling model for module/hour breakdown...');
            if (projectQuoteBtn) projectQuoteBtn.disabled = true;
          } else if (message.type === 'projectQuoteResult') {
            console.log('[DAI-Flash] 📐 Project quote result received');
            if (projectQuoteBtn) projectQuoteBtn.disabled = false;
            appendProjectQuoteCard(message);
          } else if (message.type === 'projectQuoteError') {
            console.log('[DAI-Flash] ⚠️ Project quote failed:', message.error);
            if (projectQuoteBtn) projectQuoteBtn.disabled = false;
            appendLog('⚠️ Project quote failed: ' + message.error, 'error');
          } else if (message.type === 'projectQuoteSettings') {
            if (qsRate) qsRate.value = message.ratePerHour;
            if (qsProfit) qsProfit.value = message.profitPercent;
            if (qsGst) qsGst.value = message.gstPercent;
            if (qsTierLow) qsTierLow.value = message.tierRateLow;
            if (qsTierMedium) qsTierMedium.value = message.tierRateMedium;
            if (qsTierHigh) qsTierHigh.value = message.tierRateHigh;
            if (qsTierAdvanced) qsTierAdvanced.value = message.tierRateAdvanced;
            const pricingFlatEl = document.getElementById('qsPricingFlat');
            const pricingTieredEl = document.getElementById('qsPricingTiered');
            if (message.pricingMode === 'tiered') {
              if (pricingTieredEl) pricingTieredEl.checked = true;
            } else if (pricingFlatEl) {
              pricingFlatEl.checked = true;
            }
            updateTierRatesVisibility();
            if (qsHint) qsHint.textContent = 'These 3 values are what "Quote" uses for Base Cost → Fee → GST → Final Quote. Saved automatically as you change them.';
            const qsAiCostStats = document.getElementById('qsAiCostStats');
            if (qsAiCostStats) {
              const s = message.autoAiCostStats;
              if (!s || !s.count) {
                qsAiCostStats.textContent = '📊 Run "Quote" with 0 agents ticked (Auto) at least once to see your real AI cost/hour here.';
              } else {
                const USD_TO_INR_STATS = 87;
                const costPerHourInr = s.avgCostPerHourUsd * USD_TO_INR_STATS;
                qsAiCostStats.textContent = '📊 Auto Quote runs so far: ' + s.count
                  + ' | Avg AI cost: $' + s.avgCostPerHourUsd.toFixed(4) + '/hr (≈₹' + costPerHourInr.toFixed(2) + '/hr)'
                  + ' | Avg tokens/run: ' + Math.round(s.avgInputTokens) + ' in / ' + Math.round(s.avgOutputTokens) + ' out'
                  + ' | Total quoted so far: ' + s.totalHours.toFixed(1) + ' hrs for $' + s.totalCostUsd.toFixed(4) + ' AI spend.'
                  + ' This is the AI-side cost only - compare it against your Rate/hr above to see your margin.';
              }
            }
          } else if (message.type === 'taskBreakdown') {
            console.log('[DAI-Flash] 🧭 Admin task breakdown received');
            appendTaskBreakdownCard(message);
          } else if (message.type === 'batchStarted') {
            console.log('[DAI-Flash] 📦 Batch started:', message.total, message.sourceFile);
            ensureBatchCard(message.sourceFile);
          } else if (message.type === 'batchProgress') {
            renderBatchProgress(message.snapshot);
          } else if (message.type === 'batchComplete') {
            renderBatchComplete(message.snapshot);
          } else if (message.type === 'summary') {
            console.log('[DAI-Flash] 📝 Summary received');
            appendSummaryCard(message.html);
            isRunning = false;
            if (sendBtn) sendBtn.disabled = false;
            if (stopBtn) stopBtn.disabled = true;
            setRunningGlow(false);
          } else if (message.type === 'metrics') {
            console.log('[DAI-Flash] 📊 Metrics update:', message.costUsd, message.inputTokens, message.outputTokens);
            const costLabel = document.getElementById('costLabel');
            if (costLabel) {
              costLabel.textContent = (message.costUsd || 0).toFixed(4);
            }
            const tokenLabel = document.getElementById('tokenLabel');
            if (tokenLabel) {
              tokenLabel.textContent = (message.inputTokens || 0) + ' in / ' + (message.outputTokens || 0) + ' out';
            }
          } else if (message.type === 'todo') {
            console.log('[DAI-Flash] 📋 Todo items received:', message.items?.length);
            const taskPanel = document.getElementById('taskPanel');
            if (taskPanel) {
              taskPanel.style.display = 'flex';
            }
            const todoHeader = document.getElementById('todoHeader');
            if (todoHeader) {
              const done = message.items.filter(item => item.done).length;
              todoHeader.textContent = '📋 ' + done + '/' + message.items.length;
            }
            const body = document.getElementById('todoBody');
            if (body) {
              body.innerHTML = '';
              const done = message.items.filter(item => item.done).length;
              const total = message.items.length;

              // A heading line, so opening the panel answers "is this job finished, and what
              // was it?" at a glance - the counter pill alone only ever said "2/3".
              const head = document.createElement('div');
              head.className = 'todo-head';
              head.textContent = done === total && total > 0
                ? '✅ All ' + total + ' steps completed'
                : '⏳ ' + done + ' of ' + total + ' steps done';
              body.appendChild(head);

              for (const item of message.items) {
                const row = document.createElement('div');
                row.className = 'todo-row' + (item.done ? ' todo-done' : '');
                row.textContent = (item.done ? '✓ ' : '• ') + item.label;
                body.appendChild(row);
              }
            }
          } else if (message.type === 'fileChanged') {
            console.log('[DAI-Flash] 📄 Files changed:', message.files?.length);
            const files = message.files || [];
            const taskPanel = document.getElementById('taskPanel');
            if (taskPanel) {
              taskPanel.style.display = 'flex';
            }
            const filesHeader = document.getElementById('filesHeader');
            if (filesHeader) {
              filesHeader.textContent = '📄 ' + files.length;
            }
            const body = document.getElementById('filesBody');
            if (body) {
              body.innerHTML = '';
              for (const f of files) {
                const path = f.path || 'unknown';
                const badge = document.createElement('div');
                badge.className = 'file-badge';
                badge.dataset.path = path;

                const pathSpan = document.createElement('span');
                pathSpan.className = 'file-path';
                pathSpan.textContent = '📄 ' + path;
                if (f.modelLabel) {
                  const agentTag = document.createElement('span');
                  agentTag.className = 'file-agent';
                  agentTag.textContent = ' ' + f.modelLabel + ' · attempt ' + (f.attempts || 1) + '/3';
                  pathSpan.appendChild(agentTag);
                }

                const diffSpan = document.createElement('span');
                diffSpan.className = 'file-diff';
                diffSpan.append('+' + (f.additions || 0) + ' ');
                const delSpan = document.createElement('span');
                delSpan.className = 'del';
                delSpan.textContent = '-' + (f.deletions || 0);
                diffSpan.appendChild(delSpan);

                const actions = document.createElement('span');
                actions.className = 'file-actions';
                const keepBtn = document.createElement('button');
                keepBtn.className = 'keep-file-btn';
                keepBtn.dataset.action = 'keep';
                keepBtn.dataset.path = path;
                keepBtn.textContent = 'Keep';
                const undoBtn = document.createElement('button');
                undoBtn.className = 'undo-file-btn';
                undoBtn.dataset.action = 'undo';
                undoBtn.dataset.path = path;
                undoBtn.textContent = 'Undo';
                actions.appendChild(keepBtn);
                actions.appendChild(undoBtn);

                badge.appendChild(pathSpan);
                badge.appendChild(diffSpan);
                badge.appendChild(actions);
                body.appendChild(badge);
              }
            }
          } else if (message.type === 'reviewStatus') {
            renderReviewBar(message);
          } else if (message.type === 'fileStatus') {
            const badge = document.querySelector('.file-badge[data-path="' + message.path + '"]');
            if (badge) {
              badge.classList.remove('kept', 'reverted');
              badge.classList.add(message.status === 'kept' ? 'kept' : 'reverted');
            }
          }
        } catch (err) {
          console.error('[DAI-Flash] ❌ Error handling message:', err, event.data);
        }
      });

      console.log('[DAI-Flash] ✅ Webview script fully loaded and all listeners attached');
      extLog('[DAI-Flash] ✅ Webview script fully loaded and all listeners attached');
    } catch (err) {
      console.error('[DAI-Flash] ❌ Critical error during webview initialization:', err);
    }
  </script>
</body>
</html>`;
  }

  // Halts every in-flight execution path (main runner, corrective runner, batch processor)
  // and drops the queue - shared by the plain Stop button and the panic Undo button below.
  private _stopExecution(reason: string): void {
    this._runner.stop();
    this._activeCorrectiveRunner?.stop();
    this._batchProcessor.stop();
    this._isJobRunning = false;
    if (this._taskQueue.length > 0) {
      this._onLog(`🗑 Cleared ${this._taskQueue.length} queued task(s) due to manual stop`);
      this._taskQueue = [];
    }
    this._postToWebview('log', { text: `⛔ Execution stopped (${reason})`, level: 'warn' });
    this._setAgentStatus('idle', reason);
  }

  // The header Undo button - a full "undo the last mistake" panic action, not just a
  // per-file revert: stops any job/queue still running AND reverts every still-pending file
  // change back to its real pre-job on-disk content, then discards any interrupted-job
  // checkpoint so a resume can never resurrect the work being undone.
  private async _panicUndo(): Promise<void> {
    this._stopExecution('Undo pressed');
    await this._resolveAllFiles('reverted');
    if (this._checkpoint) {
      this._checkpoint = undefined;
      this._context.workspaceState.update(CHECKPOINT_KEY, undefined);
    }
    this._postToWebview('log', { text: '↩️ Undo complete - execution stopped and all pending changes reverted', level: 'warn' });
  }

  private _handleWebviewMessage(message: any) {
    switch (message.command) {
      case 'clientLog':
        output.appendLine('[DAI-Flash][webview] ' + message.text);
        break;
      case 'run':
        if (this._isJobRunning) {
          this._taskQueue.push({ prompt: message.prompt, model: message.model });
          this._onLog(`🕒 Queued task (position ${this._taskQueue.length} in queue): ${message.prompt}`);
        } else {
          void this._runAgent(message.prompt, message.model);
        }
        break;
      case 'estimate':
        this._sendCostEstimate(message.prompt || '');
        break;
      case 'estimateProject': {
        const mode: ProjectQuoteMode = message.mode === 'ai-assisted' ? 'ai-assisted' : 'manual';
        const agentIds: string[] = Array.isArray(message.agentIds) ? message.agentIds.filter((id: unknown) => typeof id === 'string') : [];
        void this._sendProjectQuote(message.prompt || '', mode, agentIds);
        break;
      }
      case 'getProjectQuoteSettings':
        this._sendProjectQuoteSettings();
        break;
      case 'saveProjectQuoteSettings':
        void this._saveProjectQuoteSettings(message);
        break;
      case 'chatSend':
        if (typeof message.prompt === 'string' && message.prompt.trim()) {
          void this._runChat(message.prompt.trim());
        }
        break;
      case 'attachFile':
        void this._pickAndRunBatchFile(message.model);
        break;
      case 'undo':
        void this._panicUndo();
        break;
      case 'keepFile':
        this._keepFile(message.path);
        break;
      case 'undoFile':
        void this._undoFile(message.path);
        break;
      case 'showAgentReport':
        void this.showAgentReport();
        break;
      case 'keepAllFiles':
        void this._resolveAllFiles('kept');
        break;
      case 'undoAllFiles':
        void this._resolveAllFiles('reverted');
        break;
      case 'stop':
        this._stopExecution('Stopped by user');
        break;
      case 'clearChat':
        this._sessionCostUsd = 0;
        this._sessionInputTokens = 0;
        this._sessionOutputTokens = 0;
        this._chatHistory = [];
        this._postSessionsList();
        break;
      // Wipes the stored "recent sessions" rows (old 'stop' entries, rolled-back runs and the
      // like). Display-only history - clearing it never touches files, checkpoints or backups.
      case 'clearSessions':
        void this._jobHistory.clear().then(() => {
          this._onLog('🧹 Cleared the recent-sessions list.');
          this._postSessionsList(true);
        });
        break;
      case 'resumeJob':
        this._resumeJob();
        break;
      case 'discardCheckpoint':
        this._checkpoint = undefined;
        this._context.workspaceState.update(CHECKPOINT_KEY, undefined);
        this._onLog('🆕 Discarded interrupted job checkpoint - starting fresh');
        break;
      case 'openExternal':
        if (message.url) {
          vscode.env.openExternal(vscode.Uri.parse(message.url));
        }
        break;
    }
  }

  // Admin-only setting - never surfaced to standard users; gates the pre-execution
  // task-decomposition/cost-routing breakdown preview.
  private _isAdminMode(): boolean {
    return vscode.workspace.getConfiguration('daiFlash').get<boolean>('adminMode', false) === true;
  }

  // Reads the per-cost-band retry-before-escalate counts from settings (daiFlash.retry.*),
  // falling back to DEFAULT_RETRY_ATTEMPTS field-by-field so a partially-set config never loses
  // the other two bands' sane defaults. Passed into every AgentRunner.run() call so a real job, a
  // resumed job, and a quality-gate correction pass all honor the same, currently-configured
  // retry policy. Bands are by blended $ cost across the whole MODELS table (cheapest ~34%,
  // middle ~33%, priciest ~33%), not by reasoning label - see agentRunner.ts costTierBand().
  private _getRetryAttemptsConfig(): RetryAttemptsConfig {
    const config = vscode.workspace.getConfiguration('daiFlash');
    return {
      cheapTier: config.get<number>('retry.cheapTierAttempts', DEFAULT_RETRY_ATTEMPTS.cheapTier),
      midTier: config.get<number>('retry.midTierAttempts', DEFAULT_RETRY_ATTEMPTS.midTier),
      expensiveTier: config.get<number>('retry.expensiveTierAttempts', DEFAULT_RETRY_ATTEMPTS.expensiveTier),
    };
  }

  /**
   * Builds the tool loop's options, or returns undefined so the runner keeps to the original
   * single-shot path. Undefined is the default on purpose: the new road opens only when the
   * user switches it on, and until then nothing about their existing runs changes.
   *
   * Returning undefined when there is no workspace folder is not a fallback, it is the correct
   * answer - tools resolve every path against a workspace root, and there isn't one.
   */
  private _getToolLoopOptions(): ToolLoopOptions | undefined {
    const config = vscode.workspace.getConfiguration('daiFlash');
    if (!config.get<boolean>('experimental.toolLoop', false)) return undefined;

    const root = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
    if (!root) {
      this._onLog('🧰 Tool mode is on but no folder is open - falling back to the classic path for this run.');
      return undefined;
    }

    const shellLevel = config.get<string>('shellLevel', 'commit') === 'read' ? 'read' : 'commit';

    return {
      workspaceRoot: root,
      shellLevel,
      allowedScripts: readWorkspaceScripts(root),
      destructiveRatio: config.get<number>('destructiveWriteRatio', 0.4),
      // A real modal, every time, whatever Auto-Approve says. This is the one place the agent
      // is made to stop and ask a person, so it must not be something a setting can silence.
      requestConsent: async (question: string, detail: string) => {
        const choice = await vscode.window.showWarningMessage(question, { modal: true, detail }, 'Allow this change');
        return choice === 'Allow this change';
      },
    };
  }

  // Silently posts the sub-task routing/cost breakdown to the webview - Admin-only, no
  // modal/dialog involved, so it never interrupts the workflow for anyone else.
  private _maybeSendTaskBreakdown(prompt: string): void {
    if (!this._isAdminMode()) return;
    try {
      const breakdown = decomposeAndRouteTasks(prompt);
      this._postToWebview('taskBreakdown', breakdown);
    } catch (err) {
      output.appendLine(`[DAI-Flash] ⚠️ Task breakdown preview failed: ${err instanceof Error ? err.message : String(err)}`);
    }
  }

  // Pushes the live header badge state ('idle' | 'running' | 'error') to the webview.
  private _setAgentStatus(state: 'idle' | 'running' | 'error', detail?: string): void {
    this._postToWebview('agentStatus', { state, detail });
  }

  // Drops every trace of the previous task so a newly submitted prompt is executed on its
  // own, and can never resume or overwrite the work of an already-completed instruction.
  private _isolateTaskContext(newPrompt: string): void {
    if (this._checkpoint && this._checkpoint.prompt !== newPrompt) {
      this._onLog(`🧹 Cleared stale task context from previous prompt: "${this._checkpoint.prompt.slice(0, 60)}"`);
    }
    this._checkpoint = undefined;
    this._context.workspaceState.update(CHECKPOINT_KEY, undefined);
    this._postToWebview('recoveryAvailable', { available: false });

    if (this._pendingFiles.size > 0) {
      this._resolveAllFiles('kept');
    }
  }

  private async _runAgent(prompt: string, model?: string) {
    // Claim the "a job is running" flag synchronously, BEFORE the budget confirm dialog
    // below can `await` - otherwise a second prompt sent while that dialog is still open
    // would see `_isJobRunning === false` and skip the queue, starting two jobs at once.
    this._isJobRunning = true;

    if (!(await this._checkMonthlyBudget(prompt, model))) {
      this._isJobRunning = false;
      this._drainQueueIfIdle();
      return;
    }

    this._isolateTaskContext(prompt);
    this._setAgentStatus('running', 'Executing: ' + prompt.slice(0, 60));
    this._lastPrompt = prompt;
    this._lastCostUsd = this._runner.costUsd || 0;
    this._lastInputTokens = this._runner.inputTokens || 0;
    this._lastOutputTokens = this._runner.outputTokens || 0;

    this._onLog(`📌 Executing current prompt only: "${prompt}"`);
    this._orchestrate(prompt);
    this._maybeSendTaskBreakdown(prompt);

    this._checkpoint = { prompt, model, lastCompletedStep: 0, pendingFiles: [], timestamp: Date.now() };
    this._saveCheckpoint();

    this._runner.run(prompt, {
      model,
      getApiKey: (provider) => this._apiKeyManager.ensureKey(provider),
      runQualityGates: this._makeQualityGateCallback(),
      fileOps: this._makeFileOpsHooks(),
      retryAttempts: this._getRetryAttemptsConfig(),
      toolLoop: this._getToolLoopOptions(),
    });
  }

  // Monthly budget cap: warn + require explicit confirm rather than a hard block, so a
  // genuinely important job is never impossible to run - just something you have to
  // consciously say yes to once this month's spend looks high. Returns false if the job
  // should NOT proceed (cap configured, would be exceeded, and the user declined to continue).
  private async _checkMonthlyBudget(prompt: string, model?: string): Promise<boolean> {
    let estimate;
    try {
      estimate = estimateJobCostUsd(prompt, model);
    } catch {
      return true; // never block a job because the local estimate itself failed
    }
    const check = this._budgetGuard.checkBeforeJob(estimate.costUsd);
    if (!check.wouldExceed) return true;

    const choice = await vscode.window.showWarningMessage(
      `Monthly budget warning: this job (~$${estimate.costUsd.toFixed(4)} estimated on ${estimate.modelLabel}) would bring this month's spend to ~$${check.projectedUsd.toFixed(2)}, over your $${check.capUsd.toFixed(2)} monthly cap (Settings → DAI Flash → Initial Budget Usd). Already spent this month: ~$${check.spentUsd.toFixed(2)}.`,
      { modal: true },
      'Continue Anyway'
    );
    if (choice === 'Continue Anyway') {
      this._onLog(`⚠️ Proceeding over the monthly budget cap by explicit confirmation (month-to-date after this job: ~$${check.projectedUsd.toFixed(2)} / cap $${check.capUsd.toFixed(2)})`);
      return true;
    }
    this._onLog(`🛑 Job cancelled - would exceed the $${check.capUsd.toFixed(2)} monthly budget cap. Spent so far this month: ~$${check.spentUsd.toFixed(2)}.`);
    return false;
  }

  // A job cancelled at the budget-confirm step never reaches _onJobComplete (the usual
  // place the queue is drained), so if anything is waiting behind it, start that instead.
  private _drainQueueIfIdle(): void {
    if (this._isJobRunning) return;
    const next = this._taskQueue.shift();
    if (next) {
      this._onLog(`▶️ Starting next queued task: ${next.prompt}`);
      void this._runAgent(next.prompt, next.model);
    }
  }

  // "💬 Chat" - a plain conversational turn with Sonnet, completely separate from real job
  // execution (no files touched, no quality gates, no AgentRunner involved at all). Uses the
  // same Anthropic API key/rate as everything else this extension already calls - real
  // pay-per-token usage on that account, no separate "chat plan". If Sonnet judges the
  // message to be an actionable coding request, it hands back a ready-to-run agent
  // instruction too, which the webview offers as a one-click "Send to Agent" button.
  private async _runChat(prompt: string): Promise<void> {
    this._postToWebview('chatThinking', {});
    try {
      const apiKey = await this._apiKeyManager.ensureKey('anthropic');
      const result = await getChatReply(apiKey, this._chatHistory, prompt);
      this._chatHistory.push({ role: 'user', content: prompt }, { role: 'assistant', content: result.reply });
      // Keep the stored conversation bounded so it can never grow the prompt (and cost) unboundedly.
      if (this._chatHistory.length > 40) this._chatHistory = this._chatHistory.slice(-40);

      this._sessionCostUsd += result.costUsd;
      this._sessionInputTokens += result.inputTokens;
      this._sessionOutputTokens += result.outputTokens;
      void this._budgetGuard.addSpend(result.costUsd);
      this._postToWebview('metrics', {
        costUsd: this._sessionCostUsd,
        inputTokens: this._sessionInputTokens,
        outputTokens: this._sessionOutputTokens,
      });

      this._postToWebview('chatReply', { reply: result.reply, agentTask: result.agentTask });
    } catch (err) {
      this._postToWebview('chatReply', { reply: '', error: err instanceof Error ? err.message : String(err) });
    }
  }

  private _resumeJob() {
    if (!this._checkpoint) return;
    const checkpoint = this._checkpoint;
    this._isJobRunning = true;
    this._setAgentStatus('running', 'Resuming interrupted job');
    this._lastCostUsd = this._runner.costUsd || 0;
    this._lastInputTokens = this._runner.inputTokens || 0;
    this._lastOutputTokens = this._runner.outputTokens || 0;

    this._runner.run(checkpoint.prompt, {
      model: checkpoint.model,
      getApiKey: (provider) => this._apiKeyManager.ensureKey(provider),
      resumeFromStep: checkpoint.lastCompletedStep,
      resumeModelId: checkpoint.selectedModelId,
      resumePendingFiles: checkpoint.pendingFiles,
      runQualityGates: this._makeQualityGateCallback(),
      fileOps: this._makeFileOpsHooks(),
      retryAttempts: this._getRetryAttemptsConfig(),
      toolLoop: this._getToolLoopOptions(),
    });
  }

  private _saveCheckpoint() {
    this._context.workspaceState.update(CHECKPOINT_KEY, this._checkpoint);
  }

  // Returns the underlying write so deactivate() can await it - globalState.update() is
  // async, and an un-awaited write here can lose the race against extension-host teardown
  // during a normal "Reload Window", which was making every routine reload look like a
  // crash (wasLastShutdownClean() reading the stale pre-shutdown value) and silently
  // re-triggering the backup-restore flow.
  public markCleanShutdown(): Thenable<void> {
    return this._backupManager.markCleanShutdown(true);
  }

  public stopPricingSync(): void {
    this._pricingSync.stop();
  }

  // Session completion: flush any unsynced agent metrics before the host tears us down.
  public async flushMetrics(): Promise<void> {
    this._metricsSync.stop();
    await this._metricsSync.syncOnSessionEnd();
  }

  public getAgentMetricsPayload(): Record<string, unknown> {
    return this._agentMetrics.buildPayload();
  }

  // --- Admin-only entry points ---
  // Two checks, both required: the daiFlash.adminMode setting (a visibility preference) AND
  // a live re-verification against the Admin Master Key (the actual access control). The
  // setting alone used to be sufficient, which meant anyone who could open Settings could
  // grant themselves the P&L/billing/export views without ever presenting the key - this
  // closes that gap by re-checking SecretStorage against the key's digest on every call.
  private async _requireAdmin(): Promise<boolean> {
    if (!this._isAdminMode()) {
      vscode.window.showWarningMessage('DAI Flash: this command requires Admin Mode (daiFlash.adminMode).');
      return false;
    }
    if (!(await this._gate.isUnlocked())) {
      vscode.window.showWarningMessage(
        'DAI Flash: the Admin Master Key is not currently verified for this installation. Run "DAI Flash Admin: Unlock" first.'
      );
      return false;
    }
    return true;
  }

  /**
   * The agent scorecard, opened as a plain document he can read, copy and keep.
   *
   * Deliberately NOT behind Admin Mode. The P&L report is admin-gated because it is about
   * margins and billing; this one is about which of HIS agents does HIS work well, which is
   * not privileged information about a business - it is the thing he is trying to decide.
   * Locking it away is how a ledger that has been recording since day one stayed invisible.
   */
  public async showAgentReport(): Promise<void> {
    const payload = this._agentMetrics.buildPayload();
    const agents = (payload.MASTER_AGENTS || []) as unknown as AgentRow[];
    const text = buildAgentReport({ agents, generatedAt: String(payload.generatedAt || '') });
    const doc = await vscode.workspace.openTextDocument({ content: text, language: 'plaintext' });
    await vscode.window.showTextDocument(doc, { preview: false });
  }

  public async showAdminReport(): Promise<void> {
    if (!(await this._requireAdmin())) return;
    const report = this._adminAnalytics.buildReport();
    if (report.overall.jobs === 0) {
      vscode.window.showInformationMessage('DAI Flash Admin: no job history recorded yet.');
      return;
    }

    const lines: string[] = [];
    const row = (t: { key: string; jobs: number; costUsd: number; billedUsd: number; profitUsd: number; marginPct: number }) =>
      `  ${t.key.padEnd(28)} jobs=${String(t.jobs).padStart(4)}  cost=$${t.costUsd.toFixed(4)}  billed=$${t.billedUsd.toFixed(4)}  profit=$${t.profitUsd.toFixed(4)}  margin=${t.marginPct.toFixed(1)}%`;

    lines.push('=== DAI Flash Admin P&L Report ===');
    lines.push(`Generated: ${new Date(report.generatedAt).toLocaleString()}   Billing multiplier: ${report.billingMultiplier}x`);
    lines.push('', 'OVERALL', row(report.overall));
    lines.push('', 'BY MODEL', ...report.byModel.map(row));
    lines.push('', 'BY PROVIDER', ...report.byProvider.map(row));
    lines.push('', 'BY DAY', ...report.byDay.map(row));

    const history = this._pricingHistory.getSnapshots();
    lines.push('', `HISTORICAL RATE SNAPSHOTS (${history.length})`);
    for (const snap of history.slice(-5)) {
      lines.push(`  ${new Date(snap.timestamp).toLocaleString()} (${snap.source}) - ${Object.keys(snap.rates).length} models`);
    }

    // Fed entirely by the automatic execution ledger - nothing here is entered by hand.
    const agents = (this.getAgentMetricsPayload().MASTER_AGENTS || []) as Array<Record<string, number | string>>;
    lines.push('', `AGENT PERFORMANCE (${agents.length} agents, auto-synced)`);
    for (const a of agents) {
      lines.push(`  ${String(a.name).padEnd(28)} runs=${String(a.runs).padStart(4)}  done=${a.completedTasks}  errors=${a.errors}  1st-try=${a.firstTrySuccessRate}%  cost=$${a.costUsd}`);
    }

    output.appendLine(lines.join('\n'));
    output.show(true);
  }

  public async exportAdminExcel(): Promise<void> {
    if (!(await this._requireAdmin())) return;
    const report = this._adminAnalytics.buildReport();
    if (report.overall.jobs === 0) {
      vscode.window.showInformationMessage('DAI Flash Admin: no job history to export yet.');
      return;
    }

    const target = await vscode.window.showSaveDialog({
      saveLabel: 'Export Admin P&L Report',
      filters: { 'Excel-compatible CSV': ['csv'] },
      defaultUri: vscode.Uri.joinPath(this._context.globalStorageUri, `dai-flash-admin-report-${Date.now()}.csv`),
    });
    if (!target) return;

    await vscode.workspace.fs.writeFile(target, Buffer.from(this._adminAnalytics.toCsv(report), 'utf8'));
    vscode.window.showInformationMessage(`DAI Flash Admin: report exported to ${target.fsPath}`);
  }

  public async exportAdminApi(): Promise<void> {
    if (!(await this._requireAdmin())) return;
    try {
      const result = await this._adminApiExport.export({
        ...this._adminAnalytics.toApiPayload(this._adminAnalytics.buildReport()),
        agents: this.getAgentMetricsPayload(),
      });
      const where = result.posted
        ? `posted to ${result.endpoint} (HTTP ${result.statusCode}) and saved locally`
        : 'saved locally (set daiFlash.admin.apiEndpoint to also POST it)';
      vscode.window.showInformationMessage(`DAI Flash Admin: analytics ${where}: ${result.fileUri.fsPath}`);
    } catch (err) {
      vscode.window.showErrorMessage(`DAI Flash Admin export failed: ${err instanceof Error ? err.message : String(err)}`);
    }
  }

  public async syncAgentMetricsNow(): Promise<void> {
    if (!(await this._requireAdmin())) return;
    const result = await this._metricsSync.syncNow('manual');
    if (!result) {
      vscode.window.showWarningMessage('DAI Flash: agent metrics sync did not complete - see the DAI-Flash output channel.');
      return;
    }
    const where = result.posted ? `posted to ${result.endpoint} (HTTP ${result.statusCode})` : 'saved locally';
    vscode.window.showInformationMessage(`DAI Flash: agent metrics ${where}: ${result.fileUri.fsPath}`);
  }

  // Admin-only, human-confirmed delete. The AI agents never call this themselves - there is
  // no way for a generated response to trigger it - it exists purely so the admin has a safe
  // in-extension way to remove a file (e.g. a test/scratch file) without needing shell access.
  public async deleteWorkspaceFile(): Promise<void> {
    if (!(await this._requireAdmin())) return;
    const root = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
    if (!root) {
      vscode.window.showWarningMessage('DAI Flash: open a workspace folder first.');
      return;
    }

    const picked = await vscode.window.showOpenDialog({
      canSelectMany: false,
      canSelectFolders: false,
      defaultUri: vscode.Uri.file(root),
      openLabel: 'Select file to delete',
    });
    if (!picked || picked.length === 0) return;

    const abs = picked[0].fsPath;
    const relPath = path.relative(root, abs);
    if (relPath.startsWith('..') || path.isAbsolute(relPath)) {
      vscode.window.showErrorMessage('DAI Flash: refusing to delete a file outside the open workspace.');
      return;
    }

    const confirm = await vscode.window.showWarningMessage(
      `Delete "${relPath}"? It will be sent to the Recycle Bin, not permanently erased.`,
      { modal: true },
      'Delete'
    );
    if (confirm !== 'Delete') return;

    try {
      await this._fileOpsGuard.deleteFile(root, relPath);
      log(`[DAI-Flash] 🗑️ Admin deleted ${relPath} (sent to Recycle Bin)`);
      vscode.window.showInformationMessage(`DAI Flash Admin: deleted ${relPath} (recoverable from the Recycle Bin).`);
    } catch (err) {
      vscode.window.showErrorMessage(`DAI Flash Admin: delete failed - ${err instanceof Error ? err.message : String(err)}`);
    }
  }

  // Lets an admin change a provider's stored key on demand, rather than only being
  // able to re-enter it when ensureKey() rejects the stored value as malformed.
  public async updateApiKey(): Promise<void> {
    if (!(await this._requireAdmin())) return;
    const items = (Object.keys(PROVIDER_LABELS) as ApiKeyProvider[]).map((provider) => ({
      label: PROVIDER_LABELS[provider],
      provider,
    }));
    const picked = await vscode.window.showQuickPick(items, {
      title: 'DAI Flash: Update API Key',
      placeHolder: 'Select a provider to update its API key',
    });
    if (!picked) return;

    const entered = await vscode.window.showInputBox({
      title: `Enter your ${picked.label} API key`,
      password: true,
      ignoreFocusOut: true,
      placeHolder: picked.provider === 'anthropic' ? 'sk-ant-...' : 'sk-...',
    });
    if (!entered) return;

    await this._apiKeyManager.setKey(picked.provider, entered);
    vscode.window.showInformationMessage(`${picked.label} API key updated.`);
  }

  // Lets an admin remove a stored key outright (e.g. to force ensureKey() to prompt
  // fresh, or to stop using a provider) rather than only overwriting it via updateApiKey().
  public async clearApiKey(): Promise<void> {
    if (!(await this._requireAdmin())) return;
    const items = (Object.keys(PROVIDER_LABELS) as ApiKeyProvider[]).map((provider) => ({
      label: PROVIDER_LABELS[provider],
      provider,
    }));
    const picked = await vscode.window.showQuickPick(items, {
      title: 'DAI Flash: Clear API Key',
      placeHolder: 'Select a provider to clear its stored API key',
    });
    if (!picked) return;

    const confirm = await vscode.window.showWarningMessage(
      `Clear the stored ${picked.label} API key?`,
      { modal: true },
      'Clear'
    );
    if (confirm !== 'Clear') return;

    await this._apiKeyManager.clearKey(picked.provider);
    vscode.window.showInformationMessage(`${picked.label} API key cleared.`);
  }

  // Admin-only, allowlisted shell access. Only `npm install <package>` and `npm run
  // <existing script>` are ever accepted (see agentShell.ts) - never an arbitrary command,
  // and never triggered autonomously by an AI agent, only by an admin typing it in here.
  public async runSafeCommandPrompt(): Promise<void> {
    if (!(await this._requireAdmin())) return;
    const root = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
    if (!root) {
      vscode.window.showWarningMessage('DAI Flash: open a workspace folder first.');
      return;
    }

    const allowedScripts = readWorkspaceScripts(root);
    const input = await vscode.window.showInputBox({
      prompt: `Only "npm install <package>" or "npm run <script>" are allowed. Available scripts: ${allowedScripts.join(', ') || '(none found)'}`,
      placeHolder: 'npm install lodash   OR   npm run compile',
    });
    if (!input) return;

    const parsed = parseSafeCommand(input, allowedScripts);
    if (!parsed) {
      vscode.window.showErrorMessage(
        'DAI Flash: command not allowed. Only "npm install <package>[@version]" (optionally --save-dev) or "npm run <script that exists in package.json>" are permitted.'
      );
      return;
    }

    const confirm = await vscode.window.showWarningMessage(`Run "${parsed.label}" in ${root}?`, { modal: true }, 'Run');
    if (confirm !== 'Run') return;

    log(`[DAI-Flash] 🖥️ Admin running allowlisted command: ${parsed.label}`);
    vscode.window.showInformationMessage(`DAI Flash Admin: running "${parsed.label}" - see the DAI-Flash output channel for progress.`);
    const result = await runSafeCommand(root, parsed);
    for (const line of result.output.split(/\r?\n/).filter(Boolean)) log(`[DAI-Flash]    ${line}`);
    if (result.ok) {
      log(`[DAI-Flash] ✅ ${parsed.label} completed successfully.`);
      vscode.window.showInformationMessage(`DAI Flash Admin: "${parsed.label}" completed successfully.`);
    } else {
      log(`[DAI-Flash] ❌ ${parsed.label} failed (exit code ${result.exitCode}).`);
      vscode.window.showErrorMessage(`DAI Flash Admin: "${parsed.label}" failed - see the DAI-Flash output channel.`);
    }
  }

  private _sendCostEstimate(prompt: string): void {    const trimmed = prompt.trim();
    if (!trimmed) {
      this._onLog('⚠️ Enter a prompt before estimating cost');
      return;
    }
    this._onLog('⏳ Estimating cost across providers...');
    const estimate = estimateAllProviders(trimmed);
    this._postToWebview('estimateResult', estimate);
  }

  // Project Quote: prices a client's requirement/spec by ENGINEERING HOURS, unlike
  // _sendCostEstimate above (which prices the AI's own token usage for completing a single
  // task). Rate/profit/GST come from user settings so anyone can tune them to their own numbers
  // (see package.json daiFlash.projectQuote.*).
  //
  // agentIds: which specific agent(s) from the model dropdown are ticked in the webview's
  // Quote-settings panel.
  //   - 0 ticked: today's original behaviour - one auto-picked capable model does the whole
  //     estimate (`minReasoningFloor: 'high'` so a large/complex spec gets a model actually
  //     capable of scoping it, not whatever the plain length/keyword heuristic would pick).
  //   - 1 ticked: that exact agent does the whole estimate, forced.
  //   - 2+ ticked: still only ONE real AI call (the highest-tier ticked agent does the actual
  //     scoping, for the best-quality breakdown) - but the model is also asked to tag each
  //     module's difficulty tier, and ProjectQuoteEngine.routeModulesToAgents then routes each
  //     module to the CHEAPEST ticked agent capable of it (light/boilerplate work to a
  //     small/cheap agent, the hardest modules to the best ticked agent) - one combined quote,
  //     with the per-module routing shown so you can see (and later actually staff) which agent
  //     would build what. Routing only labels modules; it never changes hours/cost math - which
  //     AI you use internally doesn't change what you bill the client per hour.
  private async _sendProjectQuote(prompt: string, mode: ProjectQuoteMode, agentIds: string[]): Promise<void> {
    const trimmed = prompt.trim();
    if (!trimmed) {
      this._onLog('⚠️ Enter a client requirement/spec before requesting a project quote');
      return;
    }

    const config = vscode.workspace.getConfiguration('daiFlash');
    const ratePerHour = config.get<number>('projectQuote.ratePerHourInr', 1200);
    const profitPercent = config.get<number>('projectQuote.profitPercent', 30);
    const gstPercent = config.get<number>('projectQuote.gstPercent', 18);
    const pricingMode = config.get<string>('projectQuote.pricingMode', 'flat') === 'tiered' ? 'tiered' : 'flat';
    const tierRates = {
      low: config.get<number>('projectQuote.tierRateLowInr', 400),
      medium: config.get<number>('projectQuote.tierRateMediumInr', 700),
      high: config.get<number>('projectQuote.tierRateHighInr', 1100),
      advanced: config.get<number>('projectQuote.tierRateAdvancedInr', 1800),
    };

    const REASONING_RANK: Record<ModelInfo['reasoning'], number> = { low: 0, medium: 1, high: 2, advanced: 3 };
    const tickedAgents = agentIds
      .map((id) => MODELS.find((m) => m.id === id))
      .filter((m): m is ModelInfo => Boolean(m));
    const routeAcrossAgents = tickedAgents.length > 1;
    // Whichever ticked agent is most capable does the actual scoping call - best judgment for
    // both the hour breakdown and the tier tags routing depends on. With 0 ticked, undefined
    // leaves the pick to the usual auto-selection (minReasoningFloor: 'high').
    const estimatorAgentId = tickedAgents.length > 0
      ? [...tickedAgents].sort((a, b) => REASONING_RANK[b.reasoning] - REASONING_RANK[a.reasoning])[0].id
      : undefined;
    // Tier tags are needed for routing labels (2+ agents ticked) AND for tiered pricing - either
    // reason is enough to ask the model to tag them on this one AI call.
    const needTierTags = routeAcrossAgents || pricingMode === 'tiered';

    const modeLabel = mode === 'ai-assisted' ? 'AI-agent-assisted' : 'manual/traditional';
    const pricingLabel = pricingMode === 'tiered' ? 'tier-wise rates' : `flat ₹${ratePerHour}/hr`;
    this._onLog(`⏳ Analyzing spec into engineering modules/hours (${modeLabel} hours, ${pricingLabel}${routeAcrossAgents ? `, routed across ${tickedAgents.length} ticked agents` : ''}, 1 real AI call)...`);
    this._postToWebview('projectQuoteThinking', {});

    try {
      const { system, user } = ProjectQuoteEngine.buildEffortEstimationPrompt(trimmed, mode, needTierTags);
      const runnerResult = await this._runner.runFreeformCompletion(system, user, {
        getApiKey: (provider) => this._apiKeyManager.ensureKey(provider),
        model: estimatorAgentId,
        minReasoningFloor: estimatorAgentId ? undefined : 'high',
      });

      const effort = ProjectQuoteEngine.parseEffortEstimateResponse(runnerResult.content);
      // Every module names the agent that would build it, including in Auto (0 ticked) - the
      // routing used to be skipped entirely unless 2+ agents were ticked, so the most common
      // case showed no agent at all and there was no way to see which agent a module was
      // destined for. With nothing ticked, "Auto" means the whole model table is the pool.
      //
      // Sorted by capability and then by price, so the label matches what the runner would
      // ACTUALLY pick for that tier - the cheapest agent able to do the job, not merely the
      // first one that happens to sit high enough in the MODELS array.
      const routingPool = (tickedAgents.length > 0 ? tickedAgents : MODELS)
        .slice()
        .sort((a, b) => REASONING_RANK[a.reasoning] - REASONING_RANK[b.reasoning] || (a.input + a.output) - (b.input + b.output))
        .map((m) => ({ id: m.id, label: m.label, reasoning: m.reasoning }));
      const modules = ProjectQuoteEngine.routeModulesToAgents(effort.modules, routingPool);
      const tiersWereGuessed = ProjectQuoteEngine.hasInferredTiers(effort.modules);
      if (tiersWereGuessed && pricingMode === 'tiered') {
        this._onLog(
          '⚠️ The estimator did not tag every module with a difficulty tier, so the missing ones were estimated from module size. Treat those lines as rough and re-run the quote if the mix looks wrong.'
        );
      }
      const quote = ProjectQuoteEngine.computeProjectQuote(
        { modules, totalHours: effort.totalHours },
        { ratePerHour, profitPercent, gstPercent, pricingMode, tierRates }
      );

      // Same accounting as chat: this was a real, billed API call, so it counts toward the
      // session/monthly spend totals shown in the footer and used by the budget guard.
      this._sessionCostUsd += runnerResult.costUsd;
      this._sessionInputTokens += runnerResult.inputTokens;
      this._sessionOutputTokens += runnerResult.outputTokens;
      void this._budgetGuard.addSpend(runnerResult.costUsd);
      this._postToWebview('metrics', {
        costUsd: this._sessionCostUsd,
        inputTokens: this._sessionInputTokens,
        outputTokens: this._sessionOutputTokens,
      });

      const agentLabel = routeAcrossAgents
        ? `${tickedAgents.length} agents (routed)`
        : runnerResult.model.label;
      // Records the REAL cost/tokens of THIS scoping call against the hours it quoted, so
      // "📊 AI cost stats" in ⚙️ Quote settings can answer "what does 1 quoted hour actually
      // cost me in AI spend, on Auto" - wasAuto is true only when 0 agents were ticked (the
      // host picked the model itself), matching what "if I select Auto" means to the user.
      void this._projectQuoteStats.record({
        modelId: runnerResult.model.id,
        modelLabel: runnerResult.model.label,
        costUsd: runnerResult.costUsd,
        inputTokens: runnerResult.inputTokens,
        outputTokens: runnerResult.outputTokens,
        totalHours: effort.totalHours,
        wasAuto: tickedAgents.length === 0,
      });
      const costPerHourUsd = effort.totalHours > 0 ? runnerResult.costUsd / effort.totalHours : 0;
      this._onLog(`✅ Project quote ready (${runnerResult.model.label} scoped it${routeAcrossAgents ? ', routed across ticked agents' : ''}, $${runnerResult.costUsd.toFixed(4)} AI cost for this analysis ≈ $${costPerHourUsd.toFixed(4)}/quoted hour, ${runnerResult.inputTokens} in / ${runnerResult.outputTokens} out tokens)`);
      this._postToWebview('projectQuoteResult', { quotes: [{ agentLabel, quote, routed: routeAcrossAgents }], mode });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      this._onLog(`❌ Project quote failed: ${message}`);
      this._postToWebview('projectQuoteError', { error: message });
    }
  }

  // Pushes the current Rate/hr, Profit % and GST % (from daiFlash.projectQuote.* settings) to
  // the webview's gear-icon panel - called both when the panel is opened and once at webview
  // startup, so the inputs never show stale/default numbers.
  private _sendProjectQuoteSettings(): void {
    const config = vscode.workspace.getConfiguration('daiFlash');
    // "What does 1 quoted hour actually cost me in AI spend, on Auto" - aggregated from every
    // past Quote run made with 0 agents ticked (see ProjectQuoteStatsService/_sendProjectQuote).
    const autoStats = this._projectQuoteStats.getStats(true);
    this._postToWebview('projectQuoteSettings', {
      ratePerHour: config.get<number>('projectQuote.ratePerHourInr', 1200),
      profitPercent: config.get<number>('projectQuote.profitPercent', 30),
      gstPercent: config.get<number>('projectQuote.gstPercent', 18),
      pricingMode: config.get<string>('projectQuote.pricingMode', 'flat') === 'tiered' ? 'tiered' : 'flat',
      tierRateLow: config.get<number>('projectQuote.tierRateLowInr', 400),
      tierRateMedium: config.get<number>('projectQuote.tierRateMediumInr', 700),
      tierRateHigh: config.get<number>('projectQuote.tierRateHighInr', 1100),
      tierRateAdvanced: config.get<number>('projectQuote.tierRateAdvancedInr', 1800),
      autoAiCostStats: autoStats,
    });
  }

  // Saves the gear-icon panel's values straight into daiFlash.projectQuote.* (User settings,
  // global) - the same settings the "Quote" button already reads, so a Save here takes effect
  // on the very next Quote run with no reload/restart needed. The flat Rate/hr and the 4 tier
  // rates are validated and saved independently, since only one set is actually in use
  // (pricingMode decides which) but both stay ready the moment the user flips the toggle.
  private async _saveProjectQuoteSettings(message: any): Promise<void> {
    const rate = Number(message.ratePerHour);
    const profit = Number(message.profitPercent);
    const gst = Number(message.gstPercent);
    if (![rate, profit, gst].every((n) => Number.isFinite(n) && n >= 0)) {
      this._onLog('⚠️ Quote settings not saved - Rate/hr, Profit % and GST % must all be non-negative numbers');
      return;
    }
    const pricingMode = message.pricingMode === 'tiered' ? 'tiered' : 'flat';
    const tierLow = Number(message.tierRateLow);
    const tierMedium = Number(message.tierRateMedium);
    const tierHigh = Number(message.tierRateHigh);
    const tierAdvanced = Number(message.tierRateAdvanced);
    const tierRatesGiven = [tierLow, tierMedium, tierHigh, tierAdvanced].every((n) => n !== undefined && !Number.isNaN(n));
    if (tierRatesGiven && ![tierLow, tierMedium, tierHigh, tierAdvanced].every((n) => Number.isFinite(n) && n >= 0)) {
      this._onLog('⚠️ Quote settings not saved - the 4 tier rates must all be non-negative numbers');
      return;
    }

    const config = vscode.workspace.getConfiguration('daiFlash');
    await config.update('projectQuote.ratePerHourInr', rate, vscode.ConfigurationTarget.Global);
    await config.update('projectQuote.profitPercent', profit, vscode.ConfigurationTarget.Global);
    await config.update('projectQuote.gstPercent', gst, vscode.ConfigurationTarget.Global);
    await config.update('projectQuote.pricingMode', pricingMode, vscode.ConfigurationTarget.Global);
    if (tierRatesGiven) {
      await config.update('projectQuote.tierRateLowInr', tierLow, vscode.ConfigurationTarget.Global);
      await config.update('projectQuote.tierRateMediumInr', tierMedium, vscode.ConfigurationTarget.Global);
      await config.update('projectQuote.tierRateHighInr', tierHigh, vscode.ConfigurationTarget.Global);
      await config.update('projectQuote.tierRateAdvancedInr', tierAdvanced, vscode.ConfigurationTarget.Global);
    }
    const modeNote = pricingMode === 'tiered'
      ? `tier-wise (Low ₹${tierLow}, Medium ₹${tierMedium}, High ₹${tierHigh}, Advanced ₹${tierAdvanced})`
      : `flat ₹${rate}/hr`;
    this._onLog(`✅ Quote settings saved - Pricing: ${modeNote}, Profit ${profit}%, GST ${gst}% (used by the next "Quote" run)`);
  }

  private _onBatchProgress(snapshot: BatchProgressSnapshot): void {
    this._postToWebview('batchProgress', { snapshot });
  }

  private async _pickAndRunBatchFile(model?: string): Promise<void> {
    if (this._isJobRunning || this._batchProcessor.isRunning()) {
      this._onLog('🕒 A job/batch is already running - please wait or stop it before attaching a new file');
      return;
    }

    const picked = await vscode.window.showOpenDialog({
      canSelectMany: false,
      openLabel: 'Attach Task List File',
      filters: { 'Task Lists / Text': ['txt', 'md', 'csv', 'json', 'log'], 'All Files': ['*'] },
    });
    if (!picked || picked.length === 0) return;

    const uri = picked[0];
    const MAX_FILE_BYTES = 25 * 1024 * 1024; // hard safety cap well above the 5MB+ requirement

    try {
      const stat = await vscode.workspace.fs.stat(uri);
      if (stat.size > MAX_FILE_BYTES) {
        this._onLog(`⚠️ File too large (${(stat.size / (1024 * 1024)).toFixed(1)} MB) - max supported is ${MAX_FILE_BYTES / (1024 * 1024)} MB`);
        return;
      }

      const ext = uri.path.split('.').pop()?.toLowerCase();
      if (ext === 'pdf') {
        this._onLog('⚠️ PDF binary parsing isn\'t available offline in this build - please export/convert the task list to .txt or .csv first');
        return;
      }

      const bytes = await vscode.workspace.fs.readFile(uri);
      const text = Buffer.from(bytes).toString('utf8');
      const fileName = uri.path.split('/').pop() || uri.fsPath;
      const items = parseIntoTaskItems(text);

      if (items.length === 0) {
        this._onLog(`⚠️ No task items found in "${fileName}"`);
        return;
      }

      this._onLog(`📎 Attached "${fileName}" (${(stat.size / 1024).toFixed(1)} KB) - parsed into ${items.length} task item(s)`);
      if (this._isAdminMode()) {
        try {
          this._postToWebview('taskBreakdown', buildTaskBreakdown(items));
        } catch (err) {
          output.appendLine(`[DAI-Flash] ⚠️ Batch task breakdown preview failed: ${err instanceof Error ? err.message : String(err)}`);
        }
      }
      this._isJobRunning = true;
      this._setAgentStatus('running', `Batch: ${fileName} (${items.length} tasks)`);
      this._postToWebview('batchStarted', { total: items.length, sourceFile: fileName });

      this._batchProcessor
        .run(items, fileName, model)
        .then((snapshot) => {
          this._postToWebview('batchComplete', { snapshot });
          if (snapshot.failed > 0) {
            this._setAgentStatus('error', `${snapshot.failed} of ${snapshot.total} batch task(s) failed`);
          } else {
            this._setAgentStatus('idle');
          }
        })
        .catch((err) => {
          this._onLog(`❌ Batch processing error: ${err instanceof Error ? err.message : String(err)}`);
          this._setAgentStatus('error', 'Batch processing error');
        })
        .finally(() => {
          this._isJobRunning = false;
        });
    } catch (err) {
      this._onLog(`❌ Failed to read attached file: ${err instanceof Error ? err.message : String(err)}`);
      this._setAgentStatus('error', 'Failed to read attached file');
    }
  }

  // Actually writes every backed-up file's real content back to its exact path - this used to
  // just re-render the file list in the UI and claim "Restored!" without touching disk at all.
  private async _restoreLatestBackup(): Promise<void> {
    const backup = await this._backupManager.getLatestBackup();
    if (!backup) {
      log('[DAI-Flash] ⚠️ No intelligent backup found to restore');
      this._hadUncleanShutdown = false;
      return;
    }
    log(`[DAI-Flash] 🗄️ Restoring latest intelligent backup from ${new Date(backup.timestamp).toLocaleString()} (trigger: ${backup.trigger})`);
    log(`[DAI-Flash] ↩️ Restored prompt: "${backup.prompt}" (model: ${backup.model}, cost: $${backup.costUsd.toFixed(4)})`);

    let root: string;
    try {
      root = this._fileOpsGuard.lockWorkspaceRoot();
    } catch (err) {
      log(`[DAI-Flash] ❌ Cannot restore backup - no workspace folder is open: ${err instanceof Error ? err.message : String(err)}`);
      this._hadUncleanShutdown = false;
      return;
    }

    // Safety-snapshot: capture whatever is CURRENTLY on disk for these same paths right now,
    // before this restore overwrites any of it - so the restore itself can never destroy
    // something unrecoverably.
    const safetyFiles: BackupFileEntry[] = await Promise.all(
      backup.files.map(async (f) => {
        const content = await this._fileOpsGuard.readFile(root, f.path);
        return { path: f.path, additions: 0, deletions: 0, existed: content !== null, content };
      })
    );
    await this._backupManager.createSafetySnapshot({
      prompt: `Pre-restore safety snapshot (before restoring: "${backup.prompt}")`,
      model: 'none',
      costUsd: 0,
      files: safetyFiles,
    });
    log('[DAI-Flash] 🧷 Captured a safety snapshot of the current on-disk state before restoring, in case this restore itself needs undoing.');

    let restoredCount = 0;
    let skippedCount = 0;
    for (const f of backup.files) {
      // A pre-fix legacy backup's file objects never had a `content` key at all (not even
      // `null`) - `in`-based narrowing on BackupFileEntry's own static type would treat that
      // branch as unreachable, so this checks the loaded JSON's actual shape via `any`.
      if (typeof (f as any).content === 'undefined') {
        log(`[DAI-Flash] ⚠️ ${f.path}: Old backup format has no content to restore`);
        skippedCount++;
        continue;
      }
      if (f.content === null) {
        log(`[DAI-Flash] ⚠️ ${f.path}: no content was captured for this file at backup time - skipping restore`);
        skippedCount++;
        continue;
      }
      try {
        await this._fileOpsGuard.writeFile(root, f.path, f.content);
        restoredCount++;
      } catch (err) {
        log(`[DAI-Flash] ❌ Failed to restore ${f.path}: ${err instanceof Error ? err.message : String(err)}`);
        skippedCount++;
      }
    }

    log(`[DAI-Flash] ✅ Restore complete: ${restoredCount} file(s) actually written back to disk${skippedCount > 0 ? `, ${skippedCount} skipped` : ''}.`);
    this._onFileChanged(backup.files);
    void this._backupManager.markRestored(backup.id);
    this._hadUncleanShutdown = false;
  }

  private _onLog(msg: string) {
    this._postToWebview('log', { text: msg, level: 'info' });
    // Also to the "DAI-Flash" Output channel. Until now these lines existed ONLY in the
    // webview: a limited buffer, not selectable, not searchable, and gone the moment the panel
    // closes - so the first question anyone asks about a finished job ("what did it actually
    // do?") had nowhere to be answered from. The Output channel scrolls, selects, searches and
    // survives, which is what makes a run reviewable after the fact.
    output.appendLine(`[${new Date().toLocaleTimeString()}] ${msg}`);
  }

  private _onSummary(summary: string) {
    this._postToWebview('summary', { html: summary });
  }

  private _onProgress(data: { step: number; total: number; label: string }) {
    if (this._checkpoint) {
      this._checkpoint.lastCompletedStep = data.step;
      this._saveCheckpoint();
    }
    this._postToWebview('progress', data);
  }

  private _onPreview(data: { url: string }) {
    this._postToWebview('previewReady', data);
  }

  private _onModelSelected(modelId: string) {
    if (this._checkpoint) {
      this._checkpoint.selectedModelId = modelId;
      this._saveCheckpoint();
    }
  }

  // Lead-coordinator pass: nothing is executed blind - every request is first decomposed
  // into granular numbered sub-tasks and each one is routed to a complexity-matched model.
  private _orchestrate(prompt: string, source: 'user' | 'background' = 'user'): void {
    try {
      const plan = this._orchestrator.plan(prompt, source);
      this._activeRunId = plan.runId;
      this._runTranscript = [];
      this._onLog(`🧠 Lead orchestrator (${plan.leadModelLabel}) decomposed the request into ${plan.steps.length} sub-task(s):`);
      for (const step of plan.steps) {
        this._onLog(`   ${step.index}. [${step.category}] ${step.label} → ${step.modelLabel} (${step.providerLabel})`);
        this._onLog(`      🎭 Persona: ${step.personaLabel} | min tier: ${step.reasoningTier} | tests mandatory: ${step.requiresTests ? 'yes' : 'no'}`);
        this._orchestrator.startStep(plan.runId, step.index);
      }
      this._postToWebview('orchestrationPlan', plan);
    } catch (err) {
      this._activeRunId = undefined;
      output.appendLine(`[DAI-Flash] ⚠️ Orchestration planning failed: ${err instanceof Error ? err.message : String(err)}`);
    }
  }

  // Closes out the active plan and logs the clean summary report. Nothing is signed off until
  // the independent Sonnet reviewer confirms every planned point was actually delivered.
  private async _finishOrchestration(failure?: unknown, evidence?: string): Promise<void> {
    const runId = this._activeRunId;
    if (!runId) return;
    const plan = this._orchestrator.getPlan(runId);
    for (const step of plan?.steps || []) {
      if (failure) this._orchestrator.failStep(runId, step.index, failure);
      else this._orchestrator.completeStep(runId, step.index);
    }

    // Static gate result is recorded first - the reviewer treats a missing or failed gate as a
    // blocking finding, so this must land before the review runs.
    const gateReport = this._lastGateReport;
    if (gateReport) {
      this._orchestrator.recordQualityGate(runId, {
        passed: gateReport.passed,
        testsExecuted: gateReport.testsExecuted,
        summary: gateReport.summary,
        failureDigest: gateReport.failureDigest,
        attempts: this._lastGateAttempts,
        ranAt: gateReport.ranAt,
      });
      this._onLog(`🚦 Pre-commit gate: ${gateReport.summary}`);
    } else if (this._lastToolVerification?.ran) {
      // In tool mode the AGENT runs the build or the tests itself, so _lastGateReport is empty
      // by design - the extension never ran a gate because it did not need to. Recording the
      // agent's own run here is not a courtesy: without it the reviewer reads "no gate ran" as
      // a blocking gap and orders a corrective iteration, and a job that correctly changed
      // nothing gets a file written into it to satisfy a check that had already passed.
      const v = this._lastToolVerification;
      this._orchestrator.recordQualityGate(runId, {
        passed: v.passed,
        testsExecuted: true,
        summary: `agent-run: ${v.summary}`,
        failureDigest: v.passed ? '' : v.summary,
        attempts: 1,
        ranAt: Date.now(),
      });
      this._onLog(`🚦 Pre-commit gate (run by the agent itself): ${v.summary}`);
    }

    if (!failure) await this._runAcceptanceReview(this._lastPrompt, evidence || '');
    if (!failure) await this._runReviewGate(runId, evidence || '');

    for (const line of this._orchestrator.completeRun(runId).split('\n')) {
      this._onLog(`📊 ${line}`);
    }
    if (!failure && this._orchestrator.isSignedOff(runId) && !this._acceptanceFailed) {
      this._onLog('✅ Job Completed successfully - verified and signed off by the four-eye reviewer.');
    } else if (!failure && this._acceptanceFailed) {
      // The word-matching reviewer may well have approved this. It is not allowed to be the
      // last word any more: a green tick on work that is not what was asked for is the exact
      // failure this whole day started with.
      this._onLog('🛑 NOT signed off - the acceptance reviewer says this is not what was asked for. Read the diff before you keep it.');
    }
    // Guard against a queued job having already claimed `_activeRunId` for itself while this
    // corrective loop was still running (it never blocks the flag, only reads this closure's
    // own `runId`) - never clear a run id that isn't this one.
    if (this._activeRunId === runId) this._activeRunId = undefined;
  }

  // Builds the mandatory pre-commit gate for a run. Returns undefined when no folder is open,
  // in which case the runner reports that gates could not be executed rather than faking a pass.
  private _makeQualityGateCallback() {
    const cwd = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
    if (!cwd) return undefined;
    const gates = new QualityGateRunner(cwd);
    this._lastGateReport = undefined;
    this._lastGateAttempts = 0;
    return async (attempt: number, previousFailure?: string) => {
      if (previousFailure) {
        this._onLog(`🩺 Correction context for attempt ${attempt}: ${previousFailure.split('\n')[0]}`);
      }
      const report = await gates.runAllGates();
      this._lastGateReport = report;
      this._lastGateAttempts = attempt;
      return {
        passed: report.passed,
        summary: report.summary,
        failureDigest: report.failureDigest,
        testsExecuted: report.testsExecuted,
      };
    };
  }

  // Wires the real, vscode-aware FileOpsGuard into the (vscode-free) runner via the plain
  // FileOpsHooks contract - mirrors _makeQualityGateCallback's dependency-injection pattern
  // so all six enforced safety protocols run against the actual workspace/filesystem.
  private _makeFileOpsHooks(): FileOpsHooks {
    return createFileOpsHooks(this._fileOpsGuard, () => this._activeRunId || 'no-active-run', (msg) => this._onLog(msg));
  }

  // Consolidates everything the agents actually produced for this run into the single text
  // blob the reviewer checks the original task list against.
  private _buildFinalOutput(data: { model: string; costUsd: number; files?: any[] }): string {
    const parts: string[] = [...this._runTranscript];
    parts.push(`Executed by: ${data.model}`);
    if (this._lastGateReport) {
      parts.push(`Quality gate: ${this._lastGateReport.summary}`);
    }
    for (const f of data.files || []) {
      parts.push(`File ${f?.path ?? 'unknown'} (${f?.status ?? 'changed'}, +${f?.additions ?? 0}/-${f?.deletions ?? 0})`);
    }
    return parts.join('\n');
  }

  // Four-eye gate: re-reads the original request against the consolidated output. Gaps reopen
  // the offending sub-tasks and actually re-run them through a real corrective AI call - not
  // just a log line - looping until the reviewer approves or the corrective budget runs out.
  /**
   * The acceptance review: "is this what was asked for?"
   *
   * Deliberately separate from the pre-commit gate, which only ever answers "does it run".
   * A generic landing page compiles, lints and passes every gate there is - and is still the
   * wrong thing when what was asked for was a deployment.
   *
   * The reviewer is shown the real diff and the real exit codes, never the agent's account of
   * its own work. It is a different model from the one that did the work, because the author
   * of a change is the worst available judge of whether it met the requirement.
   */
  /**
   * Picks who reviews the work, and the one hard rule is that it is not whoever did it.
   *
   * "A high-reasoning model" was not enough: on the first run the executor was DeepSeek V4 Pro,
   * which is itself high-reasoning and cheapest at that tier, so it was handed its own work to
   * mark. An agent grading its own homework is not a second opinion, it is the same opinion
   * with a different label - and the whole reason this check exists is that the author of a
   * change is the worst available judge of whether it met the requirement.
   */
  private _pickAcceptanceReviewer(): ModelInfo | undefined {
    const rank: Record<ModelInfo['reasoning'], number> = { low: 1, medium: 2, high: 3, advanced: 4 };
    // Anything below 'medium' cannot be trusted to read a diff against a requirement, but the
    // floor stops there deliberately. An earlier version of this asked for 'high' or above,
    // which quietly excluded Claude Sonnet - it is rated 'medium' in MODELS - and left only
    // Opus and Fable in the Anthropic seat. The reviewer then cost five times the work it was
    // reviewing. Reading a diff and answering one question is a Sonnet-sized job.
    const eligible = MODELS.filter((m) => m.label !== this._lastExecutorLabel && rank[m.reasoning] >= 2);
    if (eligible.length === 0) return undefined;

    // Sonnet by name first - orchestrator.ts already says the four-eye reviewer should be a
    // Sonnet-tier model, and agreeing with it beats inventing a second, different rule.
    const sonnet = eligible.find((m) => m.provider === 'anthropic' && /sonnet/i.test(m.label));
    if (sonnet) return sonnet;

    return [...eligible].sort((a, b) => {
      const provider = (a.provider === 'anthropic' ? 0 : 1) - (b.provider === 'anthropic' ? 0 : 1);
      if (provider !== 0) return provider;
      return (a.input + a.output) - (b.input + b.output);
    })[0];
  }

  private async _runAcceptanceReview(request: string, agentSummary: string): Promise<void> {
    this._acceptanceFailed = false;
    if (!request.trim()) return;

    const mode = vscode.workspace.getConfiguration('daiFlash').get<string>('acceptanceReview', 'always');
    if (mode === 'off') return;
    // 'on-change' is the cheaper setting, and it has a known blind spot worth naming out loud:
    // a job that ran the wrong command, touched nothing and declared victory looks exactly like
    // a job that correctly had nothing to change. Skipping is the user's choice to make, but it
    // should not be a silent one - so it says so every time rather than just not happening.
    if (mode === 'on-change' && this._pendingFiles.size === 0) {
      this._onLog('🎯 Acceptance skipped - no files changed, and this setting only checks jobs that change files.');
      return;
    }

    const root = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
    const filesChanged: AcceptanceEvidence['filesChanged'] = [];
    for (const [path, info] of this._pendingFiles.entries()) {
      let diff = '(diff unavailable)';
      try {
        if (root) {
          const snapshot = info.snapshotId ? this._fileOpsGuard.getSnapshot(info.snapshotId) : undefined;
          const before = snapshot?.entries.find((e) => e.relPath === path)?.content ?? null;
          const after = (await this._fileOpsGuard.readFile(root, path)) ?? '';
          diff = buildCompactDiff(before, after);
        }
      } catch {
        // A diff we cannot build is reported as missing, never quietly skipped - the reviewer
        // has to know it is judging on incomplete evidence.
      }
      filesChanged.push({ path, additions: info.additions, deletions: info.deletions, diff });
    }

    const evidence: AcceptanceEvidence = {
      request,
      filesChanged,
      commands: this._lastCommands,
      agentSummary,
    };

    const { system, user } = buildAcceptancePrompt(evidence);
    try {
      const reviewer = this._pickAcceptanceReviewer();
      if (!reviewer) {
        this._onLog('🎯 No second agent is available to review this independently - the run is unverified.');
        return;
      }
      const result = await this._runner.runFreeformCompletion(system, user, {
        model: reviewer.id,
        getApiKey: (provider) => this._apiKeyManager.ensureKey(provider),
      });
      const verdict = parseAcceptanceReply(result.content);
      this._onLog(`🎯 ${describeVerdict(verdict)}`);
      this._onLog(`🎯 Acceptance reviewer: ${result.model.label} ($${result.costUsd.toFixed(4)})`);
      void this._budgetGuard.addSpend(result.costUsd || 0);
      this._acceptanceCostUsd += result.costUsd || 0;

      if (verdict.decision === 'no') this._acceptanceFailed = true;
      // An inconclusive verdict is NOT a pass, but it is also not proof of a problem, so it
      // is surfaced loudly and left for the person rather than blocking on a guess.
      if (verdict.inconclusive) {
        this._onLog('🎯 Acceptance was inconclusive - treat this run as unverified and check it yourself.');
      }
    } catch (err) {
      this._onLog(`🎯 Acceptance review could not run (${err instanceof Error ? err.message : String(err)}) - this run is unverified.`);
    }
  }

  private async _runReviewGate(runId: string, evidence: string): Promise<void> {
    try {
      let review = this._orchestrator.reviewRun(runId, evidence);
      for (const line of review.report) this._onLog(`🔍 ${line}`);
      this._postToWebview('orchestrationReview', review);

      while (review.verdict !== 'approved' && this._orchestrator.needsCorrectiveIteration(runId)) {
        this._onLog('🚫 Sign-off withheld - the reviewer found points that are not evidenced in the final output.');
        const reopened = this._orchestrator.beginCorrectiveIteration(runId);
        this._onLog(`♻️ Corrective iteration required - ${reopened.length} sub-task(s) reopened and must be re-run before this job can close:`);
        for (const step of reopened) {
          this._onLog(`   ${step.index}. ${step.label} → ${step.modelLabel} (${step.providerLabel})`);
        }
        this._onLog('   Corrective task list:');
        for (const task of review.correctiveTasks) this._onLog(`   • ${task}`);

        const correctivePrompt = this._orchestrator.buildCorrectivePrompt(runId, review);
        this._onLog(`🔁 Running corrective iteration ${review.iteration + 1}/${MAX_REVIEW_ITERATIONS} against the real target file...`);
        const data = await this._runCorrectiveIteration(correctivePrompt);

        if (this._lastGateReport) {
          this._orchestrator.recordQualityGate(runId, {
            passed: this._lastGateReport.passed,
            testsExecuted: this._lastGateReport.testsExecuted,
            summary: this._lastGateReport.summary,
            failureDigest: this._lastGateReport.failureDigest,
            attempts: this._lastGateAttempts,
            ranAt: this._lastGateReport.ranAt,
          });
        }

        if (data.model === 'none') {
          this._onLog('❌ Corrective iteration failed to produce usable output - stopping the corrective loop.');
          for (const gap of review.gaps) this._orchestrator.failStep(runId, gap.index, 'corrective iteration failed to produce usable output');
          break;
        }
        for (const gap of review.gaps) this._orchestrator.completeStep(runId, gap.index);

        const finalOutput = this._buildFinalOutput(data);
        review = this._orchestrator.reviewRun(runId, finalOutput);
        for (const line of review.report) this._onLog(`🔍 ${line}`);
        this._postToWebview('orchestrationReview', review);
      }

      if (review.verdict !== 'approved') {
        this._onLog(`🛑 Corrective budget exhausted after ${MAX_REVIEW_ITERATIONS} review pass(es) - escalating to you instead of closing the job.`);
        for (const gap of review.gaps) this._orchestrator.failStep(runId, gap.index, gap.reason);
      }
    } catch (err) {
      this._onLog(`⚠️ Four-eye review could not run: ${err instanceof Error ? err.message : String(err)}`);
    }
  }

  // Runs one real corrective AI attempt against `correctivePrompt` on a throwaway AgentRunner
  // instance (never `this._runner`) so this nested call can never re-trigger the main
  // `_onJobComplete` pipeline (queue draining, spend/backup/metrics bookkeeping) recursively -
  // its log/progress/file events are still forwarded to the same UI sinks and transcript as
  // the original run, so the corrective attempt is fully visible and its evidence accumulates
  // into the same four-eye review.
  private _runCorrectiveIteration(correctivePrompt: string): Promise<{
    model: string; costUsd: number; inputTokens: number; outputTokens: number; files?: any[]; fallbackHistory?: any[]; totalAttempts?: number;
  }> {
    const correctiveRunner = new AgentRunner();
    correctiveRunner.events.on('log', (msg: string) => {
      this._runTranscript.push(msg);
      this._onLog(msg);
    });
    correctiveRunner.events.on('todo', (items) => this._onTodo(items));
    correctiveRunner.events.on('fileChanged', (files) => this._onFileChanged(files));
    correctiveRunner.events.on('usage', (data) => this._onUsage(data));
    correctiveRunner.events.on('modelSelected', (modelId) => this._onModelSelected(modelId));
    correctiveRunner.events.on('progress', (data) => this._onProgress(data));
    correctiveRunner.events.on('preview', (data) => this._onPreview(data));
    this._activeCorrectiveRunner = correctiveRunner;

    return new Promise((resolve) => {
      correctiveRunner.events.once('jobComplete', (data) => {
        if (this._activeCorrectiveRunner === correctiveRunner) this._activeCorrectiveRunner = undefined;
        if (data.model !== 'none') {
          void this._budgetGuard.addSpend(data.costUsd || 0);
        }
        // Folded into the job card as well as the budget. This spend was always charged to the
        // account, but the card only ever showed the FIRST runner's figure - so a job whose
        // corrective round cost twenty times the original still reported the original. A cost
        // line that under-reports is worse than none: it gets believed.
        this._correctiveCostUsd += data.costUsd || 0;
        this._correctiveInputTokens += data.inputTokens || 0;
        this._correctiveOutputTokens += data.outputTokens || 0;
        this._correctiveRounds++;
        resolve(data);
      });
      correctiveRunner.run(correctivePrompt, {
        getApiKey: (provider) => this._apiKeyManager.ensureKey(provider),
        runQualityGates: this._makeQualityGateCallback(),
        fileOps: this._makeFileOpsHooks(),
        retryAttempts: this._getRetryAttemptsConfig(),
        // The corrective round must take the SAME road as the original attempt. Sending it down
        // the classic path while the job itself ran in tool mode is what turned "run the tests"
        // - correctly answered with zero files changed - into a 177-line file nobody wanted.
        toolLoop: this._getToolLoopOptions(),
      });
    });
  }

  private async _onJobComplete(data: {
    model: string;
    costUsd: number;
    inputTokens: number;
    outputTokens: number;
    files?: any[];
    fallbackHistory?: any[];
    totalAttempts?: number;
    /** Present in tool mode: the build or test the agent ran itself, and whether it passed. */
    verification?: { ran: boolean; passed: boolean; summary: string };
    /** Every command the tool loop ran, with its real exit code. */
    commands?: Array<{ command: string; exitCode: number | null }>;
  }) {
    // Record REAL spend (not the pre-job estimate) against the monthly running total - even
    // on a failed job. agentRunner.ts now folds in the cost of every real attempt (successful
    // or not) into data.costUsd, so a job that made real, billed API calls before every tier
    // was exhausted or a quality gate rolled it back still counts toward the budget cap; only
    // the model==='none' bookkeeping below (checkpoint clear, file backup) is success-only.
    void this._budgetGuard.addSpend(data.costUsd || 0);
    this._lastToolVerification = data.verification;
    this._lastCommands = data.commands || [];
    this._acceptanceFailed = false;
    this._lastExecutorLabel = data.model || '';
    this._acceptanceCostUsd = 0;
    this._correctiveCostUsd = 0;
    this._correctiveInputTokens = 0;
    this._correctiveOutputTokens = 0;
    this._correctiveRounds = 0;
    if (data.model !== 'none') {
      this._checkpoint = undefined;
      this._context.workspaceState.update(CHECKPOINT_KEY, undefined);
      void this._captureAndBackup(data);
    }
    // Awaited so any corrective iterations the four-eye reviewer requires (real re-runs, not
    // just log lines) fully finish - including their own spend/gate bookkeeping - before this
    // job is reported done and the queue is allowed to drain into the next one.
    await this._finishOrchestration(
      data.model === 'none' ? new Error('Execution failed before a model completed the work') : undefined,
      this._buildFinalOutput(data),
    );
    this._isJobRunning = false;

    // Always-on execution ledger (independent of admin mode), then an opportunistic sync.
    void this._agentMetrics.recordExecution({
      modelLabel: data.model === 'none' ? 'Unassigned' : data.model,
      prompt: this._lastPrompt,
      success: data.model !== 'none',
      firstTry: (data.totalAttempts ?? 1) === 1 && (data.fallbackHistory || []).length === 0,
      costUsd: data.costUsd || 0,
      inputTokens: data.inputTokens || 0,
      outputTokens: data.outputTokens || 0,
    }).then(() => this._metricsSync.syncIfDue());

    // One row per job (not aggregated), purely for the "recent sessions" list shown when
    // the panel is idle - a 'none' model here means the job failed/rolled back before
    // completing, which is still worth showing (marked unsuccessful) rather than hidden.
    const files = data.files || [];
    void this._jobHistory.record({
      prompt: this._lastPrompt,
      modelLabel: data.model === 'none' ? 'Unassigned' : data.model,
      costUsd: data.costUsd || 0,
      additions: files.reduce((sum: number, f: any) => sum + (f.additions || 0), 0),
      deletions: files.reduce((sum: number, f: any) => sum + (f.deletions || 0), 0),
      filesChanged: files.length,
      success: data.model !== 'none',
    }).then(() => this._postSessionsList());

    // Corrective rounds finished inside _finishOrchestration above, so their real spend exists
    // by now and is folded in here - before the card is drawn, never after.
    this._postToWebview('jobComplete', {
      ...data,
      costUsd: (data.costUsd || 0) + this._correctiveCostUsd + this._acceptanceCostUsd,
      inputTokens: (data.inputTokens || 0) + this._correctiveInputTokens,
      outputTokens: (data.outputTokens || 0) + this._correctiveOutputTokens,
      firstRunCostUsd: data.costUsd || 0,
      correctiveRounds: this._correctiveRounds,
      correctiveCostUsd: this._correctiveCostUsd,
      acceptanceCostUsd: this._acceptanceCostUsd,
    });

    if (data.model !== 'none') {
      // No-op unless admin mode is enabled - the service gates itself.
      void this._adminAnalytics.recordJob({
        timestamp: Date.now(),
        prompt: this._lastPrompt,
        modelLabel: data.model,
        provider: MODELS.find((m) => m.label === data.model)?.provider || 'unknown',
        inputTokens: data.inputTokens || 0,
        outputTokens: data.outputTokens || 0,
        costUsd: data.costUsd || 0,
        filesChanged: (data.files || []).length,
      });
    }

    // The runner reports a failed/aborted job as model 'none'.
    if (data.model === 'none') {
      this._setAgentStatus('error', 'Execution failed - see logs');
    } else {
      this._setAgentStatus('idle');
    }

    const next = this._taskQueue.shift();
    if (next) {
      this._onLog(`▶️ Starting next queued task: ${next.prompt}`);
      void this._runAgent(next.prompt, next.model);
    }
  }

  // Reads each changed file's REAL current content from disk before handing it to the backup
  // manager - a backup that only ever stored path/additions/deletions could never actually
  // restore anything on crash recovery, only re-render the file list in the UI.
  private async _captureAndBackup(data: { model: string; costUsd: number; files?: any[] }): Promise<void> {
    const rawFiles: Array<{ path: string; additions: number; deletions: number }> = data.files || [];
    let backupFiles: BackupFileEntry[];
    try {
      const root = this._fileOpsGuard.lockWorkspaceRoot();
      backupFiles = await Promise.all(
        rawFiles.map(async (f) => {
          const content = await this._fileOpsGuard.readFile(root, f.path);
          return { path: f.path, additions: f.additions || 0, deletions: f.deletions || 0, existed: content !== null, content };
        })
      );
    } catch (err) {
      // No workspace open (or path validation failed) - fall back to content-less entries so
      // a backup-creation problem can never block the rest of job-complete handling; the
      // restore path already reports a content-less entry honestly rather than pretending.
      log(`[DAI-Flash] ⚠️ Could not read real file content for backup: ${err instanceof Error ? err.message : String(err)}`);
      backupFiles = rawFiles.map((f) => ({ path: f.path, additions: f.additions || 0, deletions: f.deletions || 0, existed: false, content: null }));
    }

    const created = await this._backupManager.maybeCreateBackup({
      prompt: this._lastPrompt,
      model: data.model,
      costUsd: data.costUsd,
      files: backupFiles,
    });
    if (created) {
      log(`[DAI-Flash] 🗄️ Intelligent backup created (${created.reason}) - real file content saved to global extension storage`);
    }
  }

  private _onTodo(items: any[]) {
    this._postToWebview('todo', { items });
  }

  private _onFileChanged(files: any[]) {
    this._pendingFiles.clear();
    for (const f of files) {
      this._pendingFiles.set(f.path, { additions: f.additions || 0, deletions: f.deletions || 0, snapshotId: f.snapshotId });
    }
    if (this._checkpoint) {
      this._checkpoint.pendingFiles = files;
      this._saveCheckpoint();
    }
    this._postToWebview('fileChanged', { files });
    this._postReviewStatus();
    this._autoSaveMatchingDocuments(files);
  }

  // Saves any already-open real editor documents whose workspace-relative path matches a
  // file the agent reported as modified. Never writes new content itself (this runner is a
  // simulated backend) - only flushes an already-dirty open editor, which is always safe.
  private _autoSaveMatchingDocuments(files: any[]): void {
    for (const f of files) {
      const path = f.path;
      if (!path) continue;
      const doc = vscode.workspace.textDocuments.find((d) => vscode.workspace.asRelativePath(d.uri) === path);
      if (!doc) continue;
      if (!doc.isDirty) {
        this._onLog(`💾 ${path} already saved (no pending editor changes)`);
        continue;
      }
      doc.save().then((saved) => {
        this._onLog(saved ? `💾 Auto-saved ${path}` : `⚠️ Could not auto-save ${path}`);
      });
    }
  }

  private _keepFile(path: string) {
    if (!this._pendingFiles.has(path)) return;
    this._pendingFiles.delete(path);
    this._onLog(`✅ Kept changes to ${path}`);
    this._postToWebview('fileStatus', { path, status: 'kept' });
    this._postReviewStatus();
  }

  private async _undoFile(path: string) {
    const entry = this._pendingFiles.get(path);
    if (!entry) return;
    this._pendingFiles.delete(path);
    await this._rollbackSnapshot(entry.snapshotId, path);
    this._onLog(`↩️ Reverted changes to ${path}`);
    this._postToWebview('fileStatus', { path, status: 'reverted' });
    this._postReviewStatus();
  }

  private async _resolveAllFiles(status: 'kept' | 'reverted') {
    const entries = Array.from(this._pendingFiles.entries());
    if (entries.length === 0) return;
    this._pendingFiles.clear();
    if (status === 'reverted') {
      await Promise.all(entries.map(([path, entry]) => this._rollbackSnapshot(entry.snapshotId, path)));
    }
    for (const [path] of entries) {
      this._postToWebview('fileStatus', { path, status });
    }
    const verb = status === 'kept' ? '✅ Kept' : '↩️ Reverted';
    this._onLog(`${verb} changes to ${entries.length} file(s)`);
    this._postReviewStatus();
  }

  // Restores the real on-disk pre-job content for one file via its captured snapshot, if any -
  // a missing/evicted snapshot (e.g. resumed job with no fresh snapshot) is logged honestly
  // rather than silently pretending the revert happened.
  private async _rollbackSnapshot(snapshotId: string | undefined, path: string): Promise<void> {
    if (!snapshotId) {
      this._onLog(`⚠️ No pre-change snapshot available for ${path} - only cleared it from the pending review list.`);
      return;
    }
    const snapshot = this._fileOpsGuard.getSnapshot(snapshotId);
    if (!snapshot) {
      this._onLog(`⚠️ Snapshot for ${path} is no longer available - only cleared it from the pending review list.`);
      return;
    }
    await this._fileOpsGuard.rollback(snapshot);
  }

  // Drives the inline Keep/Undo review bar from the still-pending file set.
  //
  // A pending set that totals +0/-0 is accepted automatically instead of being parked behind a
  // Keep click. Those counts come from diffLineCounts(), which runs a full LCS backtrace for
  // any normally-sized file, so +0/-0 means the new content is line-for-line identical to what
  // was already on disk - there is literally nothing to review, and asking anyway just trains
  // the habit of clicking Keep without looking, which is worse than not asking. Auto-accepting
  // is also safe rather than destructive: it only clears the pending marker, it never discards
  // the file or the snapshot behind it.
  private _postReviewStatus() {
    let additions = 0;
    let deletions = 0;
    for (const stats of this._pendingFiles.values()) {
      additions += stats.additions;
      deletions += stats.deletions;
    }

    const count = this._pendingFiles.size;
    if (count > 0 && additions === 0 && deletions === 0) {
      this._onLog(
        `✅ ${count} file${count === 1 ? '' : 's'} ended up byte-identical to the existing content (+0 / -0) - nothing to review, accepted automatically.`
      );
      void this._resolveAllFiles('kept');
      return;
    }

    this._postToWebview('reviewStatus', { count, additions, deletions });
  }

  private _onUsage(data: any) {
    this._sessionCostUsd += (data.costUsd || 0) - this._lastCostUsd;
    this._sessionInputTokens += (data.inputTokens || 0) - this._lastInputTokens;
    this._sessionOutputTokens += (data.outputTokens || 0) - this._lastOutputTokens;

    this._postToWebview('metrics', {
      costUsd: this._sessionCostUsd,
      inputTokens: this._sessionInputTokens,
      outputTokens: this._sessionOutputTokens,
    });
  }

  private _postToWebview(type: string, data: any) {
    if (!this._view) return;
    this._view.webview.postMessage({ type, ...data });
  }

  // Pushes the recent-jobs list the idle-state panel shows in place of the old plain
  // placeholder text. Safe to call any time - the webview only renders it while idle with
  // nothing else already shown, per its own displaySessions() guard.
  //
  // `forced` overrides that guard, and is used only when the USER asked for the redraw (the
  // ↻ Clear button): by then the panel is showing the session list itself rather than the
  // placeholder, so without this the just-cleared rows would stay on screen.
  private _postSessionsList(forced = false): void {
    this._postToWebview('sessionsList', { sessions: this._jobHistory.getRecent(), forced });
  }
}

export function activate(context: vscode.ExtensionContext) {
  context.subscriptions.push(output);
  log('[DAI-Flash] 🚀 Extension activation starting... (INTERNAL ADMIN BUILD, channel: ' + DISTRIBUTION_CHANNEL + ')');

  const gate = new AdminGate(context);

  // A non-admin build must expose nothing at all.
  if (!ADMIN_BUILD) {
    log('[DAI-Flash] ⛔ This build is not authorised for use. No features were registered.');
    void vscode.window.showErrorMessage('DAI Flash is an internal admin-only extension and is not available in this build.');
    return;
  }

  // Only the unlock/lock commands exist before the Admin Master Key clears the gate.
  context.subscriptions.push(
    vscode.commands.registerCommand('daiFlash.admin.unlock', async () => {
      const result = await gate.requireAdmin();
      if (result.granted) {
        // The Admin Master Key is the real access control; daiFlash.adminMode is only a
        // visibility preference layered on top (see _requireAdmin). A verified key should be
        // the single step that activates admin mode, so flip the setting here rather than
        // making the user separately find and tick it in Settings.
        await vscode.workspace
          .getConfiguration('daiFlash')
          .update('adminMode', true, vscode.ConfigurationTarget.Global);
        void vscode.window.showInformationMessage('DAI Flash unlocked. Reload the window to activate the admin tools.');
      } else {
        void vscode.window.showErrorMessage(`DAI Flash: ${result.reason}`);
      }
    }),
    vscode.commands.registerCommand('daiFlash.admin.lock', async () => {
      await gate.lock();
      await vscode.workspace
        .getConfiguration('daiFlash')
        .update('adminMode', false, vscode.ConfigurationTarget.Global);
      void vscode.window.showInformationMessage('DAI Flash re-locked. The Admin Master Key will be required again.');
    })
  );

  // Everything else is registered only after the gate is cleared, so a public/normal user who
  // somehow obtains this VSIX gets no view, no commands and no agent.
  void (async () => {
    const access = await gate.requireAdmin({ prompt: false });
    if (!access.granted) {
      log('[DAI-Flash] 🔒 Locked - admin access not verified. Run "DAI Flash Admin: Unlock" to present the Admin Master Key.');
      void vscode.window.showWarningMessage(
        'DAI Flash is restricted to internal admin use and is currently locked.',
        'Unlock'
      ).then((choice) => {
        if (choice === 'Unlock') void vscode.commands.executeCommand('daiFlash.admin.unlock');
      });
      return;
    }
    registerAdminFeatures(context, gate);
  })();
}

// Wires the full admin toolset. Never called unless the Admin Master Key has been verified.
function registerAdminFeatures(context: vscode.ExtensionContext, gate: AdminGate) {
  try {
    const provider = new DaiFlashViewProvider(context, gate);
    activeProvider = provider;
    log('[DAI-Flash] ✅ Provider instance created successfully');
    
    const subscription = vscode.window.registerWebviewViewProvider(
      DaiFlashViewProvider.viewType,
      provider,
      { webviewOptions: { retainContextWhenHidden: true } }
    );
    
    log('[DAI-Flash] ✅ Webview provider registered successfully (viewType: ' + DaiFlashViewProvider.viewType + ')');
    
    context.subscriptions.push(subscription);

    context.subscriptions.push(
      vscode.commands.registerCommand('daiFlash.showAgentReport', () => provider.showAgentReport()),
      vscode.commands.registerCommand('daiFlash.admin.showReport', () => provider.showAdminReport()),
      vscode.commands.registerCommand('daiFlash.admin.exportExcel', () => provider.exportAdminExcel()),
      vscode.commands.registerCommand('daiFlash.admin.exportApi', () => provider.exportAdminApi()),
      vscode.commands.registerCommand('daiFlash.admin.syncAgentMetrics', () => provider.syncAgentMetricsNow()),
      vscode.commands.registerCommand('daiFlash.admin.deleteFile', () => provider.deleteWorkspaceFile()),
      vscode.commands.registerCommand('daiFlash.admin.runSafeCommand', () => provider.runSafeCommandPrompt()),
      vscode.commands.registerCommand('daiFlash.updateApiKey', () => provider.updateApiKey()),
      vscode.commands.registerCommand('daiFlash.clearApiKey', () => provider.clearApiKey())
    );

    log('[DAI-Flash] 🎉 Admin build activated. Open the "DAI Flash" view in the activity bar sidebar to begin.');
  } catch (err) {
    log('[DAI-Flash] ❌ Failed to activate extension: ' + err);
    throw err;
  }
}

// Returning a Thenable here matters: VS Code waits for it (with a short grace period)
// before finishing teardown, which is what makes markCleanShutdown's write actually land
// on disk before the process goes away. Previously this was fire-and-forget, so a normal
// "Reload Window" could race the write and get misread as an unclean/crashed shutdown on
// the next activation.
export async function deactivate(): Promise<void> {
  stopPreviewServer();
  await activeProvider?.markCleanShutdown();
  activeProvider?.stopPricingSync();
  await activeProvider?.flushMetrics();
  log('[DAI-Flash] Extension deactivated');
}
