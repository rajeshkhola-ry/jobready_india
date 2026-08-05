import 'package:flutter/material.dart';

import '../Pages/ai_resume_builder_page.dart';
import '../Pages/plan_features_page.dart';
import '../Services/free_trial_service.dart';

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
    final canTryFree = !isEligible && !FreeTrialService.hasUsedFreeTrial(FreeTrialService.resumeBuilderTool);
    final message = isEligible
        ? '🔥 HOT FEATURE LIVE: Free AI Resume Builder, Cover Letter Generator & Company Insights now available for 1-Year & Lifetime Plan Users!'
        : canTryFree
            ? '🎁 New here? Get 1 FREE use of the AI Resume Builder — create your free account and try it now!'
            : 'Upgrade to a 1-Year or Lifetime plan to unlock the AI Resume Builder, Cover Letter Generator, and Company Insights.';
    final ctaLabel = isEligible ? 'Try Resume Builder Now' : canTryFree ? 'Try Free Once' : 'View Plans';

    void onTapAction() {
      if (isEligible || canTryFree) {
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
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF183A5B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '$message  '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: InkWell(
                      onTap: onTapAction,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                        child: Text(
                          '$ctaLabel →',
                          style: const TextStyle(
                            color: Color(0xFFFFD166),
                            fontWeight: FontWeight.w800,
                            decoration: TextDecoration.underline,
                            decorationColor: Color(0xFFFFD166),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
