import 'dart:async';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/songUpdate.dart';
import 'package:bsteele_music_flutter/screens/player.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/status.dart' as web_socket_status;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../app/appOptions.dart';

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
      _authority = _findTheAuthority();

      if (_authority.isEmpty) {
        // do nothing
      } else if (_authority.contains('bsteele.com')) {
        //  there is never a websocket on the web
        logger.i('webSocketChannel exception: never going to be at: "$_authority"');
        //  do nothing
      } else {
        //  assume that the authority is good, or at least worth trying
        var url = 'ws://$_authority$_port/bsteeleMusicApp/bsteeleMusic';
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
              _songUpdateCount++;
            }
          }, onError: (Object error) {
            logger.d('webSocketChannel error: $error at $_authority'); //  fixme: retry later
            _closeWebSocketChannel();
          }, onDone: () {
            logger.d('webSocketChannel onDone: at $_authority');
            _closeWebSocketChannel();
          });

          notifyListeners();
          var lastAuthority = _authority;
          for (_idleCount = 0;; _idleCount++) {
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
      }

      if (delaySeconds > 0) {
        //  wait a while
        logger.i('wait a while... before retrying websocket: $delaySeconds s');
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
      authority = _appOptions.websocketHost;
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
    _songUpdateCount = 0;
    notifyListeners();
  }

  void issueSongUpdate(SongUpdate songUpdate) {
    if (_isLeader) {
      songUpdate.setUser(_appOptions.user);
      _webSocketSink?.add(songUpdate.toJson());
      _songUpdateCount++;
      logger.v("leader " + songUpdate.getUser() + " issueSongUpdate #$_songUpdateCount: " + songUpdate.toString());
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

  bool get isLeader => _isLeader;
  bool _isLeader = false;

  SongUpdate? _songUpdate;

  String get leaderName =>
      (_isLeader ? _appOptions.user : (_songUpdate != null ? _songUpdate!.user : AppOptions.unknownUser));
  WebSocketChannel? _webSocketChannel;

  String get authority => _authority;
  String _authority = '';
  static const String _port = ':8080';
  int _songUpdateCount = 0;
  int _idleCount = 0;
  WebSocketSink? _webSocketSink;
  StreamSubscription<dynamic>? _subscription;
  final AppOptions _appOptions = AppOptions();
}
