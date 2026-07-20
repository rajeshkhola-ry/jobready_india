import 'package:flutter/material.dart';

class ToolGuidancePanel extends StatelessWidget {
  final String title;
  final String summary;
  final List<String> supportedFormats;
  final List<String> howToUse;
  final List<String> faqs;
  final List<String> tips;

  const ToolGuidancePanel({
    super.key,
    required this.title,
    required this.summary,
    required this.supportedFormats,
    required this.howToUse,
    required this.faqs,
    required this.tips,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE7F4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            summary,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF475569),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          _BulletGroup(title: 'Supported Formats', items: supportedFormats),
          const SizedBox(height: 12),
          _BulletGroup(title: 'How to Use', items: howToUse),
          const SizedBox(height: 12),
          _BulletGroup(title: 'FAQ', items: faqs),
          const SizedBox(height: 12),
          _BulletGroup(title: 'Best Practices & Tips', items: tips),
        ],
      ),
    );
  }
}

class _BulletGroup extends StatelessWidget {
  final String title;
  final List<String> items;

  const _BulletGroup({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 6),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Icon(Icons.circle, size: 6, color: Color(0xFF1F2937)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF475569),
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
