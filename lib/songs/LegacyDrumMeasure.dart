import 'dart:collection';

enum DrumType { closedHighHat, openHighHat, snare, kick }

/// Descriptor of a single drum in the measure.

class Part {
  /// The drum type for the part described
  DrumType getDrumType() {
    return drumType;
  }

  /// The drum type for the part described
  void setDrumType(DrumType drumType) {
    this.drumType = drumType;
  }

  /**
   * Get the divisions per beat, i.e. the drum part resolution
   *
   * @return divisions per beat
   */
  int getDivisionsPerBeat() {
    return divisionsPerBeat;
  }

  /**
   * Set the divisions per beat, i.e. the drum part resolution
   *
   * @param divisionsPerBeat divisions per beat
   */
  void setDivisionsPerBeat(int divisionsPerBeat) {
    this.divisionsPerBeat = divisionsPerBeat;
  }

  /**
   * Get the description in the form of a string where drum hits
   * are non-white space and silence are spaces.  Resolution of the drum
   * description is determined by the divisions per beat.  When the length
   * of the description is less than the divisions per beat times the beats per measure,
   * the balance of the measure will be silent.
   *
   * @return the string encoded drum description
   */
  String getDescription() {
    return description;
  }

  /**
   * Set the drum part description
   *
   * @param description the string encoded drum description
   */
  void setDescription(String description) {
    this.description = description;
  }

  DrumType drumType;
  int divisionsPerBeat;
  String description;
}

/// Descriptor of the drums to be played for the given measure and
/// likely subsequent measures.

@deprecated
class LegacyDrumMeasure {
  /**
   * Get all parts as a map.
   *
   * @return all parts as a map
   */
  Map<DrumType, Part> getParts() {
    return parts;
  }

  /**
   * Get an individual drum's part.
   *
   * @param drumType the selected part's type
   * @return the drum's part
   */
  Part getPart(DrumType drumType) {
    return parts[drumType];
  }

  /**
   * Set an individual drum's part.
   *
   * @param drumType the selected part's type
   * @param part     the part descriptor
   */
  void setPart(DrumType drumType, Part part) {
    parts[drumType] = part;
  }

  HashMap<DrumType, Part> parts;

  //  legacy stuff
  //
  String getHighHat() {
    return highHat;
  }

  void setHighHat(String highHat) {
    this.highHat = (highHat == null ? "" : highHat);
    _isSilent = null;
  }

  String getSnare() {
    return snare;
  }

  void setSnare(String snare) {
    this.snare = (snare == null ? "" : snare);
    _isSilent = null;
  }

  String getKick() {
    return kick;
  }

  void setKick(String kick) {
    this.kick = (kick == null ? "" : kick);
    _isSilent = null;
  }

  bool isSilent() {
    if (_isSilent == null)
      _isSilent = !(regExpHasX.hasMatch(highHat) ||
          regExpHasX.hasMatch(snare) ||
          regExpHasX.hasMatch(kick));
    return _isSilent;
  }

  @override
  String toString() {
    return "{" + highHat + ", " + snare + ", " + kick + '}';
  }

  String highHat = "";
  String snare = "";
  String kick = "";
  bool _isSilent;
  static final RegExp regExpHasX = RegExp(".*[xX].*");
}
