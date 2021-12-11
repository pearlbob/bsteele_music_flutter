import 'dart:core';

import 'package:bsteeleMusicLib/songs/songMetadata.dart';
import 'package:bsteele_music_flutter/util/utilStub.dart'
// ignore: uri_does_not_exist
    if (dart.library.io) 'package:bsteele_music_flutter/util/utilLinux.dart'
// ignore: uri_does_not_exist
    if (dart.library.html) 'package:bsteele_music_flutter/util/utilWeb.dart';
import 'package:flutter/widgets.dart';

abstract class UtilWorkaround {
  /// Workaround to implement functionality that is not generic across all platforms at this point.
  Future<String> writeFileContents(String fileName, String contents, {String? fileType});

  Future<void> songFilePick(BuildContext context);

  Future<String> filePickByExtension(BuildContext context, String extension);

  Future<List<NameValue>> textFilePickAndRead(BuildContext context);

  /// factory constructor to return the correct implementation.
  factory UtilWorkaround() => getUtilWorkaround();
}
