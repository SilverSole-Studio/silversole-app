import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:silversole/app.dart';

void showErrorSnakeBar(BuildContext context, String message) {
  debugPrint('[App Error Logger] $message');
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

void comingSoon() {
  App.scaffoldMessengerKey.currentState?.showSnackBar(
    SnackBar(content: Text('coming_soon'.tr())),
  );
}
