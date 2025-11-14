import 'dart:async';

import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/audio/app_audio_player.dart';
import 'package:bsteele_music_flutter/main.dart';
import 'package:bsteele_music_flutter/util/song_update_service.dart';
import 'package:bsteele_music_lib/app_logger.dart';
import 'package:bsteele_music_lib/songs/bass.dart';
import 'package:bsteele_music_lib/songs/chord.dart';
import 'package:bsteele_music_lib/songs/chord_anticipation_or_delay.dart';
import 'package:bsteele_music_lib/songs/chord_descriptor.dart';
import 'package:bsteele_music_lib/songs/pitch.dart';
import 'package:bsteele_music_lib/songs/scale_chord.dart';
import 'package:bsteele_music_lib/songs/song_base.dart';
import 'package:bsteele_music_lib/util/util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../app/app.dart';
import '../app/appOptions.dart';

//  diagnostic logging enables
const Level _optionLogAudio = Level.debug;
const Level _logBuild = Level.debug;
const Level _logUserNameEntry = Level.debug;

/// A screen to display controls for the user to manage some of the app's options.
class Options extends StatefulWidget {
  const Options({super.key});

  @override
  OptionsState createState() => OptionsState();

  static const String routeName = 'options';
}

class OptionsState extends State<Options> {
  @override
  initState() {
    super.initState();

    _userTextEditingController.text = _appOptions.user;
    _userTextEditingController.addListener(() {
      if (_userTextEditingController.text.isNotEmpty) {
        _appOptions.user = _userTextEditingController.text;
      }
    });

    _websocketHostEditingController.text = _appOptions.websocketHost == AppOptions.idleHost
        ? ''
        : _appOptions.websocketHost;

    _songUpdateService.addListener(_songUpdateServiceCallback);
  }

  void _songUpdateServiceCallback() {
    setState(() {
      _ipAddress = _songUpdateService.ipAddress;
    });
  }

