import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';

class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key});

  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {
  Widget notActiveBody() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final safePadding = MediaQuery.paddingOf(context).vertical;
    final bodyHeight = (screenHeight - safePadding - 220).clamp(220.0, screenHeight);
    return SizedBox(
      height: bodyHeight,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 16,
          children: [
            SvgPicture.asset('assets/images/undraw_coming-soon_7lvi.svg', width: 300),
            const SizedBox(height: 32),
            Text('coming_soon'.tr(), style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text(
              'coming_soon_content'.tr(),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('analytics'.tr(), style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {},
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: notActiveBody(),
          ),
        ),
      ),
    );
  }
}
