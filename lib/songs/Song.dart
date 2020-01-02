import 'dart:convert';
import 'dart:core';

import 'package:logger/logger.dart';

import '../util.dart';
import 'SongBase.dart';
import 'key.dart';

enum SongComparatorType {
  title,
  artist,
  lastModifiedDate,
  lastModifiedDateLast,
  versionNumber,
  complexity,
}

/// A song is a wrapper class for {@link SongBase} that provides
/// file I/O routines and comparators for various sortings.
/// This is the class most all song interactions should reference.
/// <p>
/// The class is designed to provide all the GWT dependencies
/// away from SongBase so SongBase can be tested without a browser environment.
/// All the musical functions happen in SongBase.

class Song extends SongBase implements Comparable<Song> {
  /// Create a minimal song to be used internally as a place holder.
  static Song createEmptySong() {
    return createSong("", "", "", Key.get(KeyEnum.C), 100, 4, 4, "", "", "");
  }

  /// A convenience constructor used to enforce the minimum requirements for a song.
  static Song createSong(
      String title,
      String artist,
      String copyright,
      Key key,
      int bpm,
      int beatsPerBar,
      int unitsPerMeasure,
      String user,
      String chords,
      String lyrics) {
    Song song = new Song();
    song.setTitle(title);
    song.setArtist(artist);
    song.setCopyright(copyright);
    song.setKey(key);
    song.setBeatsPerMinute(bpm);
    song.setBeatsPerBar(beatsPerBar);
    song.setUnitsPerMeasure(unitsPerMeasure);
    song.setUser(user);
    song.setChords(chords);
    song.setRawLyrics(lyrics);

    return song;
  }

  /// Copy the song to a new instance.
  Song copySong() {
    Song ret = createSong(
        getTitle(),
        getArtist(),
        getCopyright(),
        getKey(),
        getBeatsPerMinute(),
        getBeatsPerBar(),
        getUnitsPerMeasure(),
        getUser(),
        toMarkup(),
        getLyricsAsString());
    ret.setFileName(getFileName());
    ret.lastModifiedTime = lastModifiedTime;
    ret.setDuration(getDuration());
    ret.setTotalBeats(getTotalBeats());
    ret.setCurrentChordSectionLocation(getCurrentChordSectionLocation());
    ret.setCurrentMeasureEditType(getCurrentMeasureEditType());
    return ret;
  }

  /// Parse a song from a JSON string.
//  static List<Song> fromJson(String jsonString) {
//    List<Song> ret = List();
//    if (jsonString == null || jsonString.length <= 0) {
//      return ret;
//    }
//
//    if (jsonString.startsWith("<")) {
//      logger.w("this can't be good: " +
//          jsonString.substring(0, min(25, jsonString.length)));
//    }
//
//    try {
//      JSONValue jv = JSONParser.parseStrict(jsonString);
//
//      JSONArray ja = jv.isArray();
//      if (ja != null) {
//        int jaLimit = ja.size();
//        for (int i = 0; i < jaLimit; i++) {
//          ret.add(Song.fromJsonObject(ja.get(i).isObject()));
//        }
//      } else {
//        JSONObject jo = jv.isObject();
//        ret.add(fromJsonObject(jo));
//      }
//    }
////    catch
////    (
////    JSONException
////    e) {
////    logger.warning(jsonString);
////    logger.warning("JSONException: " + e.getMessage());
////    return null;
////    }
//    catch (e) {
//      logger.w("exception: " + e.toString());
//      logger.w(jsonString);
//      logger.w(e.getMessage());
//      return null;
//    }
//
//    logger.d("fromJson(): " + ret[ret.length - 1].toString());
//
//    return ret;
//  }

