import 'package:flutter/widgets.dart';

Future<void> initAds() async {}

Future<bool> privacyOptionsRequired() async => false;

Future<void> showPrivacyOptions() async {}

class AdBanner extends StatelessWidget {
  const AdBanner({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
