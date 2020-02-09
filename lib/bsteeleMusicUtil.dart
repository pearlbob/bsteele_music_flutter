import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:bsteele_music_flutter/songs/Song.dart';
import 'package:logger/logger.dart';

Directory _outputDirectory = Directory.current;
File _file;
bool _verbose = false;

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

Future setLastModified(File file, int lastModified) async {
  DateTime t = DateTime.fromMillisecondsSinceEpoch(lastModified);
  //print ('t: ${t.toIso8601String()}');
  //  print ('file.path: ${file.path}');
  await Process.run(
          'bash', ['-c', 'touch --date="${t.toIso8601String()}" ${file.path}'])
      .then((result) {
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    if (result.exitCode != 0)
      throw "setLastModified() bad exit code: ${result.exitCode}";
  });
}

void main(List<String> args) {
  runMain(args);
}

/// A workaround method to get the async on main()
void runMain(List<String> args) async {
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
            _outputDirectory.createSync();
          }
        } else {
          print('missing output path for -o');
          _help();
          return;
        }
        break;
      case '-test':
        {
          DateTime t = DateTime.fromMillisecondsSinceEpoch(1570675021323);
          File file = File('/home/bob/junk/j');
          await setLastModified(file, t.millisecondsSinceEpoch);
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

        List<Song> songs;
        if (_file.path.endsWith('.zip')) {
          // Read the Zip file from disk.
          final bytes = await _file.readAsBytes();

          // Decode the Zip file
          final archive = ZipDecoder().decodeBytes(bytes);

          // Extract the contents of the Zip archive
          for (final file in archive) {
            if (file.isFile) {
              final data = file.content as List<int>;
              songs = Song.songListFromJson(utf8.decode(data));
            }
          }
        } else
          songs = Song.songListFromJson(_file.readAsStringSync());

        if (songs == null || songs.isEmpty) {
          print('didn\'t find songs in ${_file.toString()}');
          exit(-1);
        }

        for (Song song in songs) {
          DateTime fileTime =
              DateTime.fromMillisecondsSinceEpoch(song.lastModifiedTime);
          if (_verbose) {
            print(
                '${song.getTitle()} by ${song.getArtist()}  ${song.songId.toString()} ${fileTime.toIso8601String()}');
          }
          File writeTo = File(_outputDirectory.path +
              '/' +
              song.songId.toString() +
              '.songlyrics');
          print(writeTo.path);
          await writeTo.writeAsString(song.toJson(), flush: true);
          await setLastModified(writeTo, fileTime.millisecondsSinceEpoch);
        }
        break;
    }
  }
  exit(0);
}
