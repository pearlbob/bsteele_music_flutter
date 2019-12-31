import 'dart:core';
import 'dart:math';

import '../util.dart';
import 'Measure.dart';
import 'MeasureComment.dart';
import 'MeasureNode.dart';
import 'Section.dart';
import 'key.dart';
import 'package:logger/logger.dart';

class Phrase extends MeasureNode {
  Phrase(List<Measure> measures, int phraseIndex) {
    this.measures = List();
    this.measures.addAll(measures);
    this.phraseIndex = phraseIndex;
  }

  List<Measure> getMeasures() {
    return measures;
  }

  int getTotalMoments() {
    return measures.length;
  } //  fixme

  static Phrase parseString(
      String string, int phraseIndex, int beatsPerBar, Measure priorMeasure) {
    return parse(MarkedString(string), phraseIndex, beatsPerBar, priorMeasure);
  }

  static Phrase parse(MarkedString markedString, int phraseIndex,
      int beatsPerBar, Measure priorMeasure) {
    if (markedString == null || markedString.isEmpty) throw "no data to parse";

    List<Measure> measures = new List();
    List<Measure> lineMeasures = new List();

    markedString.stripLeadingSpaces();

    //  look for a set of measures and comments
    int initialMark = markedString.mark();
    int rowMark = markedString.mark();

    bool hasBracket = markedString.charAt(0) == '[';
    if (hasBracket) markedString.consume(1);

    for (int i = 0; i < 1e3; i++) {
      //  safety
      markedString.stripLeadingSpaces();
      if (markedString.isEmpty) break;

      //  assure this is not a section
      if (Section.lookahead(markedString)) break;

      try {
        Measure measure =
            Measure.parse(markedString, beatsPerBar, priorMeasure);
        priorMeasure = measure;
        lineMeasures.add(measure);

        //  we found an end of row so this row is a part of a phrase
        if (measure.endOfRow) {
          measures.addAll(lineMeasures);
          lineMeasures.clear();
          rowMark = markedString.mark();
        }
        continue;
      } catch (e) {}

      if (!hasBracket) {
        //  look for repeat marker
        markedString.stripLeadingSpaces();

        //  note: commas or newlines will have been consumed by the measure parse
        String c = markedString.charAt(0);
        if (c == '|' || c == 'x') {
          lineMeasures.clear();
          markedString.resetTo(rowMark);
          break; //  we've found a repeat so the phrase was done the row above
        }
      }

      //  force junk into a comment
      try {
        Measure measure = MeasureComment.parse(markedString);
        measures.addAll(lineMeasures);
        measures.add(measure);
        lineMeasures.clear();
        priorMeasure = null;
        continue;
      } catch (e) {}

      //  end of bracketed phrase
      if (hasBracket && markedString.charAt(0) == ']') {
        markedString.consume(1);
        break;
      }

      break;
    }

    //  look for repeat marker
    markedString.stripLeadingSpaces();

    //  note: commas or newlines will have been consumed by the measure parse
    if (markedString.available() > 0) {
      String c = markedString.charAt(0);
      if (c == '|' || c == 'x') if (measures.isEmpty) {
        //  no phrase found
        markedString.resetTo(initialMark);
        throw "no measures found in parse"; //  we've found a repeat so the phrase is appropriate
      } else {
        //  repeat found after prior rows
        lineMeasures.clear();
        markedString.resetTo(rowMark);
      }
    }

    //  collect the last row
    measures.addAll(lineMeasures);

    //  note: bracketed phrases can be empty
    if (!hasBracket && measures.isEmpty) {
      markedString.resetTo(initialMark);
      throw "no measures found in parse";
    }

    return new Phrase(measures, phraseIndex);
  }

  @override
  String transpose(Key key, int halfSteps) {
    return "Phrase"; //  error
  }

  @override
  MeasureNode transposeToKey(Key key) {
    List<Measure> newMeasures = new List<Measure>();
    for (Measure measure in measures)
      newMeasures.add(measure.transposeToKey(key) as Measure);
    return new Phrase(newMeasures, phraseIndex);
  }

  MeasureNode findMeasureNode(MeasureNode measureNode) {
    for (Measure m in measures) {
      if (m == measureNode) return m;
    }
    return null;
  }

  int findMeasureNodeIndex(MeasureNode measureNode) {
    if (measureNode == null) throw "measureNode null";

    int ret = measures.indexOf(measureNode);

    if (ret < 0) throw "measureNode not found: " + measureNode.toMarkup();

    return ret;
  }

