import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Daily Hukamnama notifications through Firebase Cloud Messaging.
///
/// The notifications themselves are sent by the "Hukamnama notifier"
/// GitHub workflow to the [topic] below. Firebase settings are passed in by
/// the cloud build; without them the app simply runs without notifications.
class PushService {
  static const topic = 'daily-hukamnama';

  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

  static bool get isConfigured =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      _apiKey.isNotEmpty &&
      _appId.isNotEmpty &&
      _senderId.isNotEmpty &&
      _projectId.isNotEmpty;

  /// The Hukamnama date a tapped notification asked to open, if any.
  static final openedDate = ValueNotifier<DateTime?>(null);

  static bool _ready = false;

  static Future<void> init() async {
    if (!isConfigured) return;
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: _apiKey,
          appId: _appId,
          messagingSenderId: _senderId,
          projectId: _projectId,
        ),
      );
      _ready = true;

      final messaging = FirebaseMessaging.instance;
      final initial = await messaging.getInitialMessage();
      if (initial != null) _handleOpen(initial);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpen);
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  /// Asks for permission (Android 13+) and subscribes, or unsubscribes.
  static Future<bool> setEnabled(bool enabled) async {
    if (!_ready) return false;
    try {
      final messaging = FirebaseMessaging.instance;
      if (enabled) {
        final settings = await messaging.requestPermission();
        if (settings.authorizationStatus == AuthorizationStatus.denied) {
          return false;
        }
        await messaging.subscribeToTopic(topic);
      } else {
        await messaging.unsubscribeFromTopic(topic);
      }
      return true;
    } catch (e) {
      debugPrint('Could not change notification setting: $e');
      return false;
    }
  }

  static void _handleOpen(RemoteMessage message) {
    final date = DateTime.tryParse(message.data['date'] as String? ?? '');
    if (date != null) openedDate.value = date;
  }
}
