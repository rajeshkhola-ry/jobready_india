import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Services/public_brand_config.dart';

class SiteFooterLink extends StatelessWidget {
  final String label;
  final String url;

  const SiteFooterLink({
    super.key,
    this.label = PublicBrandConfig.websiteHost,
    this.url = 'https://getreadyjob.com',
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _openWebsite(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F4E79),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openWebsite(BuildContext context) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open website link right now.')),
      );
    }
  }
}
