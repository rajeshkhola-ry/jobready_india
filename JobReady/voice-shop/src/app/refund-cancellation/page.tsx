import { LegalPageLayout, LegalSection } from "../legal-content";

export default function RefundCancellationPage() {
  return (
    <LegalPageLayout
      title="Refund & Cancellation Policy"
      intro="This page defines refund and cancellation terms for Voice Shop plans, passes, and wallet recharges."
    >
      <LegalSection
        title="Digital Service Nature"
        body="Voice Shop plans and wallet payments are digital service access transactions."
      />
      <LegalSection
        title="Refund Terms"
        body="Payments are non-refundable unless explicitly approved in writing by GETREADYJOB. Partial and pro-rated refunds are not issued for unused or partially consumed service periods."
      />
      <LegalSection
        title="Cancellation"
        body="Users can discontinue usage at any time. Cancellation stops future usage and does not reverse already-processed transactions."
      />
      <LegalSection
        title="Billing Support"
        body="For billing clarifications, contact support@getreadyjob.com with your order reference and registered account email."
      />
    </LegalPageLayout>
  );
}
