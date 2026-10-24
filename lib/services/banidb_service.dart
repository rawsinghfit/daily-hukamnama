import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/hukamnama.dart';

class BaniDbException implements Exception {
  const BaniDbException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Reads the Hukamnama from Sri Darbar Sahib live from BaniDB (Khalis Foundation).
class BaniDbService {
  BaniDbService({http.Client? client}) : _client = client ?? http.Client();

  static const _baseUrl = 'https://api.banidb.com/v2/hukamnamas';
  static const _timeout = Duration(seconds: 15);

  /// BaniDB's archive starts on this date.
  static final firstDate = DateTime(2002, 1, 1);

  static const networkError =
      "Couldn't reach the Gurbani database. Check your internet connection and try again.";

  final http.Client _client;

  Future<Hukamnama> latest() => _get(_baseUrl);

  Future<Hukamnama> forDate(DateTime date) =>
      _get('$_baseUrl/${date.year}/${date.month}/${date.day}');

  Future<Hukamnama> _get(String url) async {
    final http.Response response;
    try {
      response = await _client.get(Uri.parse(url)).timeout(_timeout);
    } catch (_) {
      throw const BaniDbException(networkError);
    }
    if (response.statusCode == 404) {
      throw const BaniDbException('No Hukamnama is available for that date.');
    }
    if (response.statusCode != 200) {
      throw const BaniDbException(networkError);
    }
    Hukamnama? hukamnama;
    try {
      hukamnama = Hukamnama.fromResponse(jsonDecode(utf8.decode(response.bodyBytes)));
    } catch (_) {
      hukamnama = null;
    }
    if (hukamnama == null) {
      throw const BaniDbException(
        'The Gurbani database sent an unexpected reply. Please try again.',
      );
    }
    return hukamnama;
  }
}
