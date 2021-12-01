import 'dart:collection';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/chordSection.dart';
import 'package:bsteeleMusicLib/songs/chordSectionLocation.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as music_key;
import 'package:bsteeleMusicLib/songs/scaleChord.dart';
import 'package:bsteeleMusicLib/songs/scaleNote.dart';
import 'package:bsteeleMusicLib/songs/section.dart';
import 'package:bsteeleMusicLib/songs/timeSignature.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:csslib/parser.dart' as parser;
import 'package:csslib/visitor.dart' as visitor;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../main.dart';
import 'app.dart';

const Level _cssLog = Level.debug;

TextStyle appDropdownListItemTextStyle = //  fixme: find the right place for this!
    const TextStyle(backgroundColor: Colors.white, color: Colors.black, fontSize: 24); // fixme: shouldn't be fixed

const _defaultBackgroundColor = Color(0xff2196f3);
const _defaultForegroundColor = Colors.white;

Map<String, List<String>> _propertyLiterals = {
  'text-align': [
    'left',
    'right',
    'center',
    'justify', /*'initial', 'inherit'*/
  ],
  'font-weight': [
    'normal',
    'bold',
    'bolder',
    'lighter', /*'initial', 'inherit'*/
  ],
  'font-style': [
    'normal',
    'italic', /*'oblique', 'initial', 'inherit'*/
  ],
  'border-style': [
    'none',
    'solid', /*'dotted', 'dashed', 'double', 'groove', 'ridge', 'inset', 'outset', 'hidden'*/
  ],
};

TextAlign? textAlignParse(String value) {
  return Util.enumFromString(value, TextAlign.values);
}

FontWeight? _fontWeightValue(CssProperty property) {
  var value = _getPropertyValue(property);
  if (value == null) {
    return null;
  }

  switch (value.runtimeType) {
    case String:
      return _fontWeight(value);
  }
  return null;
}

FontWeight? _fontWeight(String? value) {
  switch (value) {
    case 'normal':
      return FontWeight.normal;
    case 'bold':
      return FontWeight.bold;
    case 'bolder':
      return FontWeight.w900;
    case 'lighter':
      return FontWeight.w100;
  }
  return null;
}

FontStyle? _fontStyle(String? value) {
  if (value == null) {
    return null;
  }
  return Util.enumFromString(value, FontStyle.values);
}

BorderStyle? borderStyle(String value) {
  return Util.enumFromString(value, BorderStyle.values);
}

enum CssSelectorEnum {
  universal, //  *
  //  element,  //  there are no html DOM trees in flutter
  classSelector, //  .class
  id, //  #valueKey
  pseudo, //  css variables
}

const Map<CssSelectorEnum, String> cssSelectorCharacterMap = {
  CssSelectorEnum.universal: '*',
  CssSelectorEnum.classSelector: '.',
  CssSelectorEnum.id: '#',
};

typedef CssActionFunction = void Function(CssProperty cssProperty, dynamic value);

enum CssClassEnum {
  appbar,
  button,
  oddTitleText,
  evenTitleText,
  section,
  sectionIntro,
  sectionVerse,
  sectionPreChorus,
  sectionChorus,
  sectionA,
  sectionB,
  sectionBridge,
  sectionCoda,
  sectionTag,
  sectionOutro,
  icon,
  docs,
}

//  universal
final CssProperty _universalBackgroundColorProperty = CssProperty(
    CssSelectorEnum.universal, '*', 'background-color', Color,
    defaultValue: Colors.white, description: 'universal background color');
final CssProperty _universalForegroundColorProperty = CssProperty(CssSelectorEnum.universal, '*', 'color', Color,
    defaultValue: Colors.black, description: 'universal foreground color');
final CssProperty _universalAccentColorProperty = CssProperty(CssSelectorEnum.universal, '*', 'accent-color', Color,
    defaultValue: Colors.blue, description: 'universal accent color');
final _universalFontSizeProperty = CssProperty(CssSelectorEnum.universal, '*', 'font-size', visitor.UnitTerm,
    defaultValue: visitor.ViewportTerm(1.75, '1.75', null, parser.TokenKind.UNIT_VIEWPORT_VW),
    description: 'universal text font size');
final CssProperty _universalFontWeightProperty = CssProperty(
    CssSelectorEnum.universal, '*', 'font-weight', visitor.UnitTerm,
    defaultValue: 'normal', description: 'universal text font weight');
final CssProperty _universalFontStyleProperty = CssProperty(
    CssSelectorEnum.universal, '*', 'font-style', visitor.UnitTerm,
    defaultValue: 'normal', description: 'universal text font style, normal or italic');

void _init(CssProperty property) {
  if (property.defaultValue != null) {
    _propertyValueLookupMap[property] = property.defaultValue;
  }
}

void _initUniversal() {
  _init(_universalBackgroundColorProperty);
  _init(_universalForegroundColorProperty);
  _init(_universalAccentColorProperty);
  _init(_universalFontSizeProperty);
  _init(_universalFontWeightProperty);
  _init(_universalFontStyleProperty);
}

//  app bar
final appbarBackgroundColorProperty = CssProperty.fromCssClass(CssClassEnum.appbar, 'background-color', Color,
    defaultValue: _defaultBackgroundColor, description: 'app bar background color');
final appbarColorProperty = CssProperty.fromCssClass(CssClassEnum.appbar, 'color', Color,
    defaultValue: _defaultForegroundColor, description: 'app bar foreground color');

void _initAppBar() {
  _init(appbarBackgroundColorProperty);
  _init(appbarColorProperty);
}

//  button
final _buttonFontScaleProperty = CssProperty.fromCssClass(CssClassEnum.button, 'font-size', visitor.UnitTerm,
    defaultValue: visitor.ViewportTerm(2, '2', null, parser.TokenKind.UNIT_VIEWPORT_VW),
    description: 'button text font size');
final _buttonBackgroundColorProperty = CssProperty.fromCssClass(CssClassEnum.button, 'background-color', Color,
    defaultValue: _defaultBackgroundColor, description: 'button background color');
final _buttonColorProperty = CssProperty.fromCssClass(CssClassEnum.button, 'color', Color,
    defaultValue: _defaultForegroundColor, description: 'button foreground color');
final _oddTitleTextColorProperty = CssProperty.fromCssClass(CssClassEnum.oddTitleText, 'color', Color,
    defaultValue: Colors.black, description: 'odd row foreground color');
final _oddTitleTextBackgroundProperty = CssProperty.fromCssClass(CssClassEnum.oddTitleText, 'background-color', Color,
    defaultValue: const Color(0xffe0e0e0), description: 'odd row background color');
final _evenTitleTextColorProperty = CssProperty.fromCssClass(CssClassEnum.evenTitleText, 'color', Color,
    defaultValue: Colors.black, description: 'even row foreground color');
final _evenTitleTextBackgroundProperty = CssProperty.fromCssClass(CssClassEnum.evenTitleText, 'background-color', Color,
    defaultValue: Colors.white, description: 'even row background color');

void _initButton() {
  _init(_buttonFontScaleProperty);
  _init(_buttonBackgroundColorProperty);
  _init(_buttonColorProperty);
  _init(_oddTitleTextColorProperty);
  _init(_oddTitleTextBackgroundProperty);
  _init(_evenTitleTextColorProperty);
  _init(_evenTitleTextBackgroundProperty);
}

//  tooltip
final CssProperty _tooltipBackgroundColorProperty = CssProperty(
    CssSelectorEnum.classSelector, 'tooltip', 'background-color', _CssColor,
    defaultValue: const Color(0xffdcedc8), description: 'tool tip background color');
final CssProperty _tooltipColorProperty = CssProperty(CssSelectorEnum.classSelector, 'tooltip', 'color', _CssColor,
    defaultValue: Colors.black, description: 'tool tip foreground color');
