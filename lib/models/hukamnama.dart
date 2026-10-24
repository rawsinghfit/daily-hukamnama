/// One line of the Hukamnama exactly as returned by BaniDB.
class HukamLine {
  const HukamLine({
    required this.gurmukhi,
    this.transliteration = '',
    this.english = '',
    this.punjabi = '',
  });

  final String gurmukhi;
  final String transliteration;
  final String english;
  final String punjabi;
}

/// The Hukamnama for one day. The text is only ever displayed, never edited.
class Hukamnama {
  const Hukamnama({
    required this.date,
    required this.lines,
    this.sourceName = '',
    this.ang,
    this.raag = '',
    this.writer = '',
  });

  final DateTime date;
  final List<HukamLine> lines;
  final String sourceName;
  final int? ang;
  final String raag;
  final String writer;

  /// e.g. "Sri Guru Granth Sahib Ji, Ang 641"
  String get reference => [
        if (sourceName.isNotEmpty) sourceName,
        if (ang != null) 'Ang $ang',
      ].join(', ');

  /// Parses a BaniDB v2 /hukamnamas response. Returns null if it holds no text.
  static Hukamnama? fromResponse(dynamic body) {
    if (body is! Map) return null;

    final gregorian = _path(body, ['date', 'gregorian']);
    final year = _int(_path(gregorian, ['year']));
    final month = _int(_path(gregorian, ['month']));
    final day = _int(_path(gregorian, ['date']));
    if (year == null || month == null || day == null) return null;

    final shabads = body['shabads'];
    if (shabads is! List || shabads.isEmpty) return null;

    final lines = <HukamLine>[];
    Map? firstInfo;
    for (final shabad in shabads) {
      if (shabad is! Map) continue;
      final info = shabad['shabadInfo'];
      if (firstInfo == null && info is Map) firstInfo = info;
      final verses = shabad['verses'];
      if (verses is! List) continue;
      for (final v in verses) {
        final line = _line(v);
        if (line != null) lines.add(line);
      }
    }
    if (lines.isEmpty) return null;

    return Hukamnama(
      date: DateTime(year, month, day),
      lines: lines,
      sourceName: _string(_path(firstInfo, ['source', 'english'])),
      ang: _int(_path(firstInfo, ['pageNo'])) ??
          _int(_path(firstInfo, ['source', 'pageNo'])),
      raag: _string(_path(firstInfo, ['raag', 'english'])),
      writer: _string(_path(firstInfo, ['writer', 'english'])),
    );
  }

  static HukamLine? _line(dynamic verse) {
    if (verse is! Map) return null;
    final gurmukhi = _string(_path(verse, ['verse', 'unicode']));
    if (gurmukhi.isEmpty) return null;

    final en = _path(verse, ['translation', 'en']);
    var english = '';
    for (final key in const ['bdb', 'ms', 'ssk']) {
      english = _string(_path(en, [key]));
      if (english.isNotEmpty) break;
    }

    final pu = _path(verse, ['translation', 'pu']);
    var punjabi = '';
    for (final key in const ['ss', 'ft', 'bdb', 'ms']) {
      punjabi = _string(_path(pu, [key, 'unicode']));
      if (punjabi.isNotEmpty) break;
    }

    return HukamLine(
      gurmukhi: gurmukhi,
      transliteration: _string(_path(verse, ['transliteration', 'english'])),
      english: english,
      punjabi: punjabi,
    );
  }
}

dynamic _path(dynamic node, List<String> keys) {
  var current = node;
  for (final key in keys) {
    if (current is! Map) return null;
    current = current[key];
  }
  return current;
}

String _string(dynamic value) => value is String ? value.trim() : '';

int? _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
