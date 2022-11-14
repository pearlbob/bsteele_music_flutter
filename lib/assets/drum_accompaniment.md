# Drum Accompaniment

Feature:  Add a drum track to auto playback.

## Drum Part:

* Bass
* Snare
* Floor Tom
* Medium Tom
* High Tom
* Closed Hi Hat
* Open Hi Hat
* Ride Cymbal
* Crash Cymbal
* Cow Bell
* Rimshot
* Sticks
* Clap
* Shaker
* etc.

Drum parts are limited only by the number of recordings we are willing to make.
Controls will be limited to the active parts to limit the visual clutter of the UI.

## Drum Part Timing

Initial resolution: 1/4 of a beat expressed as: 1, 1e, 1and, 1a for all the beats.

## Drum Track Cycle

A collection of drum parts and their timings through the cycle of the drum
track. Initially this cycle will only be a single measure.

## Time Signature

All drum accompaniments should be applicable to all time signatures. These are
currently: 2/4, 3/4, 4/4, and 6/8. This might not work musically but from an
application perspective, it should always function.

We will need to empirically work out how say a 4/4 pattern is applied to a 6/8 song.
I'm thinking that reasonable mappings will prove useful.

## Song Sections

Drum accompaniments may have multiple drum track cycles for specific sections of the song.

* A default section will be the default on accompaniment entry. This pattern will
  play through all sections of the song unless overridden by the specific selections.
* A list of sections that specific drum track cycles should be played on.

## Drum Accompaniment Name

An arbitrary name can be given to identify the accompaniment for future use.
Likely they will be given a unique name by the application if the name
is not specified.

## Drumming Style

This indicates the style of the accompaniment to allow it to be identified
and attached to appropriate songs more easily.

* Rock and Pop
* Blues
* Jazz
* Reggae
* Latin
* Punk
* Metal
* etc.

## Metadata match

Drum accompaniments can be assigned to song metadata to automatically
be selected for songs with metadata but without an attached drum accompaniment.
For example, a hard driving accompaniment may be attached to the Genre:Metal
metadata so can be attached to metal songs without too much user input.

## Drum Volume

Available in software to limit drum volume.

## Future Additions

* Pushes
* Triples
* Swing degree
* Ahead or behind the beat
* Multiple measure patterns for Latin rhythm patterns and the like
* Humanization from multiple recordings of the same part
* Humanization from small variations in timing
* Humanization from small variations in volume

