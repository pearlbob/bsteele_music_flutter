import 'package:bsteele_music_lib/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../app/app.dart';

/*
_blank - specifies a new window
_self - specifies the current frame in the current window
_parent - specifies the parent of the current frame
_top - specifies the top-level frame in the current window
A custom target name of a window that exists
 */

const Level _logLink = Level.debug;

void openLink(String urlString) async {
  logger.log(_logLink, 'openLink("$urlString")');
  if (kIsWeb) {
    if (await canLaunchUrlString(urlString)) {
      await launchUrlString(urlString);
    } else {
      throw 'Could not launch $urlString';
    }
  } else if (!App().isPhone) {
    if (await canLaunchUrlString(urlString)) {
      launchUrlString(urlString);
    }
  } else {
    logger.i('openLink("$urlString") not available');
  }
}
