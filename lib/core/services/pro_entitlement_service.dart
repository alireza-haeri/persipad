/// Decides whether a Pro feature is usable and whether the store UI is worth
/// showing at all.
///
/// Our fork sells nothing: there is no store listing, no RevenueCat project of
/// our own, and on Linux the store plugin has no implementation anyway. Keeping
/// every Pro feature locked behind a purchase that can't happen would make the
/// app feel broken, so the whole feature set is unlocked here — through a single
/// switch, not by deleting the gating call sites, so this stays reversible.
///
/// Kept dependency-free (no Flutter imports) so the rules are unit-testable.
class ProEntitlementService {
  const ProEntitlementService._();

  /// Master switch for this fork: `true` means every Pro feature is free.
  static const bool unlockAll = true;

  /// Whether [ProEntitlementService] considers the user a Pro user.
  ///
  /// [unlockAll] short-circuits everything: a fork that gives the features away
  /// should not depend on a store receipt to render its own UI.
  /// [hasActivePurchase] / [hasLegacyPurchase] are the real store entitlements
  /// and keep working when [unlockAll] is turned off again.
  static bool resolvePro({
    required bool unlockAll,
    required bool hasActivePurchase,
    required bool hasLegacyPurchase,
  }) {
    return unlockAll || hasActivePurchase || hasLegacyPurchase;
  }

  /// Whether purchase/upsell surfaces (paywall entries, Pro badges, banners)
  /// should be rendered.
  ///
  /// Two independent reasons to hide them: everything is already unlocked, or
  /// the platform can't complete a purchase (Linux). Either way the user would
  /// be staring at a button that leads nowhere.
  static bool showUpsell({
    required bool unlockAll,
    required bool storeAvailable,
  }) {
    return storeAvailable && !unlockAll;
  }
}
