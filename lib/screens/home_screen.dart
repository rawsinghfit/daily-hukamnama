import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ads/ads.dart';
import '../models/hukamnama.dart';
import '../services/banidb_service.dart';
import '../services/push_service.dart';
import '../services/settings.dart';
import '../theme.dart';

const _wallpapersAppUrl =
    'https://play.google.com/store/apps/details?id=com.gurbaniwallpapers.gurbani_wallpapers';

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _weekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];

String formatDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.settings, this.service});

  final Settings settings;
  final BaniDbService? service;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final BaniDbService _service = widget.service ?? BaniDbService();
  Settings get _settings => widget.settings;

  Hukamnama? _hukamnama;
  DateTime? _latestDate;
  DateTime? _requestedDate; // null means "latest"
  bool _loading = true;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettings);
    PushService.openedDate.addListener(_onNotificationOpened);
    final opened = PushService.openedDate.value;
    _load(opened);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAskNotifications());
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettings);
    PushService.openedDate.removeListener(_onNotificationOpened);
    super.dispose();
  }

  void _onSettings() => setState(() {});

  void _onNotificationOpened() {
    final date = PushService.openedDate.value;
    if (date != null) _load(date);
  }

  Future<void> _load([DateTime? date]) async {
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
      _requestedDate = date;
    });
    try {
      final result =
          date == null ? await _service.latest() : await _service.forDate(date);
      if (!mounted || id != _requestId) return;
      setState(() {
        _hukamnama = result;
        if (date == null) _latestDate = result.date;
        _loading = false;
      });
    } on BaniDbException catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  bool get _isLatest =>
      _requestedDate == null ||
      (_latestDate != null && DateUtils.isSameDay(_requestedDate, _latestDate));

  Future<void> _maybeAskNotifications() async {
    if (!PushService.isConfigured || _settings.notifications != null) return;
    final allow = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Daily Hukamnama'),
        content: const Text(
          'Get a notification each morning when the new Hukamnama from Sri '
          'Darbar Sahib is available, with its first line.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Notify me'),
          ),
        ],
      ),
    );
    await _setNotifications(allow ?? false);
  }

  Future<void> _setNotifications(bool enabled) async {
    final ok = await PushService.setEnabled(enabled);
    await _settings.set('notifications', enabled && ok);
    if (enabled && !ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
          'Notifications are turned off for this app. You can allow them in '
          "your phone's settings.",
        ),
      ));
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _hukamnama?.date ?? now,
      firstDate: BaniDbService.firstDate,
      lastDate: _latestDate ?? now,
      helpText: 'Choose a date',
    );
    if (picked == null) return;
    _load(_latestDate != null && DateUtils.isSameDay(picked, _latestDate)
        ? null
        : picked);
  }

  void _goToDay(int offset) {
    final h = _hukamnama;
    if (h == null) return;
    final day = DateUtils.addDaysToDate(h.date, offset);
    if (day.isBefore(BaniDbService.firstDate)) return;
    final latest = _latestDate;
    if (latest != null && !day.isBefore(latest)) {
      _load();
    } else {
      _load(day);
    }
  }

  void _share(BuildContext buttonContext) {
    final h = _hukamnama;
    if (h == null) return;
    final box = buttonContext.findRenderObject() as RenderBox?;
    final text = [
      'Hukamnama from Sri Darbar Sahib, ${formatDate(h.date)}',
      '',
      ...h.lines.map((l) => l.gurmukhi),
      '',
      if (h.reference.isNotEmpty) h.reference,
      'Shared from the Daily Hukamnama app',
    ].join('\n');
    SharePlus.instance.share(ShareParams(
      text: text,
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      showDragHandle: true,
      builder: (context) => ListenableBuilder(
        listenable: _settings,
        builder: (context, _) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            children: [
              SwitchListTile(
                title: const Text('Show pronunciation'),
                value: _settings.showTransliteration,
                onChanged: (v) => _settings.set('showTransliteration', v),
              ),
              SwitchListTile(
                title: const Text('Show English meaning'),
                value: _settings.showEnglish,
                onChanged: (v) => _settings.set('showEnglish', v),
              ),
              SwitchListTile(
                title: const Text('Show Punjabi meaning'),
                value: _settings.showPunjabi,
                onChanged: (v) => _settings.set('showPunjabi', v),
              ),
              if (PushService.isConfigured)
                SwitchListTile(
                  title: const Text('Morning notification'),
                  subtitle: const Text('First line of each new Hukamnama'),
                  value: _settings.notifications ?? false,
                  onChanged: _setNotifications,
                ),
              ListTile(
                title: const Text('Text size'),
                subtitle: Slider(
                  value: _settings.textScale,
                  min: 0.8,
                  max: 1.6,
                  divisions: 8,
                  label: '${(_settings.textScale * 100).round()}%',
                  onChanged: (v) => _settings.set('textScale', v),
                ),
              ),
              FutureBuilder<bool>(
                future: privacyOptionsRequired(),
                builder: (context, snap) => snap.data == true
                    ? ListTile(
                        title: const Text('Ad privacy settings'),
                        onTap: showPrivacyOptions,
                      )
                    : const SizedBox.shrink(),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'The Hukamnama comes live from BaniDB by Khalis Foundation and '
                  'is shown exactly as it is received.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Hukamnama'),
        actions: [
          IconButton(
            tooltip: 'Choose a date',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: _pickDate,
          ),
          Builder(
            builder: (buttonContext) => IconButton(
              tooltip: 'Share',
              icon: const Icon(Icons.share_outlined),
              onPressed: _hukamnama == null ? null : () => _share(buttonContext),
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.tune),
            onPressed: _openSettings,
          ),
        ],
      ),
      bottomNavigationBar: const AdBanner(),
      body: SafeArea(top: false, child: _body()),
    );
  }

  Widget _body() {
    if (_loading && _hukamnama == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.muted),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 16),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _load(_requestedDate),
                child: const Text('Try again'),
              ),
              if (!_isLatest)
                TextButton(
                  onPressed: () => _load(),
                  child: const Text("Back to today's Hukamnama"),
                ),
            ],
          ),
        ),
      );
    }

    final h = _hukamnama!;
    return RefreshIndicator(
      onRefresh: () => _load(_requestedDate),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              _Header(hukamnama: h, isLatest: _isLatest),
              _DayNavigation(
                canGoBack: h.date.isAfter(BaniDbService.firstDate),
                canGoForward: !_isLatest,
                onPrevious: () => _goToDay(-1),
                onNext: () => _goToDay(1),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Column(
                    children: [
                      for (var i = 0; i < h.lines.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _LineView(line: h.lines[i], settings: _settings),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _WallpaperPromo(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.hukamnama, required this.isLatest});

  final Hukamnama hukamnama;
  final bool isLatest;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final details = [
      if (hukamnama.ang != null) 'Ang ${hukamnama.ang}',
      hukamnama.raag,
      hukamnama.writer,
    ].where((s) => s.isNotEmpty).join('  ·  ');
    const onBanner = Colors.white;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.kesri, AppColors.maroon],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Hukamnama Sahib · Sri Darbar Sahib',
                  style: textTheme.labelLarge?.copyWith(
                    color: onBanner.withValues(alpha: 0.85),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (isLatest)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: onBanner.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Latest',
                    style: textTheme.labelSmall?.copyWith(color: onBanner),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            formatDate(hukamnama.date),
            style: headingStyle(24, color: onBanner),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              details,
              style: textTheme.bodyMedium?.copyWith(
                color: onBanner.withValues(alpha: 0.9),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DayNavigation extends StatelessWidget {
  const _DayNavigation({
    required this.canGoBack,
    required this.canGoForward,
    required this.onPrevious,
    required this.onNext,
  });

  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: canGoBack ? onPrevious : null,
            icon: const Icon(Icons.chevron_left),
            label: const Text('Previous day'),
          ),
          Directionality(
            textDirection: TextDirection.rtl,
            child: TextButton.icon(
              onPressed: canGoForward ? onNext : null,
              icon: const Icon(Icons.chevron_left),
              label: const Text('Next day'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineView extends StatelessWidget {
  const _LineView({required this.line, required this.settings});

  final HukamLine line;
  final Settings settings;

  @override
  Widget build(BuildContext context) {
    final scale = settings.textScale;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Text(
            line.gurmukhi,
            textAlign: TextAlign.center,
            style: gurmukhiStyle(22 * scale),
          ),
          if (settings.showTransliteration && line.transliteration.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                line.transliteration,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15 * scale,
                  fontStyle: FontStyle.italic,
                  color: AppColors.muted,
                ),
              ),
            ),
          if (settings.showEnglish && line.english.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                line.english,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15 * scale, height: 1.45),
              ),
            ),
          if (settings.showPunjabi && line.punjabi.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                line.punjabi,
                textAlign: TextAlign.center,
                style: gurmukhiStyle(16 * scale, color: AppColors.maroon),
              ),
            ),
        ],
      ),
    );
  }
}

class _WallpaperPromo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        leading: const Icon(Icons.wallpaper_outlined, color: AppColors.kesri),
        title: const Text('Make a Gurbani wallpaper'),
        subtitle: const Text('Get our Gurbani Wallpapers app'),
        trailing: const Icon(Icons.open_in_new, color: AppColors.muted),
        onTap: () => unawaited(launchUrl(
          Uri.parse(_wallpapersAppUrl),
          mode: LaunchMode.externalApplication,
        )),
      ),
    );
  }
}
