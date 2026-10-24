import 'package:daily_hukamnama/models/hukamnama.dart';
import 'package:flutter_test/flutter_test.dart';

// Placeholder strings only: real Gurbani always comes from BaniDB.
Map<String, dynamic> verse(String text, {Map<String, dynamic>? source}) => {
  'verse': {'unicode': text},
  'transliteration': {'english': 'translit $text'},
  'translation': {
    'en': {'bdb': null, 'ms': 'meaning $text'},
    'pu': {
      'ss': {'gurmukhi': 'x', 'unicode': 'punjabi $text'},
    },
  },
  'source': ?source,
};

void main() {
  test('parses a hukamnamas response', () {
    final h = Hukamnama.fromResponse({
      'isLatest': true,
      'date': {
        'gregorian': {'month': 10, 'date': 24, 'year': 2026},
      },
      'shabads': [
        {
          'shabadInfo': {
            'pageNo': 641,
            'source': {'english': 'Source Name', 'pageNo': 641},
            'raag': {'english': 'Raag Name'},
            'writer': {'english': 'Writer Name'},
          },
          'verses': [
            verse('LINE 1'),
            verse('LINE 2', source: {'english': 'Source Name'}),
            {
              'verse': {'unicode': ' '},
            },
          ],
        },
      ],
    })!;

    expect(h.date, DateTime(2026, 10, 24));
    expect(h.lines.map((l) => l.gurmukhi), ['LINE 1', 'LINE 2']);
    expect(h.lines.first.english, 'meaning LINE 1');
    expect(h.lines.first.punjabi, 'punjabi LINE 1');
    expect(h.lines.first.transliteration, 'translit LINE 1');
    expect(h.reference, 'Source Name, Ang 641');
    expect(h.raag, 'Raag Name');
    expect(h.writer, 'Writer Name');
  });

  test('joins lines from several shabads', () {
    final h = Hukamnama.fromResponse({
      'date': {
        'gregorian': {'month': 1, 'date': 2, 'year': 2003},
      },
      'shabads': [
        {
          'verses': [verse('A')],
        },
        {
          'verses': [verse('B')],
        },
      ],
    })!;
    expect(h.lines.map((l) => l.gurmukhi), ['A', 'B']);
    expect(h.reference, '');
  });

  test('rejects malformed responses', () {
    expect(Hukamnama.fromResponse(null), isNull);
    expect(Hukamnama.fromResponse({'shabads': []}), isNull);
    expect(
      Hukamnama.fromResponse({
        'date': {
          'gregorian': {'month': 1, 'date': 2, 'year': 2003},
        },
        'shabads': [
          {'verses': []},
        ],
      }),
      isNull,
    );
  });
}
