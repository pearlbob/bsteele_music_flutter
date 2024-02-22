# bsteeleMusicApp bug list

# Release Planning:

## Release 1.2.6

### Release Date:

### Features

### Fixes Completed

### Fix

* text entry for bpm, remove dropdown
* nashville beat dots as an option
* Resume on next section after pause

* pause/play: jump row/section past the end of the song shouldn't happen
* random position on: First song selected not taken: double build
* mac bounce at play start
* Chords should be on lyrics line
* Need to see last section chords while on next
* player in stop, scrolling should not scroll away the key select
* fix Measure.reducedTopDots, make it an option

* player, stopped: arrows should move by section
* player leader mouse scroll location followed?

* simplified chords option: Major, minor, dom7
* autoplay does not count in
* autoplay temporal accuracy in terms of BPM
* scrolling should not stop on a given line
* player font size slider

* player top section a mess graphically on smaller screens
* visit the complexity calculations

* follower song location is not reset on a change of song
* Eliminate song views (only) from history

* I shall be released x2 required
* Drums during tempo change while playing
* As requester with blue square fill
* Random scroll location for songlist on start
* eliminate initial bounce at startup: chrome on mac only?, follower?
* player, follower: no display adjustment popup
*
* sort file read find by modification date
* add local songlist on single button
* replace songlist with local list on a single button
* Hear bpm when changing (temp drums)
* Eliminate song views from history so only playings are in the list
* Data on bpm during play pause
* Song "I shall be released" x2 required
* Stop scrolling if last is seen
* scroll lyrics lines if too many?

* More space between chords
* Centered chords in blocks?
* Scroll to the middle of the screen
* Marker at the middle of the screen? when no indicator of position
* order playlist by most sung
* order playlist by least sung
* Make complexity categories
* override complexity category by metadata, provide computed complexity value as well
* differentiate new songs from edited songs (use github history if required)  originalEntryTime

* explain "clear all local options" prior to action, confirm action
* song title, artist or cover artist change impact on history is too manual
* show relative minor keys and major keys
* missing copyright notice should be release & label
* add musicnotes.com link to edit page
* minor vs major key mapping on edit page
* all8.com/tools/bpm.htm
* beat dots on Nashville don't work
* singer chords are not correct on short beat measures
* tap to bpm on edit page
* pushes needed?
* redo charts: 2 to 4 or 4 to 2
* keys on a per section basis
* look at https://www.beatsperminuteonline.com
* edit: auto-validate more often
* edit: chords on lyrics: can be 'null' how?
* edit: alignment of chords in lyrics section, example: Mr. Jones,
  likely based on extra line based on blank at end of lyrics or chords,
  better when validated
* pause/play indicator
* Initial bump down on Mac at play start
* investigate all dot beats in all songs
* investigate the display solution used in Nashville notation.
* metadata filters should have a generated filter for singers
* tell the user why the "new songs" option is missing
* tell the user why editing is not available (too narrow or following)
*

theory: https://www.orange.k12.nj.us/site/handlers/filedownload.ashx?moduleinstanceid=4691&dataid=19752&FileName=concertpitchchart.pdf

* Make the following obvious when asking for play or edit
* Been getting requests to see the difference between new song additions
  vs edited songs. Is there a way to mark a new one?
  I'm fine marking this on the edit page, then it times out after two weeks...
* option to remove triangle indicator
* smooth scroll vs line by line in player scroll
* player: stop button at play button location on the upper left
* player: minimum play mode data on the right, max row transparency
* player: remove tally icon in menu bar
* player: remove drum and host tally in all but the widest displays
* be able to specify a 3 beat measure in a 4/4 song: e.g. D.A not D.A.
* player and guitar chord sounds in edit page, show notes in chords, A/B buttons, include inversions
* song filters based on chord descriptors
* piano fingerings
* guitar fingerings
* bpm feedback
* bpm "change in motion" indicator
* slide chords in repeat section when not expanded
* up arrow: next section, after end of current?
* down arrow: next section
* right arrow: faster bpm
* left arrow: slower bpm
* follow at row resolution
* song search should ignore commas
* Bass songs
* icon vertical alignment in row with baseline text
* Keep with consistent "first letter capitalized" rule in all menus, including Order menu
* list guess on drums should only suggest drums
* history playlist count should only count performances, not all displayed rows
* history statistics: singer attendance by month, performance count, repeats, top 40 songs
* Singer gender?
* chords used in the song at the top of song display
* chords don't align properly in the edit lyrics area when there is
  a vertical space at the end of the lyric section entry.
