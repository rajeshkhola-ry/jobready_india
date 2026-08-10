import { LegalPageLayout, LegalSection, aiDisclaimerText, legalNoticeText, privacyCommitmentText } from "../legal-content";

export default function TermsPage() {
  return (
    <LegalPageLayout
      title="Terms & Conditions"
      intro="These terms govern your use of GETREADYJOB Voice Shop and related services."
    >
      <LegalSection
        title="AI Disclaimer"
        body={aiDisclaimerText}
      />
      <LegalSection
        title="Privacy & Data Protection"
        body={privacyCommitmentText}
      />
      <LegalSection
        title="Refund & Cancellation"
        body="All subscription payments, wallet recharges, and pass purchases are digital service transactions and are non-refundable unless explicitly agreed in writing by GETREADYJOB."
      />
      <LegalSection
        title="Legal & Patent Notice"
        body={legalNoticeText}
      />
    </LegalPageLayout>
  );
}
