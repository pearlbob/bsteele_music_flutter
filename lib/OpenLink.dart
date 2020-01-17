import 'package:url_launcher/url_launcher.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart';

/*
_blank - specifies a new window
_self - specifies the current frame in the current window
_parent - specifies the parent of the current frame
_top - specifies the top-level frame in the current window
A custom target name of a window that exists
 */

void openLink(String url) async {
  if(kIsWeb) {
    html.window.open(url, '_blank');
  } else {
    if(await canLaunch(url)) {
      launch(url);
    }
  }
}