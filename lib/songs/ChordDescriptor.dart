
import 'ChordComponent.dart';

/**
 * The modifier to a chord specification that describes the basic type of chord.
 * Typical values are major, minor, dominant7, etc.
 * <p>
 * Try:  https://www.scales-chords.com/chord/
 */
 class ChordDescriptor {
  //  longest short names must come first!
  //  avoid starting descriptors with b, #, s to avoid confusion with scale notes
   /// Dominant 7th chord with the 3rd replaced by the 4th. Suspended chords are neither major or minor.
  static final ChordDescriptor sevenSus4 = ChordDescriptor._("7sus4", "R 4 5 m7");
//sevenSus2("7sus2", "R 2 5 m7"),
//sevenSus("7sus", "R 5 m7"),
//
//maug("maug", "R m3 3 #5"),
//dominant13("13", "R 3 5 m7 9 11 13"),
//dominant11("11", "R 3 5 m7 9 11"),
//mmaj7("mmaj7", "R m3 5 7"),
   static final ChordDescriptor minor7b5 = ChordDescriptor._("m7b5", "R m3 b5 m7");
//msus2("msus2", "R 2 m3 5"),
//msus4("msus4", "R m3 4 5"),
//add9("add9", "R 2 3 5 7"),
//jazz7b9("jazz7b9", "R m2 3 5"),
//sevenSharp5("7#5", "R 3 #5 m7"),
//flat5("flat5", "R 3 b5"),
//sevenFlat5("7b5", "R 3 b5 m7"),
//sevenSharp9("7#9", "R m3 5 m7"),
//sevenFlat9("7b9", "R m2 3 5 7"),
//dominant9("9", "R 3 5 m7 9"),
//six9("69", "R 2 3 5 6"),
//major6("6", "R 3 5 6"),
//diminished7("dim7", "R m3 b5 6"),
//dimMasculineOrdinalIndicator7("º7", "R m3 b5 6", diminished7),
   static final ChordDescriptor diminished = ChordDescriptor._("dim", "R m3 b5");
//diminishedAsCircle("" + MusicConstant.diminishedCircle, "R m3 b5", diminished),
//
//augmented5("aug5", "R 3 #5"),
//augmented7("aug7", "R 3 #5 m7"),
//augmented("aug", "R 3 #5"),
//suspended7("sus7", "R 5 m7"),
//suspended4("sus4", "R 4 5"),
//suspended2("sus2", "R 2 5"),
//suspended("sus", "R 5"),
//minor9("m9", "R m3 5 m7 9"),
//minor11("m11", "R m3 5 m7 11"),
//minor13("m13", "R m3 5 m7 13"),
//minor6("m6", "R m3 5 6"),
//
//major7("maj7", "R 3 5 7"),
//deltaMajor7(""+MusicConstant.greekCapitalDelta, "R 3 5 7", major7),
//capMajor7("Maj7", "R 3 5 7", major7),
//
//major9("maj9", "R 3 5 7 9"),
//maj("maj", "R 3 5"),
//majorNine("M9", "R 3 5 7 9"),
//majorSeven("M7", "R 3 5 7"),
//suspendedSecond("2", "R 2 5"),     //  alias for  suspended2
//suspendedFourth("4", "R 4 5"),      //  alias for suspended 4
//power5("5", "R 5"),  //  3rd omitted typically to avoid distortions
//minor7("m7", "R m3 5 m7"),
   static final ChordDescriptor dominant7 = ChordDescriptor._("7", "R 3 5 m7");
   static final ChordDescriptor minor = ChordDescriptor._("m", "R m3 5");
//capMajor("M", "R 3 5"),
//dimMasculineOrdinalIndicator("º", "R m3 b5", diminished),
//
///**
// * Default chord descriptor.
// */
   static final ChordDescriptor major = ChordDescriptor._("", "R 3 5");

ChordDescriptor._(String shortName, String structure, {this.alias}) {
  this.shortName = shortName;
  chordComponents = ChordComponent.parse(structure);
}


//
//static final ChordDescriptor parse(String s) {
//return parse(new MarkedString(s));
//}
//
///**
// * Parse the start of the given string for a chord description.
// *
// * @param markedString the string buffer to parse
// * @return the matching chord descriptor
// */
//static final ChordDescriptor parse(MarkedString markedString) {
//if (markedString != null && !markedString.isEmpty()) {
//final int maxLength = 10;  //  arbitrary cutoff, larger than the max shortname
//String match = markedString.remainingStringLimited(maxLength);
//for (ChordDescriptor cd : ChordDescriptor.values()) {
//if (cd.getShortName().length() > 0 && match.startsWith(cd.getShortName())) {
//markedString.consume(cd.getShortName().length());
//return cd.deAlias();
//}
//}
//}
//return ChordDescriptor.major; //  chord without modifier short name
//}
//
//public static final ChordDescriptor[] getOtherChordDescriptorsOrdered() {
//  return otherChordDescriptorsOrdered;
//}
//
//public static final ChordDescriptor[] getPrimaryChordDescriptorsOrdered() {
//  return primaryChordDescriptorsOrdered;
//}
//
//
//public static final ChordDescriptor[] getAllChordDescriptorsOrdered() {
//  return allChordDescriptorsOrdered;
//}
//
///**
// * The short name for the chord that typically gets used in human documentation such
// * as in the song lyrics or sheet music.  The name will never be null but can be empty.
// *
// * @return short, human readable name for the chord description.
// */
//public final String getShortName() {
//return shortName;
//}
//
//public final int getParseLength() {
//return shortName.length();
//}
//
///**
// * Returns the human name of this enum.
// *
// * @return the human name of this enum constant
// */
//@Override
//public String toString() {
//  if (shortName.length() == 0)
//    return name();
//  return shortName;
//}
//
//public final String chordComponentsToString() {
//StringBuilder sb = new StringBuilder();
//
//boolean first = true;
//for (ChordComponent cc : chordComponents) {
//if (first)
//first = false;
//else
//sb.append(" ");
//sb.append(cc.getShortName());
//}
//return sb.toString();
//}
//
//public final TreeSet<ChordComponent> getChordComponents() {
//return chordComponents;
//}
//
//public final ChordDescriptor deAlias(){
//if ( alias!= null)
//return alias;
//return this;
//}
//
 String shortName;
 List<ChordComponent> chordComponents;
 ChordDescriptor alias;
//
//private static final ChordDescriptor[] primaryChordDescriptorsOrdered = {
////  most common
//major,
//minor,
//dominant7,
//};
//private static final ChordDescriptor[] otherChordDescriptorsOrdered = {
////  less pop by shortname
//add9,
//augmented,
//augmented5,
//augmented7,
//diminished,
//diminished7,
//jazz7b9,
//major7,
//majorSeven,
//major9,
//majorNine,
//minor9,
//minor11,
//minor13,
//minor6,
//minor7,
//mmaj7,
//minor7b5,
//msus2,
//msus4,
//flat5,
//sevenFlat5,
//sevenFlat9,
//sevenSharp5,
//sevenSharp9,
//suspended,
//suspended2,
//suspended4,
//suspendedFourth,
//suspended7,
//sevenSus,
//sevenSus2,
//sevenSus4,
//
////  numerically named chords
//power5,
//major6,
//six9,
//dominant9,
//dominant11,
//dominant13,
//};
//private static final ChordDescriptor[] allChordDescriptorsOrdered;
//
//public static final String generateGrammar() {
//StringBuilder sb = new StringBuilder();
//sb.append("\t//\tChordDescriptor\n");
//sb.append("\t(");
//boolean first = true;
//for (ChordDescriptor chordDescriptor : ChordDescriptor.values()) {
//sb.append("\n\t\t");
//String s = chordDescriptor.shortName;
//if (s.length() > 0) {
//if (first)
//first = false;
//else
//sb.append("| ");
//sb.append("\"").append(s).append("\"");
//}
//sb.append("\t//\t").append(chordDescriptor.name());
//
//}
//sb.append("\n\t)");
//return sb.toString();
//}
//
//static {
////  compute the ordered list of all chord descriptors
//ArrayList<ChordDescriptor> list = new ArrayList<>();
//for (ChordDescriptor cd : primaryChordDescriptorsOrdered) {
//list.add(cd);
//}
//for (ChordDescriptor cd : otherChordDescriptorsOrdered) {
//list.add(cd);
//}
//allChordDescriptorsOrdered = list.toArray(new ChordDescriptor[0]);
//}
}
