import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/shared/widgets/device_status_card.dart';
import 'package:silversole/shared/widgets/map_card.dart';
import 'package:silversole/shared/widgets/warning_card.dart';

import '../widgets/recent_data_list.dart';

class HomeBody extends ConsumerStatefulWidget {
  const HomeBody({super.key});

  @override
  ConsumerState<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends ConsumerState<HomeBody> {
  @override
  Widget build(BuildContext context) {
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
              spacing: 16,
              children: [
                SizedBox(height: 100, child: DeviceStatusCard()),
                MapCard(),
                GridView.count(
                  padding: EdgeInsets.zero,
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.9,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: const [WarningCard(), WarningCard()],
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
