# bsteeleMusicFlutter How To:

# Singer

Feature:  Remember individual singers and the songs they sing.

Start:  Main screen, Menu (hamburger), Singer

Initially the page will be in setup mode as indicated by the "Singer Setup" label.
Known singers, based on prior singing will be listed alphabetically in the "All Singers"
section. They can be searched for on the "enter singer search" line.
Select a singer for the current session by clicking the plus sign in the green circle.
Clicking the minus sign from the red circle will remove them from the list of current
session singers. New singers can be added using the "enter a new singer's name" line.
Note: The singer will be forgotten if no song has been associated with the singer prior
to app termination.

By convention, singers are identified by first name and last name initial.

Clicking the toggle or the "Singing" button will move the page from setup to singing mode.
When singing, the current list of singers in the session is shown. The one with the green
background is the selected singer for the moment and their songs will be listed
with the keys they most recently sang them in. Additional songs can be added by
a combination of the song search entry at the page top and scrolling to the "Other songs"
list below their sung songs. Clicking the other song's empty box will add the song to the
singer's list. Songs can be removed from the singer's
list by clicking the checkbox.

# Requester

Start:  Main screen, Menu (hamburger), Singer

BsteeleMusicApp Singer Requester Lesson

## Motivation:

When Community Jams went singer centric, I was frustrated as only a player that I
didn’t get to request songs anymore. I created a requester role that suggests
songs the current singers might sing.

## Functionality:

A requester has a list of favorite songs. When it’s their turn, the requester’s
songs are matched against all the songs the current singers have sung in the past.
These are listed showing the singer, the song and the key the singer last sang the song in.

When a singer volunteers to sing a song, a click on that song displays it
for singing by the singer in the singer’s key. When the song is done, the requester’s turn
has ended and the next singer or requester is shown.

Notice that the singer is logged as having sung the song but has not lost their turn
in the singer list. They might get to sing two songs in a row!

## Create a new requester

1. From the main page, select menu (the hamburger)
2. Select Singers
3. You should be in “Make adjustments” mode. If not, select the “Singing” button or the toggle.
4. Add a new requester as if they were a new singer with “enter a new singer’s name”.
5. Select the new requester to be a current singer by selecting the circled + sign by the requester’s name.
6. They will have the appearance of a singer.
   Add to their list of requests with the following:

## Create a requester’s list

1. Select “Singing” mode.
2. Select the Requester.
3. If they have never requested a song, the “As requester” checkbox will be unchecked.
   Check the “As requester” checkbox.
4. Select the “just {requester} requests” radio button.
5. Songs with a checked checkbox are in the requester’s list, labeled as “Songs {requester} would like to request”.
   Others songs are not in the list, labeled with “Songs {requester} might request”. Check and/or uncheck songs as
   appropriate. The search entry on the top will filter songs like on the main page.
6. Once at least one song is in the list, the requester background in the singer’s list will be a light blue instead of
   gray.

## Use a requester’s list

1. Select “Singing” mode.
2. Select the Requester.
3. Be sure the “from the active singers above” radio button is selected.
4. Songs from the current singers that match the request list will be shown. Duplicates can happen if the same song has
   been sung by more than one singer. Requested songs that don’t have any matching singers will be shown in a list below
   with the label “Songs {requester} would like a volunteer singer:”. Selecting a singer from the list of singers and
   then selecting a song will go to the song display with the logging of the performance for that singer. Note that the
   key will be the default for the song.
5. The song search filter at the top is still active. Click on a song.
6. Returning from the song will select the next singer or requester in the singer list.

## A complication…

A singer can also be a requester!   If a participant has any songs sung in the app,
they will initially default to a singer. Check the “As requester” checkbox to see their requested songs.
When the singer/requester is selected again, the prior “As requester” selection will be used. Toggle if necessary.