final CssProperty _tooltipFontSizeProperty = CssProperty(
    CssSelectorEnum.classSelector, 'tooltip', 'font-size', visitor.UnitTerm,
    defaultValue: visitor.ViewportTerm(2, '1.5', null, parser.TokenKind.UNIT_VIEWPORT_VW),
    description: 'tool tip text font size');

void _initTooltip() {
  _init(_tooltipBackgroundColorProperty);
  _init(_tooltipColorProperty);
  _init(_tooltipFontSizeProperty);
}

//  chord note
final CssProperty _chordNoteColorProperty = CssProperty(CssSelectorEnum.classSelector, 'chordNote', 'color', _CssColor,
    defaultValue: null, description: 'chord note foreground color');
final CssProperty _chordNoteBackgroundColorProperty = CssProperty(
    CssSelectorEnum.classSelector, 'chordNote', 'background-color', _CssColor,
    defaultValue: Colors.white, description: 'chord note background color');
final CssProperty _chordNoteFontSizeProperty =
    CssProperty(CssSelectorEnum.classSelector, 'chordNote', 'font-size', visitor.UnitTerm,
        defaultValue: null, //  let the dynamic sizing be the default size
        description: 'chord note text font size');
final CssProperty _chordNoteFontWeightProperty = CssProperty(
    CssSelectorEnum.classSelector, 'chordNote', 'font-weight', visitor.UnitTerm,
    defaultValue: 'bold', description: 'chord note text font weight');
final CssProperty _chordNoteFontStyleProperty = CssProperty(
    CssSelectorEnum.classSelector, 'chordNote', 'font-style', visitor.UnitTerm,
    defaultValue: 'normal', description: 'chord note text font style, normal or italic');
final _measureMarginProperty = CssProperty(CssSelectorEnum.classSelector, 'measure', 'margin', visitor.UnitTerm,
    defaultValue: visitor.ViewportTerm(0.2, '0.2', null, parser.TokenKind.UNIT_VIEWPORT_VW),
    description: 'measure margin, i.e. the space between measures on the player screen');
final _measurePaddingProperty = CssProperty(CssSelectorEnum.classSelector, 'measure', 'padding', visitor.UnitTerm,
    defaultValue: visitor.ViewportTerm(0.35, '0.35', null, parser.TokenKind.UNIT_VIEWPORT_VW),
    description: 'measure padding, i.e. the space between chord characters and the measure boundary');

void _initChord() {
  _init(_chordNoteColorProperty);
  _init(_chordNoteBackgroundColorProperty);
  _init(_chordNoteFontSizeProperty);
  _init(_chordNoteFontWeightProperty);
  _init(_chordNoteFontStyleProperty);
  _init(_measureMarginProperty);
  _init(_measurePaddingProperty);
}

//  chord descriptor
final CssProperty _chordDescriptorColorProperty = CssProperty(
    CssSelectorEnum.classSelector, 'chordDescriptor', 'color', _CssColor,
    defaultValue: Colors.black, description: 'chord descriptor foreground color');
final CssProperty _chordDescriptorBackgroundColorProperty = CssProperty(
    CssSelectorEnum.classSelector, 'chordDescriptor', 'background-color', _CssColor,
    defaultValue: Colors.white, description: 'chord descriptor background color');
final CssProperty _chordDescriptorFontSizeProperty = CssProperty(
    CssSelectorEnum.classSelector, 'chordDescriptor', 'font-size', visitor.UnitTerm,
    defaultValue: visitor.ViewportTerm(2, '1.5', null, parser.TokenKind.UNIT_VIEWPORT_VW),
    description: 'chord descriptor text font size');
final CssProperty _chordDescriptorFontWeightProperty = CssProperty(
    CssSelectorEnum.classSelector, 'chordDescriptor', 'font-weight', visitor.UnitTerm,
    defaultValue: 'normal', description: 'chord descriptor text font weight');
final CssProperty _chordDescriptorFontStyleProperty = CssProperty(
    CssSelectorEnum.classSelector, 'chordDescriptor', 'font-style', visitor.UnitTerm,
    defaultValue: 'normal', description: 'chord descriptor text font style, normal or italic');

void _initChordDescriptor() {
  _init(_chordDescriptorColorProperty);
  _init(_chordDescriptorBackgroundColorProperty);
  _init(_chordDescriptorFontSizeProperty);
  _init(_chordDescriptorFontWeightProperty);
  _init(_chordDescriptorFontStyleProperty);
}

//  slash note
final CssProperty _chordSlashNoteColorProperty = CssProperty(
    CssSelectorEnum.classSelector, 'chordSlashNote', 'color', _CssColor,
    defaultValue: Colors.black, description: 'chord slash note foreground color');
final CssProperty _chordSlashNoteBackgroundColorProperty = CssProperty(
    CssSelectorEnum.classSelector, 'chordSlashNote', 'background-color', _CssColor,
    defaultValue: Colors.white, description: 'chord slash note background color');
final CssProperty _chordSlashNoteFontSizeProperty = CssProperty(
    CssSelectorEnum.classSelector, 'chordSlashNote', 'font-size', visitor.UnitTerm,
    defaultValue: visitor.ViewportTerm(2, '1.5', null, parser.TokenKind.UNIT_VIEWPORT_VW),
    description: 'chord slash note text font size');
final CssProperty _chordSlashNoteFontWeightProperty = CssProperty(
    CssSelectorEnum.classSelector, 'chordSlashNote', 'font-weight', visitor.UnitTerm,
    defaultValue: 'normal', description: 'chord slash note text font weight');
final CssProperty _chordSlashNoteFontStyleProperty = CssProperty(
    CssSelectorEnum.classSelector, 'chordSlashNote', 'font-style', visitor.UnitTerm,
    defaultValue: 'normal', description: 'chord slash note text font style, normal or italic');

void _initSlashNote() {
  _init(_chordSlashNoteColorProperty);
  _init(_chordSlashNoteBackgroundColorProperty);
  _init(_chordSlashNoteFontSizeProperty);
  _init(_chordSlashNoteFontWeightProperty);
  _init(_chordSlashNoteFontStyleProperty);
}

//  lyrics
final CssProperty _lyricsColorProperty = CssProperty(CssSelectorEnum.classSelector, 'lyrics', 'color', _CssColor,
    defaultValue: Colors.black, description: 'lyrics foreground color');
final CssProperty _lyricsBackgroundColorProperty = CssProperty(
    CssSelectorEnum.classSelector, 'lyrics', 'background-color', _CssColor,
    defaultValue: Colors.white, description: 'lyrics background color');
final CssProperty _lyricsFontSizeProperty = CssProperty(
    CssSelectorEnum.classSelector, 'lyrics', 'font-size', visitor.UnitTerm,
    defaultValue: visitor.ViewportTerm(2, '1.25', null, parser.TokenKind.UNIT_VIEWPORT_VW),
    description: 'lyrics text font size');
final CssProperty _lyricsFontWeightProperty = CssProperty(
    CssSelectorEnum.classSelector, 'lyrics', 'font-weight', visitor.UnitTerm,
    defaultValue: 'normal', description: 'lyrics text font weight');
final CssProperty _lyricsFontStyleProperty = CssProperty(
    CssSelectorEnum.classSelector, 'lyrics', 'font-style', visitor.UnitTerm,
    defaultValue: 'normal', description: 'lyrics text font style, normal or italic');

void _initLyrics() {
  _init(_lyricsColorProperty);
  _init(_lyricsBackgroundColorProperty);
  _init(_lyricsFontSizeProperty);
  _init(_lyricsFontWeightProperty);
  _init(_lyricsFontStyleProperty);
}

//  icons
final _iconColorProperty = CssProperty.fromCssClass(CssClassEnum.icon, 'color', Color,
    defaultValue: Colors.white, description: 'icon foreground color');
