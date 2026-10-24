import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../theme.dart';

/// Real ad unit IDs are passed in by the cloud build (--dart-define).
/// Without them, Google's official test ads are shown.
const _bannerId = String.fromEnvironment(
  'ADMOB_BANNER_ID',
  defaultValue: 'ca-app-pub-3940256099942544/6300978111',
);

bool get _supported => Platform.isAndroid || Platform.isIOS;

/// Becomes true once consent has been handled and the SDK is ready.
final _adsReady = ValueNotifier<bool>(false);

/// Asks for consent where the law requires it (EU/UK), then starts AdMob.
/// Call after runApp so the consent form has a screen to show on.
Future<void> initAds() async {
  if (!_supported) return;

  final consentDone = Completer<void>();
  ConsentInformation.instance.requestConsentInfoUpdate(
    ConsentRequestParameters(),
    () => ConsentForm.loadAndShowConsentFormIfRequired(
      (_) => consentDone.complete(),
    ),
    (_) => consentDone.complete(),
  );
  await consentDone.future;

  if (!await ConsentInformation.instance.canRequestAds()) return;

  // Family-safe ads only.
  await MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(maxAdContentRating: MaxAdContentRating.g),
  );
  await MobileAds.instance.initialize();
  _adsReady.value = true;
}

/// Whether the app must offer a way to change ad consent (EU/UK users).
Future<bool> privacyOptionsRequired() async {
  if (!_supported) return false;
  final status = await ConsentInformation.instance
      .getPrivacyOptionsRequirementStatus();
  return status == PrivacyOptionsRequirementStatus.required;
}

Future<void> showPrivacyOptions() => ConsentForm.showPrivacyOptionsForm((_) {});

/// A small banner anchored at the bottom of a screen.
/// Takes no space until an ad has actually loaded.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  int? _width;

  @override
  void initState() {
    super.initState();
    _adsReady.addListener(_load);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    if (!_adsReady.value || !mounted) return;
    final width = MediaQuery.sizeOf(context).width.truncate();
    if (width == _width) return;
    _width = width;

    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (size == null || !mounted) return;

    _ad?.dispose();
    setState(() => _loaded = false);
    _ad = BannerAd(
      adUnitId: _bannerId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) setState(() => _ad = null);
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _adsReady.removeListener(_load);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.paper,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SizedBox(
          width: double.infinity,
          height: ad.size.height.toDouble(),
          child: Center(
            child: SizedBox(
              width: ad.size.width.toDouble(),
              height: ad.size.height.toDouble(),
              child: AdWidget(ad: ad),
            ),
          ),
        ),
      ),
    );
  }
}
