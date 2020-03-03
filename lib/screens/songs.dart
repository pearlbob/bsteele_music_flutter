import 'dart:ui';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteele_music_flutter/util/screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Display the song moments in sequential order.
class Songs extends StatefulWidget {
  const Songs({Key key}) : super(key: key);

  @override
  _Songs createState() => _Songs();
}

class _Songs extends State<Songs> {
  @override
  initState() {
    super.initState();

    logger.d("_Songs.initState()");
  }

  @override
  Widget build(BuildContext context) {
    ScreenInfo screenInfo = ScreenInfo(context);
    final bool _isTooNarrow = screenInfo.isTooNarrow;

    const double defaultFontSize = 48;
    final double fontSize = defaultFontSize / (_isTooNarrow ? 2 : 1);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'bsteele Music App Songs',
          style: TextStyle(
              color: Colors.black87,
              fontSize: fontSize,
              fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Container(
        padding: EdgeInsets.all(36.0),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            textDirection: TextDirection.ltr,
            children: <Widget>[
              RaisedButton(
                child: Text(
                  'Read file',
                  style: TextStyle(
                      fontSize: fontSize, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  readFiles();
                },
              ),
            ]),
      ),
    );
  }

  readFiles() async {
    if (kIsWeb) {
      //  Web workaround
      //BSteeleMusicAppReader.filePick();
//      {
//       html.InputElement uploadInput = html.FileUploadInputElement();
//        //uploadInput.accept = '.songlyrics';  //  only accepts known types
//        uploadInput.multiple = true;
//        uploadInput.draggable = true;
//        uploadInput.onChange.listen((e) {
//          for (html.File file in uploadInput.files) {
//            if (file.name.endsWith('.songlyrics')) {
//              //logger.i('file: ${file.name}, ${file.toString()}, ${file.type}, ${file.runtimeType}');
//
//              final reader = html.FileReader();
//              reader.onLoadEnd.listen((e) {
//                Uint8List data = Base64Decoder().convert(reader.result.toString().split(",").last);
//                String s = utf8.decode(data);
//                //logger.i('onLoadEnd: $s');
//              });
//              reader.readAsDataUrl(file);
//            }
//          }
//        });
//        uploadInput.click();
//      }
    } else {
      Map<String, String> fileMap =
          await FilePicker.getMultiFilePath(fileExtension: '.songlyrics');
      for (String filename in fileMap.keys) {
        logger.i('file: $filename');
      }
    }
  }

//AppOptions _appOptions;
}
