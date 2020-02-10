import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:bsteele_music_flutter/songs/Song.dart';
import 'package:logger/logger.dart';

//     -v -o songs -x allSongs.songlyrics -a songs -f -w xallSongs.songlyrics
void main(List<String> args) {
  BsteeleMusicUtil util = BsteeleMusicUtil();
  util.runMain(args);
}

class BsteeleMusicUtil {
  void _help() {
    print(((('''
bsteeleMusicUtil:
//  a utility for the bsteele Music App
arguments:
-a {dir}            add the allSongs list from the given directory
-f                  force file writes over existing files
-h                  this help message
-o {output dir}     select the output directory, must be specified prior to -x
-v                  verbose output
-w {file}           write the current allSongs list to the given file
-x {file}           expand a songlyrics list file to the output directory

note: the output directory will not be cleaned prior to the expansion.
this means old and stale songs might remain in the directory.
'''))));
  }

  /// A workaround to call the unix touch command to modify the
  /// read song's file to reflect it's last modification date in the song list.
  Future setLastModified(File file, int lastModified) async {
    DateTime t = DateTime.fromMillisecondsSinceEpoch(lastModified);
    //print ('t: ${t.toIso8601String()}');
    //  print ('file.path: ${file.path}');
    await Process.run('bash', [
      '-c',
      'touch --date="${t.toIso8601String()}" ${file.path}'
    ]).then((result) {
      stdout.write(result.stdout);
      stderr.write(result.stderr);
      if (result.exitCode != 0)
        throw "setLastModified() bad exit code: ${result.exitCode}";
    });
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
        case '-a':
          //  assert there is another arg
          if (i >= args.length - 1) {
            print('missing directory path for -a');
            _help();
            exit(-1);
          }
          i++;
          Directory inputDirectory = Directory(args[i]);

          if (inputDirectory.statSync().type !=
              FileSystemEntityType.directory) {
            print('"${inputDirectory.path}" is not a directory for -a');
            _help();
            exit(-1);
          }
          if (!(await inputDirectory.exists())) {
            print('missing directory for -a');
            _help();
            exit(-1);
          }
          {
            List contents = inputDirectory.listSync();
            for (var file in contents) {
              if (!(file is File)) continue;
              if (!file.path.endsWith('.songlyrics')) continue;

              List<Song> addSongs =
                  Song.songListFromJson(file.readAsStringSync());
              allSongs.addAll(addSongs);
            }
          }
          break;

        case '-f':
          _force = true;
          break;

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

        case '-w':
          //  assert there is another arg
          if (i >= args.length - 1) {
            print('missing directory path for -a');
            _help();
            exit(-1);
          }
          i++;
          File outputFile = File(args[i]);

          if (await outputFile.exists() && !_force) {
            print('"${outputFile.path}" alreday exists for -w without -f');
            _help();
            exit(-1);
          }
          await outputFile.writeAsString(Song.listToJson(allSongs.toList()),
              flush: true);
          break;

        case '-v':
          _verbose = true;
          break;

        case '-x':
          //  assert there is another arg
          if (i >= args.length - 1) {
            print('missing file path for -x');
            _help();
            exit(-1);
          }

          i++;
          _file = File(args[i]);
          if (_verbose) print('input file path: ${_file.toString()}');
          if (!(await _file.exists())) {
            print('input file path: ${_file.toString()}'
                    ' is missing' +
                (_outputDirectory.isAbsolute
                    ? ""
                    : ' at ${Directory.current}'));

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
            if (_verbose) print('\t' + writeTo.path);
            await writeTo.writeAsString(song.toJsonAsFile(), flush: true);
            await setLastModified(writeTo, fileTime.millisecondsSinceEpoch);
          }
          break;
      }
    }
    exit(0);
  }

  Directory _outputDirectory = Directory.current;
  SplayTreeSet<Song> allSongs = SplayTreeSet();
  File _file;
  bool _verbose = false;
  bool _force = false; //  force a file write
}
