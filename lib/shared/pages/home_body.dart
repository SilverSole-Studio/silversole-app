import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:silversole/shared/models/user_identity.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/widgets/account_card.dart';

import '../widgets/recent_data_list.dart';

class HomeBody extends ConsumerStatefulWidget {
  const HomeBody({super.key});

  @override
  ConsumerState<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends ConsumerState<HomeBody> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final deviceNickName = settings.deviceId != null ? 'Test SilverSole Device' : 'not_binding'.tr(); //FIXME: Test code
    final deviceId = settings.deviceId ?? '-';
    final identity = settings.identity;
    final active = identity == UserIdentity.transmitter.value ? settings.deviceId != null : null; //FIXME: Test code

    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          title: Text(
            'silversole'.tr(),
            style: TextStyle(fontFamily: 'Oxanium', fontVariations: const [FontVariation('wght', 600)]),
          ),
          pinned: true,
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          sliver: SliverToBoxAdapter(
            child: Column(
              spacing: 32,
              children: [
                SizedBox(
                  height: 100,
                  child: statusCard(
                    context,
                    title: deviceNickName,
                    subtitle: deviceId,
                    icon: LucideIcons.footprints,
                    active: active,
                  ),
                ),
                RecentDataList(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
