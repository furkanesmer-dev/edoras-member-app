import 'package:flutter/material.dart';
import 'package:edoras_member_app/core/api/api_client.dart';

class WorkoutPlanDetailPage extends StatefulWidget {
  final ApiClient apiClient;
  final int planId;

  const WorkoutPlanDetailPage({
    super.key,
    required this.apiClient,
    required this.planId,
  });

  @override
  State<WorkoutPlanDetailPage> createState() => _WorkoutPlanDetailPageState();
}

class _WorkoutPlanDetailPageState extends State<WorkoutPlanDetailPage> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _data;
  int _planId = 0;

  @override
  void initState() {
    super.initState();
    _planId = widget.planId;
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await widget.apiClient.dio.get(
        '/user/workout_plan_get.php',
        queryParameters: {'id': _planId},
      );

      final json = _ensureMap(res.data);
      if (json['ok'] != true) {
        throw Exception((json['msg'] ?? 'Plan alınamadı').toString());
      }

      final data = (json['data'] is Map)
          ? Map<String, dynamic>.from(json['data'])
          : <String, dynamic>{};

      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Map<String, dynamic> get _planMap {
    final plan = _data?['plan'];
    return (plan is Map) ? Map<String, dynamic>.from(plan) : <String, dynamic>{};
  }

  String? _sOrNull(dynamic v) {
    final t = v?.toString().trim();
    if (t == null || t.isEmpty || t == 'null') return null;
    return t;
  }

  DateTime? _tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final safe = raw.contains('T') ? raw : raw.replaceFirst(' ', 'T');
    try {
      return DateTime.parse(safe);
    } catch (_) {
      return null;
    }
  }

  String _fmtDateTime(dynamic raw) {
    final s = raw?.toString() ?? '';
    if (s.isEmpty) return '-';
    final dt = _tryParse(s);
    if (dt == null) return s;
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year} • '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  bool _asBool(dynamic v) {
    if (v is bool) return v;
    final s = v?.toString().trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes';
  }

  bool _isActivePlan(Map<String, dynamic> plan) {
    final keys = [
      plan['is_active'],
      plan['active'],
      plan['aktif'],
      plan['status'],
      plan['durum'],
      plan['plan_status'],
    ];

    for (final k in keys) {
      if (k == null) continue;
      final s = k.toString().trim().toLowerCase();
      if (s == 'active' || s == 'aktif' || s == 'published' || s == 'current') {
        return true;
      }
      if (_asBool(k)) return true;
    }
    return false;
  }

  String _planStatusText(Map<String, dynamic> plan) {
    return _isActivePlan(plan) ? 'Aktif Plan' : 'Arşiv Plan';
  }

  Color _planStatusColor(Map<String, dynamic> plan) {
    return _isActivePlan(plan) ? const Color(0xFF14B86A) : const Color(0xFF4F7CFF);
  }

  int _totalExercises(List<Map<String, dynamic>> days) {
    int total = 0;
    for (final day in days) {
      total += _ensureListMap(day['exercises']).length;
    }
    return total;
  }

  List<Map<String, dynamic>> get _days {
    final daysRaw = _planMap['days'];
    return (daysRaw is List)
        ? daysRaw
            .map<Map<String, dynamic>>(
              (d) => (d is Map) ? Map<String, dynamic>.from(d) : <String, dynamic>{},
            )
            .toList()
        : <Map<String, dynamic>>[];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Stack(
          children: [
            _BrightWorkoutBackground(),
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
            const _BrightWorkoutBackground(),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: _ErrorCard(
                    message: 'Plan detayı yüklenemedi.',
                    onRetry: null,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final plan = _planMap;
    final days = _days;
    final planName =
        _sOrNull(plan['plan_name'] ?? plan['name'] ?? plan['title']) ?? 'Antrenman Planı';
    final createdAtRaw = _sOrNull(_data?['created_at'] ?? plan['created_at']);
    final createdAt = createdAtRaw == null ? null : _fmtDateTime(createdAtRaw);
    final statusText = _planStatusText(plan);
    final statusColor = _planStatusColor(plan);
    final totalDays = days.length;
    final totalExercises = _totalExercises(days);

    return Scaffold(
      body: Stack(
        children: [
          const _BrightWorkoutBackground(),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _TopBar(
                    onBack: Navigator.canPop(context) ? () => Navigator.pop(context) : null,
                    onRefresh: _load,
                  ),
                  const SizedBox(height: 14),
                  _WorkoutHeroCard(
                    title: planName,
                    createdAt: createdAt,
                    statusText: statusText,
                    statusColor: statusColor,
                    totalDays: totalDays,
                    totalExercises: totalExercises,
                  ),
                  const SizedBox(height: 18),
                  _SectionHeader(
                    title: 'Plan Günleri',
                    subtitle: days.isEmpty
                        ? 'Bu planda görüntülenecek egzersiz bulunmuyor.'
                        : 'Her günün detaylarını aşağıdan inceleyebilirsin.',
                    icon: Icons.view_agenda_rounded,
                    accent: const Color(0xFF4F7CFF),
                  ),
                  const SizedBox(height: 10),
                  if (days.isEmpty)
                    const _EmptyStateCard(
                      title: 'Plan içeriği bulunamadı',
                      subtitle: 'Bu plana ait gün veya egzersiz verisi görünmüyor.',
                      icon: Icons.inventory_2_outlined,
                      accent: Color(0xFF4F7CFF),
                    )
                  else
                    ...days.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final day = entry.value;
                      final dayName =
                          (day['day_name'] ?? day['day_title'] ?? 'Gün ${idx + 1}')
                              .toString();
                      final exList = _ensureListMap(day['exercises']);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _WorkoutDayCard(
                          dayIndex: idx + 1,
                          dayName: dayName,
                          exercises: exList,
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrightWorkoutBackground extends StatelessWidget {
  const _BrightWorkoutBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFDFEFF),
              Color(0xFFF7FAFF),
              Color(0xFFF9FCFF),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -30,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6EA8FF).withValues(alpha: 0.12),
                ),
              ),
            ),
            Positioned(
              top: 160,
              left: -50,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF8C5A).withValues(alpha: 0.09),
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
                  color: const Color(0xFF17C67B).withValues(alpha: 0.08),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback onRefresh;

  const _TopBar({
    required this.onBack,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack != null)
          _CircleIconButton(
            icon: Icons.arrow_back_rounded,
            accent: const Color(0xFF4F7CFF),
            onTap: onBack!,
          ),
        if (onBack != null) const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Plan Detayı',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF111827),
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
          ),
        ),
        _CircleIconButton(
          icon: Icons.refresh_rounded,
          accent: const Color(0xFF14B86A),
          onTap: onRefresh,
        ),
      ],
    );
  }
}

