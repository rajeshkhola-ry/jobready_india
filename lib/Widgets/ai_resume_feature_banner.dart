import 'package:flutter/material.dart';

import '../Pages/ai_resume_builder_page.dart';
import '../Pages/plan_features_page.dart';

class AiResumeFeatureBanner extends StatelessWidget {
  final String activePlan;

  const AiResumeFeatureBanner({required this.activePlan, super.key});

  bool _isEligiblePlan(String plan) {
    final normalized = plan.trim().toLowerCase();
    return normalized.contains('year') || normalized.contains('lifetime');
  }

  @override
  Widget build(BuildContext context) {
    final isEligible = _isEligiblePlan(activePlan);
    final message = isEligible
        ? '🔥 HOT FEATURE LIVE: Free AI Resume Builder, Cover Letter Generator & Company Insights now available for 1-Year & Lifetime Plan Users!'
        : 'Upgrade to a 1-Year or Lifetime plan to unlock the AI Resume Builder, Cover Letter Generator, and Company Insights.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF1F4E79), Color(0xFFFFC72C)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              if (isEligible) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AiResumeBuilderPage()),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PlanFeaturesPage()),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              backgroundColor: Colors.black.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: Text(isEligible ? 'Try Resume Builder Now' : 'View Plans'),
          ),
        ],
      ),
    );
  }
}