final _iconBackgroundColorProperty = CssProperty.fromCssClass(CssClassEnum.icon, 'background-color', Color,
    defaultValue: _defaultBackgroundColor, description: 'icon background color');
final _iconSizeProperty = CssProperty.fromCssClass(CssClassEnum.icon, 'size', visitor.UnitTerm,
    defaultValue: null, //  let the dynamic sizing be the default size
    description: 'icon size');

void _initIcons() {
  _init(_iconColorProperty);
  _init(_iconBackgroundColorProperty);
  _init(_iconSizeProperty);
}

//  musical sections
const Color _verseColor = Color(0xfff5e6b8);
const Color _chorusColor = Color(0xffffffff);
const Color _bridgeColor = Color(0xffd2f5cd);
const Color _introColor = Color(0xFFcdf5e9);
const Color _preChorusColor = Color(0xffe8e8e8);
const Color _tagColor = Color(0xffcee1f5);
final _sectionColorProperty = CssProperty.fromCssClass(CssClassEnum.section, 'color', Color,
    defaultValue: null, description: 'Section foreground color');
final _sectionBackgroundProperty = CssProperty.fromCssClass(CssClassEnum.section, 'background-color', _CssColor,
    defaultValue: Colors.white, description: 'Section background color');
final _sectionIntroBackgroundProperty = CssProperty.fromCssClass(CssClassEnum.sectionIntro, 'background-color', Color,
    defaultValue: _introColor, description: 'Intro section background color');
final _sectionVerseBackgroundProperty = CssProperty.fromCssClass(
    CssClassEnum.sectionVerse, 'background-color', _CssColor,
    defaultValue: _verseColor, description: 'Verse section background color');
final _sectionPreChorusBackgroundProperty = CssProperty.fromCssClass(
    CssClassEnum.sectionPreChorus, 'background-color', Color,
    defaultValue: _preChorusColor, description: 'PreChorus section background color');
final _sectionChorusBackgroundProperty = CssProperty.fromCssClass(CssClassEnum.sectionChorus, 'background-color', Color,
    defaultValue: _chorusColor, description: 'Chorus section background color');
final _sectionABackgroundProperty = CssProperty.fromCssClass(CssClassEnum.sectionA, 'background-color', Color,
    defaultValue: _verseColor, description: 'A section background color');
final _sectionBBackgroundProperty = CssProperty.fromCssClass(CssClassEnum.sectionB, 'background-color', Color,
    defaultValue: _chorusColor, description: 'B section background color');
final _sectionBridgeBackgroundProperty = CssProperty.fromCssClass(CssClassEnum.sectionBridge, 'background-color', Color,
    defaultValue: _bridgeColor, description: 'Bridge section background color');
final _sectionCodaBackgroundProperty = CssProperty.fromCssClass(CssClassEnum.sectionCoda, 'background-color', Color,
    defaultValue: _introColor, description: 'Coda section background color');
final _sectionTagBackgroundProperty = CssProperty.fromCssClass(CssClassEnum.sectionTag, 'background-color', Color,
    defaultValue: _tagColor, description: 'Tag section background color');
final _sectionOutroBackgroundProperty = CssProperty.fromCssClass(CssClassEnum.sectionOutro, 'background-color', Color,
    defaultValue: _introColor, description: 'Outro section background color');

void _initSections() {
  _init(_sectionColorProperty);
  _init(_sectionBackgroundProperty);
  _init(_sectionIntroBackgroundProperty);
  _init(_sectionVerseBackgroundProperty);
  _init(_sectionPreChorusBackgroundProperty);
  _init(_sectionChorusBackgroundProperty);
  _init(_sectionABackgroundProperty);
  _init(_sectionBBackgroundProperty);
  _init(_sectionBridgeBackgroundProperty);
  _init(_sectionCodaBackgroundProperty);
  _init(_sectionTagBackgroundProperty);
  _init(_sectionOutroBackgroundProperty);
}

final _docFontSizeProperty = CssProperty.fromCssClass(CssClassEnum.docs, 'font-size', visitor.UnitTerm,
    defaultValue: visitor.LengthTerm(24.0, '24.0', null), description: 'documentation text font size');

void _initDocs() {
  _init(_docFontSizeProperty);
}

/// used to store values, even those not transferable to a flutter theme
Map<CssProperty, dynamic> _propertyValueLookupMap = {};
SplayTreeSet<CssProperty>? _cssPropertiesSet = SplayTreeSet();
SplayTreeSet<CssProperty>? _cssPropertiesUsed = SplayTreeSet();

dynamic _getPropertyValue(CssProperty? property) {
  if (property == null) {
    return null;
  }
  _cssPropertiesUsed?.add(property);
  return _propertyValueLookupMap[property];
}

void _setPropertyValue(CssProperty? property, dynamic value) {
  if (property == null) {
    return;
  }
  _cssPropertiesSet?.add(property);
  _propertyValueLookupMap[property] = value;
}

Color getForegroundColorForSection(Section? section) {
  var ret = _getPropertyValue(_sectionColorProperty) ??
      _getPropertyValue(_chordNoteColorProperty) ??
      _getPropertyValue(_universalForegroundColorProperty);
  return (ret != null && ret is Color) ? ret : Colors.black;
}

Color getAccentColor() {
  var ret = _getPropertyValue(_universalAccentColorProperty);
  return (ret != null && ret is Color) ? ret : Colors.blue;
}

Color getBackgroundColorForSection(Section? section) {
  return _getBackgroundColorForSectionEnum(section?.sectionEnum ?? SectionEnum.chorus);
}

Color _getBackgroundColorForSectionEnum(SectionEnum sectionEnum) {
  final Map<SectionEnum, CssProperty> sectionMap = {
    SectionEnum.intro: _sectionIntroBackgroundProperty,
    SectionEnum.verse: _sectionVerseBackgroundProperty,
    SectionEnum.preChorus: _sectionPreChorusBackgroundProperty,
    SectionEnum.chorus: _sectionChorusBackgroundProperty,
    SectionEnum.a: _sectionABackgroundProperty,
    SectionEnum.b: _sectionBBackgroundProperty,
    SectionEnum.bridge: _sectionBridgeBackgroundProperty,
    SectionEnum.coda: _sectionCodaBackgroundProperty,
    SectionEnum.tag: _sectionTagBackgroundProperty,
    SectionEnum.outro: _sectionOutroBackgroundProperty,
  };

  var ret = _getPropertyValue(sectionMap[sectionEnum]);
  ret ??= _getPropertyValue(_sectionBackgroundProperty); //  inherited
  logger.d('_getBackgroundColorForSectionEnum: $sectionEnum: $ret');
  return (ret != null && ret is Color) ? ret : Colors.white;
}

Color? _getColor(CssProperty property) {
  var ret = _getPropertyValue(property);
  return (ret != null && ret is Color) ? ret : null;
}

EdgeInsetsGeometry? getMeasureMargin() {
  var property = CssProperty.temporary(CssSelectorEnum.classSelector, 'measure', 'margin');
  double? w = _sizeLookup(property);
  return w == null ? null : EdgeInsets.all(w);
}

EdgeInsetsGeometry? getMeasurePadding() {
  var property = CssProperty.temporary(CssSelectorEnum.classSelector, 'measure', 'padding');
  double? w = _sizeLookup(property);
  return w == null ? null : EdgeInsets.all(w);
}

/// Application keys to select all application actions. See [ appKey() ]
enum AppKeyEnum {
  ///  Return from the about screen
  aboutBack,
  aboutLog,

  ///  Write the diagnostic file of application actions
  aboutWriteDiagnosticLogFile,

