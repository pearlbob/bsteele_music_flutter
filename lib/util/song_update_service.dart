import 'dart:async';

import 'package:bsteele_music_lib/app_logger.dart';
import 'package:bsteele_music_lib/songs/song.dart';
import 'package:bsteele_music_lib/songs/song_update.dart';
import 'package:bsteele_music_lib/util/uri_helper.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/screens/player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:web_socket_channel/status.dart' as web_socket_status;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../app/appOptions.dart';

const Level _log = Level.debug;
const Level _logMessage = Level.debug;
const Level _logJson = Level.debug;
const Level _logLeader = Level.debug;

class AppSongUpdateService extends ChangeNotifier {
  AppSongUpdateService.open(BuildContext context) {
    _singleton._open(context);
  }

  AppSongUpdateService.close() {
    _singleton._close();
  }

  static final AppSongUpdateService _singleton = AppSongUpdateService._internal();

  factory AppSongUpdateService() {
    return _singleton;
  }

  AppSongUpdateService._internal();

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
          _responseCount = 0;

          _webSocketChannel =
              WebSocketChannel.connect(uri); //  fixme: currently the package can throw an unhandled exception here!
          _webSocketSink = _webSocketChannel!.sink;
          notifyListeners();

          //  setup the song update service listening
          logger.log(_log, 'listen to: $_ipAddress, $uri');
          _subscription = _webSocketChannel!.stream.listen((message) {
            _responseCount++;
            if (_responseCount == 1) {
              notifyListeners(); //  notify on change of status
            }

            if (message is String) {
              if (message.startsWith(_timeRequest)) {
                //  time
                logger.i('time response: $message');
              } else {
                _songUpdate = SongUpdate.fromJson(message);
                if (_songUpdate != null) {
                  playerUpdate(context, _songUpdate!); //  fixme:  exposure to UI internals
                  _delayMilliseconds = 0;
                  _songUpdateCount++;
                  logger.log(
                      _logMessage,
                      'received: song: ${_songUpdate?.song.title}'
                      ' at moment: ${_songUpdate?.momentNumber}');
                }
              }
            }
          }, onError: (Object error) {
            logger.log(_log, 'webSocketChannel error: "$error" at "$uri"'); //  fixme: retry later
            _closeWebSocketChannel();
            appLogMessage('webSocketChannel error: $error at $uri');
          }, onDone: () {
            logger.log(_log, 'webSocketChannel onDone: at $uri');
            _closeWebSocketChannel();
            appLogMessage('webSocketChannel onDone: at $uri');
          });

          //  See if the server is there, that is, force a response that
          //  confirms the connection
          _issueTimeRequest();

          if (lastHost != _host) {
            notifyListeners();
          }
          lastHost = _host;

          if (_webSocketChannel != null) {
            for (_idleCount = 0;; _idleCount++) {
              //  idle
              await Future.delayed(const Duration(milliseconds: _idleMilliseconds));

              //  check connection status
              if (lastHost != _findTheHost()) {
                logger.log(_log, 'lastHost != _findTheHost(): "$lastHost" vs "${_findTheHost()}"');
                appLogMessage('webSocketChannel new host: $uri');
                _closeWebSocketChannel();
                _delayMilliseconds = 0;
                notifyListeners();
                break;
              }
              if (!_isOpen) {
                logger.log(_log, 'on close: $lastHost');
                _delayMilliseconds = 0;
                _idleCount = 0;
                notifyListeners();
                break;
              }
              if (isConnected != _wasConnected) {
                _wasConnected = isConnected;
                //  notify on first idle cycle
                notifyListeners();
              }
              logger.log(_log, 'webSocketChannel open: $_isOpen, idleCount: $_idleCount');
            }
          }
        } catch (e) {
          logger.log(_log, 'webSocketChannel exception: $e');
          _closeWebSocketChannel();
        }
      }

      if (_delayMilliseconds > 0) {
        //  wait a while
        if (_delayMilliseconds < maxDelayMilliseconds) {
          logger.log(_log, 'wait a while... before retrying websocket: $_delayMilliseconds ms');
        }
        await Future.delayed(Duration(milliseconds: _delayMilliseconds));
      }

      //  backoff bothering the server with repeated failures
      if (_delayMilliseconds < maxDelayMilliseconds) {
        _delayMilliseconds += _idleMilliseconds;
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
        //  there is never a websocket on the web!
        if (_lastNeverHost != host) {
          appLogMessage('webSocketChannel exception: never going to be at: "$host"');
          _lastNeverHost = host;
        }
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
      _responseCount = 0;
      _wasConnected = false;
      await _subscription?.cancel();
      _subscription = null;
      //fixme: make sticky across retries:   _isLeader = false;
      _songUpdateCount = 0;
      notifyListeners();
    }
  }

  static const _timeRequest = 't:';

  void _issueTimeRequest() {
    _webSocketSink?.add(_timeRequest);
    logger.t('_issueTimeRequest()');
  }

  void issueSongUpdate(SongUpdate songUpdate) {
    if (_isLeader) {
      songUpdate.setUser(_appOptions.user);
      var jsonText = songUpdate.toJson();
      _webSocketSink?.add(jsonText);
      logger.log(_logJson, jsonText);
      _songUpdateCount++;
      logger.log(_logLeader, "leader ${songUpdate.getUser()} issueSongUpdate #$_songUpdateCount: $songUpdate");
    }
  }

  bool get _isOpen => _webSocketChannel != null;

  bool get isConnected => _isOpen && _responseCount > 0;

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
      (_isLeader ? _appOptions.user : (_songUpdate != null ? _songUpdate!.user : Song.defaultUser));
  WebSocketChannel? _webSocketChannel;

  String get ipAddress => _ipAddress;
  String _ipAddress = '';

  String get host => _host;
  String _host = '';
  String? _lastNeverHost;
  static const String _port = ':8080';
  int _songUpdateCount = 0;
  int _idleCount = 0;
  int _responseCount = 0;
  WebSocketSink? _webSocketSink;
  static const int _idleMilliseconds = Duration.millisecondsPerSecond ~/ 2;
  static const int maxDelayMilliseconds = 3 * Duration.millisecondsPerSecond;

  static int get delayMilliseconds => _singleton._delayMilliseconds;
  var _delayMilliseconds = 0;
  StreamSubscription<dynamic>? _subscription;
  final AppOptions _appOptions = AppOptions();
}
