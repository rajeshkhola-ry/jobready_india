# JOBREADY Roadmap Rate Card (V1 vs V2 vs V3)

Last updated: 2026-07-15
Purpose: One-file requirement comparison with tick or X so launch readiness can be tracked quickly.

Legend:
- TICK = requirement is available in that version
- X = requirement is not available in that version
- PARTIAL = available but limited or still stabilizing

## Version Availability

| Version | Status |
|---|---|
| V1 | TICK (available) |
| V2 | TICK (available, active advanced build via Phase 7.5 routes) |
| V3 | PARTIAL (separate V3 launcher scaffold available; feature parity still in progress) |

## Requirement Comparison (Rate Card)

| # | Requirement | V1 | V2 | V3 |
|---|---|---|---|---|
| 1 | Home entry and navigation baseline | TICK | TICK | PARTIAL |
| 2 | Upload and start workflow | TICK | TICK | X |
| 3 | Compress tool page and flow | TICK | TICK | X |
| 4 | Convert tool page and flow | TICK | TICK | X |
| 5 | Merge tool page and flow | TICK | TICK | X |
| 6 | Split tool page and flow | TICK | TICK | X |
| 7 | Extract tool page and flow | TICK | TICK | X |
| 8 | PDF tools workspace access | TICK | TICK (expanded) | X |
| 9 | Word to PDF entry from PDF tools | PARTIAL | TICK (now routed to convert flow) | X |
| 10 | Merge/Split/Compress cards avoid placeholder message | PARTIAL | TICK | X |
| 11 | Compression benchmark control page | TICK | TICK | X |
| 12 | Benchmark history page | X | TICK | X |
| 13 | Launch readiness page | TICK | TICK | X |
| 14 | Launch runbook page | X | TICK | X |
| 15 | Post-launch control page | X | TICK | X |
| 16 | API configuration layer (analytics, ads, links, flags) | TICK | TICK | X |
| 17 | Pricing plans block (commercial setup) | X | TICK | X |
| 18 | Coupon and promo control panel | X | TICK | X |
| 19 | Ad slot and ad-link layer | X | TICK | X |
| 20 | Footer release/support info block | TICK | TICK (expanded) | X |
| 21 | PDF-to-Word with layout-first strategy | PARTIAL | TICK | X |
| 22 | Optional language-change toggle during convert | X | X | X (planned roadmap item only) |

## V1 + V2 Launch Focus (High Priority)

Use this block as launch gate for first release decision (V1 + VA/V2 blend):

| Launch Gate Requirement | Status |
|---|---|
| Core tools open correctly (Compress, Convert, Merge, Split, Extract) | TICK |
| No Phase-9 placeholder messages in active V2 app pages | TICK |
| PDF tools card routes wired to real pages | TICK |
| Diagnose and recover script available for emergency reset | TICK |
| Stability validation run after diagnose | PARTIAL (needs repeated owner test rounds) |
| Final owner acceptance test for converter and reduce size | PENDING |

## Recommended Execution Order (for fast, safer launch)

1. Lock V1 + V2 launch scope (no new feature additions during stabilization window).
2. Run Diagnose And Recover task before each test session.
3. Execute owner acceptance checklist on core flows:
   - Convert
   - Compress
   - Merge
   - Split
   - Extract
4. Fix only blocker defects.
5. Freeze launch evidence and go-live when all launch gate rows are TICK.

## Source Basis

This file is based on the current repository and audit basis from:
- V1_V2_V3_Audit_Report_2026-07-14.html
- main_v1.dart
- main_phase_7.5_.dart
- main_v3.dart
- Pages/home_page_v2.dart
- Pages/home_page_v3.dart
- Pages/pdf_tools_page.dart
- Pages/launch_readiness_page.dart
- Pages/launch_runbook_page.dart
- Pages/post_launch_control_page.dart
- Services/api_config.dart
- Services/coupon_service.dart

## V3 Owner Roadmap Record (2026-07-15)

Owner note captured:
- If any job is already completed in V1 and V2, leave it from V3 implementation scope and do not rebuild it.

### V3 Phase List (Recorded)

