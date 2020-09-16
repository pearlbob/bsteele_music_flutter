import 'package:bsteeleMusicLib/appLogger.dart';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

void writeFileContents(String fileName, String contents) async {
  //  not web stuff
  final directory = await getApplicationDocumentsDirectory();
  String path = directory.path;
  logger.d('path: $path');

  File file = File('$path/$fileName');
  logger.d('file: $file');
  await file.writeAsString(contents, flush: true);
}
