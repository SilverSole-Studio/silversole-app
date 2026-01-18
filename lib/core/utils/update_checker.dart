import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:silversole/core/utils/utils_function.dart';
import 'package:silversole/shared/models/update_info_model.dart';

import '../error/result.dart';


const String apiUrl = 'https://api.github.com';
const String apiPath = '/repos/andongni0723/silversole-app/releases/latest';


final dio = Dio(
  BaseOptions(
    baseUrl: apiUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  )
);

bool isUpdateAvailable(String currentVersion, String latestVersion) {
  var current = currentVersion.trim().removePrefix("v");
  var latest = latestVersion.trim().removePrefix("v");
  debugPrint('[UpdateCheck] current=$current latest=$latest');
  debugPrint('[UpdateCheck] result: ${compareVersion(current, latest) < 0}');
  return compareVersion(current, latest) < 0;
}


/// Fetch github.com to get latest release tag.
///
/// Return a version name and a change log.
Future<Result<UpdateInfo>> fetchLatestReleaseTag() async {
  try {
    // Fetch latest release
    var res = await dio.get(apiPath);
    if (res.statusCode != 200) {
      return Result.error(HttpException('Error ${res.statusCode}: Get latest release failed. Try again later.'));
    }
    // Decode detail
    var body = res.data as Map<String, dynamic>;
    final tag = body['tag_name'] as String?;
    final notes = (body['body'] as String?) ?? '';
    final assets = (body['assets'] as List).cast<Map<String, dynamic>>();
    final name = assets.isNotEmpty ? (assets[0]['name'] as String?) : null;
    final size = assets.isNotEmpty ? (assets[0]['size'] as num?)?.toInt() : null;

    if (tag == null || name == null || size == null) {
      return const Result.error(HttpException('Missing tag_name/body in response'));
    }
    debugPrint('[UpdateCheck] tag=$tag notes=$notes');
    return Result.ok(UpdateInfo(tag, notes, name, size));
  } on SocketException catch (_) {
    return Result.error(Exception('Get latest release failed. No internet connection.'));
  } on TimeoutException catch (_) {
    return Result.error(Exception('Get latest release failed. Request timeout.'));
  } on Exception catch (e) {
    return Result.error(e);
  }
}