import 'package:logger/logger.dart';

import '../util.dart';
import 'Measure.dart';
import 'MeasureComment.dart';
import 'MeasureNode.dart';
import 'MeasureRepeat.dart';
import 'Phrase.dart';
import 'Section.dart';
import 'SectionVersion.dart';
import 'key.dart';

/// A chord section of a song is typically a collection of measures
/// that constitute a portion of the song that is considered musically a unit.
/// Immutable.

class ChordSection extends MeasureNode implements Comparable<ChordSection> {
  ChordSection(this._sectionVersion, List<Phrase> phrases) {
    this._phrases = (phrases != null ? phrases : List());
  }

  static ChordSection getDefault() {
    return new ChordSection(SectionVersion.getDefault(), null);
  }

  @override
  bool isSingleItem() {
    return false;
  }

  static ChordSection parseString(String s, int beatsPerBar) {
    return parse(new MarkedString(s), beatsPerBar, false);
  }

  static ChordSection parse(
      MarkedString markedString, int beatsPerBar, bool strict) {
    if (markedString == null || markedString.isEmpty) throw "no data to parse";

    markedString.stripLeadingSpaces(); //  includes newline
    if (markedString.isEmpty) throw "no data to parse";

    SectionVersion sectionVersion;
    try {
      sectionVersion = SectionVersion.parse(markedString);
    } catch (e) {
      if (strict) throw e;

      //  cope with badly formatted songs
      sectionVersion =
          new SectionVersion.bySection(Section.get(SectionEnum.verse));
    }

    List<Phrase> phrases = List();
    List<Measure> measures = List();
    List<Measure> lineMeasures = List();
    //  bool repeatMarker = false;
    Measure lastMeasure = null;
    for (int i = 0; i < 2000; i++) //  arbitrary safety hard limit
    {
      markedString.stripLeadingSpaces();
      if (markedString.isEmpty) break;

      //  quit if next section found
      if (Section.lookahead(markedString)) break;

      try {
        //  look for a block repeat
        MeasureRepeat measureRepeat = MeasureRepeat.parse(
            markedString, phrases.length, beatsPerBar, null);
        if (measureRepeat != null) {
          //  don't assume every line has an eol
          for (Measure m in lineMeasures) measures.add(m);
          lineMeasures = List();
          if (measures.isNotEmpty) {
            phrases.add(new Phrase(measures, phrases.length));
          }
          measureRepeat.setPhraseIndex(phrases.length);
          phrases.add(measureRepeat);
          measures = List();
          lastMeasure = null;
          continue;
        }
      } catch (e) {
        //  ignore
      }

      try {
        //  look for a phrase
        Phrase phrase =
            Phrase.parse(markedString, phrases.length, beatsPerBar, null);
        if (phrase != null) {
          //  don't assume every line has an eol
          for (Measure m in lineMeasures) measures.add(m);
          lineMeasures = List();
          if (measures.isNotEmpty) {
            phrases.add(new Phrase(measures, phrases.length));
          }
          phrase.setPhraseIndex(phrases.length);
          phrases.add(phrase);
          measures = List();
          lastMeasure = null;
          continue;
        }
      } catch (e) {
        //  ignore
      }

      try {
        //  add a measure to the current line measures
        Measure measure = Measure.parse(markedString, beatsPerBar, lastMeasure);
        lineMeasures.add(measure);
        lastMeasure = measure;
        continue;
      } catch (e) {
        //  ignore
      }

      //  consume unused commas
      {
        String s = markedString.remainingStringLimited(10);
        _logger.d("s: " + s);
        RegExpMatch mr = commaRegexp.firstMatch(s);
        if (mr != null) {
          markedString.consume(mr.group(0).length);
          continue;
        }
      }

      try {
        //  look for a comment
        MeasureComment measureComment = MeasureComment.parse(markedString);
        for (Measure m in lineMeasures) measures.add(m);
        lineMeasures.clear();
        lineMeasures.add(measureComment);
        continue;
      } catch (e) {
        //  ignore
      }

      //  chordSection has no choice, force junk into a comment
      {
        int n = markedString
            .indexOf("\n"); //  all comments end at the end of the line
        String s = "";
        if (n > 0)
          s = markedString.remainingStringLimited(n + 1);
        else
          s = markedString.toString();

        RegExpMatch mr = commentRegExp.firstMatch(s);

//  consume the comment
        if (mr != null) {
          s = mr.group(1);
          markedString.consume(mr.group(0).length);
//  cope with unbalanced leading ('s and trailing )'s
          s = s.replaceAll("^\\(", "").replaceAll(r"\)$", "");
          s = s
              .trim(); //  in case there is white space inside unbalanced parens

          MeasureComment measureComment = new MeasureComment(s);
          for (Measure m in lineMeasures) measures.add(m);
          lineMeasures.clear();
          lineMeasures.add(measureComment);
          continue;
        } else
          _logger.i("here: " + s);
      }
      _logger.i("can't figure out: " + markedString.toString());
      throw "can't figure out: " + markedString.toString(); //  all whitespace
    }

//  don't assume every line has an eol
    for (Measure m in lineMeasures) measures.add(m);
    if (measures.isNotEmpty) {
      phrases.add(new Phrase(measures, phrases.length));
    }

    ChordSection ret = new ChordSection(sectionVersion, phrases);
    return ret;
  }