  ///  Return to the screen's parent
  appBarBack,
  appBack, //  screen pop
  cssDemoBack,
  cssDemoButton,
  cssDemoIconButton,
  detailBack,
  detailCloseOptions,
  detailLoop,
  detailLoop1,
  detailLoop2,
  detailLoop4,
  detailLoopSelected,
  detailLyrics,
  detailOptions,
  detailPlay,
  detailStop,
  documentationBack,
  editAcceptChordModificationAndStartNewRow,
  editAcceptChordModificationAndExtendRow,
  editAcceptChordModificationAndFinish,
  editArtist,
  editBack,
  editBPM,
  editCancelChordModification,
  editChordDataPoint,
  editAddChordRow,
  editAddChordRowNew,
  editAddChordRowRepeat,
  editChordPlusInsert,
  editChordPlusAppend,
  editChordSectionAccept,
  editChordSectionAcceptAndAdd,
  editChordSectionCancel,
  editChordSectionDelete,
  editChordSectionLocation,
  editClearSong,
  editCopyright,
  editCoverArtist,
  editDeleteChordMeasure,
  editDeleteLyricsSection,
  editRepeatCancel,
  editDeleteRepeat,
  editDiscardAllChanges,
  editDominant7Chord,
  editEditKeyDropdown,
  editEnterSong,
  editHints,
  editImportLyrics,
  editMajorChord,
  editMinorChord,
  editMusicKey,
  editNewChordSection,
  editRedo,
  editRepeat,
  editRepeatX2,
  editRepeatX3,
  editRepeatX4,
  editRowJoin,
  editRowSplit,
  editScaleChord,
  editScaleNote,
  editScreenDetail,
  editSilentChord,
  editSingleChildScrollView,
  editEditTimeSignature,
  editEditTimeSignatureDropdown,
  editTitle,
  editUndo,
  editUserName,
  errorMessage,
  listsBack,
  listsCancelDeleteList,
  listsClearSearch,
  listsClearLists,
  listsDeleteList,
  listsErrorMessage,
  listsNameEntry,
  listsRadio,
  listsReadLists,
  listsSave,
  listsSaveSelected,
  listsSearchText,
  listsValueEntry,
  lyricsEntryLine,
  lyricsEntryLineAdd,
  lyricsEntryLineDelete,
  lyricsEntryLineDown,
  lyricsEntryLineUp,
  mainClearSearch,
  mainDrawerAbout,
  mainDrawerCssDemo,
  mainDrawerDocs,
  mainDrawerLists,
  mainDrawerOptions,
  mainDrawerPrivacy,
  mainDrawerSongs,
  mainDrawerTheory,
  mainHamburger,
  mainSearchText,
  mainSong,
  mainSortTypeSelection,
  mainUp,
  optionsBack,
  optionsFullScreen,
  optionsKeyOffset0,
  optionsKeyOffset1,
  optionsKeyOffset10,
  optionsKeyOffset2,
  optionsKeyOffset3,
  optionsKeyOffset4,
  optionsKeyOffset5,
  optionsKeyOffset6,
  optionsKeyOffset7,
  optionsKeyOffset8,
  optionsKeyOffset9,
  optionsLeadership,
  optionsUserName,
  optionsWebsocketBob,
  optionsWebsocketCJ,
  optionsWebsocketIP,
  optionsWebsocketNone,
  optionsWebsocketPark,
  playerBack,
  playerBPM,
  playerCapo,
  playerEdit,
  playerFloatingPlay,
  playerFloatingStop,
  playerFloatingTop,
  playerKeyDown,
  playerKeyUp,
  playerMusicKey,
  playerNextSong,
  playerPlay,
  playerPreviousSong,
  playerSongBad,
  playerSongGood,
  privacyBack,
  songsBack,
  songsReadFiles,
  songsRemoveAll,
  songsWriteFiles,
  theoryBack,
  theoryHalf,
  theoryRoot,
}

Map<AppKeyEnum, Type> appKeyEnumTypeMap = {
  AppKeyEnum.editAddChordRow: ChordSectionLocation,
  AppKeyEnum.editAddChordRowNew: ChordSectionLocation,
  AppKeyEnum.editAddChordRowRepeat: ChordSectionLocation,
  AppKeyEnum.editChordPlusInsert: ChordSectionLocation,
  AppKeyEnum.editChordPlusAppend: ChordSectionLocation,
  AppKeyEnum.editChordDataPoint: ChordSectionLocation,
  AppKeyEnum.editChordSectionAccept: ChordSection,
  AppKeyEnum.editChordSectionAcceptAndAdd: ChordSection,
  AppKeyEnum.editChordSectionCancel: ChordSection,
  AppKeyEnum.editChordSectionDelete: ChordSection,
  AppKeyEnum.editChordSectionLocation: ChordSectionLocation,
  AppKeyEnum.editRepeatCancel: ChordSectionLocation,
  AppKeyEnum.editDeleteRepeat: ChordSectionLocation,
  AppKeyEnum.editRepeat: ChordSectionLocation,
  AppKeyEnum.editRepeatX2: ChordSectionLocation,
  AppKeyEnum.editRepeatX3: ChordSectionLocation,
  AppKeyEnum.editRepeatX4: ChordSectionLocation,
  AppKeyEnum.editMusicKey: music_key.Key,
  AppKeyEnum.editScaleChord: ScaleChord,
  AppKeyEnum.editScaleNote: ScaleNote,
  AppKeyEnum.editEditTimeSignature: TimeSignature,
  AppKeyEnum.lyricsEntryLineAdd: int,
  AppKeyEnum.lyricsEntryLineDelete: int,
  AppKeyEnum.lyricsEntryLineDown: int,
  AppKeyEnum.lyricsEntryLineUp: int,
  AppKeyEnum.mainSearchText: String,
  AppKeyEnum.mainSong: Id,
  AppKeyEnum.mainSortTypeSelection: MainSortType,
  AppKeyEnum.optionsUserName: String,
  AppKeyEnum.playerBPM: int,
  AppKeyEnum.playerMusicKey: music_key.Key,
};

class Id {
  Id(this.id);

  @override
  String toString() {
    return id;
  }

  String id;
}

typedef AppKey = ValueKey<String>;

/// Generate an application key from the enumeration and an optional value
AppKey appKey(AppKeyEnum e, {dynamic value}) {
  var type = appKeyEnumTypeMap[e];
  switch (type) {
    case null:
      if (value != null) {
        logger.i('not null here:');
      }
      assert(value == null);
      return ValueKey<String>(e.name);
    case String:
      return ValueKey<String>(e.name);
    default:
      if (value.runtimeType != type) {
        logger.i('not same type here:');
      }
      assert(value.runtimeType == type);
      return ValueKey<String>('${e.name}.${value.toString()}');
  }
}

class _CssColor extends Color {
  _CssColor(int value) : super(0xFF000000 + value);

  String toCss() {
    return '#${(value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  }
}

/// Icon widget with the application look
Icon appIcon(IconData icon, {Key? key, Color? color, double? size}) {
  return Icon(icon,
      key: key,
      color: color ?? _getColor(_iconColorProperty),
      size: size ??
          _sizeLookup(_iconSizeProperty) ??
          app.screenInfo.fontSize //  let the algorithm figure the size dynamically
      );
}

class AppTheme {
  static final AppTheme _singleton = AppTheme._internal();

  factory AppTheme() {
    return _singleton;
  }

  AppTheme._internal();

