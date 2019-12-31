import 'LegacyDrumMeasure.dart';

/// Definition of drum section for one or more measures
/// to be used either as the song's default drums or
/// the special drums for a given section.

@deprecated
class LegacyDrumSection {
  /// Get the section's drum measures
  List<LegacyDrumMeasure> getDrumMeasures() {
    return drumMeasures;
  }

  ///Set the section's drum measures in bulk
  void setDrumMeasures(List<LegacyDrumMeasure> drumMeasures) {
    this.drumMeasures = drumMeasures;
  }

  List<LegacyDrumMeasure> drumMeasures;
}