class _WorkoutHeroCard extends StatelessWidget {
  final String title;
  final String? createdAt;
  final String statusText;
  final Color statusColor;
  final int totalDays;
  final int totalExercises;

  const _WorkoutHeroCard({
    required this.title,
    required this.createdAt,
    required this.statusText,
    required this.statusColor,
    required this.totalDays,
    required this.totalExercises,
  });

  @override
  Widget build(BuildContext context) {
    return _PremiumCardSurface(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Stack(
        children: [
          Positioned(
            top: -18,
            right: -18,
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF7FB2FF).withValues(alpha: 0.18),
              ),
            ),
          ),
          Positioned(
            bottom: -28,
            left: -18,
            child: Container(
              width: 98,
              height: 98,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFB074).withValues(alpha: 0.14),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: const Color(0xFFEFF5FF),
                      border: Border.all(color: const Color(0xFFD8E7FF)),
                    ),
                    child: const Text(
                      'Plan Detayı',
                      style: TextStyle(
                        color: Color(0xFF2852C8),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        height: 1,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _StatusChip(
                    text: statusText,
                    color: statusColor,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: const Color(0xFF111827),
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.45,
                      height: 1.08,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Antrenman günlerini ve egzersiz detaylarını bu ekranda inceleyebilirsin.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF667085),
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _HeroInfoChip(
                      icon: Icons.calendar_view_week_rounded,
                      text: '$totalDays gün',
                      accent: const Color(0xFF4F7CFF),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HeroInfoChip(
                      icon: Icons.fitness_center_rounded,
                      text: '$totalExercises egzersiz',
                      accent: const Color(0xFFFF7A18),
                    ),
                  ),
                ],
              ),
              if (createdAt != null) ...[
                const SizedBox(height: 10),
                _HeroInfoChip(
                  icon: Icons.schedule_rounded,
                  text: 'Oluşturulma: $createdAt',
                  accent: const Color(0xFF14B86A),
                  fullWidth: true,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkoutDayCard extends StatelessWidget {
  final int dayIndex;
  final String dayName;
  final List<Map<String, dynamic>> exercises;

  const _WorkoutDayCard({
    required this.dayIndex,
    required this.dayName,
    required this.exercises,
  });

  @override
  Widget build(BuildContext context) {
    return _PremiumCardSurface(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          initiallyExpanded: dayIndex == 1,
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFFF1E7),
                  Color(0xFFFFF8F1),
                ],
              ),
              border: Border.all(color: const Color(0xFFF8DEC7)),
            ),
            child: const Icon(
              Icons.event_note_rounded,
              color: Color(0xFFFF7A18),
              size: 24,
            ),
          ),
          title: Text(
            dayName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF111827),
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${exercises.length} egzersiz',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF667085),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          children: [
            if (exercises.isEmpty)
              const _EmptyMiniBlock(
                text: 'Bu güne ait egzersiz bulunmuyor.',
              )
            else
              Column(
                children: exercises
                    .map(
                      (ex) => Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: _ExerciseCard(ex: ex),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final Map<String, dynamic> ex;
  const _ExerciseCard({required this.ex});

  String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty || s == 'null' ? null : s;
  }

  @override
  Widget build(BuildContext context) {
    final name =
        (ex['exercise_name'] ?? ex['name'] ?? ex['egzersiz'] ?? 'Egzersiz').toString();
    final sets = _str(ex['sets'] ?? ex['set']);
    final reps = _str(ex['reps'] ?? ex['tekrar']);

    final String? gif = _str(
      ex['exercise_gif'] ??
          ex['gif'] ??
          ex['gif_url'] ??
          ex['gifUrl'] ??
          ex['image'] ??
          ex['image_url'],
    );

    Future<void> openGif() async {
      if (gif == null) return;

      await showDialog(
        context: context,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              width: 360,
              height: 420,
              child: Image.network(
                gif,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF4F7CFF),
                    ),
                  );
                },
                errorBuilder: (context, _, __) {
                  return Center(
                    child: Text(
                      'GIF yüklenemedi',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF667085),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    final subtitle = (sets != null && reps != null)
        ? 'Set: $sets • Tekrar: $reps'
        : (sets != null
            ? 'Set: $sets'
            : (reps != null ? 'Tekrar: $reps' : 'Detay bilgisi yok'));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: gif != null ? openGif : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFBFDFF),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE8EEF7)),
          ),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFEFF5FF),
                      Color(0xFFF7FAFF),
                    ],
                  ),
                  border: Border.all(color: const Color(0xFFDCE7FB)),
                ),
                child: gif == null
                    ? const Icon(
                        Icons.image_not_supported_rounded,
                        color: Color(0xFF667085),
                      )
                    : Image.network(
                        gif,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image_outlined,
                          color: Color(0xFF667085),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: const Color(0xFF111827),
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF667085),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              if (gif != null)
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF4F7CFF).withValues(alpha: 0.10),
                  ),
                  child: const Icon(
                    Icons.open_in_full_rounded,
                    color: Color(0xFF4F7CFF),
                    size: 18,
                  ),
                ),
            ],
          ),
        ),
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
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
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
                      color: const Color(0xFF111827),
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF667085),
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

class _HeroInfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color accent;
  final bool fullWidth;

  const _HeroInfoChip({
    required this.icon,
    required this.text,
    required this.accent,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF111827),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );

    if (fullWidth) return child;
    return child;
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.14)),
          ),
          child: Icon(icon, color: accent, size: 20),
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
    return _PremiumCardSurface(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 30, color: accent),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF111827),
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF667085),
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMiniBlock extends StatelessWidget {
  final String text;

  const _EmptyMiniBlock({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFDFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EEF7)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF667085),
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _ErrorCard({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
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
                  color: const Color(0xFF111827),
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF667085),
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
          ),
          if (onRetry != null) ...[
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
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFFCFDFF),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFE8EEF7),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8DAEF5).withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

List<Map<String, dynamic>> _ensureListMap(dynamic v) {
  if (v is List) {
    return v
        .map<Map<String, dynamic>>(
          (e) => (e is Map) ? Map<String, dynamic>.from(e) : <String, dynamic>{},
        )
        .toList();
  }
  return <Map<String, dynamic>>[];
}

Map<String, dynamic> _ensureMap(dynamic data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  return <String, dynamic>{};
}