import 'dart:async';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/songUpdate.dart';
import 'package:bsteele_music_flutter/screens/player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:universal_io/io.dart';
import 'package:web_socket_channel/status.dart' as web_socket_status;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../app/appOptions.dart';

const Level _log = Level.verbose;

class SongUpdateService extends ChangeNotifier {
  SongUpdateService.open(BuildContext context) {
    _singleton._open(context);
  }

  SongUpdateService.close() {
    _singleton._close();
  }

  static final SongUpdateService _singleton = SongUpdateService._internal();

  factory SongUpdateService() {
    return _singleton;
  }

  SongUpdateService._internal();

  void _open(BuildContext context) async {
    currentContext = context;
    if (_isRunning) {
      return;
    }
    _isRunning = true; //  start only once!

    var lastAuthority = '';

    while (_isRunning) //  retry on a failure
    {
      _closeWebSocketChannel();

      //  look back to the server to possibly find a websocket
      _authority = _findTheAuthority();
      _ipAddress = '';

      if (_authority.isEmpty) {
        // do nothing
      } else {
        //  assume that the authority is good, or at least worth trying
        var url = 'ws://$_authority$_port/bsteeleMusicApp/bsteeleMusic';
        logger.log(_log, 'trying: $url');

        try {
          //  or re-try
          Uri uri = Uri.parse(url);
          _webSocketChannel = WebSocketChannel.connect(uri);

          //  lookup the ip address
          try {
            await InternetAddress.lookup(uri.host, type: InternetAddressType.IPv4).then((value) async {
              for (var element in value) {
                _ipAddress = element.address; //  just the first one will do

                break;
              }
            });
          } catch (e) {
            _ipAddress = ''; //  fixme: UnimplementedError
          }
          notifyListeners();

          _webSocketSink = _webSocketChannel!.sink;

          _subscription = _webSocketChannel!.stream.listen((message) {
            _songUpdate = SongUpdate.fromJson(message as String);
            if (_songUpdate != null) {
              // logger.d('received: ${songUpdate.song.title} at moment: ${songUpdate.momentNumber}');
              playerUpdate(context, _songUpdate!); //  fixme:  exposure to UI internals
              _delaySeconds = 0;
              _songUpdateCount++;
            }
          }, onError: (Object error) {
            logger.log(_log, 'webSocketChannel error: $error at $_authority'); //  fixme: retry later
            _closeWebSocketChannel();
          }, onDone: () {
            logger.log(_log, 'webSocketChannel onDone: at $_authority');
            _closeWebSocketChannel();
          });

          if (lastAuthority != _authority) {
            notifyListeners();
          }
          lastAuthority = _authority;

          for (_idleCount = 0;; _idleCount++) {
            await Future.delayed(const Duration(seconds: kIsWeb ? 5 : 1));
            if (kIsWeb) {
              notifyListeners();
            }

            if (lastAuthority != _findTheAuthority()) {
              logger.log(_log, 'lastAuthority != _findTheAuthority(): $lastAuthority vs ${_findTheAuthority()}');
              _closeWebSocketChannel();
              _delaySeconds = 0;
              notifyListeners();
              break;
            }
            if (!_isOpen) {
              logger.log(_log, 'on close: $lastAuthority');
              _delaySeconds = 0;
              notifyListeners();
              break;
            }
            if (_idleCount == 0) {
              //  notify on first idle cycle
              notifyListeners();
            }
            logger.log(_log, 'webSocketChannel idle: $_isOpen, count: $_idleCount');
          }
        } catch (e) {
          logger.log(_log, 'webSocketChannel exception: ${e.toString()}');
          _closeWebSocketChannel();
          notifyListeners();
        }
      }

      if (_delaySeconds > 0) {
        //  wait a while
        if (_delaySeconds < maxDelaySeconds) {
          logger.log(_log, 'wait a while... before retrying websocket: $_delaySeconds s');
        }
        await Future.delayed(Duration(seconds: _delaySeconds));
      }

      //  backoff bothering the server with repeated failures
      if (_delaySeconds < maxDelaySeconds) {
        _delaySeconds++;
      }
    }
  }

  void _close() {
    _isRunning = false;
  }

  String _findTheAuthority() {
    var authority = '';
    if (_appOptions.websocketHost.isNotEmpty) {
      authority = _appOptions.websocketHost;
    } else if (kIsWeb && Uri.base.scheme == 'http') {
      authority = Uri.base.authority;
      if (authority.contains('bsteele.com') || (kDebugMode && authority.contains('localhost'))) {
        //  there is never a websocket on the web
        logger.log(_log, 'webSocketChannel exception: never going to be at: "$_authority"');
        //  do nothing
        authority = '';
      }
    }
    logger.log(_log, 'authority: \'$authority\'');
    return authority;
  }

  void _closeWebSocketChannel() async {
    if (_webSocketSink != null) {
      _webSocketSink = null;
      _webSocketChannel?.sink.close(web_socket_status.normalClosure);
      _webSocketChannel = null;
      _idleCount = 0;
      await _subscription?.cancel();
      _subscription = null;
      //fixme: make sticky across retries:   _isLeader = false;
      _songUpdateCount = 0;
      notifyListeners();
    }
  }

  void issueSongUpdate(SongUpdate songUpdate) {
    if (_isLeader) {
      songUpdate.setUser(_appOptions.user);
      _webSocketSink?.add(songUpdate.toJson());
      _songUpdateCount++;
      logger.v("leader ${songUpdate.getUser()} issueSongUpdate #$_songUpdateCount: $songUpdate");
    }
  }

  bool get _isOpen => _webSocketChannel != null;

  bool get isConnected =>
      _isOpen && _idleCount > 0 //  fixme: needs connection confirmation from server without a song update
      ;

  bool get isIdle => authority.isEmpty;

  set isLeader(bool value) {
    if (value == _isLeader) {
      return;
    }
    _isLeader = value;
    notifyListeners();
  }

  bool _isRunning = false;
  BuildContext? currentContext;

  bool get isFollowing => !_isLeader && !isIdle && isConnected;

  bool get isLeader => isConnected && _isLeader;
  bool _isLeader = false;

  SongUpdate? _songUpdate;

  String get leaderName =>
      (_isLeader ? _appOptions.user : (_songUpdate != null ? _songUpdate!.user : AppOptions.unknownUser));
  WebSocketChannel? _webSocketChannel;

  String get ipAddress => _ipAddress;
  String _ipAddress = '';

  String get authority => _authority;
  String _authority = '';
  static const String _port = ':8080';
  int _songUpdateCount = 0;
  int _idleCount = 0;
  WebSocketSink? _webSocketSink;
  static const int maxDelaySeconds = 10;

  static int get delaySeconds => _singleton._delaySeconds;
  var _delaySeconds = 0;
  StreamSubscription<dynamic>? _subscription;
  final AppOptions _appOptions = AppOptions();
}
