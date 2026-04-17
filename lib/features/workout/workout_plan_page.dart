import 'package:flutter/material.dart';
import 'package:edoras_member_app/core/api/api_client.dart';
import 'package:edoras_member_app/core/theme/app_colors.dart';
import 'package:edoras_member_app/features/workout/workout_plans_page.dart';

class WorkoutPlanPage extends StatefulWidget {
  final ApiClient apiClient;

  const WorkoutPlanPage({
    super.key,
    required this.apiClient,
  });

  @override
  State<WorkoutPlanPage> createState() => WorkoutPlanPageState();
}

class WorkoutPlanPageState extends State<WorkoutPlanPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> reload() => _load();
  Future<void> reloadPlans() => _load();

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1) Aktif plan özetini al
      final currentRes =
          await widget.apiClient.dio.get('/user/workout_plan_current.php');
      final currentJson = _ensureMap(currentRes.data);
      final currentData = _extractDataMap(currentJson);

      final hasPlan = _asBool(currentData['has_plan']) || _asBool(currentData['hasPlan']);

      if (!hasPlan) {
        if (!mounted) return;
        setState(() {
          _data = <String, dynamic>{
            'has_plan': false,
          };
          _loading = false;
        });
        return;
      }

      // 2) Aktif plan id bul
      final planId = _extractPlanId(currentData);
      if (planId == null || planId <= 0) {
        throw Exception('Aktif plan id bulunamadı.');
      }

      // 3) Çalışan detail endpoint ile tam planı çek
      final detailRes = await widget.apiClient.dio.get(
        '/user/workout_plan_get.php',
        queryParameters: {'id': planId},
      );

      final detailJson = _ensureMap(detailRes.data);
      if (detailJson['ok'] != true) {
        throw Exception((detailJson['msg'] ?? 'Plan alınamadı').toString());
      }

      final detailData = (detailJson['data'] is Map)
          ? Map<String, dynamic>.from(detailJson['data'])
          : <String, dynamic>{};

      // current page için has_plan flag'i de ekleyelim
      detailData['has_plan'] = true;

      if (!mounted) return;
      setState(() {
        _data = detailData;
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

  Map<String, dynamic> _ensureMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  Map<String, dynamic> _extractDataMap(dynamic raw) {
    final map = _ensureMap(raw);
    final inner = map['data'];
    if (inner is Map) return Map<String, dynamic>.from(inner);
    return map;
  }

  bool _asBool(dynamic v) {
    if (v is bool) return v;
    final s = v?.toString().trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes';
  }

  int? _extractPlanId(Map<String, dynamic> currentData) {
    final planRaw = currentData['plan'] ??
        currentData['plan_data'] ??
        currentData['planData'];

    if (planRaw is Map) {
      final plan = Map<String, dynamic>.from(planRaw);

      final candidates = [
        plan['id'],
        plan['plan_id'],
        plan['workout_plan_id'],
        currentData['plan_id'],
        currentData['id'],
      ];

      for (final c in candidates) {
        final id = int.tryParse('${c ?? ''}');
        if (id != null && id > 0) return id;
      }
    }

    final topLevelCandidates = [
      currentData['plan_id'],
      currentData['id'],
      currentData['workout_plan_id'],
    ];

    for (final c in topLevelCandidates) {
      final id = int.tryParse('${c ?? ''}');
      if (id != null && id > 0) return id;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _WorkoutLoadingView();
    }

    if (_error != null) {
      return _WorkoutErrorView(
        msg: _error!,
        onRetry: _load,
      );
    }

    if (_data == null || _data!.isEmpty) {
      return _WorkoutErrorView(
        msg: 'Antrenman verisi alınamadı.',
        onRetry: _load,
      );
    }

    return _WorkoutPlanView(
      apiClient: widget.apiClient,
      data: _data!,
      onRefresh: _load,
    );
  }
}

class _WorkoutPlanView extends StatelessWidget {
  final ApiClient apiClient;
  final Map<String, dynamic> data;
  final Future<void> Function() onRefresh;

  const _WorkoutPlanView({
    required this.apiClient,
    required this.data,
    required this.onRefresh,
  });

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

  String _fmtDate(dynamic raw) {
    final s = raw?.toString() ?? '';
    if (s.isEmpty) return '-';
    final dt = _tryParse(s);
    if (dt == null) return s;
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year}';
  }

  bool _asBool(dynamic v) {
    if (v is bool) return v;
    final s = v?.toString().trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes';
  }

  Map<String, dynamic> getPlan(Map<String, dynamic> data) {
    final plan = data['plan'];
    return (plan is Map) ? Map<String, dynamic>.from(plan) : <String, dynamic>{};
  }

  List<Map<String, dynamic>> getDays(Map<String, dynamic> plan) {
    final daysRaw = plan['days'];
    return (daysRaw is List)
        ? daysRaw
            .map<Map<String, dynamic>>(
              (d) => (d is Map) ? Map<String, dynamic>.from(d) : <String, dynamic>{},
            )
            .toList()
        : <Map<String, dynamic>>[];
  }

  int totalExercises(List<Map<String, dynamic>> days) {
    int total = 0;
    for (final day in days) {
      final ex = day['exercises'];
      if (ex is List) total += ex.length;
    }
    return total;
  }

  void _openArchive(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutPlansPage(apiClient: apiClient),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasPlan = _asBool(data['has_plan']) || _asBool(data['hasPlan']);

    if (!hasPlan) {
      return Stack(
        children: [
          const _BrightWorkoutBackground(),
          RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              children: [
                const SizedBox(height: 12),
                const _WorkoutEmptyState(),
                const SizedBox(height: 14),
                _ArchiveEntryCard(
                  onTap: () => _openArchive(context),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final plan = getPlan(data);
    final days = getDays(plan);

    final planName =
        _sOrNull(plan['plan_name'] ?? plan['name'] ?? plan['title']) ??
            'Aktif Antrenman Planın';

    final createdAt = _fmtDate(data['created_at'] ?? plan['created_at']);
    final totalDays = days.length;
    final totalEx = totalExercises(days);

    return Stack(
      children: [
        const _BrightWorkoutBackground(),
        RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            children: [
              _WorkoutHeroCard(
                title: planName,
                createdAt: createdAt == '-' ? null : createdAt,
                totalDays: totalDays,
                totalExercises: totalEx,
              ),
              const SizedBox(height: 16),
              Text(
                'Antrenman Günleri',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
              ),
              const SizedBox(height: 10),
              if (days.isEmpty)
                const _EmptyMiniBlock(
                  text: 'Aktif plan bulundu ama gün içeriği henüz eklenmemiş.',
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
              const SizedBox(height: 6),
              _ArchiveEntryCard(
                onTap: () => _openArchive(context),
              ),
            ],
          ),
        ),
      ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${exercises.length} egzersiz',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name =
        (ex['exercise_name'] ?? ex['name'] ?? ex['egzersiz'] ?? 'Egzersiz')
            .toString();
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
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ClipRRect(
  borderRadius: BorderRadius.circular(24),
  child: SizedBox(
    width: 360,
    height: 360,
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
                  color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
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
            color: isDark ? AppColors.darkSurface2 : const Color(0xFFFBFDFF),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE8EEF7)),
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
                    ? Icon(
                        Icons.image_not_supported_rounded,
                        color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                      )
                    : Image.network(
                        gif,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.broken_image_outlined,
                          color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
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
                            color: isDark ? AppColors.darkText : AppColors.lightText,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
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

class _WorkoutLoadingView extends StatelessWidget {
  const _WorkoutLoadingView();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const _BrightWorkoutBackground(),
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: const [
            _LoadingCard(height: 188),
            SizedBox(height: 14),
            _LoadingCard(height: 96),
            SizedBox(height: 12),
            _LoadingCard(height: 96),
            SizedBox(height: 12),
            _LoadingCard(height: 96),
          ],
        ),
      ],
    );
  }
}

class _WorkoutErrorView extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;

  const _WorkoutErrorView({
    required this.msg,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        const _BrightWorkoutBackground(),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 460),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE7ECF3)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A101828),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFE74C3C),
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Antrenman sayfası yüklenemedi',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    msg,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                        ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onRetry,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text(
                        'Tekrar Dene',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WorkoutEmptyState extends StatelessWidget {
  const _WorkoutEmptyState();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE7ECF3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A101828),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFEFF5FF),
                  Color(0xFFF7FAFF),
                ],
              ),
              border: Border.all(color: const Color(0xFFDCE7FB)),
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              size: 34,
              color: Color(0xFF4F7CFF),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Aktif antrenman planın bulunmuyor',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Eğitmenin sana aktif bir plan oluşturduğunda bu ekranda direkt onu göreceksin.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _ArchiveEntryCard extends StatelessWidget {
  final VoidCallback onTap;

  const _ArchiveEntryCard({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE7ECF3)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A101828),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF5FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.archive_outlined,
                  color: Color(0xFF4F7CFF),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Geçmiş Planlar',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: isDark ? AppColors.darkText : AppColors.lightText,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Arşivdeki planlarını ayrı ekranda görüntüle.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF98A2B3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkoutHeroCard extends StatelessWidget {
  final String title;
  final String? createdAt;
  final int totalDays;
  final int totalExercises;

  const _WorkoutHeroCard({
    required this.title,
    required this.createdAt,
    required this.totalDays,
    required this.totalExercises,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFDDE8F7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D101828),
            blurRadius: 26,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0xFFEFF5FF),
                  border: Border.all(color: const Color(0xFFD8E7FF)),
                ),
                child: const Text(
                  'Aktif Plan',
                  style: TextStyle(
                    color: Color(0xFF2852C8),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    height: 1,
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  height: 1.08,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Antrenman sekmesine girdiğinde öncelikle aktif planını görürsün. Geçmiş planlar altta ayrı erişim olarak tutulur.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                    fontWeight: FontWeight.w800,
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

class _PremiumCardSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _PremiumCardSurface({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.28) : AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _EmptyMiniBlock extends StatelessWidget {
  final String text;

  const _EmptyMiniBlock({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final double height;

  const _LoadingCard({required this.height});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
    );
  }
}

class _BrightWorkoutBackground extends StatelessWidget {
  const _BrightWorkoutBackground();

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
                  color: AppColors.primary.withValues(alpha: isDark ? 0.14 : 0.08),
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
                  color: AppColors.secondary.withValues(alpha: isDark ? 0.10 : 0.06),
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
                  color: AppColors.success.withValues(alpha: isDark ? 0.08 : 0.05),
                ),
              ),
            ),
          ],
        ),
      ),
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