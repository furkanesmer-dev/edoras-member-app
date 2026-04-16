import 'package:flutter/material.dart';
import 'package:edoras_member_app/core/api/api_client.dart';
import 'package:edoras_member_app/core/storage/token_storage.dart';
import 'package:edoras_member_app/core/theme/app_colors.dart';
import 'package:edoras_member_app/features/profile/profile_screen.dart';
import 'package:edoras_member_app/core/ui/widgets/state_views.dart';

class HomeScreen extends StatefulWidget {
  final ApiClient apiClient;
  final TokenStorage tokenStorage;

  final VoidCallback? onOpenSessions;
  final VoidCallback? onOpenWorkouts;
  final VoidCallback? onOpenNutrition;
  final VoidCallback? onOpenProfile;

  const HomeScreen({
    super.key,
    required this.apiClient,
    required this.tokenStorage,
    this.onOpenSessions,
    this.onOpenWorkouts,
    this.onOpenNutrition,
    this.onOpenProfile,
  });

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _subscription;
  Map<String, dynamic>? _targets;

  Map<String, dynamic>? _workoutSummary;
  Map<String, dynamic>? _beslenmeSummary;
  Map<String, dynamic>? _upcomingSession;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> reload() => _loadAll();

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = widget.apiClient;

      final results = await Future.wait([
        api.dio.get('/profile/me.php'),
        api.dio.get('/workout/summary.php'),
        api.dio.get('/beslenme/summary.php'),
        api.dio.get('/seans/upcoming.php'),
      ]);

      final meAll = _extractDataMap(results[0].data);
      final profile = (meAll['profile'] is Map)
          ? Map<String, dynamic>.from(meAll['profile'])
          : <String, dynamic>{};
      final subscription = (meAll['subscription'] is Map)
          ? Map<String, dynamic>.from(meAll['subscription'])
          : <String, dynamic>{};
      final targets = (meAll['targets'] is Map)
          ? Map<String, dynamic>.from(meAll['targets'])
          : <String, dynamic>{};

      final workoutData = _extractDataMap(results[1].data);
      final beslenmeData = _extractDataMap(results[2].data);

      final upcomingMap = (results[3].data is Map)
          ? Map<String, dynamic>.from(results[3].data)
          : <String, dynamic>{};