  @override
  Widget build(BuildContext context) {
    appWidgetHelper = AppWidgetHelper(context);
    app.screenInfo.refresh(context);

    logger.log(_logBuild, 'options build: ${_songUpdateService.isConnected}');
    var style = generateAppTextStyle();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: appWidgetHelper.backBar(title: 'bsteeleMusicApp Options'),
      body: DefaultTextStyle(
        //  fixme: necessary?
        style: style,
        child: SingleChildScrollView(
          //  for phones when horizontal
          child: Container(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: .start,
              crossAxisAlignment: .start,
              textDirection: TextDirection.ltr,
              children: <Widget>[
                if (utilWorkaround.fullscreenEnabled)
                  Row(
                    children: <Widget>[
                      appButton(
                        'Enter fullscreen',
                        onPressed: () {
                          utilWorkaround.requestFullscreen();
                        },
                      ),
                    ],
                  ),

                const AppSpace(),
                //  User name
                Row(
                  crossAxisAlignment: .baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.only(right: 24, bottom: 24.0),
                      child: const Text('User name: '),
                    ),
                    AppTextField(
                      controller: _userTextEditingController,
                      hintText: 'Enter your user name.',
                      width: (style.fontSize ?? appDefaultFontSize) * 30,
                      maxLines: 1,
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          logger.log(_logUserNameEntry, 'user name onChanged: $value');
                          setState(() {
                            _appOptions.user = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
                const AppSpace(),
                // Leader/Follower Server Address
                Row(
                  crossAxisAlignment: .baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.only(right: 24),
                      child: const Text('Leader/Follower Server Address: '),
                    ),
                  ],
                ),
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.only(left: 30, right: 24),
                      child: const AppTooltip(
                        message: 'Manually add the server host IP address.',
                        child: Text('Host IP: '),
                      ),
                    ),
                    SizedBox(
                      width: app.screenInfo.mediaWidth / 3,
                      child: AppTooltip(
                        message: 'Manually add the server host IP address.',
                        child: AppTextField(
                          controller: _websocketHostEditingController,
                          hintText: 'address here',
                          onChanged: (value) {
                            _appOptions.websocketHost = value;
                          },
                        ),
                      ),
                    ),
                    const AppSpace(),
                    Text(
                      _ipAddress.isEmpty || _ipAddress == _websocketHostEditingController.text
                          ? ''
                          : 'Address found: $_ipAddress',
                      style: style,
                    ),
                  ],
                ),
                const AppSpace(),
                AppWrapFullWidth(
                  spacing: 15,
                  children: [
                    Container(
                      padding: const EdgeInsets.only(left: 30),
                      child: const AppTooltip(
                        message: 'These buttons allow easy configuration of known server hosts.',
                        child: Text('Known Hosts:'),
                      ),
                    ),
                    AppTooltip(
                      message: 'No leader/follower',
                      child: appButton(
                        'None',
                        onPressed: () {
                          _appOptions.websocketHost = AppOptions.idleHost;
                          _websocketHostEditingController.text = '';
                        },
                      ),
                    ),
                    AppTooltip(
                      message: 'You are in the Community Jams studio.',
                      child: appButton(
                        'Studio',
                        onPressed: () {
                          _appOptions.websocketHost = 'cj.local';
                          _websocketHostEditingController.text = _appOptions.websocketHost;
                        },
                      ),
                    ),
                    AppTooltip(
                      message: 'You are in the park.',
                      child: appButton(
                        'Park',
                        onPressed: () {
                          _appOptions.websocketHost = parkFixedIpAddress;
                          _websocketHostEditingController.text = _appOptions.websocketHost;
                        },
                      ),
                    ),
                    AppTooltip(
                      message: 'You have a local raspberry pi from bob.',
                      child: appButton(
                        'Bob\'s pi',
                        onPressed: () {
                          _appOptions.websocketHost = 'bobspi.local';
                          _websocketHostEditingController.text = _appOptions.websocketHost;
                        },
                      ),
                    ),
                    if (hostIsWebsocketHost)
                      AppTooltip(
                        message:
                            'Your web server should have a leader/follower connection.'
                            '\nClick here to use it.',
                        child: appButton(
                          'This host',
                          onPressed: () {
                            _appOptions.websocketHost = host;
                            _websocketHostEditingController.text = _appOptions.websocketHost;
                          },
                        ),
                      ),
                    if (kDebugMode)
                      appButton(
                        'bob\'s place',
                        onPressed: () {
                          _appOptions.websocketHost = 'bob'; //'bobspi.local';
                          _websocketHostEditingController.text = _appOptions.websocketHost;
                        },
                      ),
                  ],
                ),
                const AppSpace(),
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.only(left: 30),
                      child: const AppTooltip(
                        message:
                            'You want to be idle if you have no leader/follower,\n'
                            'Otherwise you need to be connected.',
                        child: Text('Status: '),
                      ),
                    ),
                    Text(
                      (_songUpdateService.isConnected
                          ? 'Connected'
                          : (_songUpdateService.isIdle ? 'Idle' : 'Retrying ${_songUpdateService.host}')),
                      style: generateAppTextStyle(
                        fontWeight: .bold,
                        backgroundColor: _songUpdateService.isConnected || _songUpdateService.isIdle
                            ? Colors.green
                            : Colors.red[300],
                      ),
                    ),
                    const AppSpace(),
                    if (_songUpdateService.isConnected)
                      AppTooltip(
                        message: _songUpdateService.isLeader
                            ? 'Abdicate your leadership if you no longer want to be group leader.'
                            : 'Only become a leader if you want to lead your followers through a song.',
                        child: appButton(
                          _songUpdateService.isLeader ? 'Abdicate my leadership' : 'Make me the leader',
                          onPressed: () {
                            setState(() {
                              if (_songUpdateService.isConnected) {
                                _songUpdateService.isLeader = !_songUpdateService.isLeader;
                              }
                            });
                          },
                        ),
                      ),
                  ],
                ),
                const AppSpace(verticalSpace: 30),
                AppWrapFullWidth(
                  spacing: 15,
                  children: [
                    const Text('Accidental Notes:'),
                    SegmentedButton<AccidentalExpressionChoice>(
                      selectedIcon: appIcon(Icons.check),
                      segments: <ButtonSegment<AccidentalExpressionChoice>>[
                        ButtonSegment<AccidentalExpressionChoice>(
                          value: .byKey,
                          label: Text('By Key', style: buttonTextStyle()),
                          tooltip: _appOptions.toolTips
                              ? 'When required, accidentals notes are expressed as a sharp or flat\n'
                                    'based on the song\'s key.'
                              : null,
                        ),
                        ButtonSegment<AccidentalExpressionChoice>(
                          value: .easyRead,
                          label: Text('Easy Read', style: buttonTextStyle()),
                          tooltip: _appOptions.toolTips
                              ? 'When required, accidental notes are expressed as an easy to read expression.\n'
                                    'For example, A♯ will always be expressed as B♭'
                              : null,
                        ),
                      ],
                      selected: <AccidentalExpressionChoice>{_appOptions.accidentalExpressionChoice},
                      onSelectionChanged: (Set<AccidentalExpressionChoice> newSelection) {
                        setState(() {
                          // By default there is only a single segment that can be
                          // selected at one time, so its value is always the first
                          // item in the selected set.
                          _appOptions.accidentalExpressionChoice = newSelection.first;
                        });
                      },
                    ),
                  ],
                ),