  Future init({String css = 'app.css'}) async {
    //  initialize the lazy final values
    _initUniversal();
    _initAppBar();
    _initButton();
    _initTooltip();
    _initChord();
    _initChordDescriptor();
    _initSlashNote();
    _initLyrics();
    _initIcons();
    _initSections();
    _initDocs();

    //  read the css file
    String cssAsString = await loadString('lib/assets/$css');
    List<parser.Message> errors = [];
    var stylesheet = parser.parse(cssAsString, errors: errors);
    for (var error in errors) {
      logger.e('CSS error: ${error.level}:'
          ' (from line ${error.span?.start.line}:${error.span?.start.column}'
          ' to ${error.span?.end.line}:${error.span?.end.column})'
          ': ${error.message}');
    }

    //  parse the style sheet
    for (var treeNode in stylesheet.topLevels) {
      if (treeNode is visitor.RuleSet) {
        if (treeNode.selectorGroup != null) {
          var selectorGroup = treeNode.selectorGroup;
          for (var selectors in selectorGroup!.selectors) {
            for (var selector in selectors.simpleSelectorSequences) {
              CssSelectorEnum cssSelector;
              switch (selector.simpleSelector.runtimeType) {
                case visitor.ClassSelector:
                  cssSelector = CssSelectorEnum.classSelector;
                  break;
                case visitor.ElementSelector:
                  cssSelector =
                      selector.simpleSelector.name == '*' ? CssSelectorEnum.universal : CssSelectorEnum.id; //fixme
                  break;
                case visitor.IdSelector:
                  cssSelector = CssSelectorEnum.id;
                  break;

                case visitor.PseudoClassSelector:
                  cssSelector = CssSelectorEnum.pseudo;
                  break;

                default:
                  cssSelector = CssSelectorEnum.id;
                  logger.e('unknown selector.simpleSelector.runtimeType: ${selector.simpleSelector.runtimeType}');
                  break;
              }

              for (var dec in treeNode.declarationGroup.declarations) {
                if (dec is visitor.Declaration) {
                  var property = dec.property;
                  var literals = _propertyLiterals[property];
                  var expression = dec.expression;
                  if (expression is visitor.Expressions) {
                    var expressions = expression;
                    for (var exp in expressions.expressions) {
                      if (exp is visitor.VarUsage) {
                        applyAction(cssSelector, selector.simpleSelector.name, property, cssVariables[exp.name]);
                      } else if (exp is visitor.LengthTerm) {
                        applyAction(cssSelector, selector.simpleSelector.name, property, exp);
                      } else if (exp is visitor.HexColorTerm) {
                        var hexColorTerm = exp;
                        if (_threeDigitHexRegExp.hasMatch(hexColorTerm.text)) {
                          var t = hexColorTerm.text.characters;
                          var s = t.characterAt(0) +
                              t.characterAt(0) +
                              t.characterAt(1) +
                              t.characterAt(1) +
                              t.characterAt(2) +
                              t.characterAt(2);
                          int i = int.parse(s.toString(), radix: 16);
                          var name = selector.simpleSelector.name;
                          applyAction(cssSelector, name, property, _CssColor(i), rawValue: hexColorTerm.span?.text);
                        } else if (hexColorTerm.value is int) {
                          int i = hexColorTerm.value;
                          applyAction(cssSelector, selector.simpleSelector.name, property, _CssColor(i),
                              rawValue: hexColorTerm.span?.text);
                        } else {
                          logger.e('Not understood: HexColorTerm: '
                              '${hexColorTerm.runtimeType} ${hexColorTerm.value} ${hexColorTerm.toString()}');
                        }
                      } else if (exp is visitor.ViewportTerm) {
                        var viewportTerm = exp;
                        applyAction(cssSelector, selector.simpleSelector.name, property, viewportTerm);
                      } else if (exp is visitor.LiteralTerm) {
                        var literalTerm = exp;
                        if (literals != null) {
                          if (literals.contains(literalTerm.text)) {
                            applyAction(cssSelector, selector.simpleSelector.name, property, literalTerm.text);
                          } else {
                            logger.e('error: NOT valid value for'
                                ' ${cssSelectorCharacterMap[cssSelector] ?? ''}cssSelector $selector.$property:'
                                ' "${literalTerm.value}"');
                          }
                        } else {
                          logger.e('error: (LiteralTerm) NOT understood: "${literalTerm.value}"');
                        }
                      } else {
                        logger.e('error: NOT understood: ${exp.runtimeType} ${exp.toString()}');
                      }
                    }
                  } else {
                    logger.e('error: expression is NOT Expressions: "$expression"');
                  }
                } else {
                  logger.e('error: NOT declaration: ${dec.runtimeType} $dec');
                }
              }
            }
          }
        }
      }
    }

    _logActions();

    {
      // var iconTheme = IconThemeData(color: _defaultForegroundColor); fixme
      // var radioTheme = RadioThemeData(fillColor: MaterialStateProperty.all(_defaultForegroundColor)); fixme
      var elevatedButtonThemeStyle = app.themeData.elevatedButtonTheme.style ?? const ButtonStyle();
      elevatedButtonThemeStyle = elevatedButtonThemeStyle.copyWith(elevation: MaterialStateProperty.all(6));

      //  hassle with mapping Color to MaterialColor
      var color = _getPropertyValue(appbarBackgroundColorProperty) as Color;
      Map<int, Color> colorCodes = {
        50: color.withOpacity(.1),
        100: color.withOpacity(.2),
        200: color.withOpacity(.3),
        300: color.withOpacity(.4),
        400: color.withOpacity(.5),
        500: color.withOpacity(.6),
        600: color.withOpacity(.7),
        700: color.withOpacity(.8),
        800: color.withOpacity(.9),
        900: color.withOpacity(1),
      };
      MaterialColor materialColor = MaterialColor(color.value, colorCodes);
      color = _getPropertyValue(_universalBackgroundColorProperty) as Color;

      app.themeData = app.themeData.copyWith(
        backgroundColor: color,
        primaryColor: color,
        elevatedButtonTheme: ElevatedButtonThemeData(style: elevatedButtonThemeStyle),
        colorScheme: ColorScheme.fromSwatch(primarySwatch: materialColor, accentColor: getAccentColor()),
      );
    }

    CssProperty.logCreations();
  }

  void _logActions() {
    SplayTreeSet<CssProperty> properties = SplayTreeSet();
    for (var appliedAction in appliedActions) {
      properties.add(appliedAction.cssAction.cssProperty);
    }
    properties.addAll(_propertyValueLookupMap.keys);

    for (var property in properties) {
      var value = _getPropertyValue(property);
      if (value == null) {
        logger.i('fixme here!!!!! null _getPropertyValue(\'$property\')');
        // var appliedAction = appliedActions.firstWhere((e) => (property.hashCode == e.cssAction.cssProperty.hashCode));
        // logger.i('applied: ${appliedAction.cssAction.cssProperty.id}:'
        //     ' ${appliedAction.rawValue ?? appliedAction.value};'
        //     '    /* ${appliedAction.cssAction.cssProperty.type} */');
      } else {
        logger.d('lookup: $property: $value;'
            '    /* ${property.type} */');
      }
    }
  }

