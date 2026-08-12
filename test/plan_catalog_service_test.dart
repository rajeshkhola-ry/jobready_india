import 'package:flutter_test/flutter_test.dart';
import 'package:jobready_india/Services/plan_catalog_service.dart';

void main() {
  group('Unified plan catalog', () {
    test('exposes the shared free, starter, and pro plan IDs with correct pricing', () {
      final defaults = PlanCatalogConfig.defaults();

      expect(defaults.inrPrices['free'], 0.0);
      expect(defaults.inrPrices['starter_99'], 99.0);
      expect(defaults.inrPrices['pro_299'], 299.0);
      expect(defaults.usdPrices['free'], 0.0);
      expect(defaults.usdPrices['starter_99'], 99.0);
      expect(defaults.usdPrices['pro_299'], 299.0);
    });

    test('maps the unified plan IDs to the correct voice and access settings', () {
      final freePlan = PlanService.resolvePlan('free');
      final starterPlan = PlanService.resolvePlan('starter_99');
      final proPlan = PlanService.resolvePlan('pro_299');

      expect(freePlan.planId, 'free');
      expect(freePlan.planName, 'Free / Trial');
      expect(freePlan.voiceMinutesRemaining, 5);
      expect(freePlan.toolsUnlimited, false);

      expect(starterPlan.planId, 'starter_99');
      expect(starterPlan.planName, 'Starter Plan');
      expect(starterPlan.voiceMinutesRemaining, 60);
      expect(starterPlan.toolsUnlimited, true);

      expect(proPlan.planId, 'pro_299');
      expect(proPlan.planName, 'Pro Unlimited');
      expect(proPlan.voiceMinutesRemaining, 500);
      expect(proPlan.toolsUnlimited, true);
    });

    test('formats the new plan pricing strings consistently for INR and USD', () {
      expect(PlanCatalogService.formatPlanPriceLine('starter_99', currencyCode: 'INR'), '₹99');
      expect(PlanCatalogService.formatPlanPriceLine('pro_299', currencyCode: 'INR'), '₹299');
      expect(PlanCatalogService.formatPlanPriceLine('starter_99', currencyCode: 'USD'), '\$99');
      expect(PlanCatalogService.formatPlanPriceLine('pro_299', currencyCode: 'USD'), '\$299');
    });

    test('provides guided access cards and an active-pass check for the voice tools', () {
      final guides = PlanService.getToolUsageGuides();

      expect(guides.length, 4);
      expect(guides.first.title, 'AI Voice Translator');
      expect(guides.first.steps.length, 3);
      expect(PlanService.hasActiveToolAccess(planId: 'Free'), isFalse);
      expect(PlanService.hasActiveToolAccess(planId: 'Monthly'), isTrue);
      expect(PlanService.hasActiveToolAccess(planId: 'starter_99'), isTrue);
    });
  });
}
