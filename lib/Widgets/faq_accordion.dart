import 'package:flutter/material.dart';

/// A single FAQ question/answer pair. Keep this text in sync with the
/// matching `faq` entry in `web/index.html`'s routeSeo array so the visible
/// page content matches the FAQPage JSON-LD structured data for that route.
class FaqItem {
  const FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;
}

/// Compact expandable FAQ section used on tool pages.
class FaqAccordion extends StatelessWidget {
  const FaqAccordion({
    super.key,
    required this.items,
    this.title = 'Frequently Asked Questions',
    this.accentColor = const Color(0xFF1A2B45),
  });

  final List<FaqItem> items;
  final String title;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE6F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_rounded, color: accentColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Column(
              children: items
                  .map(
                    (item) => ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 12),
                      title: Text(
                        item.question,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            item.answer,
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