* don\'t put spaces at the end of chord rows in player display
* clearing song requests requires a browser cache clear
* drum edit interaction should be improved
* lib/assets/release_notes_head and tail should not be in a .war file
* edit: chords on lyrics not up to date until after validate?
* move follower key offset to options page
* make the user edit field a "regular" field, so any change can be undone or saved. Update the field only if unknown.
* And it seems to want to default to my last name change,
  rather than a default of my name - not sure if that is definable.
* Metadata fields are caseless. The software will Capitalize All Fields As Required.
* visual delay on Mac mini? Just off, slow. correct when measured post render.
* Mute button? Display and keyboard shortcut
* regenerate generated metadata after editing
* playlist: change of screen from menu item, change of order,
  or change of filter should focus on the empty search text
* Time the player selected measure in autoplay mode: adjust timing if required
* Improve startup delay.
* Search for song on web with & in the title
* drum select vs drum edit in drums from player: turn off editing when one drum is saved
* drum edit, no-write, safety popup
* Drums: All caps first letter yes
* Drums on in idle: synchronized song start? Yes, if required.
* Live bpm changes? First "1": phase only, subsequent 1's are tempo,
* Live bpm changes: Smoothing?,. Real-time delay
* Live beat 1 reset: Does NOT imply new bpm
* Test tap to tempo... Jittery or me?
* drums in pause, then play
* video alignment with audio current time

## Release 1.3

### Features

* history statistics: songs sung by singer, cj top 40
* bsteeleBassBox recording
* drums completion push!  shaker, rimshot
* banner display mode (lyric to measure mapping)
* named & stored drum accompaniments (basic), drums to json, standard drum list
* better documentation screen structure
* export csv songlist(s) for the CJ website from the app
*
    * edit web lookups: tapbpm.com (or tap to tempo on page)
* feature to simplify chords: Fm7 to Fm
* chord section list on pro-input?
* edit: convert song 4/4 to 2/4 and back again

## Release 1.4

### Features

* recording displayed in banner display mode
* recording playback
* looping
* piano chords one ear, mp3 in other

### Bugs

* Finish UI debug mode: input logging, replay, programmatic testing.
* minor key song entry (when chosen, include relative Major)
* theory page: circle of fifths
* drum audio recording quality?
* song not selected on main list after a file read and return to main list
* save last valid edit version in shared_preferences: store the undo list?
* flutter.js: Exception while loading service worker: Error: Service worker not supported (or configured).

## Release 1.5

### Features

* banner mode editing, including lyrics adjustments
* noise to notes in banner
* sheet music in banner
* octaves in bsteeleBox

# Bugs

### Shari UI stuff:

* Shari UI: 3 compress/expand modes:  compressed, expanded, as transcribed
* Shari UI: easy move from player to singer
* Shari UI: the back button doesn't take you to where you just were in the list ( mostly fixed )
* Shari UI: When one clicks a play button at the top left and then suddenly doesn't see a stop button next to it
* Shari UI: two back buttons
* Shari UI: buttons too close
* Shari UI: scroll to chord line on scroll
* Shari UI: aim a little low on a large section i.e. always show next section first row (approximate)
* Shari UI: more on follower display when leader is not playing a song
* Any way to allow zoom on play screen so one might read the lyrics?
* Browsing our list is super unfriendly without sorting function
* If the phone version cannot be user-friendly, I suggest we redirect users to a webpage like the searchable,
  sortable Beginner list generated from the spreadsheet. http://communityjams.org/index.php/beginner-jam-song-list/

