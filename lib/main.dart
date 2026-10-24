import 'package:flutter/material.dart';

import 'ads/ads.dart';
import 'screens/home_screen.dart';
import 'services/push_service.dart';
import 'services/settings.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await Settings.load();
  await PushService.init();
  runApp(DailyHukamnamaApp(settings: settings));
  initAds();
}

class DailyHukamnamaApp extends StatelessWidget {
  const DailyHukamnamaApp({super.key, required this.settings});

  final Settings settings;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily Hukamnama',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: HomeScreen(settings: settings),
    );
  }
}
