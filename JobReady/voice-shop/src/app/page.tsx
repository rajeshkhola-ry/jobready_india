"use client";

import { FormEvent, useEffect, useState } from "react";
import { ArrowRight, Check, CheckCircle2, CircleDollarSign, Clock3, Globe2, Headphones, LockKeyhole, LogOut, Mail, Mic2, ShieldCheck, Sparkles, UserRound, WalletCards, X } from "lucide-react";
import Image from "next/image";
import Link from "next/link";

type AuthMode = "login" | "signup" | "forgot";
type SessionUser = { id: number; email: string; fullName: string };
type PriceCatalog = {
  currency: "INR" | "USD";
  symbol: string;
  trialEnabled: boolean;
  walletRates: { personal: number; business: number };
  walletTopUps: number[];
  passes: Array<{ code: string; personal: number; business: number }>;
};

const passLabels: Record<string, string> = { "1-day": "1 Day", "7-day": "7 Days", "30-day": "30 Days", "1-year": "1 Year" };
const showcaseTools = [
  { title: "AI Mock Interviewer", image: "/showcase/mock-interview.svg", alt: "An interviewer and student practicing with a phone on the table", description: "Practice mock interviews at home. The AI asks real interview questions and gives instant feedback to improve your confidence." },
  { title: "Real-time Voice & Language Translator", image: "/showcase/voice-translator.svg", alt: "Two people translating a conversation through one smartphone", description: "Break language barriers. Speak in your native language, and the AI instantly translates and speaks it back in the other person's language." },
  { title: "AI Study & Learning Assistant", image: "/showcase/study-assistant.svg", alt: "A student learning with books and a mobile AI tutor", description: "Your personal study buddy. Understand tough topics in plain, easy language and make learning fun." },
  { title: "AI Resume & Career Tools", image: "/showcase/resume-career.svg", alt: "A professional resume being generated on a phone", description: "Create professional ATS-friendly resumes in minutes and apply for job opportunities directly." },
] as const;
const universalFeatures = ["AI Voice Shop & Calling", "AI Mock Interview Practice", "Real-time Voice Translator", "AI Study & Learning Partner", "AI Resume & Career Builder", "Unlimited Tool Switching", "24/7 Customer Support"] as const;
const planColumns = ["1-Day Pass", "7-Days Pass", "30-Days Pass", "1-Year Pass"] as const;
const indianLanguages = ["Hindi", "Tamil", "Telugu", "Bengali", "Marathi", "Gujarati", "Kannada", "Malayalam", "Punjabi", "Odia", "Assamese", "Urdu"] as const;
const internationalLanguages = ["English (US/UK/IN)", "Spanish", "French", "German", "Mandarin Chinese", "Japanese", "Korean", "Arabic", "Russian", "Portuguese", "Italian", "Dutch", "Turkish", "Vietnamese", "Indonesian"] as const;
const faqs = [
  {
    question: "How does the AI Mock Interviewer help me practise?",
    answer: "The Voice Shop mock interview workspace presents realistic interview practice and is designed to help users improve confidence, communication and career preparation.",
  },
  {
    question: "Can I use Voice Shop without a monthly subscription?",
    answer: "Yes. Voice Shop offers pay-as-you-go wallet rates and fixed 1-Day, 7-Day, 30-Day and 1-Year passes without requiring a monthly subscription.",
  },
  {
    question: "Is there a free trial available?",
    answer: "When the trial program is enabled, a signed-in account can claim one 2-minute Voice Shop trial, subject to the global trial allocation.",
  },
] as const;