### Shari:

* Bb/CCX Bb/CCX - two beats of Bb and a stab on the C. But the app insists on adding a dot to the Bb like this: Bb./CCX
  Bb./CCx Still can't put in the X after the C without it forcing a dot, but it will work.

I continue to have intermittent trouble if I have to scroll back up during the play mode. Here is the sequence:

1. First enter play mode, then use space bar to advance
2. After 1-3 space bar advances, manually scroll up, but not all the way to the top. It doesn't ever glitch if I go all
   the way back up.
3. Once I force it to scroll up to the top and play again, it doesn't seem to glitch again until I load another song.
4. This may take 2-4 attempts to break, not dependent on complexity.
5. It requires the scroll-up to break - never breaks if I simply play it straight through with the space bar.

new section

1. If we normally use Player mode to play charts, there is no reason not to freeze the row of buttons at the top when
   not in Player mode.
   We can scan down the song and not have to scroll back and forth/up and down to determine where there are potential
   problems before performing.

2. Bodhi is swinging back to wanting some of the more musically dense songs charted in 2, which makes sense for
   readability and therefore playability.
   In fact, it would be nice if he could mark this type of timing edit in a special way, since it comes up more than
   other issues.
   Is there a way to mark the 'type' of edit - as in timing change versus content change?

3. I have a feeling I may need two sets of some charts, in 2 or 4, in case we need to move in the other direction as in
   the past.
   Is there a way to do this programmatically?

4. Technically, I have been looking at a lot of sheet music and most of our 2-time charts are not technically in 2/2 or
   2/4 (bouncy folk timing),
   so I suggest that the app should not specifically refer to "time signature" if we want to spread out the chords and
   make charts more jam-friendly.

It is difficult to find an alternative that does not confuse. One article I found refers to harmonic rhythm, but that is
too long a term.
https://www.ars-nova.com/Theory%20Q&A/Q5.html

I believe the most appropriate term for us to use is beats per measure, rather than time signature.
Since that confuses with the common term bpm (beats per minute), perhaps we can switch our bpm to "tempo" and switch our
time to "b/m"?
That would give us more freedom to chart songs with our desired simple beats per measure and not be limited by the
formal
and occasionally inaccurate use of "time signature."
With b/m, we might even add the elusive 3-5 to the list - the 3-5 beat pattern that is not actually a real time
signature but keeps coming up on songs without any reference on the chart.

I also try to keep tempo within the industry standards. Here is another reference for that:
https://songbpm.com/searches/ce40775f-0d09-496b-89c1-403d48591227

I need these types of guidelines so I am not forced to make arbitrary decisions while charting.
I am not clear how Bodhi calculates his tempo, but sometimes it is outside of these standards, so I will need to discuss
this with him.

We cannot obtain proper "Copyright" information so I suggest we name the field properly until we can.
I suggest that we use the term "Credit" instead, rather than mislead the audience about copyright.

## New Features

* Bodhi's idea: Involves data and random numbers and games and music. And fun.
* personal list for individuals. by individuals from emailed lists to jam leader?
* singer mode: section title, first 3 measures then ellipsis
* roll list start when returning to song list vs back to the same location
* edit: paste from edit buffer
* Method to search library for desired songs: UI sketches

## Playful ideas

* song selection: name part name
* playing songs in wrong genre

* simply button: simplified chords, no slash notes,

## General Fixes

* metadata entry for drum parts
* fix linux run from compile: 'FlutterEngineInitialize' returned 'kInvalidArguments'.
  Not running in AOT mode but could not resolve the kernel binary.
* Local song history, independent of CJ
* fix key guess
* edit: assisted edit slash note dropdown: make smarter
* default empty singer songs and requests to singer add
* edit a song that's on the history list, what version gets shown when?