| Phase | Module | Main Goal | Priority | Scope Status |
|---|---|---|---|---|
| V3.1 | JOBREADY AI Assistant | Chat with documents and ask questions | Critical | PENDING |
| V3.2 | Advanced AI Writing Studio | CVs, cover letters, SOPs, emails, applications | Critical | PENDING |
| V3.3 | Smart CV and Resume Builder | ATS-friendly professional resumes | Critical | PENDING |
| V3.4 | Job Application Toolkit | Prepare complete job applications | High | PENDING |
| V3.5 | Student and Academic Toolkit | SOP, LOR, research proposal, academic CV | High | PENDING |
| V3.6 | Advanced OCR and Document Intelligence | Understand scans, handwriting, tables, forms | High | PENDING |
| V3.7 | Smart Document Workspace | Organize, search, and manage documents | High | PENDING |
| V3.8 | Team and Business Workspace | Collaboration for companies and institutions | Medium-High | PENDING |
| V3.9 | Global Language Intelligence | Translation and multilingual document tools | High | PENDING |
| V3.10 | Automation and Smart Workflows | Automate repetitive document tasks | Medium-High | PENDING |
| V3.11 | JOBREADY API and Integrations | Connect JOBREADY with external platforms | Medium | PARTIAL FOUNDATION IN V2 |
| V3.12 | Enterprise Security and Admin | Business-grade controls and security | High | PENDING |
| V3.13 | Global Payments and Monetization | International plans and subscriptions | Critical | PARTIAL FOUNDATION IN V2 |
| V3.14 | Performance, QA and Beta | Large-scale testing and optimization | Critical | PENDING |
| V3.15 | Global Version 3 Launch | International public release | Critical | PENDING |

### V3.1 JOBREADY AI Assistant (Detailed Record)

Expected document question flow:
- Summarize document
- Explain specific page in simple English
- Find important dates
- Compare two documents
- Create email based on document

Expected upload types:
- PDF, Word, Image, Excel, Presentation

### V3.2 Advanced AI Writing Studio (Detailed Record)

Target writing workspace includes:
- Emails and letters
- Job applications
- Cover letters
- SOPs
- Personal statements
- Research proposals
- Business letters
- Grammar correction
- Tone rewrite
- Shorten or expand text

Positioning rule:
- Keep AI specialized for documents, careers, students, applications, and professional productivity (not generic chatbot behavior).

### V3.3 Smart CV and Resume Builder (Detailed Record)

Expected outputs:
- ATS-friendly resumes
- Modern professional CVs
- Academic CVs
- Country-specific formats
- Role-specific versions
- One-click PDF and Word export

AI constraint:
- Suggest improvements from job description without inventing qualifications or experience.

### V3.4 Job Application Toolkit (Detailed Record)

Expected pipeline:
- Upload CV
- Paste job description
- Match analysis
- CV improvement suggestions
- Tailored cover letter generation
- Interview question generation
- Save application record

### V3.5 Student and Academic Toolkit (Detailed Record)

Scope list:
- Academic CV builder
- SOP assistant
- LOR draft assistant
- Research proposal structure
- Scholarship application support
- University application checklist
- Document requirement tracker
- Citation and reference assistance
- Thesis/research document summarization

### V3.6 Advanced OCR and Document Intelligence (Detailed Record)

Target inputs and understanding:
- Scanned PDFs
- Document photos
- Forms
- Tables
- Receipts
- Certificates
- Invoices
- Handwriting when technically reliable

Outcome target:
- Return structured understanding, not only raw text blocks.

### V3.7 Smart Document Workspace (Detailed Record)

Workspace sections:
- My Documents
- Recent Files
- Favourites
- Shared With Me
- AI History
- Conversion History

Search direction:
- Filename search
- Content search where privacy architecture allows.

### V3.8 Team and Business Workspace (Detailed Record)

Business collaboration scope:
- Team accounts
- Shared folders
- Role-based permissions
- Admin dashboard
- Usage reports
- Central billing
- Brand templates
- Shared AI credits

### V3.9 Global Language Intelligence (Detailed Record)

Language direction:
- Hindi and English first
- Expand to major European languages, Arabic, and other high-demand languages

Conversion goal:
- Translate documents while preserving structure and formatting as much as possible.

### V3.10 Automation and Smart Workflows (Detailed Record)

Example automations:
- Invoice upload to data extraction to Excel
- Batch PDF to Word conversion
- Batch compression below threshold
- Batch translation workflows

### V3.11 JOBREADY API and Integrations (Detailed Record)

Planned platform connections:
- Cloud storage
- Email
- Office productivity services
- Developer APIs

Ordering note:
- Keep later in V3 after core user workflows are stable.

### V3.12 Enterprise Security and Admin (Detailed Record)