  /// Parse a song from a JSON object.
//  static Song fromJsonObject(JSONObject jsonObject) {
//    if (jsonObject == null) {
//      return null;
//    }
//    //  file information available
//    if (jsonObject.keySet().contains("file"))
//      return songFromJsonFileObject(jsonObject);
//
//    //  straight song
//    return songFromJsonObject(jsonObject);
//  }
//
//  static Song songFromJsonFileObject(JSONObject jsonObject) {
//    Song song;
//    double lastModifiedTime = 0;
//    String fileName = null;
//
//    JSONNumber jn;
//    for (String name in jsonObject.keySet()) {
//      JSONValue jv = jsonObject.get(name);
//      switch (name) {
//        case "song":
//          song = songFromJsonObject(jv.isObject());
//          break;
//        case "lastModifiedDate":
//          jn = jv.isNumber();
//          if (jn != null) {
//            lastModifiedTime = jn.doubleValue();
//          }
//          break;
//        case "file":
//          fileName = jv.isString().stringValue();
//          break;
//      }
//    }
//    if (song == null) return null;
//
//    if (lastModifiedTime > song.lastModifiedTime)
//      song.setLastModifiedTime(lastModifiedTime);
//    song.setFileName(fileName);
//
//    return song;
//  }

//  static Song songFromJsonObject(JSONObject jsonObject) {
//    Song song = Song.createEmptySong();
//    JSONNumber jn;
//    JSONArray ja;
//    for (String name in jsonObject.keySet()) {
//      JSONValue jv = jsonObject.get(name);
//      switch (name) {
//        case "title":
//          song.setTitle(jv.isString().stringValue());
//          break;
//        case "artist":
//          song.setArtist(jv.isString().stringValue());
//          break;
//        case "copyright":
//          song.setCopyright(jv.isString().stringValue());
//          break;
//        case "key":
//          song.setKey(Key.parseString(jv.isString().stringValue()));
//          break;
//        case "defaultBpm":
//          jn = jv.isNumber();
//          if (jn != null) {
//            song.setDefaultBpm(jn.doubleValue() as int);
//          } else {
//            song.setDefaultBpm(int.parse(jv.isString().stringValue()));
//          }
//          break;
//        case "timeSignature":
//          //  most of this is coping with real old events with poor formatting
//          jn = jv.isNumber();
//          if (jn != null) {
//            song.setBeatsPerBar(jn.doubleValue() as int);
//            song.setUnitsPerMeasure(4); //  safe default
//          } else {
//            String s = jv.isString().stringValue();
//
//            final RegExp timeSignatureExp =
//                RegExp(r"^\w*(\d{1,2})\w*\/\w*(\d)\w*$");
//            RegExpMatch mr = timeSignatureExp.firstMatch(s);
//            if (mr != null) {
//              // parse
//              song.setBeatsPerBar(int.parse(mr.group(1)));
//              song.setUnitsPerMeasure(int.parse(mr.group(2)));
//            } else {
//              s = s.replaceAll("/.*", ""); //  fixme: info lost
//              if (s.length > 0) {
//                song.setBeatsPerBar(int.parse(s));
//              }
//              song.setUnitsPerMeasure(4); //  safe default
//            }
//          }
//          break;
//        case "chords":
//          ja = jv.isArray();
//          if (ja != null) {
//            int jaLimit = ja.size();
//            StringBuffer sb = new StringBuffer();
//            for (int i = 0; i < jaLimit; i++) {
//              sb.write(ja.get(i).isString().stringValue());
//              sb.write(
//                  ", "); //  brutal way to transcribe the new line without the chaos of a newline character
//            }
//            song.setChords(sb.toString());
//          } else {
//            song.setChords(jv.isString().stringValue());
//          }
//          break;
//        case "lyrics":
//          ja = jv.isArray();
//          if (ja != null) {
//            int jaLimit = ja.size();
//            StringBuffer sb = new StringBuffer();
//            for (int i = 0; i < jaLimit; i++) {
//              sb.write(ja.get(i).isString().stringValue());
//              sb.write("\n");
//            }
//            song.setRawLyrics(sb.toString());
//          } else {
//            song.setRawLyrics(jv.isString().stringValue());
//          }
//          break;
//        case "lastModifiedDate":
//          jn = jv.isNumber();
//          if (jn != null) {
//            song.setLastModifiedTime(jn.doubleValue());
//          }
//          break;
//        case "user":
//          song.setUser(jv.isString().stringValue());
//          break;
//      }
//    }
//    return song;
//  }
//
//  static String toJson(Collection<Song> songs) {
//    if (songs == null || songs.isEmpty()) {
//      return null;
//    }
//    StringBuffer sb = new StringBuffer();
//    sb.write("[\n");
//    bool first = true;
//    for (Song song in songs) {
//      if (first)
//        first = false;
//      else
//        sb.write(",\n");
//      sb.write(song.toJsonAsFile());
//    }
//    sb.write("]\n");
//    return sb.toString();
//  }

  String toJsonAsFile() {
    return "{ \"file\": " +
        jsonEncode(getFileName()) +
        ", \"lastModifiedDate\": " +
        lastModifiedTime.toString() +
        ", \"song\":" +
        " \n" +
        toJson() +
        "}";
  }

  ///Generate the JSON expression of this song.
  String toJson() {
    StringBuffer sb = new StringBuffer();

    sb.write("{\n");
    sb.write("\"title\": ");
    sb.write(jsonEncode(getTitle()));
    sb.write(",\n");
    sb.write("\"artist\": ");
    sb.write(jsonEncode(getArtist()));
    sb.write(",\n");
    sb.write("\"user\": ");
    sb.write(jsonEncode(getUser()));
    sb.write(",\n");
    sb.write("\"lastModifiedDate\": ");
    sb.write(lastModifiedTime);
    sb.write(",\n");
    sb.write("\"copyright\": ");
    sb.write(jsonEncode(getCopyright()));
    sb.write(",\n");
    sb.write("\"key\": \"");
    sb.write(getKey().toString());
    sb.write("\",\n");
    sb.write("\"defaultBpm\": ");
    sb.write(getDefaultBpm());
    sb.write(",\n");
    sb.write("\"timeSignature\": \"");
    sb.write(getBeatsPerBar());
    sb.write("/");
    sb.write(getUnitsPerMeasure());
    sb.write("\",\n");
    sb.write("\"chords\": \n");
    sb.write("    [\n");

    //  chord content
    bool first = true;
    for (String s in chordsToJsonTransportString().split("\n")) {
      if (s.length == 0) //  json is not happy with empty array elements
        continue;
      if (first) {
        first = false;
      } else {
        sb.write(",\n");
      }
      sb.write("\t");
      sb.write(jsonEncode(s));
    }
    sb.write("\n    ],\n");
    sb.write("\"lyrics\": \n");
    sb.write("    [\n");
    //  lyrics content
    first = true;
    for (String s in getLyricsAsString().split("\n")) {
      if (first) {
        first = false;
      } else {
        sb.write(",\n");
      }
      sb.write("\t");

      sb.write(jsonEncode(s));
    }
    sb.write("\n    ]\n");
    sb.write("}\n");

    return sb.toString();
  }

