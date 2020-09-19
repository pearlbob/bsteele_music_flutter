import 'package:bsteele_music_flutter/util/screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_markdown/flutter_markdown.dart'  as md;

import '../main.dart';

/// Display the application's privacy policy
class Documentation extends StatefulWidget {
  const Documentation({Key key}) : super(key: key);

  @override
  _State createState() => _State();
}

class _State extends State<Documentation> {
  @override
  initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    ScreenInfo screenInfo = ScreenInfo(context);
    final double fontSize = screenInfo.isTooNarrow ? 16 : 24;

    TextStyle style = TextStyle(color: Colors.black87, fontSize: fontSize);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'bsteele Music App Documentation',
          style: TextStyle(
              color: Colors.black87,
              fontSize: fontSize,
              fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: DefaultTextStyle(
        style: style,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
            padding:  EdgeInsets.all(8.0),
          child:  Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              textDirection: TextDirection.ltr,
              children: <Widget>[
            md.MarkdownBody(
              styleSheet: md.MarkdownStyleSheet(textScaleFactor:  isNotPhone ? 2 : 1),
                data: '''
# General File Specification
All songs are stored in files with the ".songlyrics" file name extension.
The file format is compliant with JSON (https://www.json.org/). 
Note that this includes escaping all appropriate characters. 
This includes characters like '"', '\', '/', and other special characters.

Multiple songs can be written in a single file as a JSON array of songs.

File information for songs can be written as a JSON object with the following name/value pairs:

| Name |	Type |	Value Description
|------|-------|----------------------------------------------------
|file	|JSON String|	File name of the song's file as it exists in the local operating system.
|lastModifiedDate|JavaScript JSDate|The number of milliseconds from since the Unix epoch (00:00:00 UTC on 1 January 1970). See javascript File.lastModified.
|song|	JSON object|	The song attributes as described below.
|song|	JSON object|	The song attributes as described below.


Musical notes or keys can be noted with either the lowercase 'b' or the Unicode music flat sign '♭' (U+266D).
Musical notes or keys can be noted with either the sharp '#' or the Unicode music sharp sign '♯' (U+266F).

Song unique identifiers are built from the song's title and artist without concern for capitalization or white space. Songs with the same song id will be over written by new songs.

# Song Specifications
Song attributes for songs are be written as a JSON object with the following name/value pairs:

| Name |	Type |	Value Description	| Notes |
|----|----|:------------------:|---|
| title |	JSON String |	The song's title as the user would know it. |For search purposes, titles beginning with "The" will have the preposition swapped to the end of the title after a comma.|
artist|	JSON String|	The artist of the song.	|For search purposes, artist names beginning with "The" will have the preposition swapped to the end of the title after a comma.|
lastModifiedDate|	JavaScript JSDate	|The number of milliseconds from since the Unix epoch (00:00:00 UTC on 1 January 1970). This represents the last time the song (not the file) was modified. See javascript File.lastModified.	|
copyright	|JSON String	|The copyright notice of the owner.	|Copyrights are often difficult to find and may not be proper legally. I would appreciate all users to provide a reasonable effort to find the proper copyright. At the moment, the software only insists that it be non-null. Please do make an effort. If you Google the song title plus the word "lyrics", Google will often provide a copyright.
key|	JSON String|	The major key the song is provided in designated as one of the following: G♭, D♭, A♭, E♭, B♭, F, C, G, D, A, E, B, F♯|	This will be extended to minor keys eventually.
defaultBpm	|integer	|The song's default beats per minute, i.e. the song's tempo.	|The term default indicates my intention to eventually allow section tempo changes. Currently the tempo is restricted between 50 and 400 BPM inclusive.
timeSignature|	int + "/" + int|	The song's time signature in the common form of the number of beats in a measure over which note value gets the beatbeats per minute.|	Known signatures include "2/4", "3/4", "4/4" (the default), and "6/8".
chords|	JSON array of strings|	The song's chord structure written in the chord markup language described below.	|Generally speaking, each string represents the section identifiers and chords as they are to be presented to the user. Do not include the carriage return or newline character within the quoted JSON lines. The application may adjust their presentation.
lyrics|	JSON array of strings	|The song's lyric sections written in temporal order and in the lyric markup language described below.|	Do not include the carriage return or newline character. The application may adjust their presentation

# Chord Markup Language
The chord markup language typically has a format of:

    (section version? ':' measure*)+

Measures need to be separated from each other by whitespace. There are exceptions for repeats as described below.

# Sections
Sections can be identified by either their name or abreviation as follows:

Name|	Abbreviation	|Formal Name|	Description
|----|----|--------------|---|
intro	|I|	Intro|	A section that introduces the song.
verse	|V	|Verse	|A repeating section of the song that typically has new lyrics for each instance.
preChorus|	PC	|Prechorus|	A section that precedes the chorus but may not be used to lead all chorus sections.
chorus|	C|	Chorus|	A repeating section of the song that typically has lyrics that repeat to enforce the song's theme.
a	|A	|A	|A section labeled "A" to be used in contrast the "B" section. A concept borrowed from jazz.
b	|B	|B	|A section labeled "B" to be used in contrast the "A" section. A concept borrowed from jazz.
bridge|	Br|	Bridge|	A non-repeating section often used once to break the repeated section patterns prior to the last sections of a song.
coda	|Co|	Coda|	A section used to jump to for an ending or repeat.
tag	|T|	Tag|	A short section that repeats or closely resembles a number of measures from the end of a previous section. Typically used to end a song.
outro|	O|	Outro	|The ending section of many songs.

Capitalization is not significant to section identification.

Section versions can be identified by a single digit ( 1 - 9 ) immediately following the section. Sections without a version id will be considered an additional section.

# Measures
Measures are collections of chords meant to be played within the beats defined by the time signature. They are separated by whitespace. Chords not separated by whitespace are meant to be played within the same measure of time. Rules for their sharing of this time across the beats will be described below.

Chords are in the form of:

scaleNote chordDescriptor

A scaleNote is one of: A, A♯, B, C, C♯, D, D♯, E, F, F♯, G, G♯, G♭, E♭, D♭, B♭, A♭, C♭, E♯, B♯, F♭.

A chordDescriptor is one of: 7sus4, 7sus2, 7sus, maug, 13, 11, mmaj7, m7b5, msus2, msus4, add9, jazz7b9, 7#5, flat5, 7b5, 7#9, 7b9, 9, 69, 6, dim7, º7, dim, º, aug5, aug7, aug, sus7, sus4, sus2, sus, m9, m11, m13, m6, maj7, Δ, Maj7, maj9, maj, M9, M7, 2, 4, 5, m7, 7, m, M, º, major. A missing chord descriptor will be understood to be a major chord. Suggestion: choose the button "Show All Chords" above to see all possible chords.

Capitalization is significant to scaleNote identification and chord description.

A part of the measure where no chord is to be played is noted with a capital X. This can also be used to indicate a pause if it is the entire measure. Note that X chords cannot have a chord descriptor.

Note: Annotations for anticipations (pushes) and delays are planned but not part of the markup language as yet.

A measure followed by a slash '/' and a chord without whitespace will be interpreted as an inversion over the measure. This typically is a note played by the bass or piano but no other instrument.

In a measure with a single chord, it is to be played over the entire measure.

In a measure with a multiple chords, the chords are to be played evenly over the measure. When is this not the intention, periods '.' can be used to repeat the prior chord for one more beat. The number of chords and repeats should total to the number of beats per measure.

A measure defined by a single minus sign '-' is to be a repeat of the prior measure.

# Repeats
A measure line that ends with a 'x' and a number is a repeat. The line is to be repeated the number of counts indicated by the number.

A repeat can also be represented by bracketed measures followed by an 'x' and a number is a repeat. Bracketed measures start with square bracket '[', have an arbitrary number of measures followed by a closing square bracket ']'. A new line is not required in this case. That is a new collection of measures can lead the bracketing and follow the bracketing. There is no restrictions on the number of measures in the bracketed repeat. The multi-line separator bar '|' should not be used.

For example:

V: D C G G [ D C D D G B D C] x4 B G C G

# Multiline Repeats
If a measure line ends with a vertical bar '|' it will be included with the following line or lines in a repeat. By convention, the last line of the repeat should also have a vertical bar '|' before the 'x' and a number of the repeat. This is consdered a legacy form that will be deprecated and retired in favor of the bracketed format.

Lyric Markup Language
The lyric markup language is of the form:

sectionVersion: lyrics

The sectionVersion is to be the sectionVersion name or abbreviated name as defined above. Section versions used in the lyrics should be defined in the chords. All chord sectionVersions defined should be used in the lyrics.

Note that the parsing makes the use of colon ':' problematic in the general lyrics. Typically it will not happen but the word in front of the colon should not match any of the sectionVersion names. A space in front of the colon will fix all this.

Note that the current implementation requires the sectionVersion to be on it's own line. This restriction will likely be lifted in the future.

# Suggestions
Writing all songs will provide a sample file format for examination. To write all songs, choose Options, Write All Songs. See the button below.

# Notes
Any sequence of measures can be bracketed, if it's a repeat or not. That is started with '[' and ended with ']'. In the near future, these brackeded sequences will be prefixed with indicators controlling the number of columns to be used in their display representation and other preferences.
            ''')
              ]),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pop(context);
        },
        tooltip: 'Back',
        child: Icon(Icons.arrow_back),
      ),
    );
  }
}