  final RegExp _threeDigitHexRegExp = RegExp(r'^[\da-fA-f]{3}$');
}

double? _sizeLookup(CssProperty property) {
  var value = _getPropertyValue(property);
  if (value == null) {
    return null;
  }
  switch (value.runtimeType) {
    case visitor.LengthTerm:
      var term = value as visitor.LengthTerm;
      switch (term.unit) {
        case parser.TokenKind.UNIT_LENGTH_PX:
          return term.value.toDouble();
        default:
          return null;
      }
    case visitor.ViewportTerm:
      var term = value as visitor.ViewportTerm;
      return term.value * app.screenInfo.widthInLogicalPixels / 100; //  ie. dynamically mapped into pixels
    default:
      return null;
  }
}

double lookupIconSize() {
  return _sizeLookup(_iconSizeProperty) ?? 24; //  fixme
}

List<String> _appLog = [];

List<String> appLog() {
  return _appLog;
}

void appLogKeyCallback(ValueKey<String> key) {
  _appLog.add(key.value);
}

typedef KeyCallback = void Function();

ElevatedButton appEnumeratedButton(
  String commandName, {
  required AppKeyEnum appKeyEnum,
  required VoidCallback? onPressed,
  Color? backgroundColor,
  double? fontSize,
}) {
  return appButton(
    commandName,
    appKeyEnum: appKeyEnum,
    onPressed: onPressed,
    backgroundColor: backgroundColor,
    fontSize: fontSize,
  );
}

ElevatedButton appButton(
  String commandName, {
  required AppKeyEnum appKeyEnum,
  required VoidCallback? onPressed,
  Color? backgroundColor,
  double? fontSize,
  dynamic value,
}) {
  fontSize ??= _sizeLookup(_buttonFontScaleProperty) ?? _sizeLookup(_universalFontSizeProperty);
  var key = appKey(appKeyEnum, value: value);

  return ElevatedButton(
    key: key,
    child: Text(commandName,
        style: app.themeData.elevatedButtonTheme.style?.textStyle?.resolve({}) ?? TextStyle(fontSize: fontSize)),
    clipBehavior: Clip.hardEdge,
    onPressed: onPressed == null
        ? null //  show as disabled
        : () {
            appLogKeyCallback(key); //  log the click
            onPressed();
          },
    style:
        app.themeData.elevatedButtonTheme.style?.copyWith(backgroundColor: MaterialStateProperty.all(backgroundColor)),
  );
}

TextButton appTextButton(
  String text, {
  required AppKeyEnum appKeyEnum,
  required VoidCallback onPressed,
}) {
  var key = appKey(appKeyEnum);
  return TextButton(
    key: key,
    child: Text(text),
    onPressed: () {
      appLogKeyCallback(key);
      onPressed();
    },
    style: app.themeData.elevatedButtonTheme.style,
  );
}

TextButton appIconButton({
  required AppKeyEnum appKeyEnum,
  required Widget icon,
  required VoidCallback onPressed,
}) {
  var key = appKey(appKeyEnum);
  return TextButton.icon(
    key: key,
    icon: icon,
    label: const Text(''),
    onPressed: () {
      appLogKeyCallback(key);
      onPressed();
    },
    style: app.themeData.elevatedButtonTheme.style,
  );
}

InkWell appInkWell({
  required AppKeyEnum appKeyEnum,
  Color? backgroundColor,
  double? fontSize,
  GestureTapCallback? onTap,
  Widget? child,
  KeyCallback? keyCallback,
  dynamic value, // overrides onPressed(), requires key
}) {
  fontSize ??= _sizeLookup(_buttonFontScaleProperty) ?? _sizeLookup(_universalFontSizeProperty);

  //  some form of callback is required, but not two!
  assert((keyCallback != null && onTap == null) || (keyCallback == null && onTap != null));

  var key = appKey(appKeyEnum, value: value);

  //  supply an on pressed callback with key, if asked
  if (keyCallback != null) {
    onTap = () {
      appLogKeyCallback(key);
      keyCallback();
    };
  }

  return InkWell(
    key: key,
    onTap: onTap,
    child: child,
  );
}

IconButton appEnumeratedIconButton({
  required Widget icon,
  required AppKeyEnum appKeyEnum,
  required VoidCallback onPressed, //  insist on action
  Color? color,
  double? iconSize,
}) {
  var key = appKey(appKeyEnum);
  return IconButton(
    icon: icon,
    key: key,
    onPressed: () {
      appLogKeyCallback(key);
      onPressed();
    },
    color: color,
    iconSize: iconSize ?? 24.0, //  demanded by IconButton
  );
}

DropdownMenuItem<T> appDropdownMenuItem<T>({
  required AppKeyEnum appKeyEnum,
  KeyCallback? keyCallback,
  T? value,
  required Widget child,
}) {
  var key = appKey(appKeyEnum, value: value);

  return DropdownMenuItem<T>(
      key: key,
      onTap: () {
        appLogKeyCallback(key);
        if (keyCallback != null) {
          keyCallback();
        }
      },
      value: value,
      enabled: true,
      alignment: AlignmentDirectional.centerStart,
      child: child);
}

FloatingActionButton appFloatingActionButton({
  required AppKeyEnum appKeyEnum,
  required VoidCallback onPressed,
  Widget? child,
  bool mini = false,
}) {
  var key = appKey(appKeyEnum);
  return FloatingActionButton(
    key: key,
    onPressed: () {
      appLogKeyCallback(key);
      onPressed();
    },
    child: child,
    mini: mini,
    backgroundColor: _getColor(_iconBackgroundColorProperty) ?? _getColor(appbarBackgroundColorProperty),
  );
}

void appTextFieldListener(AppKeyEnum appKeyEnum, TextEditingController controller) {
  logger.d('appLogListener( $appKeyEnum:\'${controller.text}\':${controller.selection} )');
}

ListTile appListTile({required AppKeyEnum appKeyEnum, required Widget title, required GestureTapCallback onTap}) {
  var key = appKey(appKeyEnum);
  return ListTile(
    key: key,
    title: title,
    onTap: () {
      appLogKeyCallback(key);
      onTap();
    },
  );
}

Switch appSwitch({required AppKeyEnum appKeyEnum, required bool value, required ValueChanged<bool> onChanged}) {
  var key = appKey(appKeyEnum);
  return Switch(
    key: key,
    value: value,
    onChanged: (value) {
      appLogKeyCallback(key);
      onChanged(value);
    },
  );
}

TextField appTextField({
  required AppKeyEnum appKeyEnum,
  TextEditingController? controller,
  final ValueChanged<String>? onChanged,
  String? hintText,
  double? fontSize,
  bool? enabled,
}) {
  return TextField(
    key: appKey(appKeyEnum),
    controller: controller,
    enabled: enabled,
    onChanged: onChanged,
    decoration: InputDecoration(
      hintText: hintText,
    ),
    style: generateAppTextFieldStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
    maxLength: null,
  );
}

GestureDetector appGestureDetector(
    {required AppKeyEnum appKeyEnum, dynamic value, Widget? child, GestureTapCallback? onTap}) {
  var key = appKey(appKeyEnum, value: value);
  return GestureDetector(
    key: key,
    child: child,
    onTap: () {
      appLogKeyCallback(key);
      if (onTap != null) {
        onTap();
      }
    },
  );
}

const String appDefaultFontFamily = 'Roboto';
const List<String> appFontFamilyFallback = [
  appDefaultFontFamily,
  'DejaVu', //  deals with "tofu" for flat and sharp symbols
  //'Bravura',  // music symbols are over sized in the vertical
];

/// style used to get DejaVu as a fallback family for musical sharps and flats
/// Creates the app's text style.
///
/// The `package` argument must be non-null if the font family is defined in a
/// package. It is combined with the `fontFamily` argument to set the
/// [fontFamily] property.

TextStyle generateAppTextStyle({
  Color? color,
  Color? backgroundColor,
  double? fontSize,
  FontWeight? fontWeight,
  FontStyle? fontStyle,
  TextBaseline? textBaseline,
  String? fontFamily = appDefaultFontFamily,
  TextDecoration? decoration,
  bool nullBackground = false,
}) {
  fontSize ??= _sizeLookup(_universalFontSizeProperty);
  fontSize = Util.limit(fontSize, appDefaultFontSize, 150.0) as double?;
  return TextStyle(
    color: color ?? _getColor(_universalForegroundColorProperty),
    //  watch out: backgroundColor interferes with mouse text select on textFields!
    backgroundColor: nullBackground ? null : backgroundColor ?? _getColor(_universalBackgroundColorProperty),
    fontSize: fontSize,
    fontWeight: fontWeight ?? _fontWeightValue(_universalFontWeightProperty),
    fontStyle: fontStyle ?? _fontStyle(_getPropertyValue(_universalFontStyleProperty)),
    textBaseline: textBaseline,
    fontFamily: fontFamily,
    fontFamilyFallback: appFontFamilyFallback,
    decoration: decoration,
    overflow: TextOverflow.clip,
  );
}

TextStyle generateAppTextFieldStyle({
  Color? color,
  double? fontSize,
  FontWeight? fontWeight,
  FontStyle? fontStyle,
  TextBaseline? textBaseline,
  String? fontFamily = appDefaultFontFamily,
  TextDecoration? decoration,
}) {
  return generateAppTextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      fontFamily: fontFamily,
      textBaseline: textBaseline,
      decoration: decoration,
      nullBackground: true //  force a null background for mouse text selection
      );
}

