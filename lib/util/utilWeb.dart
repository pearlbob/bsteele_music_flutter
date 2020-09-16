// ignore: avoid_web_libraries_in_flutter
import 'dart:html';

import 'package:bsteele_music_flutter/util/utilWorkaround.dart';


/// Workaround to implement functionality that is not generic across all platforms at this point.
class UtilWeb implements UtilWorkaround {

  void writeFileContents(String fileName, String contents) {
    //   web stuff
    Blob blob = Blob([contents], 'text/plain', 'native');

    AnchorElement(
      href: Url.createObjectUrlFromBlob(blob).toString(),
    )
      ..setAttribute("download", fileName)
      ..click();
  }
}


UtilWorkaround getUtilWorkaround() => UtilWeb();