                //  Nashville beats
                const AppSpace(verticalSpace: 30),
                AppWrapFullWidth(
                  spacing: 15,
                  children: [
                    const Text('Nashville beats:'),
                    SegmentedButton<bool>(
                      selectedIcon: appIcon(Icons.check),
                      segments: <ButtonSegment<bool>>[
                        ButtonSegment<bool>(
                          value: true,
                          label: Text('Reduced', style: buttonTextStyle()),
                          tooltip: _appOptions.toolTips
                              ? 'Show Nashville style beats only when they are absolutely required.\n'
                                    'This will not happen if the measure is full length.\n'
                                    'Typically the period convention will be used.'
                              : null,
                        ),
                        ButtonSegment<bool>(
                          value: false,
                          label: Text('Always', style: buttonTextStyle()),
                          tooltip: _appOptions.toolTips
                              ? 'Show Nashville style beats any time the beats are not a full measure.'
                              : null,
                        ),
                      ],
                      selected: <bool>{_appOptions.reducedNashvilleDots},
                      onSelectionChanged: (Set<bool> newSelection) {
                        setState(() {
                          // By default there is only a single segment that can be
                          // selected at one time, so its value is always the first
                          // item in the selected set.
                          _appOptions.reducedNashvilleDots = newSelection.first;
                        });
                      },
                    ),
                  ],
                ),