TextStyle generateAppBarLinkTextStyle() {
  return generateAppTextStyle(
    fontWeight: FontWeight.bold,
    color: _getColor(appbarColorProperty),
    backgroundColor: Colors.transparent,
  );
}

TextStyle generateAppLinkTextStyle() {
  return generateAppTextStyle(
    color: Colors.blue, //  fixme
    decoration: TextDecoration.underline,
  );
}

TextStyle generateTooltipTextStyle({double? fontSize}) {
  return generateAppTextStyle(
    color: _getPropertyValue(_tooltipColorProperty),
    backgroundColor: _getPropertyValue(_tooltipBackgroundColorProperty),
    fontSize: fontSize ?? _sizeLookup(_tooltipFontSizeProperty),
  );
}

TextStyle generateChordTextStyle({double? fontSize, Color? backgroundColor}) {
  return generateAppTextStyle(
    color: _getPropertyValue(_chordNoteColorProperty),
    backgroundColor: backgroundColor ??
        _getPropertyValue(_chordNoteBackgroundColorProperty) ??
        _getPropertyValue(_universalBackgroundColorProperty),
    fontSize: fontSize ?? _sizeLookup(_chordNoteFontSizeProperty),
    fontWeight: _fontWeight(_getPropertyValue(_chordNoteFontWeightProperty)) ??
        _fontWeight(_getPropertyValue(_universalFontWeightProperty)),
    fontStyle: _fontStyle(_getPropertyValue(_chordNoteFontStyleProperty)) ??
        _fontStyle(_getPropertyValue(_universalFontStyleProperty)),
  );
}

TextStyle generateLyricsTextStyle({double? fontSize, Color? backgroundColor}) {
  return generateAppTextStyle(
    color: _getPropertyValue(_lyricsColorProperty),
    backgroundColor: backgroundColor ??
        _getPropertyValue(_lyricsBackgroundColorProperty) ??
        _getPropertyValue(_universalBackgroundColorProperty),
    fontSize: fontSize ?? _sizeLookup(_lyricsFontSizeProperty),
    fontWeight: _fontWeight(_getPropertyValue(_lyricsFontWeightProperty)) ??
        _fontWeight(_getPropertyValue(_universalFontWeightProperty)),
    fontStyle: _fontStyle(_getPropertyValue(_lyricsFontStyleProperty)) ??
        _fontStyle(_getPropertyValue(_universalFontStyleProperty)),
  );
}

TextStyle generateChordDescriptorTextStyle({double? fontSize}) {
  return generateAppTextStyle(
    color: _getPropertyValue(_chordDescriptorColorProperty) ?? _getPropertyValue(_universalForegroundColorProperty),
    backgroundColor: _getPropertyValue(_chordDescriptorBackgroundColorProperty) ??
        _getPropertyValue(_chordNoteBackgroundColorProperty) ??
        _getPropertyValue(_universalBackgroundColorProperty),
    fontSize: fontSize ?? _sizeLookup(_chordDescriptorFontSizeProperty) ?? _sizeLookup(_chordNoteFontSizeProperty),
    fontWeight: _fontWeight(_getPropertyValue(_chordDescriptorFontWeightProperty)) ??
        _fontWeight(_getPropertyValue(_chordNoteFontWeightProperty)) ??
        _fontWeight(_getPropertyValue(_universalFontWeightProperty)),
    fontStyle: _fontStyle(_getPropertyValue(_chordDescriptorFontStyleProperty)) ??
        _fontStyle(_getPropertyValue(_chordNoteFontStyleProperty)) ??
        _fontStyle(_getPropertyValue(_universalFontStyleProperty)),
  );
}

TextStyle generateChordSlashNoteTextStyle({double? fontSize}) {
  return generateAppTextStyle(
    color: _getPropertyValue(_chordSlashNoteColorProperty) ?? _getPropertyValue(_universalForegroundColorProperty),
    backgroundColor: _getPropertyValue(_chordSlashNoteBackgroundColorProperty) ??
        _getPropertyValue(_chordNoteBackgroundColorProperty) ??
        _getPropertyValue(_universalBackgroundColorProperty),
    fontSize: fontSize ?? _sizeLookup(_chordSlashNoteFontSizeProperty) ?? _sizeLookup(_chordNoteFontSizeProperty),
    fontWeight: _fontWeight(_getPropertyValue(_chordSlashNoteFontWeightProperty)) ??
        _fontWeight(_getPropertyValue(_chordNoteFontWeightProperty)) ??
        _fontWeight(_getPropertyValue(_universalFontWeightProperty)),
    fontStyle: _fontStyle(_getPropertyValue(_chordSlashNoteFontStyleProperty)) ??
        _fontStyle(_getPropertyValue(_chordNoteFontStyleProperty)) ??
        _fontStyle(_getPropertyValue(_universalFontStyleProperty)),
  );
}

TextStyle oddTitleText({TextStyle? from}) {
  return (from ?? generateAppTextStyle()).copyWith(
      backgroundColor: _getPropertyValue(_oddTitleTextBackgroundProperty),
      color: _getPropertyValue(_oddTitleTextColorProperty));
}

TextStyle evenTitleText({TextStyle? from}) {
  return (from ?? generateAppTextStyle()).copyWith(
      backgroundColor: _getPropertyValue(_evenTitleTextBackgroundProperty),
      color: _getPropertyValue(_evenTitleTextColorProperty));
}

@immutable
class CssProperty implements Comparable<CssProperty> {
  CssProperty(this.selector, this.selectorName, this.property, this.type,
      {required this.defaultValue, this.description})
      : _id = '${cssSelectorCharacterMap[selector] ?? ''}${selector == CssSelectorEnum.universal ? '' : selectorName}'
            '.$property' {
    _setPropertyValue(this, defaultValue);
    allCssProperties.add(this);
  }

  CssProperty.fromCssClass(CssClassEnum cssClass, this.property, this.type,
      {required this.defaultValue, this.description})
      : selector = CssSelectorEnum.classSelector,
        selectorName = Util.enumToString(cssClass),
        _id = '${cssSelectorCharacterMap[CssSelectorEnum.classSelector] ?? ''}'
            '${Util.enumToString(cssClass)}.$property' {
    _setPropertyValue(this, defaultValue);
    allCssProperties.add(this);
  }

  CssProperty.temporary(this.selector, this.selectorName, this.property)
      : type = Object,
        _id = '${cssSelectorCharacterMap[selector] ?? ''}${selector == CssSelectorEnum.universal ? '' : selectorName}'
            '.$property',
        defaultValue = 'none',
        description = 'none';