* singer setup: click on singer label should toggle session membership
* leader shouldn't be allowed to have a key offset
* edit metadata from the edit screen
* data management documentation
* very small screen chord & lyrics fontsize
* singer requester editing not remembered...immediately
* undo-redo in metadata editing
* metadata editing change summary, file read change summary
* random songlist locations on startup
* random songlist locations on search clear
* very small screens, chord font size is too large relative to lyrics
* very small screens, menu title stuff too large
* PlayList:  song count on bottom?
* fix history song count to show only displayed songs
* Singer mode chords proportional to chord font, limit length
* add the closest matches if songlist is empty on search

* Follower display while leader choosing a song
* test singer and requester on one singer/requester
* Jumping jack flash, fix in bloom,
* silly love songs spacing ,
* master scroll got lost(after space? Likely after open link)
* re-locate on change of display mode or repeat expansion
* the blank spacing between the section and the lyrics is a problem
* re-search main list on song file read

* triples in the drums
* show lists to followers (main and singer)
* jump to current follow location without motion from leader at signup

* button to adjust leader/follower when dis-connected

* put DNS on the pi to ease the configuration. Say "park.local" instead of "192.168.1.205"

* F# and gb,. # override for guitar players (not persistent)
* notes for song transcriptions,
* pop songs from history list:  i.e. CJ top 40

* play tally off space bar: what? Do I have to pay attention?....
* freezing? do you mean always displaying the play button, key and beats per measure? capo is in that category. Bodhi
  wants to change bpm while in play.
* share the "sung by" in the follower update
* eliminate singer needs a song requirement

* improve player: Tap to tempo, follow space bar to beat 1
* verify full validation of song before entry
* Capitalization of username?
* get real file name of written file for confirmation message
* player scroll to top doesn't on songs with big intros and short verticals: bohemian rhapsody

* first singers list doesn't showup on message section when all singers are written