  bool insert(int index, MeasureNode newMeasureNode) {
    if (newMeasureNode == null) return false;

    switch (newMeasureNode.getMeasureNodeType()) {
      case MeasureNodeType.measure:
        break;
      default:
        return false;
    }

    Measure newMeasure = newMeasureNode as Measure;

    if (measures == null) measures = new List();

    if (measures.isEmpty) {
      measures.add(newMeasure);
      return true;
    }

    try {
      _addAt(index, newMeasure);
    } catch (ex) {
      measures.add(newMeasure); //  default to the end!
    }
    return true;
  }

  bool replace(int index, MeasureNode newMeasureNode) {
    if (measures == null || measures.isEmpty) return false;

    if (newMeasureNode == null) return false;

    switch (newMeasureNode.getMeasureNodeType()) {
      case MeasureNodeType.measure:
        break;
      default:
        return false;
    }

    Measure newMeasure = newMeasureNode as Measure;

    try {
      List<Measure> replacementList = new List();
      if (index > 0) replacementList.addAll(measures.sublist(0, index));
      replacementList.add(newMeasure);
      if (index < measures.length - 1)
        replacementList.addAll(measures.sublist(index + 1, measures.length));
      measures = replacementList;
    } catch (ex) {
      measures.add(newMeasure); //  default to the end!
    }
    return true;
  }

  bool append(int index, MeasureNode newMeasureNode) {
    if (newMeasureNode == null) return false;

    switch (newMeasureNode.getMeasureNodeType()) {
      case MeasureNodeType.measure:
        break;
      default:
        return false;
    }

    Measure newMeasure = newMeasureNode as Measure;

    if (measures == null) measures = new List();
    if (measures.isEmpty) {
      measures.add(newMeasure);
      return true;
    }

    try {
      _addAt(index + 1, newMeasure);
    } catch (ex) {
      measures.add(newMeasure); //  default to the end!
    }

    return true;
  }

  bool add(List<Measure> newMeasures) {
    if (newMeasures == null || newMeasures.isEmpty) return false;
    if (measures == null) measures = new List<Measure>();
    measures.addAll(newMeasures);
    return true;
  }

  bool addAt(int index, List<Measure> newMeasures) {
    if (newMeasures == null || newMeasures.isEmpty) return false;
    if (measures == null) measures = new List<Measure>();
    index = min(index, measures.length - 1);
    addAllAt(index, newMeasures);
    return true;
  }

  void _addAt(int index, Measure m) {
    if (measures == null) measures = List();
    if (measures.length < index)
      measures.add(m);
    else
      measures.insert(index + 1, m);
  }

  bool addAllAt(int index, List<Measure> list) {
    if (list == null || list.isEmpty) return false;
    if (measures == null) measures = List();
    if (measures.length < index)
      measures.addAll(list);
    else {
      for (Measure m in list) measures.insert(index++ + 1, m);
    }
    return true;
  }

  bool edit(MeasureEditType type, int index, MeasureNode newMeasureNode) {
    if (newMeasureNode == null) {
      switch (type) {
        case MeasureEditType.delete:
          break;
        default:
          return false;
      }
    } else {
      //  reject wrong node type
      switch (newMeasureNode.getMeasureNodeType()) {
        case MeasureNodeType.phrase: //  multiple measures
        case MeasureNodeType.comment:
        case MeasureNodeType.measure:
          break;
        //  repeats not allowed!
        default:
          return false;
      }
    }

    //  assure measures are ready
    switch (type) {
      case MeasureEditType.replace:
      case MeasureEditType.delete:
        if (measures == null || measures.isEmpty) return false;
        break;
      case MeasureEditType.insert:
      case MeasureEditType.append:
        if (measures == null) measures = new List();

        //  index doesn't matter
        if (measures.isEmpty) {
          if (newMeasureNode.isSingleItem())
            measures.add(newMeasureNode as Measure);
          else
            measures.addAll((newMeasureNode as Phrase).getMeasures());
          return true;
        }
        break;
      default:
        return false;
    }

    //  edit by type
    switch (type) {
      case MeasureEditType.delete:
        try {
          measures.remove(index);
          //  note: newMeasureNode is ignored
        } catch (ex) {
          return false;
        }
        break;
      case MeasureEditType.insert:
        try {
          if (newMeasureNode.isSingleItem())
            _addAt(index, newMeasureNode as Measure);
          else
            addAllAt(index, (newMeasureNode as Phrase).getMeasures());
        } catch (ex) {
          //  default to the end!
          if (newMeasureNode.isSingleItem())
            measures.add(newMeasureNode as Measure);
          else
            measures.addAll((newMeasureNode as Phrase).getMeasures());
        }
        break;
      case MeasureEditType.append:
        try {
          if (newMeasureNode.isSingleItem())
            _addAt(index + 1, newMeasureNode as Measure);
          else
            addAllAt(index + 1, (newMeasureNode as Phrase).getMeasures());
        } catch (ex) {
          //  default to the end!
          if (newMeasureNode.isSingleItem())
            measures.add(newMeasureNode as Measure);
          else
            measures.addAll((newMeasureNode as Phrase).getMeasures());
        }
        break;
      case MeasureEditType.replace:
        try {
          measures.remove(index);
          if (newMeasureNode.isSingleItem())
            _addAt(index, newMeasureNode as Measure);
          else
            addAllAt(index, (newMeasureNode as Phrase).getMeasures());
        } catch (ex) {
          //  default to the end!
          if (newMeasureNode.isSingleItem())
            measures.add(newMeasureNode as Measure);
          else
            measures.addAll((newMeasureNode as Phrase).getMeasures());
        }
        break;
      default:
        return false;
    }

    return true;
  }

