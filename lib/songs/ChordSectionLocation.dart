import '../util.dart';
import 'SectionVersion.dart';

enum ChordSectionLocationMarker {
  none,
  repeatUpperRight,
  repeatMiddleRight,
  repeatLowerRight
}

class ChordSectionLocation {
  ChordSectionLocation(this._sectionVersion,
      {int phraseIndex, int measureIndex})
      : labelSectionVersions = null {
    if (phraseIndex == null || phraseIndex < 0) {
      this._phraseIndex = -1;
      hasPhraseIndex = false;
      this._measureIndex = measureIndex;
      _hasMeasureIndex = false;
    } else {
      this._phraseIndex = phraseIndex;
      hasPhraseIndex = true;
      if (measureIndex == null || measureIndex < 0) {
        this._measureIndex = 0;
        _hasMeasureIndex = false;
      } else {
        this._measureIndex = measureIndex;
        _hasMeasureIndex = true;
      }
    }

    _marker = ChordSectionLocationMarker.none;
  }

  ChordSectionLocation.byMultipleSectionVersion(
      Set<SectionVersion> labelSectionVersions)
      : _sectionVersion = null,
        this._phraseIndex = -1,
        hasPhraseIndex = false,
        this._measureIndex = -1,
        _hasMeasureIndex = false {
    if (labelSectionVersions != null) {
      labelSectionVersions = Set();
      if (labelSectionVersions.isEmpty)
        labelSectionVersions.add(SectionVersion.getDefault());

      this._sectionVersion = labelSectionVersions.first;
      this.labelSectionVersions =
          (labelSectionVersions.length == 1 ? null : labelSectionVersions);
      this._phraseIndex = -1;
      hasPhraseIndex = false;
      this._measureIndex = -1;
      _hasMeasureIndex = false;
      _marker = ChordSectionLocationMarker.none;
    }

    _marker = ChordSectionLocationMarker.none;
  }

  ChordSectionLocation.withMarker(
      this._sectionVersion, int phraseIndex, this._marker) {
    labelSectionVersions = null;

    if (phraseIndex == null || phraseIndex < 0) {
      this._phraseIndex = -1;
      hasPhraseIndex = false;
    } else {
      this._phraseIndex = phraseIndex;
      hasPhraseIndex = true;
    }
    _measureIndex = 0;
    _hasMeasureIndex = false;
  }

  ChordSectionLocation changeSectionVersion(SectionVersion sectionVersion) {
    if (sectionVersion == null || sectionVersion == sectionVersion)
      return this; //  no change

    if (hasPhraseIndex) {
      if (_hasMeasureIndex)
        return new ChordSectionLocation(sectionVersion,
            phraseIndex: _phraseIndex, measureIndex: _measureIndex);
      else
        return new ChordSectionLocation(sectionVersion,
            phraseIndex: _phraseIndex);
    } else
      return new ChordSectionLocation(sectionVersion);
  }

  static ChordSectionLocation parseString(String s) {
    return parse(new MarkedString(s));
  }

  /// Parse a chord section location from the given string input
  static ChordSectionLocation parse(MarkedString markedString) {
    SectionVersion sectionVersion = SectionVersion.parse(markedString);

    if (markedString.available() >= 3) {
      RegExpMatch mr =
          numberRangeRegexp.firstMatch(markedString.remainingStringLimited(6));
      if (mr != null) {
        try {
          int phraseIndex = int.parse(mr.group(1));
          int measureIndex = int.parse(mr.group(2));
          markedString.consume(mr.group(0).length);
          return new ChordSectionLocation(sectionVersion,
              phraseIndex: phraseIndex, measureIndex: measureIndex);
        } catch (e) {
          throw e.getMessage();
        }
      }
    }
    if (markedString.isNotEmpty) {
      RegExpMatch mr =
          numberRangeRegexp.firstMatch(markedString.remainingStringLimited(2));
      if (mr != null) {
        try {
          int phraseIndex = int.parse(mr.group(1));
          markedString.consume(mr.group(0).length);
          return new ChordSectionLocation(sectionVersion,
              phraseIndex: phraseIndex);
        } catch (nfe) {
          throw nfe.getMessage();
        }
      }
    }
    return new ChordSectionLocation(sectionVersion);
  }

  ChordSectionLocation nextMeasureIndexLocation() {
    if (!hasPhraseIndex || !_hasMeasureIndex) return this;
    return new ChordSectionLocation(_sectionVersion,
        phraseIndex: _phraseIndex, measureIndex: _measureIndex + 1);
  }

  ChordSectionLocation nextPhraseIndexLocation() {
    if (!hasPhraseIndex) return this;
    return new ChordSectionLocation(_sectionVersion,
        phraseIndex: _phraseIndex + 1);
  }

  @override
  String toString() {
    return getId();
  }

  String getId() {
    if (id == null) {
      if (labelSectionVersions == null)
        id = _sectionVersion.toString() +
            (hasPhraseIndex
                ? _phraseIndex.toString() +
                    (_hasMeasureIndex ? ":" + _measureIndex.toString() : "")
                : "");
      else {
        StringBuffer sb = new StringBuffer();
        for (SectionVersion sv in labelSectionVersions) {
          sb.write(sv.toString());
          sb.write(" ");
        }
        id = sb.toString();
      }
    }
    return id;
  }

  bool get isSection => hasPhraseIndex == false && _hasMeasureIndex == false;

  bool get isPhrase => hasPhraseIndex == true && _hasMeasureIndex == false;

  bool get isMeasure => hasPhraseIndex == true && _hasMeasureIndex == true;

  SectionVersion get sectionVersion => _sectionVersion;
  SectionVersion _sectionVersion;
  Set<SectionVersion> labelSectionVersions;

  int get phraseIndex => _phraseIndex;
  int _phraseIndex;
  bool hasPhraseIndex;

  int get measureIndex => _measureIndex;
  int _measureIndex;

  bool get hasMeasureIndex => _hasMeasureIndex;
  bool _hasMeasureIndex;

  ChordSectionLocationMarker get marker => _marker;
  ChordSectionLocationMarker _marker;
  String id;

  static final RegExp numberRangeRegexp = RegExp("^(\\d+):(\\d+)");
  static final RegExp numberRegexp = RegExp("^(\\d+)");
}
