import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:silversole/constants.dart';

/// Answers a game page's `getUserMedia` request — the H5 games' camera mode
/// (`engine/camera_input.js`, opened with `?cam=1`), for wearers without soles.
///
/// Only the camera, and only for the game site ([Constants.gameUrl]'s origin):
/// a request for anything else (the microphone, motion sensors) or from any
/// other page is denied without asking. A camera request first asks the
/// wearer for the system permission; turning it down denies the page too, and
/// the game falls back to its on-screen buttons.
///
/// [gameBase] and [askCamera] exist for tests.
Future<PermissionResponse> answerGamePermission(
  PermissionRequest request, {
  String? gameBase,
  Future<bool> Function()? askCamera,
}) async {
  final base = Uri.parse(gameBase ?? Constants.gameUrl);
  final granted =
      isGameCameraRequest(request, base) && await (askCamera ?? _askCamera)();
  return PermissionResponse(
    resources: request.resources,
    action: granted
        ? PermissionResponseAction.GRANT
        : PermissionResponseAction.DENY,
  );
}

/// Whether [request] asks for the camera alone, from [gameBase]'s origin.
bool isGameCameraRequest(PermissionRequest request, Uri gameBase) {
  final resources = request.resources;
  if (resources.isEmpty) return false;
  if (resources.any((r) => r != PermissionResourceType.CAMERA)) return false;
  final origin = request.origin;
  return origin.scheme == gameBase.scheme &&
      origin.host == gameBase.host &&
      origin.port == gameBase.port;
}

Future<bool> _askCamera() async =>
    (await Permission.camera.request()).isGranted;
