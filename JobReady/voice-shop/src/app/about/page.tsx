import { LegalPageLayout, LegalSection, legalNoticeText } from "../legal-content";

export default function AboutPage() {
  return (
    <LegalPageLayout
      title="About GETREADYJOB Voice Shop"
      intro="Voice Shop delivers practical AI voice tools for interview practice, translation, and career workflows."
    >
      <LegalSection
        title="What We Build"
        body="GETREADYJOB Voice Shop provides AI-powered mock interview preparation, voice translation support, and career-oriented productivity tools in one secure workspace."
      />
      <LegalSection
        title="Who We Serve"
        body="Students, professionals, and teams who need reliable AI voice workflows for preparation, communication, and job readiness."
      />
      <LegalSection
        title="Legal & Patent Notice"
        body={legalNoticeText}
      />
    </LegalPageLayout>
  );
}
