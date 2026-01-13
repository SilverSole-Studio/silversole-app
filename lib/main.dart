import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.env[Constants.supabaseUrlKey] ?? '',
    anonKey: dotenv.env[Constants.supabasePublicDefaultKey] ?? '',
  );
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('zh', 'TW')],
      path: 'assets/translations/strings.csv',
      assetLoader: CsvAssetLoader(),
      fallbackLocale: const Locale('en'),
      child: const App(),
    ),
  );
}
