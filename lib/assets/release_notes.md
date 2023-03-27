# bsteeleMusicApp

# Release Notes:

### Contents:

<!-- TOC -->

* [bsteeleMusicApp](#bsteelemusicapp)
* [Release Notes:](#release-notes-)
  * [Contents:](#contents-)
  * [Release 1.2.2](#release-122)
    * [Release Date: Mar  23, 2023](#release-date--mar--23-2023)
    * [Features](#features)
    * [Fixes Completed](#fixes-completed)
  * [Release 1.2.1](#release-121)
    * [Release Date: Mar  18, 2023](#release-date--mar--18-2023)
    * [Features](#features-1)
    * [Fixes Completed](#fixes-completed-1)
  * [Release 1.2.0](#release-120)
    * [Release Date: Mar  3, 2023](#release-date--mar--3-2023)
    * [Features](#features-2)
  * [Fixes Completed](#fixes-completed-2)

<!-- TOC -->

## Release 1.2.2

### Release Date: Mar  23, 2023

### Features

### Fixes Completed

* lost lyrics on specific screen sizes are no longer lost

## Release 1.2.1

### Release Date: Mar  18, 2023

### Features

### Fixes Completed

* automatic selection of next singer should be at the top of the new playlist
* options for click in player screen
* add playlist OR operator on multiple metadata, not just the current implied AND

## Release 1.2.0

### Release Date: Mar  3, 2023

### Features

* drum regularity
* Named drum parts attached to songs
* history from tomcat server log

## Fixes Completed

* bsteeleMusicServer update
* count-in drums and indicator on autoplay
* verify/fix auto playback timing and jitter
* Back to player from song preview on YouTube.com, fullscreen button missing
* Improved startup delay based on history. More is required.
* generate Decade, time signature, key, bpm metadata from the song's year... programmatically.
* drums on 2/4, 3/4, 6/8
* drums in the background while in "manual play" mode. that is, things as they typically are now with drums playing but
  not auto advance nor any indication of the current measure. basically a replacement for your foot pedals.
* browser reload on subsequent pages
* find the closest songId for history songs without non-null song
* Beta fails on song title change from history
* Shari UI: the listed key disappears once you are in play mode
* singer mode: no capo!
* re-download canvaskit on staging
* drum: the default volume should be max.
* grab bar on scroll for song list
* Drum edit preview, with bpm and volume
* In player screen, capo mode can be forgotten inappropriately.
* Metadata list shouldn't scroll after metadata change
* connect player popup volume slider to volume
* A new singer/requester without any songs sung or requested should default to a singer
* followers should never have drum selections




