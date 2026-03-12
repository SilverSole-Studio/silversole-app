import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> createFileAndShare({
  required String fileName,
  required String content,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsString(content);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path)],
      text: 'Exported File'
    )
  );
}