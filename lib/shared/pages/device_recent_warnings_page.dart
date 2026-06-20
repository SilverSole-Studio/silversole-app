import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';

class DeviceRecentWarningsPage extends ConsumerStatefulWidget {
  const DeviceRecentWarningsPage({super.key});

  @override
  ConsumerState<DeviceRecentWarningsPage> createState() =>
      _DeviceRecentWarningsPageState();
}

class _DeviceRecentWarningsPageState
    extends ConsumerState<DeviceRecentWarningsPage> {
  Widget hintBindingPage() {
    final tt = context.textTheme;
    final colorScheme = context.colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: AppSpacing.base,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(
              LucideIcons.link2,
              color: colorScheme.onPrimaryContainer,
              size: 28,
            ),
          ),
          Text('not_binding'.tr(), style: tt.titleLarge),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'device_recent_warnings'.tr(),
          style: context.textTheme.titleLarge,
        ),
      ),
    );
  }
}
