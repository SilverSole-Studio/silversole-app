import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/shared/widgets/device_status_card.dart';
import 'package:silversole/shared/widgets/map_card.dart';
import 'package:silversole/shared/widgets/recent_data_chart_card.dart';
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {},
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Column(
              spacing: 16,
              children: [
                Row(
                  // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  spacing: 16,
                  children: [
                    CircleAvatar(
                      backgroundColor: cs.primaryContainer,
                      child: Icon(LucideIcons.user, color: cs.onPrimaryContainer),
                    ),
                    Text(
                      'SilverSole',
                      style: tt.titleLarge?.copyWith(
                        fontFamily: 'oxanium',
                        fontVariations: [FontVariation('wght', 700)],
                      ),
                    ),
                    Expanded(child: const SizedBox()),
                    IconButton(onPressed: comingSoon, icon: Icon(LucideIcons.bell)),
                  ],
                ),
                DeviceStatusCard(),
                MapCard(),
                WarningCard(),
                RecentDataChartCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
