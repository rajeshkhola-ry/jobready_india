import { LegalPageLayout, LegalSection, privacyCommitmentText } from "../legal-content";

export default function PrivacyPage() {
  return (
    <LegalPageLayout
      title="Privacy Policy"
      intro={privacyCommitmentText}
    >
      <LegalSection
        title="Data Protection Commitment"
        body={privacyCommitmentText}
      />
      <LegalSection
        title="Processing Approach"
        body="We process service data only for account security, checkout verification, and support operations required to deliver Voice Shop."
      />
      <LegalSection
        title="No Third-Party Sale"
        body="We do not sell, rent, or transfer personal user documents or private data to third parties for commercial resale."
      />
    </LegalPageLayout>
  );
}