  bool contains(MeasureNode measureNode) {
    return measures.contains(measureNode);
  }

  Measure getMeasure(int measureIndex) {
    return measures[measureIndex];
  }

  /// Delete the given measure if it belongs in the sequence item.
  bool delete(Measure measure) {
    if (measures == null) return false;
    return measures.remove(measure);
  }

  bool deleteAt(int measureIindex) {
    return measures.remove(measureIindex);
  }

  @override
  bool isSingleItem() {
    return false;
  }

  int compareTo(Object o) {
    if (!(o is Phrase)) return -1;
    Phrase other = o as Phrase;
    int limit = min(measures.length, other.measures.length);
    for (int i = 0; i < limit; i++) {
      int ret = measures[i].compareTo(other.measures[i]);
      if (ret != 0) return ret;
    }
    if (measures.length != other.measures.length)
      return measures.length < other.measures.length ? -1 : 1;
    return 0;
  }

  @override
  String getId() {
    return null;
  }

  @override
  MeasureNodeType getMeasureNodeType() {
    return MeasureNodeType.phrase;
  }

  @override
  bool isEmpty() {
    return measures == null || measures.isEmpty;
  }

  @override
  String toMarkup() {
    if (measures == null || measures.isEmpty) return "[]";

    StringBuffer sb = StringBuffer();
    for (Measure measure in measures) {
      sb.write(measure.toMarkup());
      sb.write(" ");
    }
    return sb.toString();
  }

  @override
  String toEntry() {
    if (measures == null || measures.isEmpty) return "[]";

    StringBuffer sb = new StringBuffer();
    for (Measure measure in measures) {
      sb.write(measure.toEntry());
      sb.write(" ");
    }
    return sb.toString();
  }

  @override
  bool setMeasuresPerRow(int measuresPerRow) {
    if (measuresPerRow <= 0) return false;

    bool ret = false;
    int i = 0;
    if (measures != null && measures.length > 0) {
      Measure lastMeasure = measures[measures.length - 1];
      for (Measure measure in measures) {
        if (measure.isComment()) //  comments get their own row
          continue;
        if (i == measuresPerRow - 1 && measure != lastMeasure) {
          //  new row required
          if (!measure.endOfRow) {
            measure.endOfRow = true;
            ret = true;
          }
        } else {
          if (measure.endOfRow) {
            measure.endOfRow = false;
            ret = true;
          }
        }
        i++;
        i %= measuresPerRow;
      }
    }
    return ret;
  }

  @override
  String toJson() {
    if (measures == null || measures.isEmpty) return " ";

    StringBuffer sb = new StringBuffer();
    if (measures.isNotEmpty) {
      Measure lastMeasure = measures[measures.length - 1];
      for (Measure measure in measures) {
        sb.write(measure.toJson());
        if (measure == lastMeasure) {
          sb.write("\n");
          break;
        } else if (measure.endOfRow) {
          sb.write("\n");
        } else
          sb.write(" ");
      }
    }
    return sb.toString();
  }

  @override
  String toString() {
    return toMarkup() + "\n";
  }

  int get length => measures.length;

  int getPhraseIndex() {
    return phraseIndex;
  }

  void setPhraseIndex(int phraseIndex) {
    this.phraseIndex = phraseIndex;
  }

  List<Measure> measures;
  int phraseIndex;

  Logger logger = Logger();
}
