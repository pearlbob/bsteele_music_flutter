import '../util.dart';
import 'Section.dart';

/// A version identifier for multiple numerical variations of a given section.
class SectionVersion implements Comparable<SectionVersion> {
  /// A convenience constructor for a section without numerical variation.
  SectionVersion.bySection(this._section)
      : version = 0,
        name = _section.abbreviation;

  /// A constructor for the section version variation's representation.
  SectionVersion(this._section, this.version)
      : name = _section.abbreviation + (version > 0 ? version.toString() : "");

  static SectionVersion getDefault() {
    return new SectionVersion.bySection(Section.get(SectionEnum.verse));
  }

  static SectionVersion parseString(String s) {
    return parse(new MarkedString(s));
  }

  /// Return the section from the found id. Match will ignore case. String has to
  /// include the : delimiter and it will be considered part of the section id.
  /// Use the returned version.getParseLength() to find how many characters were
  /// used in the id.

  static SectionVersion parse(MarkedString markedString) {
    if (markedString == null) throw "no data to parse";

    RegExpMatch m = sectionRegexp.firstMatch(markedString.toString());
    if (m == null) throw "no section version found";

    String sectionId = m.group(1);
    String versionId = (m.groupCount >= 2 ? m.group(2) : null);
    int version = 0;
    if (versionId != null && versionId.length > 0) {
      version = int.parse(versionId);
    }
    Section section = Section.getSection(sectionId);
    if (section == null) throw "no section found";

    //   consume the section label
    markedString.consume(m.group(0).length); //  includes the separator
    return SectionVersion(section, version);
  }

  /// Return the generic section for this section version.
  Section getSection() {
    return _section;
  }

  /// Return the numeric count for this section version.
  int getVersion() {
    return version;
  }

  /// Gets the internal name that will identify this specific section and version
  String getId() {
    return name;
  }

  /// The external facing string that represents the section version to the user.
  @override
  String toString() {
    //  note: designed to go to the user display
    return name + ":";
  }

  ///Gets a more formal name for the section version that can be presented to the user.
  String getFormalName() {
    //  note: designed to go to the user display
    return _section.formalName + (version > 0 ? version.toString() : "") + ":";
  }

  @override
  int compareTo(SectionVersion o) {
    if (getSection() != o.getSection()) {
      return getSection().compareTo(o.getSection());
    }

    if (version != o.version) {
      return version < o.version ? -1 : 1;
    }
    return 0;
  }

  Section get section => _section;
  final Section _section;
  final int version;
  final String name;

  static final RegExp sectionRegexp = RegExp("^([a-zA-Z]+)([\\d]*):\\s*,*");
}
