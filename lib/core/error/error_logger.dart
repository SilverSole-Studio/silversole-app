import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:silversole/app.dart';

void showErrorSnakeBar(String message) {
  debugPrint('[App Error Logger] $message');
  App.scaffoldMessengerKey.currentState?.showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      backgroundColor: Colors.redAccent,
    ),
  );
}

void showMessage(String message) {
  App.scaffoldMessengerKey.currentState?.showSnackBar(
    SnackBar(
      content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
      duration: Duration(seconds: 1),
    ),
  );
}

void comingSoon() {
  App.scaffoldMessengerKey.currentState?.showSnackBar(
    SnackBar(
      content: Text('coming_soon'.tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
      duration: Duration(seconds: 1),
    ),
  );
}
