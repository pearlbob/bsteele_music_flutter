import 'dart:async';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/songUpdate.dart';
import 'package:bsteele_music_flutter/screens/player.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/status.dart' as web_socket_status;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../appOptions.dart';

class SongUpdateService extends ChangeNotifier {
  SongUpdateService.open(BuildContext context) {
    _singleton.open(context);
  }

  static final SongUpdateService _singleton = SongUpdateService._internal();

  factory SongUpdateService() {
    return _singleton;
  }

  SongUpdateService._internal();

  void open(BuildContext context) async {
    var delaySeconds = 0;

    for (;;) //  retry on a failure
    {
      _closeWebSocketChannel();

      //  look back to the server to possibly find a websocket
      var authority = _findTheAuthority();

      //  there is never a websocket on the web
      if (authority.contains('bsteele.com')) {
        logger.i('webSocketChannel exception: never going to be at: $authority');
        return;
      }

      var url = 'ws://$authority/bsteeleMusicApp/bsteeleMusic';
      logger.i('trying: $url');

      try {
        //  or re-try
        _webSocketChannel = WebSocketChannel.connect(Uri.parse(url));

        _webSocketSink = _webSocketChannel!.sink;

        _subscription = _webSocketChannel!.stream.listen((message) {
          _songUpdate = SongUpdate.fromJson(message as String);
          if (_songUpdate != null) {
            // print('received: ${songUpdate.song.title} at moment: ${songUpdate.momentNumber}');
            playerUpdate(context, _songUpdate!); //  fixme:  exposure to UI internals
            delaySeconds = 0;
            songUpdateCount++;
          }
        }, onError: (Object error) {
          logger.d('webSocketChannel error: $error at $authority'); //  fixme: retry later
          _closeWebSocketChannel();
        }, onDone: () {
          logger.d('webSocketChannel onDone: at $authority');
          _closeWebSocketChannel();
        });

        notifyListeners();
        var lastAuthority = authority;
        for ( _idleCount = 0;; _idleCount++) {
          await Future.delayed(const Duration(seconds: 5));
          notifyListeners();

          if (lastAuthority != _findTheAuthority()) {
            logger.d('lastAuthority != _findTheAuthority(): $lastAuthority vs ${_findTheAuthority()}');
            _closeWebSocketChannel();
            delaySeconds = 0;
            break;
          }
          if (!_isOpen) {
            logger.d('on close: $lastAuthority');
            delaySeconds = 0;
            break;
          }
          logger.v('webSocketChannel idle: $_isOpen, count: $_idleCount');
        }
      } catch (e) {
        logger.i('webSocketChannel exception: ${e.toString()}');
        _closeWebSocketChannel();
      }

      if (delaySeconds > 0) {
        //  wait a while
        logger.i('wait a while!... before closing');
        await Future.delayed(Duration(seconds: delaySeconds));
      }

      //  backoff bothering the server with repeated failures
      if (delaySeconds < 60) {
        delaySeconds += 5;
      }
    }
  }

  String _findTheAuthority() {
    var authority = '';
    if (_appOptions.websocketHost.isNotEmpty) {
      authority = _appOptions.websocketHost + ':8080';
    } else if (kIsWeb && Uri.base.scheme == 'http') {
      authority = Uri.base.authority;
    }
    return authority;
  }

  void _closeWebSocketChannel() async {
    _webSocketSink = null;
    _webSocketChannel?.sink.close(web_socket_status.normalClosure);
    _webSocketChannel = null;
    await _subscription?.cancel();
    _subscription = null;
    //fixme: make sticky across retries:   _isLeader = false;
    songUpdateCount = 0;
    notifyListeners();
  }

  void issueSongUpdate(SongUpdate songUpdate) {
    if (_isLeader) {
      songUpdate.setUser(_appOptions.user);
      _webSocketSink?.add(songUpdate.toJson());
      songUpdateCount++;
      logger.v("leader " + songUpdate.getUser() + " issueSongUpdate: " + songUpdate.toString());
    }
  }

  bool get _isOpen => _webSocketChannel != null;

  bool get isConnected =>
      _isOpen && _idleCount > 0 //  fixme: needs connection confirmation from server without a song update
      ;

  set isLeader(bool value) {
    if (value == _isLeader) {
      return;
    }
    _isLeader = value;
    notifyListeners();
  }

  SongUpdate? _songUpdate;

  bool get isLeader => _isLeader;
  bool _isLeader = false;

  String get leaderName => (_isLeader ? _appOptions.user : (_songUpdate != null ? _songUpdate!.user : 'unknown'));
  WebSocketChannel? _webSocketChannel;
  int songUpdateCount = 0;
  int _idleCount = 0;
  WebSocketSink? _webSocketSink;
  StreamSubscription<dynamic>? _subscription;
  final AppOptions _appOptions = AppOptions();
}