                //  Simplified Chords
                const AppSpace(verticalSpace: 30),
                AppWrapFullWidth(
                  spacing: 15,
                  children: [
                    const Text('Simplified Chords:'),
                    SegmentedButton<bool>(
                      selectedIcon: appIcon(Icons.check),
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith((states) {
                          return _appOptions.simplifiedChords ? Colors.red : null;
                        }),
                      ),
                      segments: <ButtonSegment<bool>>[
                        ButtonSegment<bool>(
                          value: true,
                          label: Text('Simplified', style: buttonTextStyle()),
                          tooltip: _appOptions.toolTips
                              ? 'Show chords in simplified form.\n'
                                    'These will be an approximation of the original chords\n'
                                    'to help beginners as they play.'
                              : null,
                        ),
                        ButtonSegment<bool>(
                          value: false,
                          label: Text('Original', style: buttonTextStyle()),
                          tooltip: _appOptions.toolTips
                              ? 'Show chords in a simplified form or in their full complexity.'
                              : null,
                        ),
                      ],
                      selected: <bool>{_appOptions.simplifiedChords},
                      onSelectionChanged: (Set<bool> newSelection) {
                        setState(() {
                          // By default there is only a single segment that can be
                          // selected at one time, so its value is always the first
                          // item in the selected set.
                          _appOptions.simplifiedChords = newSelection.first;
                        });
                      },
                    ),
                  ],
                ),

                const AppSpace(verticalSpace: 30),
                AppWrap(
                  children: [
                    AppTooltip(
                      message: 'Enable Tooltips',
                      child: appButton(
                        'Tooltips',

                        onPressed: () {
                          setState(() {
                            _appOptions.toolTips = !_appOptions.toolTips;
                          });
                        },
                        // softWrap: false,
                      ),
                    ),
                    appSwitch(
                      value: _appOptions.toolTips,
                      onChanged: (value) {
                        setState(() {
                          _appOptions.toolTips = value;
                        });
                      },
                    ),
                  ],
                ),
                const AppSpace(),
                AppWrap(
                  alignment: WrapAlignment.start,
                  children: [
                    const Text('Player Clicks:'),
                    const AppSpace(),
                    AppTooltip(
                      message:
                          'On the player screen:\n\n'
                          'Never: never advance the section on a click or tap\n'
                          'Up or down: Tap on the bottom half of the screen to advance a section.\n'
                          '     Tap on the top half to go back a section.\n'
                          'Always down: advance the section on any click or tap, anywhere',
                      child: DropdownButton<TapToAdvance>(
                        items: TapToAdvance.values.toList().map((TapToAdvance value) {
                          return DropdownMenuItem<TapToAdvance>(
                            key: ValueKey(value.name),
                            value: value,
                            child: Text(Util.firstToUpper(Util.camelCaseToLowercaseSpace(value.name)), style: style),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null && value != _appOptions.tapToAdvance) {
                            setState(() {
                              _appOptions.tapToAdvance = value;
                            });
                          }
                        },
                        value: _appOptions.tapToAdvance,
                        style: generateAppTextStyle(color: Colors.black, textBaseline: TextBaseline.ideographic),
                        itemHeight: null,
                      ),
                    ),
                    // appSwitch(
                    //   appKeyEnum: AppKeyEnum.optionsTapToAdvance,
                    //   value: _appOptions.tapToAdvance,
                    //   onChanged: (value) {
                    //     setState(() {
                    //       _appOptions.tapToAdvance = !_appOptions.tapToAdvance;
                    //     });
                    //   },
                    // ),
                  ],
                ),

                //  UserDisplayStyle
                AppWrapFullWidth(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: viewportWidth(0.5),
                  children: [
                    RadioGroup<UserDisplayStyle>(
                      groupValue: _appOptions.userDisplayStyle,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _appOptions.userDisplayStyle = value;
                            switch (value) {
                              case .highContrast:
                                _appOptions.playerScrollHighlight = PlayerScrollHighlight.off;
                                _appOptions.simplifiedChords = true;
                                _appOptions.accidentalExpressionChoice = .easyRead;
                                break;
                              default:
                                _appOptions.simplifiedChords = false;
                                _appOptions.accidentalExpressionChoice = .byKey;
                                break;
                            }
                          });
                        }
                      },
                      child: Row(
                        children: [
                          AppTooltip(
                            message: 'Select the display style for the song.',
                            child: Text(
                              'Display style: ',
                              //  style: boldStyle,
                            ),
                          ),
                          //       //  pro player
                          //       AppWrap(children: [
                          //         Radio<UserDisplayStyle>(
                          //           value: .proPlayer,
                          //           groupValue: _appOptions.userDisplayStyle,
                          //           onChanged: (value) {
                          //             setState(() {
                          //               if (value != null) {
                          //                 _appOptions.userDisplayStyle = value;
                          //                 _adjustDisplay();
                          //               }
                          //             });
                          //           },
                          //         ),
                          //         AppTooltip(
                          //           message: 'Display the song using the professional player style.\n'
                          //               'This condenses the song chords to a minimum presentation without lyrics.',
                          //           child: appTextButton(
                          //             'Pro',
                          //             appKeyEnum: AppKeyEnum.optionsUserDisplayStyle,
                          //             value: .proPlayer,
                          //             onPressed: () {
                          //               setState(() {
                          //                 _appOptions.userDisplayStyle = .proPlayer;
                          //                 _adjustDisplay();
                          //               });
                          //             },
                          //             style: popupStyle,
                          //           ),
                          //         ),
                          //       ]),
                          //       //  player
                          //       AppWrap(children: [
                          //         Radio<UserDisplayStyle>(
                          //           value: .player,
                          //           groupValue: _appOptions.userDisplayStyle,
                          //           onChanged: (value) {
                          //             setState(() {
                          //               if (value != null) {
                          //                 _appOptions.userDisplayStyle = value;
                          //                 _adjustDisplay();
                          //               }
                          //             });
                          //           },
                          //         ),
                          //         AppTooltip(
                          //           message: 'Display the song using the player style.\n'
                          //               'This favors the chords over the lyrics,\n'
                          //               'to the point that the lyrics maybe clipped.',
                          //           child: appTextButton(
                          //             'Player',
                          //             appKeyEnum: AppKeyEnum.optionsUserDisplayStyle,
                          //             value: .player,
                          //             onPressed: () {
                          //               setState(() {
                          //                 _appOptions.userDisplayStyle = .player;
                          //                 _adjustDisplay();
                          //               });
                          //             },
                          //             style: popupStyle,
                          //           ),
                          //         ),
                          //       ]),
                          //  both
                          //  high contrast
                          Flexible(
                            child: RadioListTile<UserDisplayStyle>(
                              title: Text('Both Player and Singer', style: style),
                              value: .both,
                            ),
                          ),
                          Flexible(
                            child: RadioListTile<UserDisplayStyle>(
                              title: Text(
                                'High Contrast',
                                style: style.copyWith(
                                  color: Colors.white,
                                  backgroundColor: Colors.black,
                                  fontSize: (style.fontSize ?? appDefaultFontSize) * 2,
                                ),
                              ),
                              value: .highContrast,
                            ),
                          ),
                        ],
                      ),
                    ),
                    //       //  singer
                    //       AppWrap(children: [
                    //         Radio<UserDisplayStyle>(
                    //           value: .singer,
                    //           groupValue: _appOptions.userDisplayStyle,
                    //           onChanged: (value) {
                    //             setState(() {
                    //               if (value != null) {
                    //                 _appOptions.userDisplayStyle = value;
                    //                 _adjustDisplay();
                    //               }
                    //             });
                    //           },
                    //         ),
                    //         AppTooltip(
                    //           message: 'Display the song showing all the lyrics.\n'
                    //               'The display of chords is minimized.',
                    //           child: appTextButton(
                    //             'Singer',
                    //             appKeyEnum: AppKeyEnum.optionsUserDisplayStyle,
                    //             value: .singer,
                    //             onPressed: () {
                    //               setState(() {
                    //                 _appOptions.userDisplayStyle = .singer;
                    //                 _adjustDisplay();
                    //               });
                    //             },
                    //             style: style,
                    //           ),
                    //         ),
                    //       ]),
                    //       //  banner
                    //       // AppWrap(children: [
                    //       //   Radio<UserDisplayStyle>(
                    //       //     value: .banner,
                    //       //     groupValue: _appOptions.userDisplayStyle,
                    //       //     onChanged: (value) {
                    //       //       setState(() {
                    //       //         if (value != null) {
                    //       //           _appOptions.userDisplayStyle = value;
                    //       //           adjustDisplay();
                    //       //         }
                    //       //       });
                    //       //     },
                    //       //   ),
                    //       //   AppTooltip(
                    //       //     message: 'Display the song in banner (piano scroll) mode.',
                    //       //     child: appTextButton(
                    //       //       'Banner',
                    //       //       appKeyEnum: AppKeyEnum.optionsUserDisplayStyle,
                    //       //       value: .banner,
                    //       //       onPressed: () {
                    //       //         setState(() {
                    //       //           _appOptions.userDisplayStyle = .banner;
                    //       //           adjustDisplay();
                    //       //         });
                    //       //       },
                    //       //       style: style,
                    //       //     ),
                    //       //   ),
                    //       // ]),
                    //     ]),
                  ],
                ),

                //  fixme: audio!
                if (kDebugMode) const AppSpace(verticalSpace: 30),
                if (kDebugMode)
                  Row(
                    children: <Widget>[
                      appWidgetHelper.checkbox(
                        value: _appOptions.playWithChords,
                        onChanged: (value) {
                          setState(() {
                            _appOptions.playWithChords = value ?? false;
                          });
                        },
                      ),
                      const Text(
                        'Playback with chords',
                        //    style: AppTextStyle(fontSize: fontSize),
                      ),
                    ],
                  ),
                if (kDebugMode)
                  Row(
                    children: <Widget>[
                      appWidgetHelper.checkbox(
                        value: _appOptions.playWithBass,
                        onChanged: (value) {
                          setState(() {
                            _appOptions.playWithBass = value ?? true;
                          });
                        },
                      ),
                      const Text(
                        'Playback with bass',
                        //   style: AppTextStyle(fontSize: fontSize),
                      ),
                    ],
                  ),
                if (kDebugMode)
                  Row(
                    children: <Widget>[
                      const Text(
                        'audio test: ',
                        //   style: AppTextStyle(fontSize: fontSize),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _stop();
                          });
                        },
                        child: Icon(Icons.stop, size: app.screenInfo.fontSize * 2),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _audioTest();
                          });
                        },
                        child: Icon(Icons.play_arrow, size: app.screenInfo.fontSize * 2),
                      ),
                    ],
                  ),
                if (kDebugMode)
                  Row(
                    children: <Widget>[
                      appWidgetHelper.checkbox(
                        value: _appOptions.debug,
                        onChanged: (value) {
                          _appOptions.debug = value;
                          Logger.level = _appOptions.debug ? Level.debug : Level.info;
                          setState(() {});
                        },
                      ),
                      const Text('debug'),
                    ],
                  ),
                const AppSpace(verticalSpace: 30),
                Row(
                  children: <Widget>[
                    appButton(
                      'Clear all local stored options',
                      onPressed: () {
                        setState(() {
                          _appOptions.clear();
                        });
                      },
                      // softWrap: false,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: appWidgetHelper.floatingBack(),
    );
  }

  @override
  void dispose() {
    _songUpdateService.removeListener(_songUpdateServiceCallback);
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    //_audioPlayer.stop();
  }

  void _audioTest() async {
    _timer?.cancel();

    _test = 0;
    const int bpm = 50;
    const double timerPeriod = 60 / bpm;

    const int microsecondsPerSecond = 1000000;
    int periodMs = (microsecondsPerSecond * timerPeriod).round();
    logger.log(_optionLogAudio, 'periodMs: ${periodMs.toString()}');
    logger.log(_optionLogAudio, 'timerPeriod: ${timerPeriod.toString()}, _testType: $_testType');
    _timerT = _audioPlayer.getCurrentTime() + 2;
    _testType = 'bass';
    const double gap = 0.25;
    _timer = Timer.periodic(Duration(microseconds: periodMs), (timer) {
      try {
        logger.log(_optionLogAudio, '_audioTest() $_testNumber.$_test');
        switch (_testNumber) {
          case 0:
            switch (_testType) {
              case 'bass':
                if (_test > 39) {
                  _testType = 'guitar';
                  _test = 0;
                }
                break;
              case 'guitar':
                if (_test > 30) {
                  _timer?.cancel();
                  _timer = null;
                }
                break;
            }

            _audioPlayer.play('audio/${_testType}_$_test.mp3', when: _timerT, duration: timerPeriod - gap, volume: 1.0);
            _test++;
            break;
          case 1:
            if (_test > 20) {
              _timer?.cancel();
              _timer = null;
            }

            //  guitar and bass
            _audioPlayer.play('audio/bass_$_test.mp3', when: _timerT, duration: timerPeriod - gap, volume: 1.0 / 4);
            _audioPlayer.play('audio/guitar_$_test.mp3', when: _timerT, duration: timerPeriod - gap, volume: 1.0 / 4);
            _audioPlayer.play(
              'audio/guitar_${_test + 4 /*half steps to major 3rd*/}.mp3',
              when: _timerT,
              duration: timerPeriod - gap,
              volume: 1.0 / 4,
            );
            _audioPlayer.play(
              'audio/guitar_${_test + 7 /*half steps to 5th*/}.mp3',
              when: _timerT,
              duration: timerPeriod - gap,
              volume: 1.0 / 4,
            );

            _test++;
            break;
          case 2:
            if (_test >= _pitches.length) {
              _timer?.cancel();
              _timer = null;
            }

            _audioPlayer.oscillate(_pitches[_test].frequency, when: _timerT, duration: timerPeriod - gap, volume: 1.0);
            _test++;
            break;
          case 3:
            if (_test < 12) _test = 3 * 12;
            if (_test >= _pitches.length - 3 * 12) {
              _timer?.cancel();
              _timer = null;
            }

            ChordDescriptor chordDescriptor = ChordDescriptor.minor;
            Pitch refPitch = _pitches[_test];

            //  guitar and bass
            _audioPlayer.play(
              'audio/bass_${Bass.mapPitchToBassFret(refPitch)}.mp3',
              when: _timerT,
              duration: timerPeriod - gap,
              volume: 1.0 / 8,
            );

            //  piano chord
            Chord chord = Chord(
              ScaleChord(refPitch.getScaleNote(), chordDescriptor),
              4,
              4,
              null,
              ChordAnticipationOrDelay.defaultValue,
              false,
            );
            List<Pitch> pitches = chord.getPitches(_atOrAbove);
            double duration = timerPeriod - gap;
            double amp = 1.0 / (pitches.length + 2);
            for (final Pitch pitch in pitches) {
              _playPianoPitch(pitch, duration, amp);
            }
            Pitch octaveLower = pitches[0].octaveLower();
            _playPianoPitch(octaveLower, duration, amp);
            _playPianoPitch(octaveLower.octaveLower(), duration, amp);

            _test++;
            break;

          case 4:
            _audioPlayer.play('audio/snare_4406.flac', when: _timerT, duration: timerPeriod - gap, volume: 1.0 / 4);
            break;
        }
        _timerT += periodMs / microsecondsPerSecond;
      } catch (e) {
        logger.log(_optionLogAudio, '_audioTest() error: ${e.toString()}');
      }
    });
  }

  void _playPianoPitch(Pitch pitch, double duration, double amp) {
    _audioPlayer.play(
      'audio/Piano.mf.${pitch.getScaleNote().toMarkup()}${pitch.number.toString()}.mp3',
      when: _timerT,
      duration: duration,
      volume: amp,
    );
  }

  final TextEditingController _userTextEditingController = TextEditingController();
  final TextEditingController _websocketHostEditingController = TextEditingController();

  static const int _testNumber = 4;
  int _test = 0;

  String _testType = 'unknown';
  final List<Pitch> _pitches = Pitch.flats;
  static final Pitch _atOrAbove = Pitch.get(.A3);

  late AppWidgetHelper appWidgetHelper;

  Timer? _timer;

  double _timerT = 0;
  final AppSongUpdateService _songUpdateService = AppSongUpdateService();
  String _ipAddress = '';

  final AppAudioPlayer _audioPlayer = AppAudioPlayer();
  final AppOptions _appOptions = AppOptions();
  final App app = App();
}
