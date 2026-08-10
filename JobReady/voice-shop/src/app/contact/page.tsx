import { LegalPageLayout, LegalSection } from "../legal-content";

export default function ContactPage() {
  return (
    <LegalPageLayout
      title="Contact Us"
      intro="For support, compliance review, and business communication, use the official GETREADYJOB contact channels below."
    >
      <LegalSection
        title="Support Email"
        body="support@getreadyjob.com"
      />
      <LegalSection
        title="Business Email"
        body="hello@getreadyjob.com"
      />
      <LegalSection
        title="Physical Office Address"
        body="GETREADYJOB, India (physical office support desk; full mailing address shared to verified review teams on request)."
      />
    </LegalPageLayout>
  );
}
