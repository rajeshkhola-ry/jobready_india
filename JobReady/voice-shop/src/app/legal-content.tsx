import Link from "next/link";
import type { ReactNode } from "react";

export const legalNoticeText =
  'GETREADYJOB is a protected platform. The technology and core systems, including the "VOICE ENABLED MULTILINGUAL JOB PREPARATION PLATFORM WITH AUTOMATED LANGUAGE CONVERTER TOOLS", are filed and protected under the Indian Patent Act (Patent Application No. 202611096315).\n\nAll content, branding, design, and software tools on https://getreadyjob.com are the exclusive intellectual property of GETREADYJOB. Unauthorized copying, scraping, reverse-engineering, or reproduction of any part of this platform without prior written permission is strictly prohibited and subject to legal action.';

export const aiDisclaimerText =
  "Disclaimer: Our tools utilize Artificial Intelligence to assist users with job preparation, resume building, and translations. Users are advised to review and verify all generated content for accuracy before official submission to government forms, employers, or institutions.";

export const privacyCommitmentText =
  "We prioritize user data privacy. Any resumes, documents, or personal information uploaded to GETREADYJOB are processed securely and are never sold, shared, or transferred to any third parties.";

type LegalPageLayoutProps = {
  title: string;
  intro: string;
  children: ReactNode;
};

export function LegalPageLayout({ title, intro, children }: LegalPageLayoutProps) {
  return (
    <main className="app-shell legal-shell">
      <header className="topbar legal-topbar">
        <a className="brand" href="https://voice.getreadyjob.com/" aria-label="Back to Voice Shop home">
          <span className="brand-mark">G</span>
          <span>
            GETREADYJOB <b>VOICE SHOP</b>
          </span>
        </a>
        <nav className="topnav" aria-label="Legal navigation">
          <Link href="/about">About</Link>
          <Link href="/privacy">Privacy</Link>
          <Link href="/terms">Terms</Link>
          <Link href="/refund-cancellation">Refund</Link>
          <Link href="/contact">Contact</Link>
        </nav>
      </header>

      <section className="legal-content-wrap">
        <article className="legal-card">
          <p className="eyebrow">Compliance & public review</p>
          <h1 className="legal-title">{title}</h1>
          <p className="legal-intro">{intro}</p>
          <div className="legal-sections">{children}</div>
        </article>
      </section>

      <footer className="production-footer">
        <div className="footer-brand">
          <strong>GETREADYJOB</strong>
          <p>Professional tools for resumes, documents, PDF workflows, and AI voice tasks.</p>
        </div>
        <nav className="footer-links" aria-label="Footer navigation">
          <Link href="/about">About Us</Link>
          <Link href="/contact">Contact</Link>
          <Link href="/privacy">Privacy Policy</Link>
          <Link href="/terms">Terms &amp; Conditions</Link>
          <Link href="/refund-cancellation">Refund &amp; Cancellation</Link>
        </nav>
        <div className="footer-details">
          <div>
            <a href="mailto:support@getreadyjob.com">Support email: support@getreadyjob.com</a>
            <p>Business email: hello@getreadyjob.com</p>
            <p>Office: GETREADYJOB, India (physical office support desk; full mailing address shared to verified review teams on request)</p>
          </div>
          <div>
            <a href="https://getreadyjob.com/">Website: getreadyjob.com</a>
            <p>Patent Pending (App No. 202611096315) | © 2026 GETREADYJOB</p>
            <p>{legalNoticeText}</p>
          </div>
        </div>
      </footer>
    </main>
  );
}

type LegalSectionProps = {
  title: string;
  body: string;
};

export function LegalSection({ title, body }: LegalSectionProps) {
  return (
    <section className="legal-section-block">
      <h2>{title}</h2>
      <p>{body}</p>
    </section>
  );
}