  bool add(int index, MeasureNode newMeasureNode) {
    if (newMeasureNode == null) return false;

    switch (newMeasureNode.getMeasureNodeType()) {
      case MeasureNodeType.repeat:
      case MeasureNodeType.phrase:
        break;
      default:
        return false;
    }

    Phrase newPhrase = newMeasureNode as Phrase;

    if (_phrases == null) _phrases = List();

    if (_phrases.isEmpty) {
      _phrases.add(newPhrase);
      return true;
    }

    try {
      _addPhraseAt(index, newPhrase);
    } catch (e) {
      _phrases.add(newPhrase); //  default to the end!
    }
    return true;
  }

  bool insert(int index, MeasureNode newMeasureNode) {
    if (newMeasureNode == null) return false;

    switch (newMeasureNode.getMeasureNodeType()) {
      case MeasureNodeType.repeat:
      case MeasureNodeType.phrase:
        break;
      default:
        return false;
    }

    Phrase newPhrase = newMeasureNode as Phrase;

    if (_phrases == null) _phrases = List();

    if (_phrases.isEmpty) {
      _phrases.add(newPhrase);
      return true;
    }

    try {
      _addPhraseAt(index, newPhrase);
    } catch (e) {
      _phrases.add(newPhrase); //  default to the end!
    }
    return true;
  }

  void _addPhraseAt(int index, Phrase m) {
    if (_phrases == null) _phrases = List();
    if (_phrases.length < index)
      _phrases.add(m);
    else
      _phrases.insert(index + 1, m);
  }

//  void _addAllPhrasesAt(int index, List<Phrase> list) {
//    if (_phrases == null) _phrases = List();
//    if (_phrases.length < index)
//      _phrases.addAll(list);
//    else {
//      for (Phrase phrase in list) _phrases.insert(index++ + 1, phrase);
//    }
//  }

  MeasureNode findMeasureNode(MeasureNode measureNode) {
    for (Phrase measureSequenceItem in getPhrases()) {
      if (measureSequenceItem == measureNode) return measureSequenceItem;
      MeasureNode mn = measureSequenceItem.findMeasureNode(measureNode);
      if (mn != null) return mn;
    }
    return null;
  }

  int findMeasureNodeIndex(MeasureNode measureNode) {
    int index = 0;
    for (Phrase phrase in getPhrases()) {
      int i = phrase.findMeasureNodeIndex(measureNode);
      if (i >= 0) return index + i;
      index += phrase.size();
    }
    return -1;
  }

  Phrase findPhrase(MeasureNode measureNode) {
    for (Phrase phrase in getPhrases()) {
      if (phrase == measureNode || phrase.contains(measureNode)) return phrase;
    }
    return null;
  }

  int findPhraseIndex(MeasureNode measureNode) {
    for (int i = 0; i < getPhrases().length; i++) {
      Phrase p = getPhrases()[i];
      if (measureNode == p || p.contains(measureNode)) return i;
    }
    return -1;
  }

  int indexOf(Phrase phrase) {
    for (int i = 0; i < getPhrases().length; i++) {
      Phrase p = getPhrases()[i];
      if (phrase == p) return i;
    }
    return -1;
  }

  Measure getMeasure(int phraseIndex, int measureIndex) {
    try {
      Phrase phrase = getPhrase(phraseIndex);
      return phrase.getMeasure(measureIndex);
    } catch (e) {
      return null;
    }
  }

  bool deletePhrase(int phraseIndex) {
    try {
      return _phrases.remove(phraseIndex) != null;
    } catch (e) {
      return false;
    }
  }

  bool deleteMeasure(int phraseIndex, int measureIndex) {
    try {
      Phrase phrase = getPhrase(phraseIndex);
      bool ret = phrase.deleteAt(measureIndex) != null;
      if (ret && phrase.isEmpty()) return deletePhrase(phraseIndex);
      return ret;
    } catch (e) {
      return false;
    }
  }

  int getTotalMoments() {
    int total = 0;
    for (Phrase measureSequenceItem in _phrases) {
      total += measureSequenceItem.getTotalMoments();
    }
    return total;
  }

  /**
   * Return the sectionVersion beats per minute
   * or null to default to the song BPM.
   *
   * @return the sectionVersion BPM or null
   */
//   Integer getBeatsPerMinute() {
//    return bpm;
//}

  /**
   * Return the sections's number of beats per bar or null to default to the song's number of beats per bar
   *
   * @return the number of beats per bar
   */
//       Integer getBeatsPerBar() {
//        return beatsPerBar;
//    }

