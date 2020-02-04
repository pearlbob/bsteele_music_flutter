import 'dart:io';

import 'package:bsteele_music_flutter/songs/Song.dart';
import 'package:logger/logger.dart';

Directory _outputDirectory = Directory.current;
File _file;
bool _verbose = false;

main(List<String> args) async {
  Logger.level = Level.info;

  //  help if nothing to do
  if (args == null || args.length <= 0) {
    _help();
    return;
  }

  //  process the requests
  for (int i = 0; i < args.length; i++) {
    String arg = args[i];
    switch (arg) {
      case '-h':
        _help();
        break;
      case '-o':
        //  assert there is another arg
        if (i < args.length - 1) {
          i++;
          _outputDirectory = Directory(args[i]);
          if (_verbose) print('output path: ${_outputDirectory.toString()}');
          if (!(await _outputDirectory.exists())) {
            if (_verbose)
              print('output path: ${_outputDirectory.toString()}'
                      ' is missing' +
                  (_outputDirectory.isAbsolute
                      ? ""
                      : ' at ${Directory.current}'));

            Directory parent = _outputDirectory.parent;
            if (!(await parent.exists())) {
              print('parent path: ${parent.toString()}'
                      ' is missing' +
                  (_outputDirectory.isAbsolute
                      ? ""
                      : ' at ${Directory.current}'));
              return;
            }
          }
        } else {
          print('missing output path for -o');
          _help();
          return;
        }
        break;
      case '-v':
        _verbose = true;
        break;
      case '-x':
        //  assert there is another arg
        if (i >= args.length - 1) {
          print('missing file path for -x');
          _help();
          return;
        }


        i++;
        _file = File(args[i]);
        if (_verbose) print('input file path: ${_file.toString()}');
        if (!(await _file.exists())) {
          print('input file path: ${_file.toString()}'
                  ' is missing' +
              (_outputDirectory.isAbsolute ? "" : ' at ${Directory.current}'));

          exit(-1);
          return;
        }

        if (_verbose)
          print(
              'input file: ${_file.toString()}, file size: ${await _file.length()}');

        List<Song> songs = Song.songListFromJson(_file.readAsStringSync());
        if (songs == null || songs.isEmpty) {
          print('didn\'t find songs in ${_file.toString()}');
          exit(-1);
        }
        if (_verbose) {
          print('songs found: ');
          for (Song song in songs) {
            print('${song.getTitle()} by ${song.getArtist()}  ${song.songId.toString()}');
          }
        }
        break;
    }
  }
  exit(0);
}

void _help() {
  print('''
bsteeleMusicUtil:
//  a utility for the bsteele Music App
arguments:
-h                  this help message
-o {output dir}     select the output directory
-v                  verbose output
-x {file}           expand a songlyrics list file to the output directory
''');
}
