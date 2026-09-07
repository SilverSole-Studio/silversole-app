import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Release builds stay silent; debug keeps `[FBP] ...` errors, which is where
  // GATT status codes behind a dropped link show up. Raise to LogLevel.verbose
  // when tracing a connection problem.
  FlutterBluePlus.setLogLevel(kDebugMode ? LogLevel.error : LogLevel.none);
  await EasyLocalization.ensureInitialized();
  // Required before any DateFormat with an explicit locale (e.g. the zh_TW
  // weekday/month names on the home screen); without it intl throws
  // LocaleDataException at runtime.
  await initializeDateFormatting();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.env[Constants.supabaseUrlKey] ?? '',
    anonKey: dotenv.env[Constants.supabasePublicDefaultKey] ?? '',
  );
  // Desktop platforms (macOS) have no permission_handler implementation for
  // this channel; skip rather than crash before runApp.
  try {
    await Permission.locationWhenInUse.request();
  } on MissingPluginException {
    // No-op: permission not requestable on this platform.
  }
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(
    ProviderScope(
      child: EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('zh', 'TW')],
        path: 'assets/translations/strings.csv',
        assetLoader: CsvAssetLoader(),
        fallbackLocale: const Locale('en'),
        child: const App(),
      ),
    ),
  );
}
