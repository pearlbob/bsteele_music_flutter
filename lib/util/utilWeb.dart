// ignore: avoid_web_libraries_in_flutter
import 'dart:html';

void writeFileContents(String fileName, String contents) {
  //   web stuff
  Blob blob = Blob([contents], 'text/plain', 'native');

  AnchorElement(
    href: Url.createObjectUrlFromBlob(blob).toString(),
  )
    ..setAttribute("download", fileName)
    ..click();
}