  @override
  void resetLastModifiedDateToNow() {
    lastModifiedTime = DateTime.now().millisecondsSinceEpoch;
  }

  static List<StringTriple> diff(Song a, Song b) {
    List<StringTriple> ret = SongBase.diff(a, b);
    int limit = 15;
    if (ret.length > limit) {
      while (ret.length > limit) {
        ret.removeAt(ret.length - 1);
      }
      ret.add(new StringTriple("+more", "", ""));
    }
    ret.insert(
        0,
        new StringTriple(
            "file date",
            DateTime.fromMillisecondsSinceEpoch(a.lastModifiedTime).toString(),
            DateTime.fromMillisecondsSinceEpoch(b.lastModifiedTime)
                .toString()));
    return ret;
  }

  static Comparator<Song> getComparatorByType(SongComparatorType type) {
    switch (type) {
      case SongComparatorType.artist:
        return _comparatorByArtist;
      case SongComparatorType.lastModifiedDate:
        return _comparatorByLastModifiedDate;
      case SongComparatorType.lastModifiedDateLast:
        return _comparatorByLastModifiedDateLast;
      case SongComparatorType.versionNumber:
        return _comparatorByVersionNumber;
      case SongComparatorType.complexity:
        return _comparatorByComplexity;
      default:
        return _comparatorByTitle;
    }
  }

  /// Compare only the title and artist.
  /// To be used for general user listing purposes only.
  /// <p>Note that leading articles will be rotated to the end.</p>
  @override
  int compareTo(Song o) {
    int ret = getSongId().compareTo(o.getSongId());
    if (ret != 0) {
      return ret;
    }
    ret = getArtist().compareTo(o.getArtist());
    if (ret != 0) {
      return ret;
    }

    //    //  more?  if so, changes in lyrics will be a new "song"
    //    ret = getLyricsAsString().compareTo(o.getLyricsAsString());
    //    if (ret != 0) {
    //      return ret;
    //    }
    //    ret = getChordsAsString().compareTo(o.getChordsAsString());
    //    if (ret != 0) {
    //      return ret;
    //    }
    return 0;
  }

  static final Logger logger = Logger();
}

/// A comparator that sorts by song title and then artist.
/// Note the title order implied by {@link #compareTo(Song)}.
Comparator<Song> _comparatorByTitle = (Song o1, Song o2) {
  return o1.compareBySongId(o2);
};

/// A comparator that sorts on the artist.
Comparator<Song> _comparatorByArtist = (Song o1, Song o2) {
  int ret = o1.getArtist().compareTo(o2.getArtist());
  if (ret != 0) return ret;
  return o1.compareBySongId(o2);
};

int _compareByLastModifiedDate(Song o1, Song o2) {
  int mod1 = o1.lastModifiedTime;
  int mod2 = o2.lastModifiedTime;

  if (mod1 == mod2) return o1.compareTo(o2);
  return mod1 < mod2 ? 1 : -1;
}

/// Compares its two arguments for order my most recent modification date.
Comparator<Song> _comparatorByLastModifiedDate = (Song o1, Song o2) {
  return _compareByLastModifiedDate(o1, o2);
};

/// Compares its two arguments for order my most recent modification date, reversed
Comparator<Song> _comparatorByLastModifiedDateLast = (Song o1, Song o2) {
  return -_compareByLastModifiedDate(o1, o2);
};

/// Compares its two arguments for order my most recent modification date.
Comparator<Song> _comparatorByVersionNumber = (Song o1, Song o2) {
  int ret = o1.compareTo(o2);
  if (ret != 0) return ret;
  if (o1.getFileVersionNumber() != o2.getFileVersionNumber())
    return o1.getFileVersionNumber() < o2.getFileVersionNumber() ? -1 : 1;
  return _compareByLastModifiedDate(o1, o2);
};

/// Compares its two arguments for order my most recent modification date.
Comparator<Song> _comparatorByComplexity = (Song o1, Song o2) {
  if (o1.getComplexity() != o2.getComplexity())
    return o1.getComplexity() < o2.getComplexity() ? -1 : 1;
  return o1.compareTo(o2);
};