export default function Home() {
  const [user, setUser] = useState<SessionUser | null>(null);
  const [catalog, setCatalog] = useState<PriceCatalog | null>(null);
  const [authOpen, setAuthOpen] = useState(false);
  const [authMode, setAuthMode] = useState<AuthMode>("login");
  const [status, setStatus] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    Promise.all([fetch("/api/auth/me").then((response) => response.json()), fetch("/api/pricing").then((response) => response.json())])
      .then(([session, pricing]) => { setUser(session.user || null); setCatalog(pricing); });
  }, []);

  async function claimTrial() {
    if (!user) {
      setAuthMode("signup");
      setStatus("Create your verified account before activating the free trial.");
      setAuthOpen(true);
      return;
    }
    setBusy(true);
    const response = await fetch("/api/trial/claim", { method: "POST" });
    const data = await response.json();
    setStatus(data.granted ? `${data.minutes} free minutes activated.` : trialMessage(data.reason));
    setBusy(false);
  }

  async function logout() {
    await fetch("/api/auth/logout", { method: "POST" });
    setUser(null);
    setStatus("Signed out securely.");
  }

  return (
    <main className="app-shell">
      <header className="topbar">
        <a className="brand" href="#workspace" aria-label="Caddaddy Voice Shop home"><span className="brand-mark"><Mic2 size={20} /></span><span>CADDADDY <b>VOICE SHOP</b></span></a>
        <nav className="topnav" aria-label="Primary navigation"><a href="#workspace">Voice Studio</a><a href="#pricing">Pricing</a><a href="#passes">Passes</a></nav>
        <div className="account-actions">
          <span className="currency-pill"><Globe2 size={15} /> {catalog?.currency || "..."}</span>
          {user ? <><span className="user-name"><UserRound size={16} /> {user.fullName}</span><button className="icon-button" onClick={logout} title="Sign out" aria-label="Sign out"><LogOut size={18} /></button></> : <button className="text-button" onClick={() => { setAuthMode("login"); setAuthOpen(true); }}>Sign in</button>}
        </div>
      </header>

      <section className="voice-workspace" id="workspace">
        <div className="workspace-copy">
          <p className="eyebrow"><Sparkles size={15} /> Account-protected voice access</p>
          <h1>Voice Shop</h1>
          <p className="lead">A secure voice workspace for personal projects and business production, priced by the minute or by pass.</p>
          {catalog?.trialEnabled === true && <div className="workspace-actions">
            <button className="primary-button" onClick={claimTrial} disabled={busy}>{busy ? "Activating..." : "Claim 2 free minutes"}<ArrowRight size={18} /></button>
            <span className="secure-note"><LockKeyhole size={15} /> Login required. One trial per account.</span>
          </div>}
          {status && <p className="status-line" role="status">{status}</p>}
        </div>
        <div className="voice-console" aria-label="Voice preview console">
          <div className="console-head"><span><Headphones size={17} /> Studio preview</span><span className="live-dot">Ready</span></div>
          <div className="waveform" aria-hidden="true">{Array.from({ length: 34 }, (_, index) => <i key={index} style={{ height: `${20 + ((index * 29) % 62)}%` }} />)}</div>
          <div className="console-meta">{catalog?.trialEnabled === true && <span><Clock3 size={15} /> 02:00 trial</span>}<span><ShieldCheck size={15} /> Secure voice access</span></div>
        </div>
      </section>

      <section className="trust-strip">{catalog?.trialEnabled === true && <><span><Check size={16} /> One verified account per trial</span><span><Check size={16} /> Global 1,000-account cap</span></>}<span><Check size={16} /> Low-balance alerts</span><span><Check size={16} /> INR/USD location pricing</span></section>

      <section className="showcase-section" id="tools">
        <div className="showcase-heading"><p className="eyebrow">One account, practical AI tools</p><h2>Everyday help that feels simple</h2><p>Use one familiar workspace for interview practice, conversation, study, and career preparation.</p></div>
        <div className="showcase-list">
          {showcaseTools.map((tool, index) => <article className="showcase-item" key={tool.title}>
            <figure className="showcase-visual"><Image src={tool.image} alt={tool.alt} width={640} height={400} /></figure>
            <div className="showcase-copy"><span>0{index + 1}</span><h3>{tool.title}</h3><p>{tool.description}</p><a href="#passes">Explore passes <ArrowRight size={17} /></a></div>
          </article>)}
        </div>
      </section>

      <section className="matrix-section" id="features">
        <div className="section-heading"><div><p className="eyebrow">No tool restrictions</p><h2>All tools. Every pass.</h2></div><p>Choose a pass for the time you need. Your tool access stays the same across every duration.</p></div>
        <div className="matrix-scroll" role="region" aria-label="Universal feature matrix" tabIndex={0}>
          <table className="feature-matrix">
            <thead><tr><th scope="col">Features &amp; Tools</th>{planColumns.map((plan) => <th scope="col" key={plan}>{plan}</th>)}</tr></thead>
            <tbody>{universalFeatures.map((feature) => <tr key={feature}><th scope="row">{feature}</th>{planColumns.map((plan) => <td key={plan}><CheckCircle2 aria-label="Included" /></td>)}</tr>)}</tbody>
          </table>
        </div>
        <p className="matrix-note"><CheckCircle2 size={18} /> Every pass includes every tool and service listed above.</p>
      </section>

      <section className="pricing-section" id="pricing">
        <div className="section-heading"><div><p className="eyebrow">Pay only for what you use</p><h2>Wallet rates</h2></div><p>Prices are shown in {catalog?.currency || "your local currency"}. International rates use the monthly average USD-INR exchange rate.</p></div>
        <div className="rate-grid">
          <article className="rate-panel personal"><div className="rate-icon"><UserRound /></div><p>Personal</p><strong>{catalog ? `${catalog.symbol}${catalog.walletRates.personal}` : "..."}<small>/min</small></strong><span>Voice projects for individual use</span></article>
          <article className="rate-panel business"><div className="rate-icon"><CircleDollarSign /></div><p>Business</p><strong>{catalog ? `${catalog.symbol}${catalog.walletRates.business}` : "..."}<small>/min</small></strong><span>Commercial and client-facing production</span></article>
          <div className="topup-panel"><div><WalletCards size={22} /><h3>Wallet top-ups</h3></div><div className="topup-options">{(catalog?.walletTopUps || []).map((amount) => <button key={amount}>{catalog?.symbol}{amount}</button>)}</div><p>Balance alerts appear before funds run low.</p></div>
        </div>
      </section>

      <section className="passes-section" id="passes">
        <div className="section-heading"><div><p className="eyebrow">Fixed access windows</p><h2>Package passes</h2></div><p>Choose a duration, then select Personal or Business at checkout.</p></div>
        <div className="pass-table"><div className="pass-row pass-header"><span>Duration</span><span>Personal</span><span>Business</span><span /></div>{(catalog?.passes || []).map((pass) => <div className="pass-row" key={pass.code}><strong>{passLabels[pass.code]}</strong><span>{catalog?.symbol}{pass.personal}</span><span>{catalog?.symbol}{pass.business}</span><button className="icon-button" title={`Choose ${passLabels[pass.code]}`} aria-label={`Choose ${passLabels[pass.code]}`}><ArrowRight size={18} /></button></div>)}</div>
      </section>

      <section className="faq-section" id="faq">
        <div className="section-heading"><div><p className="eyebrow">Voice Shop answers</p><h2>Frequently asked questions</h2></div><p>Clear details about interview practice, flexible access, and the account-based trial.</p></div>
        <div className="faq-list">
          {faqs.map((faq, index) => <details key={faq.question} open={index === 0}>
            <summary>{faq.question}<span aria-hidden="true">+</span></summary>
            <p>{faq.answer}</p>
          </details>)}
        </div>
      </section>

      <section className="supported-languages-section" aria-labelledby="supported-languages-heading">
        <div className="languages-heading">
          <p className="eyebrow">Multilingual career preparation</p>
          <h2 id="supported-languages-heading">🌍 Supported Languages &amp; Global Reach</h2>
          <p>Practice AI mock interviews and real-time voice translation seamlessly in your preferred language.</p>
        </div>
        <div className="language-groups">
          <article className="language-group">
            <h3>🇮🇳 Indian Regional Languages</h3>
            <div className="language-chips" aria-label="Indian regional languages">
              {indianLanguages.map((language) => <span key={language}>{language}</span>)}
            </div>
          </article>
          <article className="language-group">
            <h3>🌐 International Languages</h3>
            <div className="language-chips" aria-label="International languages">
              {internationalLanguages.map((language) => <span key={language}>{language}</span>)}
            </div>
          </article>
        </div>
        <p className="language-upcoming-note"><strong>🚀 Rest of the World:</strong> We are actively expanding our AI speech models for all remaining global languages and dialects. Rolling out soon!</p>
      </section>

      <footer><span>CADDADDY Voice Shop</span><span>Secure voice access for global customers</span></footer>

      {authOpen && <AuthDialog mode={authMode} status={status} trialEnabled={catalog?.trialEnabled === true} onModeChange={setAuthMode} onClose={() => setAuthOpen(false)} onAuthenticated={(authenticatedUser) => { setUser(authenticatedUser); setAuthOpen(false); setStatus(catalog?.trialEnabled === true ? "Account verified. Your trial is ready to activate." : "Account verified. You are signed in securely."); }} onStatus={setStatus} />}
    </main>
  );
}

