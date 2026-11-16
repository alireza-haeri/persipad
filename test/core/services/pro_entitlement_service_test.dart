import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/services/pro_entitlement_service.dart';

void main() {
  group('ProEntitlementService.resolvePro', () {
    test('unlocking everything wins over a missing purchase', () {
      expect(
        ProEntitlementService.resolvePro(
          unlockAll: true,
          hasActivePurchase: false,
          hasLegacyPurchase: false,
        ),
        isTrue,
      );
    });

    test('a real purchase still counts when the unlock switch is off', () {
      expect(
        ProEntitlementService.resolvePro(
          unlockAll: false,
          hasActivePurchase: true,
          hasLegacyPurchase: false,
        ),
        isTrue,
      );
    });

    test('legacy purchases still count when the unlock switch is off', () {
      expect(
        ProEntitlementService.resolvePro(
          unlockAll: false,
          hasActivePurchase: false,
          hasLegacyPurchase: true,
        ),
        isTrue,
      );
    });

    test('a locked build without any purchase stays locked', () {
      expect(
        ProEntitlementService.resolvePro(
          unlockAll: false,
          hasActivePurchase: false,
          hasLegacyPurchase: false,
        ),
        isFalse,
      );
    });
  });

  group('ProEntitlementService.showUpsell', () {
    test('nothing to sell when every feature is unlocked', () {
      expect(
        ProEntitlementService.showUpsell(unlockAll: true, storeAvailable: true),
        isFalse,
      );
    });

    test('nothing to sell when the store is unavailable (e.g. Linux)', () {
      expect(
        ProEntitlementService.showUpsell(unlockAll: false, storeAvailable: false),
        isFalse,
      );
    });

    test('upsell shows only when selling is possible and something is locked', () {
      expect(
        ProEntitlementService.showUpsell(unlockAll: false, storeAvailable: true),
        isTrue,
      );
    });
  });

  group('this fork', () {
    test('ships fully unlocked so no feature requires a purchase we cannot sell', () {
      expect(ProEntitlementService.unlockAll, isTrue);
    });

    test('hides every upsell surface as a consequence', () {
      for (final storeAvailable in [true, false]) {
        expect(
          ProEntitlementService.showUpsell(
            unlockAll: ProEntitlementService.unlockAll,
            storeAvailable: storeAvailable,
          ),
          isFalse,
        );
      }
    });
  });
}