  @override
  int compareTo(CssProperty other) {
    if (identical(this, other)) {
      return 0;
    }
    var ret = selector.index - other.selector.index;
    if (ret != 0) {
      return ret < 0 ? -1 : 1;
    }
    ret = selectorName.compareTo(other.selectorName);
    if (ret != 0) {
      return ret;
    }
    ret = property.compareTo(other.property);
    if (ret != 0) {
      return ret;
    }
    // if (type != other.type) {
    //   ret = type.toString().compareTo(other.type.toString());
    //   if (ret != 0) {
    //     return ret;
    //   }
    // }
    return 0;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CssProperty &&
          runtimeType == other.runtimeType &&
          selector == other.selector &&
          selectorName == other.selectorName &&
          property == other.property
      // &&
      // type == other.type
      ;

  @override
  int get hashCode => selector.hashCode ^ selectorName.hashCode ^ property.hashCode
      // ^ type.hashCode
      ;

  @override
  String toString() {
    return id;
  }

  static void logCreations() {
    if (kDebugMode) {
      logger.d('CssProperty.allCssProperties.length: ${CssProperty.allCssProperties.length}');
      for (var property in allCssProperties) {
        logger.d(
            'log CssProperty: $property: ${_getPropertyValue(property)}, was ${property.defaultValue}, hash: ${property.hashCode}');
      }

      //  try to use all the generators
      generateAppTextStyle();
      generateTooltipTextStyle();
      generateChordTextStyle();
      generateLyricsTextStyle();
      generateChordDescriptorTextStyle();
      generateChordSlashNoteTextStyle();
      generateAppTextFieldStyle();
      generateAppBarLinkTextStyle();
      generateAppLinkTextStyle();

      if (_cssPropertiesUsed != null && _cssPropertiesSet != null) {
        logger.d('_cssPropertiesUsed.length: ${_cssPropertiesUsed!.length}');
        logger.d('_cssPropertiesSet.length: ${_cssPropertiesSet!.length}');
        for (var property in _cssPropertiesUsed!) {
          if (_cssPropertiesUsed!.contains(property)) {
            if (_cssPropertiesSet!.contains(property)) {
              logger.v('cssProperty used and set: $property: ${_getPropertyValue(property)}');
            } else {
              logger.w('cssProperty used but NOT set: $property');
            }
          } else {
            logger.w('cssProperty NOT used: $property');
          }
        }
        for (var property in _cssPropertiesSet!) {
          if (!_cssPropertiesUsed!.contains(property)) {
            logger.w('cssProperty set but NOT used: $property: ${_getPropertyValue(property)}');
          }
        }
      }
    }
    // logger.i(_documentCssProperties(_cssPropertiesSet));

    //  values no longer required after initialization
    allCssProperties.clear();
    _cssPropertiesUsed = null;
    _cssPropertiesSet = null;
  }

  final CssSelectorEnum selector;
  final String selectorName;
  final String property;
  final Type type;
  final dynamic defaultValue;
  final String? description;

  String get id => _id;
  final String _id;

  static SplayTreeSet<CssProperty> allCssProperties = SplayTreeSet();
}

class CssAction implements Comparable<CssAction> {
  CssAction(this.cssProperty, this.cssActionFunction);

  @override
  int compareTo(CssAction other) {
    return cssProperty.compareTo(other.cssProperty); //  fixme: deal with action function comparisons
  }

  @override
  String toString() {
    return cssProperty.toString();
  }

  CssProperty cssProperty;
  CssActionFunction cssActionFunction;
}

@immutable
class _AppliedAction {
  const _AppliedAction(this.cssAction, this.value, {this.rawValue});

  @override
  String toString() {
    return '$cssAction ${rawValue ?? value};';
  }

  final CssAction cssAction;
  final dynamic value;
  final String? rawValue;
}

void generateCssDocumentation() {
  logger.i('CssToCssFile:');
  logger.i(_documentCssProperties(cssActions.map((e) => e.cssProperty)));
}

String _documentCssProperties(final Iterable<CssProperty>? properties) {
  if (properties == null) {
    return '';
  }

  var sb = StringBuffer('''
/*
  bsteele Music App CSS style commands documentation
  
  Selectors are listed in increasing priority order.
  Note that many, many CSS features are missing in this mapping.
  The concept is to give basic control of major items.
*/

''');
  CssSelectorEnum lastSelector = CssSelectorEnum.id;
  String lastSelectorName = '';
  SplayTreeSet<CssProperty> sortedProperties = SplayTreeSet();
  sortedProperties.addAll(properties);
  for (var property in sortedProperties) {
    var value = _getPropertyValue(property) ?? 'unknown value';
    if (property.selector != lastSelector || property.selectorName != lastSelectorName) {
      if (lastSelectorName.isNotEmpty) {
        sb.writeln('}\n');
      }
      lastSelector = property.selector;
      lastSelectorName = property.selectorName;
      sb.writeln('${cssSelectorCharacterMap[CssSelectorEnum.classSelector] ?? ''}${property.selectorName} {');
    }

    String valueString = value.toString();
    switch (value.runtimeType) {
      case _CssColor:
        valueString = value.toCss();
        break;
    }
    sb.writeln('  ${property.property}: $valueString;'
        '\t\t\t/* type is ${property.type}, ${property.description} */');

    switch (value.runtimeType) {
      case visitor.LengthTerm:
        sb.writeln('  /* NOTE: the use of non-reactive font sizes is strongly discouraged\n'
            '     due to the many screen sizes required of the application.\n'
            '     Try using viewport (vw) instead.  E.g.: 2.2vw  */');
        break;
    }
  }
  if (lastSelectorName.isNotEmpty) {
    sb.writeln('}\n');
  }
  return sb.toString();
}

List<_AppliedAction> appliedActions = [];

List<CssAction> cssActions = [
  CssAction(_buttonBackgroundColorProperty, (CssProperty p, value) {
    assert(value is Color);
    app.themeData = app.themeData.copyWith(
        elevatedButtonTheme: ElevatedButtonThemeData(
            style: (app.themeData.elevatedButtonTheme.style == null
                ? ElevatedButton.styleFrom(primary: value)
                : app.themeData.elevatedButtonTheme.style!
                    .copyWith(backgroundColor: MaterialStateProperty.all(value)))));
    _setPropertyValue(p, value);
  }),
  CssAction(_buttonColorProperty, (CssProperty p, value) {
    assert(value is Color);
    app.themeData = app.themeData.copyWith(
        elevatedButtonTheme: ElevatedButtonThemeData(
            style: (app.themeData.elevatedButtonTheme.style == null
                ? ElevatedButton.styleFrom(onPrimary: value)
                : app.themeData.elevatedButtonTheme.style!
                    .copyWith(foregroundColor: MaterialStateProperty.all(value)))));
    _setPropertyValue(p, value);
  }),
  CssAction(appbarBackgroundColorProperty, (p, value) {
    assert(value is Color);
    app.themeData = app.themeData.copyWith(appBarTheme: app.themeData.appBarTheme.copyWith(backgroundColor: value));
    _setPropertyValue(p, value);
  }),
  CssAction(appbarColorProperty, (p, value) {
    assert(value is Color);
    app.themeData = app.themeData.copyWith(appBarTheme: app.themeData.appBarTheme.copyWith(foregroundColor: value));
    _setPropertyValue(p, value);
  }),
];

Map<String, dynamic> cssVariables = {};

void applyAction(
  CssSelectorEnum selector,
  String selectorName,
  String property,
  dynamic value, {
  String? rawValue,
}) {
  switch (selector) {
    case CssSelectorEnum.pseudo:
      if (selectorName == 'root') {
        cssVariables[property] = value;
        logger.d('cssVariables[ $property ] = $value;');
      } else {
        logger.e('unknown pseudo selector: $selectorName');
      }
      break;
    default:
      var applications = 0;
      for (var action in cssActions.where((e) =>
          selector == e.cssProperty.selector &&
          selectorName == e.cssProperty.selectorName &&
          property == e.cssProperty.property)) {
        logger.log(_cssLog, 'CSS action: ${action.toString()} /*${value.runtimeType}*/ $value;');
        action.cssActionFunction(action.cssProperty, value);
        appliedActions.add(_AppliedAction(action, value, rawValue: rawValue));

        applications++;
      }
      if (applications == 0) {
        _setPropertyValue(CssProperty.temporary(selector, selectorName, property), value);
        logger.log(
            _cssLog,
            'CSS action assumed: '
            '${cssSelectorCharacterMap[selector] ?? ''}$selectorName.$property: $value;'
            ' allCssProperties: ${CssProperty.allCssProperties.length}');
      }
  }
}

ThemeData generateDocsThemeData() {
  return ThemeData(
    textTheme: TextTheme(bodyText2: TextStyle(fontSize: _sizeLookup(_docFontSizeProperty) ?? 24.0)),
  );
}

final ThemeData appDocsThemeData = generateDocsThemeData();
