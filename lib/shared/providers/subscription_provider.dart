import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/data/save_service.dart';

/// Monthly price shown on the subscription page (NT\$).
const kSubscriptionMonthlyPrice = 149;

/// Whether this account has an active subscription.
///
/// There is no billing yet (user 2026-11-01: 「先做 APP 畫面但不接金流」):
/// the only way to turn it on is the test switch on the subscription page,
/// shown in debug builds and developer mode. It is stored on this phone
/// only. When Google Play Billing / StoreKit is wired up, replace [build]
/// with the store's entitlement and drop [setFake].
class SubscriptionNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final raw = await loadLocalValue(LocalSavableKey.fakeSubscription);
    if (raw == 'true') state = true;
  }

  /// Test-only switch (debug / developer mode).
  Future<void> setFake(bool on) async {
    await saveLocalValue(LocalSavableKey.fakeSubscription, on ? 'true' : 'false');
    state = on;
  }
}

final subscriptionActiveProvider = NotifierProvider<SubscriptionNotifier, bool>(
  SubscriptionNotifier.new,
);
