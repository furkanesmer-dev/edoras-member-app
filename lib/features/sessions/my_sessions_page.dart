import 'dart:async';

import 'package:flutter/material.dart';
import 'package:edoras_member_app/core/api/api_client.dart';
import 'package:edoras_member_app/core/theme/app_colors.dart';

class MySessionsPage extends StatefulWidget {
  final ApiClient apiClient;

  const MySessionsPage({
    super.key,
    required this.apiClient,
  });

  @override
  State<MySessionsPage> createState() => MySessionsPageState();
}

class MySessionsPageState extends State<MySessionsPage> {
  bool _loading = true;
  String? _error;

  int _tab = 0; // 0: Yaklaşan, 1: Geçmiş

  List<Map<String, dynamic>> _upcoming = const [];
  List<Map<String, dynamic>> _past = const [];

  Map<String, dynamic> _paket = const {};

  static const int _upcomingPreviewCount = 3;

  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    _scheduleMidnightRefresh();
    _load();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    super.dispose();
  }

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();

    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final delay = nextMidnight.difference(now);

    _midnightTimer = Timer(delay, () {
      if (mounted) {
        setState(() {});
        _scheduleMidnightRefresh();
      }
    });
  }

  Future<void> reload() => _load();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await widget.apiClient.dio.get('/seans/list.php');
      final raw = res.data;

      if (raw is! Map) throw Exception('Beklenmeyen response');
      // Backend hem ok hem success döndürebilir; ikisini de destekle.
      final isOk = raw['ok'] == true || raw['success'] == true;
      if (!isOk) throw Exception((raw['msg'] ?? raw['message'] ?? 'Hata').toString());

      final data = raw['data'];
      if (data is! Map) throw Exception('data alanı yok');

      final up = (data['upcoming'] is List) ? List.from(data['upcoming']) : [];
      final past = (data['past'] is List) ? List.from(data['past']) : [];

      // Güvenli cast: liste elemanı Map değilse (beklenmeyen backend verisi) atla.
      final upcoming = up
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final pastList = past
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final paketRaw = data['paket'] ?? data['package'] ?? data['session_info'];
      final paket = (paketRaw is Map)
          ? Map<String, dynamic>.from(paketRaw)
          : <String, dynamic>{};

      upcoming.sort((a, b) => _cmpDateTimeAsc(
            (a['seans_tarih_saat'] ?? '').toString(),
            (b['seans_tarih_saat'] ?? '').toString(),
          ));
      pastList.sort((a, b) => _cmpDateTimeDesc(
            (a['seans_tarih_saat'] ?? '').toString(),
            (b['seans_tarih_saat'] ?? '').toString(),
          ));

      if (!mounted) return;
      // Tab otomatik geçişini aynı setState içinde yaparak double rebuild engellendi.
      setState(() {
        _upcoming = upcoming;
        _past = pastList;
        _paket = paket;
        _loading = false;
        if (upcoming.isEmpty && pastList.isNotEmpty) _tab = 1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  DateTime? _tryParseIso(String iso) {
    final t = iso.trim();
    if (t.isEmpty) return null;
    final safe = t.contains('T') ? t : t.replaceFirst(' ', 'T');
    try {
      return DateTime.parse(safe);
    } catch (_) {
      return null;
    }
  }

  int _cmpDateTimeAsc(String a, String b) {
    final da = _tryParseIso(a);
    final db = _tryParseIso(b);
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  }

  int _cmpDateTimeDesc(String a, String b) {
    final da = _tryParseIso(a);
    final db = _tryParseIso(b);
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return db.compareTo(da);
  }

  String _fmtDateTime(String iso) {
    final d = _tryParseIso(iso);
    if (d == null) return '-';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} • '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _trStatus(String s) {
    switch (s) {
      case 'planned':
        return 'Planlandı';
      case 'done':
        return 'Tamamlandı';
      case 'no_show':
        return 'Gelmedi';
      case 'canceled':
        return 'İptal';
      default:
        return s.isEmpty ? '-' : s;
    }
  }

  ({Color bg, Color fg, Color border, IconData icon}) _statusColors(String rawStatus) {
    switch (rawStatus) {
      case 'done':
        return (
          bg: const Color(0xFFEAFBF2),
          fg: const Color(0xFF138A55),
          border: const Color(0xFFC7F0D8),
          icon: Icons.check_circle_rounded,
        );
      case 'planned':
        return (
          bg: const Color(0xFFEEF4FF),
          fg: const Color(0xFF315FDC),
          border: const Color(0xFFD8E5FF),
          icon: Icons.schedule_rounded,
        );
      case 'canceled':
        return (
          bg: const Color(0xFFFFEFEF),
          fg: const Color(0xFFD14343),
          border: const Color(0xFFF7D0D0),
          icon: Icons.cancel_rounded,
        );
      case 'no_show':
        return (
          bg: const Color(0xFFFFF4E9),
          fg: const Color(0xFFE37A14),
          border: const Color(0xFFF9DFC0),
          icon: Icons.person_off_rounded,
        );
      default:
        return (
          bg: const Color(0xFFF4F7FB),
          fg: AppColors.lightTextSub,
          border: const Color(0xFFE7EDF5),
          icon: Icons.info_rounded,
        );
    }
  }

  String _valStr(dynamic v) {
    if (v == null) return '-';
    final s = v.toString().trim();
    return s.isEmpty ? '-' : s;
  }

  int? _valInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }

  int _remainingDaysToEnd(DateTime end) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endDate = DateTime(end.year, end.month, end.day);

    final diff = endDate.difference(today).inDays;
    return diff < 0 ? 0 : diff;
  }

  _SummaryData _summaryData() {
    final abonelikTipiRaw =
        (_paket['abonelik_tipi'] ?? _paket['subscription_type'] ?? _paket['type'])
            ?.toString()
            .trim()
            .toLowerCase();

    final abonelikSuresiAy =
        _valInt(_paket['abonelik_suresi_ay'] ?? _paket['sure_ay'] ?? _paket['months']);

    final baslangicStr =
        (_paket['baslangic_tarihi'] ?? _paket['start_date'] ?? '').toString();
    final bitisStr = (_paket['bitis_tarihi'] ?? _paket['end_date'] ?? '').toString();

    final paketToplamSeans = _valInt(
      _paket['paket_toplam_seans'] ?? _paket['toplam_seans'] ?? _paket['total_sessions'],
    );
    final paketKalanSeans = _valInt(
      _paket['paket_kalan_seans'] ?? _paket['kalan_seans'] ?? _paket['remaining_sessions'],
    );

    String leftTitle = 'Kalan Seans';
    String leftValue = '-';

    String rightTitle = 'Paket';
    String rightValue = '-';

    if (abonelikTipiRaw == 'aylik') {
      final x = abonelikSuresiAy ?? 0;
      rightValue = 'Aylık (${x} Ay)';

      leftTitle = 'Kalan Gün';
      final end = _tryParseIso(bitisStr);
      if (end != null) {
        final days = _remainingDaysToEnd(end);
        leftValue = '$days Gün';
      } else {
        leftValue = '-';
      }
    } else if (abonelikTipiRaw == 'ders_paketi') {
      final x = paketToplamSeans ?? 0;
      rightValue = '$x Ders';

      leftTitle = 'Kalan Seans';
      leftValue = paketKalanSeans?.toString() ?? '-';
    } else {
      final kalanSeans = paketKalanSeans;
      final toplamSeans = paketToplamSeans;

      if (kalanSeans != null && toplamSeans != null) {
        leftValue = '$kalanSeans / $toplamSeans';
      } else if (kalanSeans != null) {
        leftValue = kalanSeans.toString();
      }

      final paketAdi = _valStr(_paket['paket_adi'] ?? _paket['ad'] ?? _paket['name']);
      final paketTipi = _valStr(_paket['paket_tipi'] ?? _paket['tip'] ?? _paket['type']);
      rightValue = paketAdi != '-' ? paketAdi : paketTipi;
    }

    return _SummaryData(
      leftTitle: leftTitle,
      leftValue: leftValue,
      rightTitle: rightTitle,
      rightValue: rightValue,
      baslangic: baslangicStr,
      bitis: bitisStr,
    );
  }

  _PastStats _calcPastStats() {
    int done = 0, canceled = 0, noShow = 0;

    for (final s in _past) {
      final st = (s['durum'] ?? '').toString();
      switch (st) {
        case 'done':
          done++;
          break;
        case 'canceled':
          canceled++;
          break;
        case 'no_show':
          noShow++;
          break;
      }
    }

    return _PastStats(
      total: _past.length,
      done: done,
      canceled: canceled,
      noShow: noShow,
    );
  }

  Widget _buildTopArea() {
    final summary = _summaryData();
    final stats = _calcPastStats();

    return Column(
      children: [
        _SessionsHeroCard(
          tab: _tab,
          upcomingCount: _upcoming.length,
          pastCount: _past.length,
          onTabChange: (i) => setState(() => _tab = i),
        ),
        const SizedBox(height: 14),
        _PackageSummaryCard(summary: summary),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MiniStatCard(
                title: summary.leftTitle,
                value: summary.leftValue,
                accent: const Color(0xFF4F7CFF),
                icon: Icons.auto_awesome_motion_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniStatCard(
                title: 'Tamamlanan',
                value: stats.done.toString(),
                accent: const Color(0xFF14B86A),
                icon: Icons.check_circle_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniStatCard(
                title: 'İptal',
                value: stats.canceled.toString(),
                accent: const Color(0xFFFF7A18),
                icon: Icons.cancel_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sessionTile(Map<String, dynamic> s, {required bool isPast}) {
    final title = (s['baslik'] ?? 'Seans').toString();
    final tarihSaat = (s['seans_tarih_saat'] ?? '').toString();
    final sure = (s['sure_dk'] ?? 0).toString();
    final lokasyonRaw = (s['lokasyon'] ?? '').toString().trim();

    final rawStatus = (s['durum'] ?? '').toString();
    final statusText = _trStatus(rawStatus);
    final statusTheme = _statusColors(rawStatus);

    final dateText = _fmtDateTime(tarihSaat);
    final locationText = lokasyonRaw.isNotEmpty ? lokasyonRaw : 'Konum belirtilmedi';

    return _SessionPremiumCard(
      title: title,
      dateTimeText: dateText,
      durationText: '$sure dk',
      locationText: locationText,
      statusText: statusText,
      statusTheme: statusTheme,
      accent: isPast ? const Color(0xFF14B86A) : const Color(0xFF4F7CFF),
      isPast: isPast,
    );
  }

  Widget _buildUpcomingTab() {
    final preview = (_upcoming.length <= _upcomingPreviewCount)
        ? _upcoming
        : _upcoming.take(_upcomingPreviewCount).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        children: [
          _buildTopArea(),
          const SizedBox(height: 14),
          _SectionHeader(
            title: 'Yaklaşan Seanslar',
            subtitle: preview.isEmpty
                ? 'Planlı bir seans görünmüyor.'
                : 'Sıradaki seansların burada listeleniyor.',
            icon: Icons.schedule_rounded,
            accent: const Color(0xFF4F7CFF),
          ),
          const SizedBox(height: 10),
          if (preview.isEmpty)
            const _EmptyStateCard(
              title: 'Yaklaşan seans yok',
              subtitle: 'Yeni planlanan seanslar burada görünecek.',
              icon: Icons.event_busy_rounded,
              accent: Color(0xFF4F7CFF),
            )
          else
            ...preview.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _sessionTile(s, isPast: false),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPastTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        children: [
          _buildTopArea(),
          const SizedBox(height: 14),
          _SectionHeader(
            title: 'Geçmiş Seanslar',
            subtitle: _past.isEmpty
                ? 'Henüz geçmiş seans verisi yok.'
                : 'Tamamlanan ve geçmiş kayıtların burada listeleniyor.',
            icon: Icons.history_rounded,
            accent: const Color(0xFF14B86A),
          ),
          const SizedBox(height: 10),
          if (_past.isEmpty)
            const _EmptyStateCard(
              title: 'Geçmiş seans yok',
              subtitle: 'Tamamlanan seansların daha sonra burada görünecek.',
              icon: Icons.inbox_rounded,
              accent: Color(0xFF14B86A),
            )
          else
            ..._past.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _sessionTile(s, isPast: true),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Stack(
          children: [
            _BrightSessionsBackground(),
            SafeArea(
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF4F7CFF),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Stack(
          children: [
            const _BrightSessionsBackground(),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _ErrorCard(
                    message: _error!,
                    onRetry: _load,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          const _BrightSessionsBackground(),
          SafeArea(
            child: IndexedStack(
              index: _tab,
              children: [
                _buildUpcomingTab(),
                _buildPastTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrightSessionsBackground extends StatelessWidget {
  const _BrightSessionsBackground();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IgnorePointer(
      child: Container(
        color: isDark ? AppColors.darkBg : AppColors.lightBg,
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -30,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(isDark ? 0.14 : 0.08),
                ),
              ),
            ),
            Positioned(
              top: 150,
              left: -50,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary.withOpacity(isDark ? 0.10 : 0.06),
                ),
              ),
            ),
            Positioned(
              bottom: 100,
              right: -45,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success.withOpacity(isDark ? 0.08 : 0.05),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionsHeroCard extends StatelessWidget {
  final int tab;
  final int upcomingCount;
  final int pastCount;
  final ValueChanged<int> onTabChange;

  const _SessionsHeroCard({
    required this.tab,
    required this.upcomingCount,
    required this.pastCount,
    required this.onTabChange,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _PremiumCardSurface(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Stack(
        children: [
          Positioned(
            top: -18,
            right: -18,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF7FB2FF).withOpacity(0.18),
              ),
            ),
          ),
          Positioned(
            bottom: -28,
            left: -20,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFB074).withOpacity(0.13),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0xFFEFF5FF),
                  border: Border.all(color: const Color(0xFFD8E7FF)),
                ),
                child: const Text(
                  'Seanslarım',
                  style: TextStyle(
                    color: Color(0xFF2852C8),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Programını takip et,\nritmini koru.',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      height: 1.08,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Yaklaşan seanslarını görüntüle, geçmiş kayıtlarını incele ve seans akışını tek ekrandan yönet.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 16),
              _PremiumPillTabs(
                index: tab,
                onChanged: onTabChange,
                leftLabel: 'Yaklaşan',
                rightLabel: 'Geçmiş',
                leftCount: upcomingCount,
                rightCount: pastCount,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PackageSummaryCard extends StatelessWidget {
  final _SummaryData summary;

  const _PackageSummaryCard({
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _PremiumCardSurface(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF4F7CFF),
                      Color(0xFF7AA6FF),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F7CFF).withOpacity(0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.wallet_membership_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paket Özeti',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: isDark ? AppColors.darkText : AppColors.lightText,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Aktif paket ve tarih bilgilerin burada yer alır.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0xFFEFF5FF),
                  border: Border.all(color: const Color(0xFFD8E7FF)),
                ),
                child: Text(
                  summary.rightValue,
                  style: const TextStyle(
                    color: Color(0xFF2852C8),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  label: 'Başlangıç',
                  value: summary.baslangic.isEmpty ? '-' : summary.baslangic,
                  icon: Icons.play_circle_outline_rounded,
                  color: const Color(0xFF4F7CFF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InfoTile(
                  label: 'Bitiş',
                  value: summary.bitis.isEmpty ? '-' : summary.bitis,
                  icon: Icons.event_available_rounded,
                  color: const Color(0xFFFF7A18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color accent;
  final IconData icon;

  const _MiniStatCard({
    required this.title,
    required this.value,
    required this.accent,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _PremiumCardSurface(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  height: 1,
                ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: accent, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SessionPremiumCard extends StatelessWidget {
  final String title;
  final String dateTimeText;
  final String durationText;
  final String locationText;
  final String statusText;
  final ({Color bg, Color fg, Color border, IconData icon}) statusTheme;
  final Color accent;
  final bool isPast;

  const _SessionPremiumCard({
    required this.title,
    required this.dateTimeText,
    required this.durationText,
    required this.locationText,
    required this.statusText,
    required this.statusTheme,
    required this.accent,
    required this.isPast,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _PremiumCardSurface(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: [
                      accent.withOpacity(0.16),
                      accent.withOpacity(0.08),
                    ],
                  ),
                  border: Border.all(color: accent.withOpacity(0.14)),
                ),
                child: Icon(
                  isPast ? Icons.history_toggle_off_rounded : Icons.event_available_rounded,
                  color: accent,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: isDark ? AppColors.darkText : AppColors.lightText,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          statusTheme.icon,
                          size: 15,
                          color: statusTheme.fg,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            statusText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: statusTheme.fg,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: statusTheme.bg,
                  border: Border.all(color: statusTheme.border),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusTheme.fg,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 1,
            color: const Color(0xFFE8EEF7),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _DetailChip(
                  icon: Icons.calendar_month_rounded,
                  text: dateTimeText,
                  accent: const Color(0xFF4F7CFF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DetailChip(
                  icon: Icons.timer_outlined,
                  text: durationText,
                  accent: const Color(0xFFFF7A18),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DetailChip(
                  icon: Icons.location_on_outlined,
                  text: locationText,
                  accent: const Color(0xFF14B86A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color accent;

  const _DetailChip({
    required this.icon,
    required this.text,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EEF7)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumPillTabs extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final String leftLabel;
  final String rightLabel;
  final int leftCount;
  final int rightCount;

  const _PremiumPillTabs({
    required this.index,
    required this.onChanged,
    required this.leftLabel,
    required this.rightLabel,
    required this.leftCount,
    required this.rightCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FD),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE6EDF7)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              selected: index == 0,
              label: leftLabel,
              count: leftCount,
              accent: const Color(0xFF4F7CFF),
              onTap: () => onChanged(0),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _TabButton(
              selected: index == 1,
              label: rightLabel,
              count: rightCount,
              accent: const Color(0xFF14B86A),
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final bool selected;
  final String label;
  final int count;
  final Color accent;
  final VoidCallback onTap;

  const _TabButton({
    required this.selected,
    required this.label,
    required this.count,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? accent : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: accent.withOpacity(0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: selected ? Colors.white : (isDark ? AppColors.darkTextSub : AppColors.lightTextSub),
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white.withOpacity(0.18) : accent.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: selected ? Colors.white : accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFDFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EEF7)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;

  const _EmptyStateCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _PremiumCardSurface(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 30, color: accent),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _PremiumCardSurface(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEFEF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              size: 30,
              color: Color(0xFFD14343),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Bir hata oluştu',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F7CFF),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              child: const Text(
                'Tekrar Dene',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumCardSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _PremiumCardSurface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.28)
                : AppColors.primary.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.18 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SummaryData {
  final String leftTitle;
  final String leftValue;
  final String rightTitle;
  final String rightValue;
  final String baslangic;
  final String bitis;

  const _SummaryData({
    required this.leftTitle,
    required this.leftValue,
    required this.rightTitle,
    required this.rightValue,
    required this.baslangic,
    required this.bitis,
  });
}

class _PastStats {
  final int total;
  final int done;
  final int canceled;
  final int noShow;

  const _PastStats({
    required this.total,
    required this.done,
    required this.canceled,
    required this.noShow,
  });
}