function AuthDialog({ mode, status, trialEnabled, onModeChange, onClose, onAuthenticated, onStatus }: { mode: AuthMode; status: string; trialEnabled: boolean; onModeChange: (mode: AuthMode) => void; onClose: () => void; onAuthenticated: (user: SessionUser) => void; onStatus: (message: string) => void; }) {
  const [busy, setBusy] = useState(false);
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    const payload = Object.fromEntries(new FormData(event.currentTarget).entries());
    const endpoint = mode === "signup" ? "/api/auth/signup" : mode === "forgot" ? "/api/auth/forgot-password" : "/api/auth/login";
    const response = await fetch(endpoint, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(payload) });
    const data = await response.json();
    setBusy(false);
    if (!response.ok) return onStatus(data.error || "Unable to continue.");
    if (mode === "forgot") return onStatus(data.developmentResetUrl ? `Local reset ready: ${data.developmentResetUrl}` : data.message);
    onAuthenticated(data.user);
  }
  return (
    <div className="dialog-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose(); }}>
      <div className="auth-dialog" role="dialog" aria-modal="true" aria-labelledby="auth-title">
        <button className="dialog-close" onClick={onClose} aria-label="Close"><X /></button><p className="eyebrow">Caddaddy account</p>
        <h2 id="auth-title">{mode === "signup" ? "Create your account" : mode === "forgot" ? "Reset your password" : "Welcome back"}</h2>
        <p>{mode === "signup" ? (trialEnabled ? "Your account protects trial access, wallet balance, and active passes." : "Your account protects wallet balance and active passes.") : mode === "forgot" ? "Enter your registered email to prepare a secure reset link." : "Sign in to continue to Voice Shop."}</p>
        {mode !== "forgot" && <div className="social-grid"><Link href="/api/auth/oauth/google" className="social-button"><span className="google-g">G</span> Continue with Google</Link><Link href="/api/auth/oauth/microsoft" className="social-button"><span className="ms-mark"><i /><i /><i /><i /></span> Continue with Microsoft</Link></div>}
        {mode !== "forgot" && <div className="or-divider"><span>or use email</span></div>}
        <form onSubmit={submit} className="auth-form">
          {mode === "signup" && <><label>Full name<input name="fullName" required minLength={2} autoComplete="name" /></label><div className="field-pair"><label>Mobile number<input name="mobile" required minLength={7} autoComplete="tel" /></label><label>Country<input name="country" required minLength={2} autoComplete="country-name" /></label></div></>}
          <label>Email ID<input name="email" type="email" required autoComplete="email" /></label>
          {mode !== "forgot" && <label>Password<input name="password" type="password" required minLength={8} autoComplete={mode === "signup" ? "new-password" : "current-password"} /></label>}
          <button className="primary-button form-submit" disabled={busy}>{busy ? "Please wait..." : mode === "signup" ? "Create account" : mode === "forgot" ? "Prepare reset link" : "Sign in"}<ArrowRight size={17} /></button>
        </form>
        {status && <p className="dialog-status" role="status">{status}</p>}
        <div className="auth-switches">{mode !== "login" && <button onClick={() => onModeChange("login")}>Sign in</button>}{mode !== "signup" && <button onClick={() => onModeChange("signup")}>Create account</button>}{mode !== "forgot" && <button onClick={() => onModeChange("forgot")}><Mail size={14} /> Forgot password</button>}</div>
      </div>
    </div>
  );
}

function trialMessage(reason: string) {
  if (reason === "already_claimed") return "This account has already used its free trial.";
  if (reason === "global_cap_reached") return "The global free-trial allocation has ended.";
  return "Please sign in before claiming the trial.";
}
