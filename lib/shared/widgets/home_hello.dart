import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/shared/providers/auth_provider.dart';

/// The date line and the greeting every 「今天」 page opens with, e.g.
/// 「11月4日　週三」 and 「午安，王阿姨」. Both come from the clock and the
/// account, so they are real: the account only gives an email, so its local
/// part stands in as the name until a real profile name exists.
({String date, String hello}) homeHello(BuildContext context, WidgetRef ref) {
  final user = ref.watch(authUserProvider);
  final now = DateTime.now();
  final locale = context.locale.toString();
  final key = now.hour < 12
      ? 'greeting_morning'
      : now.hour < 18
      ? 'greeting_afternoon'
      : 'greeting_evening';
  final name = user?.email.split('@').first ?? 'silversole'.tr();
  return (
    date:
        '${DateFormat.MMMd(locale).format(now)}　'
        '${DateFormat.E(locale).format(now)}',
    hello: '${key.tr()}，$name',
  );
}