* this is likely wrong:  void _readExternalSongList() async { if (appOptions.isInThePark()) ...


* suggested solo notes and scales
* white rabbit no f sharp, no indicator
* Read of files by dmg from web version


* singers: purge singer without them coming back from the web site
* in edit: show diff with similar song
* edit "pro-mode", canvas copy and paste for chords and lyrics
* edit lyrics: not updated!  should be on timeout like chords?
* edit lyrics: one blank row is now two? at section end?
* messages for file task completions or failures.
* mac native:  desktop app couldn't get I Shall Be Released to save in the key of E

* For me, key change creates a duplicate chart. And then looks like it keeps key change UNTIL you get rid of old
  version. Very weird.
* map accented characters to lower case without accent: "Exposé" should match "expose"   dart package diacritic

* research if the song id is case-sensitive: e.g.: "I shall be released" vs "I Shall Be Released". YES!

* studio instructions for personal tablets

* lyrics for a section in one vertical block?
* verify blank lyrics lines force position in lyric sections
* expanded repeat player, no x, no repeat #

* edit: change of title, artist or cover artist should trigger a comparison at song collisions


* 3 beat bars in 2/4? 3 beat bars in 4/4? one beat bars in 2/4?

* player: validate follower accuracy
* player: Intro and solo repeats
* player: Dynamic Tempo adjustments
* player: Metronome audio
* player: Bouncing ball, accuracy
* player: Guitar and/or piano chords audio
* sheetMusic: Read mp3 audio
* sheetMusic: Display mp3 with chords and zoom
* sheetMusic: Align drag and drop editing
* sheetMusic: N2N processing
* sheetMusic: Chord and slash suggestions
* sheetMusic: Looping playback
* sheetMusic: Variable tempo?
* sheetMusic: Drum machine
* sheetMusic: evaluate Performance
* sheetMusic: Automated song transcription

* edit: transpose song to new key

* key guess
* close gap between lyrics lines on player
* lyrics, jump left right based on pinching the chords
* vertical bars to split lyrics into measures
* play screen freeze top when not in play mode
* Nashville notation for leading lyrics
* not all lyrics changes get proper notification

* file differences on song file read as opposed to assuming all is well
* args from screens on url end keeps app from reloading
* metronome just as a resource for editing screen

* disable player tooltips when in follow mode


* select by last change should jump to top
* very old songs: dec 31, 1969 30+ songs, some have been edited

* edit chords at lyrics section
* space in front of lyrics in hopes of being able to select the first character from the left
* Random song order on singers list
* option to turn off the click to advance feature of the player screen,
* deletes returning on restart???
* Singer preselect for the night's songs
* Disable sections for playing
* use subsections for intro
* timing delay of mic to headphones?
* remember: debugger( when: );
* Love song Sara Bareilles in G
* Fix "Not enough", fix "I shall be released"
* Singer demands at least one song
* flutter webview 3.0 has an iframe
* feature: for ninjam: put title, chords in ninjam format for copy/paste to ninjam comment, + /bpm and /bpi
* edit: change title: does not get a new modification date
* If the key was changed on a song, and it is saved, it displays in the previous key instead of the new original key.
  The
  behavior should display as original key.
* main: change to last changed, sticks to last selected song
* edit: disposing of controllers and/or focus nodes fails
* edit: web version: enter doesn't work
* player: time signature always in view if not 4/4
* player: if in play, no tool tips, timeout any current tooltip
* lists: don't select the entry name/value until it's valid
* lists: "write all to file" can appear disabled
* songmetadata thumbs up should eliminate the name:value from thumbs down, and vise-versa
* songmetadata file should delete all prior metadata of same name:value from all songs
* edit: no format errors on section add
* edit: add a measure on a new row doesn't work, entry never appears
* edit repeat add plus's should be in the last column, the one with the repeat count
* repeat brackets and repeat counts should be without background so they don't get too wide based on other measures in
  other rows
* lyrics "instrumental:" blows up
* edit: big blowup if Song.createEmptySong() goes into song on a clear
* edit join/split should only do the following measure
* better websocket response
* player: cancel follow... without losing websocket ip address
* edit: delete section
* next/previous song in list on player
* singer lists, eg. singer:vicki, select and auto add in player
* map song:singer to key for default key next time
* should the leader be able to capo?
* should the leader be able to key offset? no
* edit: measure entry should allow section header declarations
* verify in studio:  let it be in C, cramped on HDMI on Mac,
* on mac + chrome: bold musical flat sign is way ugly
* player chord display elevations trash on mac, b, minor, slash notes
* util: beginner list songlist to google doc format: title, artist, original key
* delete metadata when reading file
* baseline wrong on chrome on mac
* beta: lyrics in one block area
* align all repeats in a single column of the edit screen
* add phrase before first repeat in edit screen section
* add phrase between repeats in edit screen
* can't add repeats
* can't add phrase after a repeat
* edit: recent chords
* edit lyrics entry rows should align to chord rows as they will in the player display
* "I'll Take You There" by "Staple Singers, The": maxLength: 107
* first leader selection not shown
* show header if first section, even in play
* full screen option
* crash on edit clear
* can't append a phrase (measure) after a repeat in edit
* edit speed issues?
* joy to the world, sheet music, measure size error
* edit screen: section id is inline on chords, but above in lyrics
* after an edit change, don't allow navigator pop without admission that edits will be lost
* song diff page
* surrender leadership when leader song update appears
* space in title entry jumps to lyrics Section
* singer mode: first measure after the section

### session stuff:

* in the park: no web list read
* lyrics should correlate to compressed repeats

# References to investigate

* Drumeo
* Moises
* https://www.apronus.com/music/onlineguitar.htm
* https://www.pianochord.org/
* https://www.all8.com/tools/bpm.htm
* https://getsongkey.com/
* https://www.musicnotes.com/  sheet music in pdf pro-version?
* https://www.all8.com/tools/bpm.htm
* jetbrains email: If you want to log program state during debugging, use non-suspending breakpoints. Select the
  expression that you want to log, hold Shift, and click the gutter at the line where the expression should be logged.
  In the example, sent.size() will be logged upon reaching line 24.
* ultimate guitar drum patterns
* chordify
* musicca.com  "bookmark" drum patterns, audio quality?


