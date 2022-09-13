import 'dart:async';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/songUpdate.dart';
import 'package:bsteeleMusicLib/util/uri_helper.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/screens/player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:universal_io/io.dart';
import 'package:web_socket_channel/status.dart' as web_socket_status;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../app/appOptions.dart';

const Level _log = Level.debug;
const Level _logMessage = Level.debug;
const Level _logJson = Level.debug;

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

    var lastHost = '';

    while (_isRunning) //  retry on a failure
    {
      _closeWebSocketChannel();

      //  look back to the server to possibly find a websocket
      _host = _findTheHost();
      _ipAddress = '';

      if (_host.isEmpty) {
        // do nothing
        logger.log(_log, 'webSocket: empty host');
      } else {
        //  assume that the authority is good, or at least worth trying
        var url = 'ws://$_host$_port/bsteeleMusicApp/bsteeleMusic';
        logger.log(_log, 'trying: $url');
        appLogMessage('webSocket try host: "$host"');

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
              logger.log(
                  _logMessage,
                  'received: song: ${_songUpdate?.song.title}'
                  ' at moment: ${_songUpdate?.momentNumber}');
              playerUpdate(context, _songUpdate!); //  fixme:  exposure to UI internals
              _delaySeconds = 0;
              _songUpdateCount++;
            }
          }, onError: (Object error) {
            logger.log(_log, 'webSocketChannel error: $error at $uri'); //  fixme: retry later
            _closeWebSocketChannel();
            appLogMessage('webSocketChannel error: $error at $uri');
          }, onDone: () {
            logger.log(_log, 'webSocketChannel onDone: at $uri');
            _closeWebSocketChannel();
            appLogMessage('webSocketChannel onDone: at $uri');
          });

          if (lastHost != _host) {
            notifyListeners();
          }
          lastHost = _host;

          for (_idleCount = 0;; _idleCount++) {
            //  idle
            await Future.delayed(const Duration(seconds: 1));

            //  check connection status
            if (lastHost != _findTheHost()) {
              logger.log(_log, 'lastHost != _findTheHost(): "$lastHost" vs "${_findTheHost()}"');
              appLogMessage('webSocketChannel new host: $uri');
              _closeWebSocketChannel();
              _delaySeconds = 0;
              notifyListeners();
              break;
            }
            if (!_isOpen) {
              logger.log(_log, 'on close: $lastHost');
              _delaySeconds = 0;
              notifyListeners();
              break;
            }
            if (isConnected != _wasConnected) {
              _wasConnected = isConnected;
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

  String _findTheHost() {
    var host = '';
    if (_appOptions.websocketHost.isNotEmpty) {
      host = _appOptions.websocketHost;
      if (_appOptions.websocketHost == AppOptions.idleHost) {
        host = ''; //  never a real host
      }
    } else if (kIsWeb && Uri.base.scheme == 'http') {
      host = Uri.base.authority;
      if (host.contains('bsteele.com') || (kDebugMode && host.contains('localhost'))) {
        //  there is never a websocket on the web
        appLogMessage('webSocketChannel exception: never going to be at: "$host"');
        //  do nothing
        host = '';
      } else {
        //  clean host errors
        var uri = extractUri(host);
        host = uri?.host ?? '';
      }
    }

    return host;
  }

  void _closeWebSocketChannel() async {
    if (_webSocketSink != null) {
      _webSocketSink = null;
      _webSocketChannel?.sink.close(web_socket_status.normalClosure);
      _webSocketChannel = null;
      _idleCount = 0;
      _wasConnected = false;
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
      var jsonText = songUpdate.toJson();
      _webSocketSink?.add(jsonText);
      logger.log(_logJson, jsonText);
      _songUpdateCount++;
      logger.v("leader ${songUpdate.getUser()} issueSongUpdate #$_songUpdateCount: $songUpdate");
    }
  }

  bool get _isOpen => _webSocketChannel != null;

  bool get isConnected =>
      _isOpen && _idleCount > 1 //  fixme: needs connection confirmation from server without a song update
      ;

  bool _wasConnected = false;

  bool get isIdle => host.isEmpty;

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

  String get host => _host;
  String _host = '';
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
