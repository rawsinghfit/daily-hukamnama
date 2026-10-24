/// Ads are shown only in the Android/iOS app. The web version has none.
library;

export 'ads_stub.dart' if (dart.library.io) 'ads_mobile.dart';
