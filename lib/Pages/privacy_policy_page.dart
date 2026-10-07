import 'package:flutter/material.dart';

import '../Services/public_brand_config.dart';
import 'site_content_page.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SiteContentPage(
      title: 'Privacy Policy',
      intro: 'This privacy policy explains how GETREADYJOB (operated by Druta Systems) handles your data across its free, browser-based tools and its paid plans. Last updated: 2026-10-07.',
      seoTitle: 'Privacy Policy | GetReadyJob',
      seoDescription: 'How GetReadyJob handles your files: which tools run entirely in your browser, which send your file to our processing server, and what happens to it there.',
      canonicalPath: '/privacy',
      highlights: const ['Privacy First', 'File Handling', 'Your Rights', 'Grievance Officer'],
      sections: [
        const SiteContentSection(
          title: 'File Handling',
          body: 'Whether a file leaves your device depends on which tool you use, so we set it out tool by tool rather than making one claim for all of them.\n\n'
              'Processed entirely in your browser — the file never leaves your device: merge PDF, split PDF, the Aadhaar/PAN smart redactor and privacy masker, the purpose watermark and fraud-check authenticity seal, the job application document bundle, and government photo and signature resizing at standard sizes.\n\n'
              'Sent to our processing server: PDF compression, image compression, PDF to Word conversion, spreadsheet and CSV conversion, PDF to image conversion, text recognition (OCR) when a scanned PDF holds no selectable text, and poster-size photo rendering at very large canvases. These need software that cannot run inside a browser.\n\n'
              'For that second group, your file is sent over an encrypted connection to our processing server, written to a temporary working directory, processed, and deleted as soon as the result is returned to you. It is not retained, not backed up, not reviewed by any person, not linked to your account, and not used for anything other than producing the output you asked for.\n\n'
              'We keep no copy of anything you process, so please keep your own copies of files that matter to you.',
        ),
        const SiteContentSection(
          title: 'Data We Collect',
          body: 'For paid subscriptions (Weekly, Monthly, Yearly, or Lifetime plans), we collect account information such as your email address, subscription/plan status, and a payment reference from our payment processor. We do not receive or store your full card, UPI, or bank details — these are handled directly by our payment processor. We also collect basic, non-identifying usage/analytics data (such as pages visited) to understand how the site is used and to fix issues.',
        ),
        const SiteContentSection(
          title: 'Third-Party Services & Cookies',
          body: 'Account and subscription data for paid plans is processed on our own backend servers. The document-processing server described under File Handling is operated by us and hosted on Render. We use Razorpay to process payments for paid plans, Google Firebase to host this website, and Google Tag Manager for basic site analytics. These providers may set cookies or use similar technologies in your browser; each is governed by its own privacy policy. You can control or clear cookies at any time through your browser settings; this will not affect your ability to use our free, client-side tools.',
        ),
        const SiteContentSection(
          title: 'Data Retention',
          body: 'We keep no copy of your files. Files handled entirely in your browser never reach us at all. Files sent to our processing server exist there only for the length of that one request and are deleted when it finishes; they are not added to any backup. Account and subscription data for paid users is kept for as long as your account is active, or as required to meet our legal, accounting, or tax obligations, after which it is deleted or anonymized.',
        ),
        const SiteContentSection(
          title: 'Your Rights',
          body: 'Under India\'s Digital Personal Data Protection Act, 2023 and other applicable data protection laws, you may request access to, correction of, or deletion of your personal data (such as your account email or subscription record) that we hold. To exercise these rights, contact our Grievance Officer below.',
        ),
        const SiteContentSection(
          title: 'Children\'s Privacy',
          body: 'GETREADYJOB is intended for users aged 18 and above, or minors using the platform with the consent and supervision of a parent or guardian. We do not knowingly collect personal data from children without such consent.',
        ),
        SiteContentSection(
          title: 'Grievance Officer & Support',
          body: 'For privacy questions, data requests, or complaints, contact our Grievance Officer:\n\nName: Rajesh Kumar Yadav\nDesignation: Grievance Officer, GETREADYJOB (Druta Systems)\nEmail: ${PublicBrandConfig.supportEmail}\n\nWe aim to acknowledge requests within 24 hours and resolve them within 15 days.',
        ),
        const SiteContentSection(
          title: 'Policy Updates',
          body: 'This policy may be updated as our privacy architecture, retention controls, and compliance requirements evolve. Material changes will be reflected by updating the "Last updated" date above.',
        ),
      ],
    );
  }
}
