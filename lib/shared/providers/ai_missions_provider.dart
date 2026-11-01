import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/constants.dart';
import 'package:silversole/core/data/save_service.dart';
import 'package:silversole/core/missions/ai_mission_client.dart';

/// Whether the daily missions may use Claude at all: [Constants.aiMissions],
/// off in debug builds too. With it off nothing about AI shows and the server
/// is never called.
final aiMissionsEnabledProvider = Provider<bool>((ref) => Constants.aiMissions);

/// The wearer's answer to "may the app send my numbers to have the missions
/// written?". [unset] until they have answered once.
enum AiMissionsConsent {
  unset,
  yes,
  no;

  /// [unset] for nothing or anything this app did not write.
  static AiMissionsConsent decode(String? raw) =>
      AiMissionsConsent.values.asNameMap()[raw] ?? unset;
}

/// The saved [AiMissionsConsent]. Loaded from the phone; a stored value that
/// cannot be read counts as unset, so the wearer is asked again rather than
/// assumed to have agreed.
class AiMissionsConsentNotifier extends AsyncNotifier<AiMissionsConsent> {
  @override
  Future<AiMissionsConsent> build() async {
    try {
      return AiMissionsConsent.decode(
        await loadLocalValue(LocalSavableKey.aiMissionsConsent),
      );
    } catch (_) {
      return AiMissionsConsent.unset;
    }
  }

  /// Takes effect at once; when the phone cannot save it, it holds for this
  /// run only and the wearer is asked again next time.
  Future<void> set(AiMissionsConsent value) async {
    state = AsyncData(value);
    try {
      await saveLocalValue(LocalSavableKey.aiMissionsConsent, value.name);
    } catch (_) {
      // Kept in memory only.
    }
  }
}

final aiMissionsConsentProvider =
    AsyncNotifierProvider<AiMissionsConsentNotifier, AiMissionsConsent>(
      AiMissionsConsentNotifier.new,
    );

/// The client the plan asks. Replaced by a fake in tests.
final aiMissionClientProvider = Provider<AiMissionClient>(
  (ref) => const SupabaseAiMissionClient(),
);