      Map<String, dynamic>? upcomingItem;
      if (upcomingMap['item'] is Map) {
        upcomingItem = Map<String, dynamic>.from(upcomingMap['item']);
      } else if (upcomingMap['data'] is Map) {
        final d = Map<String, dynamic>.from(upcomingMap['data']);
        if (d['item'] is Map) upcomingItem = Map<String, dynamic>.from(d['item']);
      }

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _subscription = subscription;
        _targets = targets.isNotEmpty ? targets : null;
        _workoutSummary = workoutData;
        _beslenmeSummary = beslenmeData;
        _upcomingSession = upcomingItem;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Bir hata oluştu. Lütfen tekrar deneyin.";
        _loading = false;
      });
    }
  }

  Map<String, dynamic> _extractDataMap(dynamic raw) {
    if (raw == null) return <String, dynamic>{};
    final map = (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

    // Backend ok:false / success:false ile 200 dönerse boş map ile devam et;
    // 401/403 ise Dio interceptor zaten yakalar.
    final hasStatusField = map.containsKey('ok') || map.containsKey('success');
    if (hasStatusField) {
      final isOk = map['ok'] == true || map['success'] == true;
      if (!isOk) return <String, dynamic>{};
    }

    final inner = (map['data'] is Map) ? Map<String, dynamic>.from(map['data']) : <String, dynamic>{};
    return inner.isNotEmpty ? inner : map;
  }

  String _s(dynamic v, [String fallback = '-']) {
    final t = v?.toString().trim();
    return (t == null || t.isEmpty) ? fallback : t;
  }

  bool _b(dynamic v) {
    if (v is bool) return v;
    final s = v?.toString();
    return s == '1' || s == 'true' || s == 'True';
  }

  int? _numToInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.round();

    var s = v.toString().trim();
    if (s.isEmpty) return null;

    s = s.replaceAll(RegExp(r'[^0-9\.,-]'), '');
    s = s.replaceAll('.', '').replaceAll(',', '.');

    final d = double.tryParse(s);
    return d?.round();
  }

  String _fmtDateTime(dynamic raw) {
    final s = raw?.toString() ?? '';
    if (s.isEmpty) return '-';
    final dt = DateTime.tryParse(s.replaceAll(' ', 'T'));
    if (dt == null) return s;
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year} • '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  String _firstName(Map<String, dynamic> profile) {
    final ad = _s(profile['ad'], '').trim();
    final isim = _s(profile['isim'], '').trim();
    final kullanici = _s(profile['kullanici_adi'], '').trim();
    final full = [ad, isim].where((e) => e.isNotEmpty).join(' ').trim();

    if (full.isNotEmpty) {
      return full.split(' ').first;
    }
    if (kullanici.isNotEmpty) {
      return kullanici.split(' ').first;
    }
    return 'Sporcu';
  }

  String? _profilePhotoUrl(Map<String, dynamic> profile) {
    final raw = (profile['foto_url'] ?? profile['foto_yolu'] ?? '').toString().trim();
    if (raw.isEmpty) return null;

    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;

    final base = widget.apiClient.dio.options.baseUrl;
    final origin = Uri.parse(base).origin;
    return '$origin/${raw.replaceFirst(RegExp(r'^/+'), '')}';
  }

  Future<void> _goProfile() async {
    if (widget.onOpenProfile != null) {
      widget.onOpenProfile!.call();
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          apiClient: widget.apiClient,
          tokenStorage: widget.tokenStorage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SafeArea(child: LoadingView(text: 'Yükleniyor...'));
    }

    if (_error != null) {
      return SafeArea(
        child: ErrorView(
          title: 'Bir hata oluştu',
          subtitle: _error,
          onRetry: _loadAll,
        ),
      );
    }

    final profile = _profile ?? <String, dynamic>{};
    final subscription = _subscription ?? <String, dynamic>{};
    final targets = _targets;

    final workout = _workoutSummary ?? <String, dynamic>{};
    final beslenme = _beslenmeSummary ?? <String, dynamic>{};
    final upcoming = _upcomingSession;

    final uyeAktif = _b(subscription['uye_aktif']);
    final baslangic = _s(subscription['baslangic_tarihi']);
    final bitis = _s(subscription['bitis_tarihi']);

    final targetKcal = _numToInt(targets?['target_kcal']);
    final proteinG = _numToInt(targets?['protein_g']);
    final karbG = _numToInt(targets?['karb_g']);
    final yagG = _numToInt(targets?['yag_g']);

    final workoutTotal = _s(workout['total'], '0');
    final workoutHasActive = _b(workout['active_exists']);
    final activeWorkoutName = _s(workout['active_name'], '');

    final beslenmeTotal = _s(beslenme['total'], '0');
    final beslenmeHasActive = _b(beslenme['active_exists']);
    final activeHedef = _s(beslenme['active_hedef'], '');

    final photoUrl = _profilePhotoUrl(profile);
    final firstName = _firstName(profile);

    final workoutSubtitle = activeWorkoutName.trim().isNotEmpty
        ? activeWorkoutName
        : (workoutHasActive ? 'Aktif planın hazır' : 'Aktif plan bulunmuyor');

    final nutritionSubtitle = activeHedef.trim().isNotEmpty
        ? activeHedef
        : (beslenmeHasActive ? 'Aktif planın hazır' : 'Aktif plan bulunmuyor');

    final upcomingSubtitle = upcoming != null
        ? '${_fmtDateTime(upcoming['seans_tarih_saat'])}'
            ' • ${_s(upcoming['sure_dk'], '-')} dk'
            '${(_s(upcoming['lokasyon'], '') != '-') && _s(upcoming['lokasyon'], '').isNotEmpty ? ' • ${_s(upcoming['lokasyon'])}' : ''}'
        : 'En yakın tarihli seans burada görünecek.';

    return SafeArea(
      child: Stack(
        children: [
          const _BrightHomeBackground(),
          RefreshIndicator(
            onRefresh: _loadAll,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              children: [
                _TopHeader(
                  firstName: firstName,
                  photoUrl: photoUrl,
                  onProfileTap: _goProfile,
                ),
                const SizedBox(height: 14),
                _HeroWelcomeCard(
                  firstName: firstName,
                  onWorkoutTap: widget.onOpenWorkouts,
                  onNutritionTap: widget.onOpenNutrition,
                ),
                const SizedBox(height: 14),
                _SubscriptionPremiumCard(
                  uyeAktif: uyeAktif,
                  baslangic: baslangic,
                  bitis: bitis,
                ),
                const SizedBox(height: 14),
                _MotivationBanner(
                  title: 'Bugünün mesajı',
                  subtitle: 'Bugün attığın her adım, hedefindeki seni biraz daha yakınlaştırır.',
                ),
                const SizedBox(height: 14),
                _PrimaryActionCard(
                  title: upcoming != null ? _s(upcoming['baslik'], 'Yaklaşan Seans') : 'Yaklaşan seans yok',
                  subtitle: upcomingSubtitle,
                  assetPath: 'assets/icons/sessions.png',
                  accent: const Color(0xFF4F7CFF),
                  badgeText: upcoming != null ? 'Seansların' : 'Takvim',
                  onTap: () => widget.onOpenSessions?.call(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _CompactPremiumActionCard(
                        title: 'Antrenman',
                        subtitle: '$workoutTotal plan',
                        footnote: workoutSubtitle,
                        assetPath: 'assets/icons/workout.png',
                        accent: const Color(0xFFFF7A18),
                        onTap: () => widget.onOpenWorkouts?.call(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CompactPremiumActionCard(
                        title: 'Beslenme',
                        subtitle: '$beslenmeTotal plan',
                        footnote: nutritionSubtitle,
                        assetPath: 'assets/icons/nutrition.png',
                        accent: const Color(0xFF14B86A),
                        onTap: () => widget.onOpenNutrition?.call(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _CaloriesPremiumCard(
                  kcal: targetKcal,
                  proteinG: proteinG,
                  karbG: karbG,
                  yagG: yagG,
                  assetPath: 'assets/icons/calorie.png',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrightHomeBackground extends StatelessWidget {
  const _BrightHomeBackground();

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
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: isDark ? 0.14 : 0.08),
                ),
              ),
            ),
            Positioned(
              top: 160,
              left: -50,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary.withValues(alpha: isDark ? 0.10 : 0.07),
                ),
              ),
            ),
            Positioned(
              bottom: 100,
              right: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success.withValues(alpha: isDark ? 0.08 : 0.06),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  final String firstName;
  final String? photoUrl;
  final VoidCallback onProfileTap;

  const _TopHeader({
    required this.firstName,
    required this.photoUrl,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subtitleColor = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Merhaba, $firstName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: titleColor,
                      letterSpacing: -0.6,
                      height: 1.0,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Bugün güçlü başla, ritmini koru.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: subtitleColor,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _AvatarButton(
          photoUrl: photoUrl,
          onTap: onProfileTap,
        ),
      ],
    );
  }
}

class _AvatarButton extends StatelessWidget {
  final String? photoUrl;
  final VoidCallback onTap;

  const _AvatarButton({
    required this.photoUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 50,
        width: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? AppColors.darkSurface : Colors.white,
          border: Border.all(
            color: isDark ? AppColors.primaryLight.withValues(alpha: 0.40) : AppColors.primary.withValues(alpha: 0.25),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.20),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipOval(
          child: photoUrl != null
              ? Image.network(
                  photoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.person_rounded,
                    color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                    size: 24,
                  ),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Center(
                      child: SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    );
                  },
                )
              : Icon(
                  Icons.person_rounded,
                  color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                  size: 24,
                ),
        ),
      ),
    );
  }
}

class _HeroWelcomeCard extends StatelessWidget {
  final String firstName;
  final VoidCallback? onWorkoutTap;
  final VoidCallback? onNutritionTap;

  const _HeroWelcomeCard({
    required this.firstName,
    required this.onWorkoutTap,
    required this.onNutritionTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor  = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;

    return _PremiumCardSurface(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Stack(
        children: [
          Positioned(
            top: -16,
            right: -16,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -26,
            left: -22,
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withValues(alpha: isDark ? 0.10 : 0.07),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 14),
              Text(
                'Bugün kendin için iyi bir gün.',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      height: 1.08,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Programlarını takip et, seanslarını kaçırma ve hedeflerini her gün biraz daha ileri taşı.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: subColor,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _HeroMiniButton(
                      label: 'Antrenman',
                      icon: Icons.local_fire_department_rounded,
                      color: AppColors.primary,
                      onTap: onWorkoutTap,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HeroMiniButton(
                      label: 'Beslenme',
                      icon: Icons.restaurant_rounded,
                      color: AppColors.success,
                      onTap: onNutritionTap,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMiniButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _HeroMiniButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: color.withValues(alpha: isDark ? 0.15 : 0.10),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubscriptionPremiumCard extends StatelessWidget {
  final bool uyeAktif;
  final String baslangic;
  final String bitis;

  const _SubscriptionPremiumCard({
    required this.uyeAktif,
    required this.baslangic,
    required this.bitis,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = uyeAktif ? const Color(0xFF14B86A) : const Color(0xFFEF4444);

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
                  gradient: LinearGradient(
                    colors: uyeAktif
                        ? [const Color(0xFF13C67B), const Color(0xFF5BE5A7)]
                        : [const Color(0xFFEF4444), const Color(0xFFFF8A8A)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.24),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  uyeAktif ? Icons.verified_rounded : Icons.block_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Abonelik Durumu',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkText : AppColors.lightText,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      uyeAktif ? 'Üyeliğin aktif görünüyor' : 'Üyeliğin pasif görünüyor',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextSub : AppColors.lightTextSub,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              _StatusChip(
                text: uyeAktif ? 'Aktif' : 'Pasif',
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  label: 'Başlangıç',
                  value: baslangic,
                  icon: Icons.play_circle_outline_rounded,
                  color: const Color(0xFF4F7CFF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InfoTile(
                  label: 'Bitiş',
                  value: bitis,
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

class _MotivationBanner extends StatelessWidget {
  final String title;
  final String subtitle;

  const _MotivationBanner({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 116,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5B8DFF).withValues(alpha: 0.20),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/banner/banner_bg_overlay_centered_2.0x.webp',
              fit: BoxFit.cover,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0F172A).withValues(alpha: 0.25),
                    const Color(0xFF0F172A).withValues(alpha: 0.58),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              top: -12,
              right: -12,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String assetPath;
  final Color accent;
  final String badgeText;
  final VoidCallback? onTap;

  const _PrimaryActionCard({
    required this.title,
    required this.subtitle,
    required this.assetPath,
    required this.accent,
    required this.badgeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _PremiumCardSurface(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        children: [
          _IllustrationBubble(
            assetPath: assetPath,
            accent: accent,
            size: 68,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Badge(text: badgeText, accent: accent),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkText : AppColors.lightText,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.25,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextSub : AppColors.lightTextSub,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.10),
            ),
            child: Icon(
              Icons.arrow_forward_rounded,
              color: accent,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactPremiumActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String footnote;
  final String assetPath;
  final Color accent;
  final VoidCallback? onTap;

  const _CompactPremiumActionCard({
    required this.title,
    required this.subtitle,
    required this.footnote,
    required this.assetPath,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _PremiumCardSurface(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IllustrationBubble(
                assetPath: assetPath,
                accent: accent,
                size: 52,
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right_rounded,
                color: accent,
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkText : AppColors.lightText,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            footnote,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextSub : AppColors.lightTextSub,
                  fontWeight: FontWeight.w600,
                  height: 1.28,
                ),
          ),
        ],
      ),
    );
  }
}

class _CaloriesPremiumCard extends StatelessWidget {
  final int? kcal;
  final int? proteinG;
  final int? karbG;
  final int? yagG;
  final String assetPath;

  const _CaloriesPremiumCard({
    required this.kcal,
    required this.proteinG,
    required this.karbG,
    required this.yagG,
    required this.assetPath,
  });

  String _v(int? n) => n == null ? '-' : '$n';

  @override
  Widget build(BuildContext context) {
    return _PremiumCardSurface(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IllustrationBubble(
                assetPath: assetPath,
                accent: const Color(0xFFFFB020),
                size: 60,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Günlük Hedef Kalori',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextSub : AppColors.lightTextSub,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _v(kcal),
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkText : AppColors.lightText,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.8,
                                height: 1,
                              ),
                        ),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            'kcal',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextSub : AppColors.lightTextSub,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 1,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkBorder
                : AppColors.lightBorder,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MacroStatTile(
                  label: 'Protein',
                  value: _v(proteinG),
                  unit: 'g',
                  accent: const Color(0xFFFF7A18),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MacroStatTile(
                  label: 'Karb',
                  value: _v(karbG),
                  unit: 'g',
                  accent: const Color(0xFF4F7CFF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MacroStatTile(
                  label: 'Yağ',
                  value: _v(yagG),
                  unit: 'g',
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

class _MacroStatTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color accent;

  const _MacroStatTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 4,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextSub : AppColors.lightTextSub,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkText : AppColors.lightText,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                        height: 1,
                      ),
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  unit,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextSub : AppColors.lightTextSub,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IllustrationBubble extends StatelessWidget {
  final String assetPath;
  final Color accent;
  final double size;

  const _IllustrationBubble({
    required this.assetPath,
    required this.accent,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.34),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.18),
            accent.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
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
        color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
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
                        color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextSub : AppColors.lightTextSub,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkText : AppColors.lightText,
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

class _Badge extends StatelessWidget {
  final String text;
  final Color accent;

  const _Badge({
    required this.text,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: accent.withValues(alpha: 0.10),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: accent,
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
          height: 1,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusChip({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
          height: 1,
        ),
      ),
    );
  }
}

class _PremiumCardSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const _PremiumCardSurface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = Container(
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
                ? Colors.black.withValues(alpha: 0.30)
                : AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: content,
      ),
    );
  }
}