  /**
   * Compares this object with the specified object for order.  Returns a
   * negative integer, zero, or a positive integer as this object is less
   * than, equal to, or greater than the specified object.
   *
   * @param o the object to be compared.
   * @return a negative integer, zero, or a positive integer as this object
   * is less than, equal to, or greater than the specified object.
   * @throws NullPointerException if the specified object is null
   * @throws ClassCastException   if the specified object's type prevents it
   *                              from being compared to this object.
   */
  @override
  int compareTo(ChordSection o) {
    if (_sectionVersion.compareTo(o._sectionVersion) != 0)
      return _sectionVersion.compareTo(o._sectionVersion);

    if (_phrases.length != o._phrases.length)
      return _phrases.length < o._phrases.length ? -1 : 1;

    for (int i = 0; i < _phrases.length; i++) {
      int ret = _phrases[i].toMarkup().compareTo(o._phrases[i].toMarkup());
      if (ret != 0) return ret;
    }
    return 0;
  }

  @override
  String getId() {
    return _sectionVersion.getId();
  }

  @override
  MeasureNodeType getMeasureNodeType() {
    return MeasureNodeType.section;
  }

  MeasureNode lastMeasureNode() {
    if (_phrases == null || _phrases.isEmpty) return this;
    Phrase measureSequenceItem = _phrases[_phrases.length - 1];
    List<Measure> measures = measureSequenceItem.getMeasures();
    if (measures == null || measures.isEmpty) return measureSequenceItem;
    return measures[measures.length - 1];
  }

  @override
  String transpose(Key key, int halfSteps) {
    StringBuffer sb = StringBuffer();
    sb.write(getSectionVersion().toString());
    if (_phrases != null)
      for (Phrase phrase in _phrases)
        sb.write(phrase.transpose(key, halfSteps));
    return sb.toString();
  }

  @override
  MeasureNode transposeToKey(Key key) {
    List<Phrase> newPhrases = null;
    if (_phrases != null) {
      newPhrases = List();
      for (Phrase phrase in _phrases)
        newPhrases.add(phrase.transposeToKey(key) as Phrase);
    }
    return new ChordSection(_sectionVersion, newPhrases);
  }

  @override
  String toMarkup() {
    StringBuffer sb = new StringBuffer();
    sb.write(getSectionVersion().toString());
    sb.write(" ");
    sb.write(phrasesToMarkup());
    return sb.toString();
  }

  String phrasesToMarkup() {
    if (_phrases == null || _phrases.isEmpty) {
      return "[]";
    }
    StringBuffer sb = new StringBuffer();
    for (Phrase phrase in _phrases) sb.write(phrase.toMarkup());
    return sb.toString();
  }

  @override
  String toEntry() {
    StringBuffer sb = new StringBuffer();
    sb.write(getSectionVersion().toString());
    sb.write("\n ");
    sb.write(phrasesToEntry());
    return sb.toString();
  }

  @override
  bool setMeasuresPerRow(int measuresPerRow) {
    if (measuresPerRow <= 0) return false;

    bool ret = false;
    for (Phrase phrase in _phrases) {
      ret = ret || phrase.setMeasuresPerRow(measuresPerRow);
    }
    return ret;
  }

  String phrasesToEntry() {
    if (_phrases == null || _phrases.isEmpty) {
      return "[]";
    }
    StringBuffer sb = new StringBuffer();
    for (Phrase phrase in _phrases) sb.write(phrase.toEntry());
    return sb.toString();
  }

  @override
  String toJson() {
    StringBuffer sb = new StringBuffer();
    sb.write(getSectionVersion().toString());
    sb.write("\n");
    if (_phrases == null || _phrases.isEmpty) {
      sb.write("[]");
    } else
      for (Phrase phrase in _phrases) {
        String s = phrase.toJson();
        sb.write(s);
        if (!s.endsWith("\n")) sb.write("\n");
      }
    return sb.toString();
  }

  /**
   * Old style markup
   *
   * @return old style markup
   */
  @override
  String toString() {
    StringBuffer sb = new StringBuffer();
    sb.write(getSectionVersion().toString());
    sb.write("\n");
    if (_phrases != null)
      for (Phrase phrase in _phrases) sb.write(phrase.toString());
    return sb.toString();
  }

  SectionVersion getSectionVersion() {
    return _sectionVersion;
  }

  Section getSection() {
    return _sectionVersion.getSection();
  }

  List<Phrase> getPhrases() {
    return _phrases;
  }

  Phrase getPhrase(int index) {
    return _phrases[index];
  }

  void setPhrases(List<Phrase> phrases) {
    this._phrases = phrases;
  }

  int getPhraseCount() {
    if (_phrases == null) return 0;
    return _phrases.length;
  }

  Phrase lastPhrase() {
    if (_phrases == null) return null;
    return _phrases[_phrases.length - 1];
  }

  @override
  bool isEmpty() {
    return _phrases == null || _phrases.isEmpty || _phrases[0].isEmpty();
  }

  SectionVersion get sectionVersion => _sectionVersion;
  final SectionVersion _sectionVersion;
  List<Phrase> _phrases;

  static RegExp commaRegexp = RegExp("^\\s*,");
  static RegExp commentRegExp = RegExp("^(\\S+)\\s+");

  static Logger _logger = new Logger();
}