Security and governance scope:
- Encryption in transit
- Secure temporary file handling
- Automatic file deletion
- Data retention controls
- Account security
- Audit logs
- Admin permissions
- Backup strategy
- Privacy documentation
- GDPR and applicable privacy obligations

### V3.13 Global Payments and Monetization (Detailed Record)

Planned plan structure:
- Free
- Premium
- Pro
- Business

Pricing rule:
- Finalize after real cost profiling (AI, infra, storage, payment fees, taxes, support, competitive benchmarks).

### V3.14 Performance, QA and Beta Testing (Detailed Record)

Required test areas:
- Small and large files
- Slow internet
- Different browsers
- Windows and Android
- Mobile screen sizes
- Corrupt documents
- Password-protected PDFs
- Scanned PDFs
- Multiple languages
- AI accuracy
- Payment failures
- Account recovery
- Privacy and deletion workflows

### V3.15 Global Version 3 Launch (Detailed Record)

Recommended release ladder:
- Private alpha
- Invitation-only beta
- Public beta
- Staged rollout
- Full global release

## V2 Pending Execution Log (2026-07-15)

Scope rule applied:
- Keep V1 and V2 UI pattern unchanged while implementing missing functionality.

Completed today:
- V2.3 PDF-to-JPG/PNG improved to page-by-page export (ZIP output).
- V2.6 Image-to-PDF upgraded to combine multiple images into one PDF file.
- V2.9 foundation added: recent document history (local), account profile block, privacy toggle to disable history tracking.
- V2 quota foundation added: local daily usage counters, V2 home status panel, and near-limit / over-limit warning messaging.
- V2.12 quality hardening: clearer handling and messaging for password-protected/encrypted PDF conversion failures.
- V2.12 validation support: System Check page now includes focused checklist for newly delivered V2 features.
- PDF OCR merged into existing PDF Edit flow (Load Text + Run OCR actions) without adding a new standalone tool page.
- PDF-to-Word now uses OCR fallback in the same PDF tools flow when embedded text extraction is insufficient.
- Word-to-PDF reliability improved with structured DOCX-to-PDF handling and explicit legacy .doc guidance.

In progress:
- V2.1 and V2.7 OCR depth upgrade (scanned-PDF/image OCR) requires OCR runtime/provider integration.

Next implementation targets in same UI:
- Broaden OCR capability path once OCR engine is attached.
- Expand V2.9 from local profile/history to authenticated account model when backend auth is finalized.
- Continue V2.12 release hardening around corrupted/password-protected file paths and broader acceptance tests.

## Strict Remaining Work Checklist (V1 + V2)

Owner mode:
- Quality over speed.
- Keep V1/V2 UI style and merge overlapping tools into current pages.

### 1) Must Finish Before V1 + V2 Release

- [ ] V1 final owner acceptance test on core flows (Compress, Convert, Merge, Split, Extract).
- [ ] V1 repeated stability validation rounds and final sign-off evidence.
- [ ] V2 conversion reliability hardening for production-critical paths:
   - Word to PDF reliability baseline with clear pass criteria.
   - PDF to Word scanned document fallback quality check (OCR path).
   - Corrupt/password-protected file handling and user-safe messages.
- [ ] V2 quota and plan enforcement final check (free limit, upgrade prompt, paid plan path behavior).
- [ ] V2 launch smoke matrix:
   - Chrome and Edge latest.
   - Small/large file cases.
   - Slow network and interruption scenarios.

### 2) Can Finish After Release (Phase 2)

- [ ] V2 real account system (login/session) replacing local-only profile.
- [ ] V2 synced document history (server-backed) replacing local-only history.
- [ ] V2 true cloud integration uploads (OneDrive and others) beyond open/share helper links.
- [ ] V2 broader device optimization (Android-first polish, then iOS).
- [ ] V2 extended automated regression tests.

### 3) Move To V3 Only (Do Not Block V1/V2 Release)

- [ ] AI document assistant suite (summarize/rewrite/translate/Q&A at scale).
- [ ] Full student toolkit and job-application intelligence modules.
- [ ] Team/business multi-user workspace and admin governance.
- [ ] Enterprise API productization and public developer platform.
- [ ] Global multilingual intelligence rollout and advanced workflow automation.

### Current Practical Completion Snapshot

- V1: Near release-ready; mostly validation/sign-off pending.
- V2: Core toolset strong and expanded, but backend-grade account/cloud/payment/AI layers remain partial.
