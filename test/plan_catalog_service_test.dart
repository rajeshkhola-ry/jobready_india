import 'package:flutter_test/flutter_test.dart';
import 'package:jobready_india/Services/plan_catalog_service.dart';

void main() {
  group('PlanCatalogConfig', () {
    test('includes HD Photo Studio as a registered tool and preserves it in serialization', () {
      final defaults = PlanCatalogConfig.defaults();
      expect(defaults.enabledToolsByPlan['Yearly'], contains('HD Photo Studio'));
      expect(defaults.enabledToolsByPlan['Lifetime'], contains('HD Photo Studio'));

      final roundTrip = PlanCatalogConfig.fromMap(defaults.toMap());
      expect(roundTrip.enabledToolsByPlan['Yearly'], contains('HD Photo Studio'));
      expect(roundTrip.enabledToolsByPlan['Lifetime'], contains('HD Photo Studio'));
    });

    test('exposes a shared registry of supported tools for admin toggles and matrix rows', () {
      final registeredTools = PlanCatalogConfig.registeredToolNames;
      expect(registeredTools, contains('HD Photo Studio'));
      expect(registeredTools, contains('OCR'));
      expect(registeredTools, isNotEmpty);
    });

    test('round-trips user quota values per plan through serialization', () {
      final defaults = PlanCatalogConfig.defaults();
      expect(defaults.userQuotasByPlan['Free'], '2');
      expect(defaults.userQuotasByPlan['Lifetime'], 'Unlimited');

      final custom = PlanCatalogConfig(
        inrPrices: defaults.inrPrices,
        usdPrices: defaults.usdPrices,
        enabledToolsByPlan: defaults.enabledToolsByPlan,
        userQuotasByPlan: {
          ...defaults.userQuotasByPlan,
          'Monthly': '500',
          'Yearly': 'Unlimited',
        },
      );

      final roundTrip = PlanCatalogConfig.fromMap(custom.toMap());
      expect(roundTrip.userQuotasByPlan['Monthly'], '500');
      expect(roundTrip.userQuotasByPlan['Yearly'], 'Unlimited');
    });
  });

  group('PlanCatalogService display pricing', () {
    test('shows the dashboard-friendly INR/USD pairing for the main paid plans', () {
      expect(PlanCatalogService.formatPlanPriceLine('7Days', currencyCode: 'USD'), '₹49 / \$0.99');
      expect(PlanCatalogService.formatPlanPriceLine('Monthly', currencyCode: 'USD'), '₹99 / \$1.99');
      expect(PlanCatalogService.formatPlanPriceLine('Yearly', currencyCode: 'USD'), '₹799 / \$14.99');
    });

    test('uses a single-currency line when INR is selected', () {
      expect(PlanCatalogService.formatPlanPriceLine('Monthly', currencyCode: 'INR'), '₹99');
    });
  });
}
