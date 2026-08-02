import 'package:flutter/material.dart';

class WhyChooseCard extends StatelessWidget {
  final double scale;

  const WhyChooseCard({super.key, this.scale = 1.0});

  double _s(double value) => value * scale;

  Widget item(IconData icon, String title, String subtitle) {
    return Container(
      margin: EdgeInsets.only(bottom: _s(10)),
      padding: EdgeInsets.symmetric(horizontal: _s(13), vertical: _s(12)),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(_s(18)),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: _s(10),
            offset: Offset(0, _s(4)),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: _s(40),
            height: _s(40),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4CC),
              borderRadius: BorderRadius.circular(_s(14)),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFFFC72C),
              size: _s(20),
            ),
          ),
          SizedBox(width: _s(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: _s(15),
                    color: Color(0xFF1F2937),
                  ),
                ),
                SizedBox(height: _s(3)),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: _s(12),
                    height: 1.3,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(_s(24)),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF183A5B).withValues(alpha: 0.06),
            blurRadius: _s(18),
            offset: Offset(0, _s(8)),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(_s(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: _s(10), vertical: _s(5)),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(_s(999)),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Text(
                'TRUSTED EXPERIENCE',
                style: TextStyle(
                  fontSize: _s(10),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: Color(0xFF1F4E79),
                ),
              ),
            ),
            SizedBox(height: _s(12)),
            Text(
              'Why Choose GETREADYJOB?',
              style: TextStyle(
                fontSize: _s(18),
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937),
              ),
            ),
            SizedBox(height: _s(6)),
            Text(
              'Built for fast document work with a calmer interface, safer handling, and clearer results.',
              style: TextStyle(
                fontSize: _s(13.5),
                height: 1.4,
                color: Color(0xFF6B7280),
              ),
            ),
            SizedBox(height: _s(16)),
            Text(
              'Why these tools stand out',
              style: TextStyle(
                fontSize: _s(13),
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F4E79),
              ),
            ),
            SizedBox(height: _s(8)),
            Container(
              padding: EdgeInsets.all(_s(10)),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E6),
                borderRadius: BorderRadius.circular(_s(12)),
                border: Border.all(color: const Color(0xFFFFD166)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Resume Builder',
                    style: TextStyle(fontSize: _s(13), fontWeight: FontWeight.w800, color: Color(0xFF1F2937)),
                  ),
                  SizedBox(height: _s(3)),
                  Text(
                    'Create polished resumes with smart tailoring, cover letters, and interview prep support.',
                    style: TextStyle(fontSize: _s(12), height: 1.35, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            SizedBox(height: _s(8)),
            Container(
              padding: EdgeInsets.all(_s(10)),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(_s(12)),
                border: Border.all(color: const Color(0xFF93C5FD)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HD Photo Tool',
                    style: TextStyle(fontSize: _s(13), fontWeight: FontWeight.w800, color: Color(0xFF1F2937)),
                  ),
                  SizedBox(height: _s(3)),
                  Text(
                    'Enhance and restore photos with a clean, focused workflow for better visual output.',
                    style: TextStyle(fontSize: _s(12), height: 1.35, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            SizedBox(height: _s(16)),
            item(
              Icons.flash_on_rounded,
              'Lightning Fast Conversion',
              'Move from upload to output in a simple, low-friction flow.',
            ),
            item(
              Icons.security_rounded,
              '100% Secure Documents',
              'Your document actions stay focused on protected handling.',
            ),
            item(
              Icons.cloud_done_rounded,
              'Cloud Ready',
              'Designed for modern browser-based workflows and quick access.',
            ),
            item(
              Icons.workspace_premium_rounded,
              'Professional Quality Output',
              'Clean results, structured export steps, and better delivery polish.',
            ),
            item(
              Icons.support_agent_rounded,
              '24×7 Customer Support',
              'Clear support path through GETREADYJOB whenever users need help.',
            ),
          ],
        ),
      ),
    );
  }
}
