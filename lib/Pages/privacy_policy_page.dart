import 'package:flutter/material.dart';

import '../Services/public_brand_config.dart';
import 'site_content_page.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SiteContentPage(
      title: 'Privacy Policy',
      intro: 'This privacy policy explains how GETREADYJOB (operated by Druta Systems) handles your data across its free, browser-based tools and its paid plans. Last updated: 2026-09-09.',
      seoTitle: 'Privacy Policy | GetReadyJob',
      seoDescription: 'Read the GetReadyJob privacy policy covering our 100% client-side, browser-based document and photo tools that never upload your files.',
      canonicalPath: '/privacy',
      highlights: const ['Privacy First', 'File Handling', 'Your Rights', 'Grievance Officer'],
      sections: [
        const SiteContentSection(
          title: 'File Handling (Client-Side Processing)',
          body: 'For our free tools (PDF utilities, photo enhancement, document conversion, and similar features), your files, images, and their contents are processed entirely in your browser and are never uploaded to, or stored on, our servers. Users should still keep their own copies of important files, since we retain no backup of anything processed locally.',
        ),
        const SiteContentSection(
          title: 'Data We Collect',
          body: 'For paid subscriptions (Weekly, Monthly, Yearly, or Lifetime plans), we collect account information such as your email address, subscription/plan status, and a payment reference from our payment processor. We do not receive or store your full card, UPI, or bank details — these are handled directly by our payment processor. We also collect basic, non-identifying usage/analytics data (such as pages visited) to understand how the site is used and to fix issues.',
        ),
        const SiteContentSection(
          title: 'Third-Party Services & Cookies',
          body: 'Account and subscription data for paid plans is processed on our own backend servers. We use Razorpay to process payments for paid plans, Google Firebase to host this website, and Google Tag Manager for basic site analytics. These providers may set cookies or use similar technologies in your browser; each is governed by its own privacy policy. You can control or clear cookies at any time through your browser settings; this will not affect your ability to use our free, client-side tools.',
        ),
        const SiteContentSection(
          title: 'Data Retention',
          body: 'Uploaded files and processed outputs from our free tools are never stored, so there is nothing to retain or delete. Account and subscription data for paid users is kept for as long as your account is active, or as required to meet our legal, accounting, or tax obligations, after which it is deleted or anonymized.',
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
