import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bsteele_music_lib/app_logger.dart';
import 'package:bsteele_music_lib/songs/chord_pro.dart';
import 'package:bsteele_music_lib/songs/song.dart';
import 'package:bsteele_music_lib/songs/song_metadata.dart';
import 'package:bsteele_music_flutter/util/utilWorkaround.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'dart:js_interop';
import 'package:web/web.dart';

/// Workaround to implement functionality that is not generic across all platforms at this point.
class UtilWeb implements UtilWorkaround {
  /// Workaround to implement functionality that is not generic across all platforms at this point.
  @override
  Future<String> writeFileContents(String fileName, String contents, {String? fileType}) async {
    //   web stuff write
    final blob = Blob(
      // JSArray<JSAny> is required here.
      [Uint8List.fromList(utf8.encode(contents)).toJS].toJS,
      BlobPropertyBag(type: 'text/plain'),
    );

    final url = URL.createObjectURL(blob);

    final anchor = HTMLAnchorElement()
      ..href = url
      ..download = fileName;

    document.body?.append(anchor);
    anchor.click();
    anchor.remove();

    URL.revokeObjectURL(url);

    return 'The file was written into your browser\'s download folder named: \'$fileName\'';
  }

  @override
  Future<List<Song>> songFilePick(BuildContext context) async {
    return await getSongsAsync();
  }

  Future<List<Song>> getSongsAsync() async {
    List<NameValue> fileData = await _getFiles('songlyrics');
    logger.d("files.length: ${fileData.length}");
    List<Song> ret = [];
    for (var nameValue in fileData) {
      String s = nameValue.value;
      //logger.d('data: ${s.substring(0, min(200, s.length))}');
      if (chordProRegExp.hasMatch(nameValue.name)) {
        //  chordpro encoded songs
        ret.add(ChordPro().parse(s));
      } else {
        //  .songlyrics
        List<Song> addSongs = Song.songListFromJson(s);
        for (final Song song in addSongs) {
          logger.d('add: ${song.toString()}');
          ret.add(song);
        }
      }
    }
    return ret;
  }

  Future<List<NameValue>> _getFiles(final String? accept) async {
    var allowedExtensions = accept == null ? null : [accept.startsWith('.') ? accept.substring(1) : accept];
    logger.i('file accept: "$accept"');
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );

    List<NameValue> ret = [];
    if (result != null) {
      for (PlatformFile file in result.files) {
        logger.i('file name: ${file.name}, path: "${file.path}"');
        logger.i('   size: "${file.size}"');
        String contents = utf8.decode(file.bytes?.toList() ?? []);
        logger.i('   toString(): $contents');
        ret.add(NameValue(file.name, contents));
      }
    } else {
      // User canceled the picker
    }

    return ret;
  }

  @override
  Future<List<NameValue>> textFilePickAndRead(BuildContext context) async {
    List<NameValue> fileData = await _getFiles(null);
    logger.d("files.length: ${fileData.length}");
    List<NameValue> ret = [];
    for (var nameValue in fileData) {
      ret.add(NameValue(nameValue.name, nameValue.value));
    }
    return ret;
  }

  FileList? files;
  final RegExp chordProRegExp = RegExp(r'pro$');

  /// extensions should include the dot separator
  @override
  Future<String> filePickByExtension(BuildContext context, String extension) async {
    for (NameValue nameValue in await _getFiles(extension)) {
      return nameValue.value;
    }
    return '';
  }
}

UtilWorkaround getUtilWorkaround() => UtilWeb();
