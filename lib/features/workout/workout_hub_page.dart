import 'package:flutter/material.dart';
import 'package:edoras_member_app/core/api/api_client.dart';
import 'package:edoras_member_app/features/workout/workout_plan_detail_page.dart';

class WorkoutHubPage extends StatefulWidget {
  final ApiClient apiClient;

  const WorkoutHubPage({
    super.key,
    required this.apiClient,
  });

  @override
  State<WorkoutHubPage> createState() => WorkoutHubPageState();
}

class WorkoutHubPageState extends State<WorkoutHubPage> {
  bool _loading = true;
  String? _error;

  int? _activeId;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> reloadPlans() => _load();

  Map<String, dynamic> _ensureMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await widget.apiClient.dio.get('/user/workout_plans_list.php');
      final json = _ensureMap(res.data);

      if (json['ok'] != true) {
        throw Exception((json['msg'] ?? 'Planlar alınamadı').toString());
      }

      final data = (json['data'] is Map)
          ? Map<String, dynamic>.from(json['data'])
          : <String, dynamic>{};

      final activeIdRaw = data['active_id'];
      final itemsRaw = data['items'];

      final items = <Map<String, dynamic>>[];
      if (itemsRaw is List) {
        for (final it in itemsRaw) {
          if (it is Map) {
            items.add(Map<String, dynamic>.from(it));
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _activeId = (activeIdRaw is num)
            ? activeIdRaw.toInt()
            : int.tryParse(activeIdRaw?.toString() ?? '');
        _items = items;
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

  Future<void> _openDetail(int id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkoutPlanDetailPage(
          apiClient: widget.apiClient,
          planId: id,
        ),
      ),
    );

    await _load();
  }

  bool _isActiveItem(Map<String, dynamic> it) {
    final id = (it['id'] is num)
        ? (it['id'] as num).toInt()
        : int.tryParse(it['id']?.toString() ?? '');

    final byActiveId = (_activeId != null && id != null && id == _activeId);

    final isActiveField = it['is_active'];
    final byField = (isActiveField == true) || (isActiveField?.toString() == '1');

    return byActiveId || byField;
  }

  String _planName(Map<String, dynamic> it) {
    final name = (it['plan_name'] ?? it['name'] ?? it['title'] ?? 'Plan')
        .toString()
        .trim();
    return name.isEmpty ? 'Plan' : name;
  }

  String? _createdAt(Map<String, dynamic> it) {
    final value = (it['created_at'] ?? '').toString().trim();
    return value.isEmpty ? null : value;
  }

  int? _planId(Map<String, dynamic> it) {
    if (it['id'] is num) return (it['id'] as num).toInt();
    return int.tryParse(it['id']?.toString() ?? '');
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
                    message: 'Bir hata oluştu',
                    subtitle: '',
                    onRetry: null,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Map<String, dynamic>? activePlan;
    for (final it in _items) {
      if (_isActiveItem(it)) {
        activePlan = it;
        break;
      }
    }

    final archived = <Map<String, dynamic>>[];
    for (final it in _items) {
      if (!_isActiveItem(it)) {
        archived.add(it);
      }
    }

    final activePlanId = activePlan == null ? null : _planId(activePlan);
    final activePlanName = activePlan == null ? null : _planName(activePlan);
    final activeCreatedAt = activePlan == null ? null : _createdAt(activePlan);

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
                  _TopBar(onRefresh: _load),
                  const SizedBox(height: 14),
                  if (activePlan != null && activePlanId != null && activePlanId > 0)
                    _ActiveWorkoutHeroCard(
                      title: activePlanName ?? 'Aktif Antrenman Planı',
                      createdAt: activeCreatedAt,
                      onTap: () => _openDetail(activePlanId),
                    )
                  else
                    const _EmptyWorkoutHeroCard(),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _MiniStatCard(
                          title: 'Aktif Plan',
                          value: activePlan != null ? '1' : '0',
                          accent: const Color(0xFF14B86A),
                          icon: Icons.verified_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MiniStatCard(
                          title: 'Arşiv',
                          value: '${archived.length}',
                          accent: const Color(0xFF4F7CFF),
                          icon: Icons.inventory_2_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MiniStatCard(
                          title: 'Durum',
                          value: activePlan != null ? 'Hazır' : 'Bekliyor',
                          accent: activePlan != null
                              ? const Color(0xFFFF7A18)
                              : const Color(0xFF8B5CF6),
                          icon: activePlan != null
                              ? Icons.local_fire_department_rounded
                              : Icons.schedule_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionHeader(
                    title: 'Arşiv Planları',
                    subtitle: archived.isEmpty
                        ? 'Arşiv plan bulunmuyor.'
                        : 'Önceki planlarını aşağıdan görüntüleyebilirsin.',
                    icon: Icons.history_rounded,
                    accent: const Color(0xFF4F7CFF),
                  ),
                  const SizedBox(height: 10),
                  if (archived.isEmpty)
                    const _EmptyStateCard(
                      title: 'Arşiv plan yok',
                      subtitle: 'Daha önce oluşturulmuş arşiv antrenman planı bulunmuyor.',
                      icon: Icons.inventory_2_outlined,
                      accent: Color(0xFF4F7CFF),
                    )
                  else
                    ...archived.map((plan) {
                      final id = _planId(plan);
                      final title = _planName(plan);
                      final createdAt = _createdAt(plan);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ArchivePlanCard(
                          title: title,
                          createdAt: createdAt,
                          onTap: (id == null || id <= 0) ? null : () => _openDetail(id),
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
                  color: const Color(0xFF6EA8FF).withOpacity(0.12),
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
                  color: const Color(0xFFFF8C5A).withOpacity(0.09),
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
                  color: const Color(0xFF17C67B).withOpacity(0.08),
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
  final VoidCallback onRefresh;

  const _TopBar({
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Antrenman',
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

class _ActiveWorkoutHeroCard extends StatelessWidget {
  final String title;
  final String? createdAt;
  final VoidCallback onTap;

  const _ActiveWorkoutHeroCard({
    required this.title,
    required this.createdAt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rawCreatedAt = createdAt;
    final hasCreatedAt = rawCreatedAt != null && rawCreatedAt.trim().isNotEmpty;

    return _PremiumCardSurface(
      onTap: onTap,
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
                color: const Color(0xFF7FB2FF).withOpacity(0.18),
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
                color: const Color(0xFFFFB074).withOpacity(0.14),
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
                      color: const Color(0xFFEAFBF2),
                      border: Border.all(color: const Color(0xFFC7F0D8)),
                    ),
                    child: const Text(
                      'Aktif Plan',
                      style: TextStyle(
                        color: Color(0xFF138A55),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        height: 1,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const _StatusChip(
                    text: 'Hazır',
                    color: Color(0xFF14B86A),
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
                'Tanımlanmış mevcut antrenman planına doğrudan buradan ulaşabilirsin.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF667085),
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 16),
              const _HeroInfoChip(
                icon: Icons.local_fire_department_rounded,
                text: 'Planı aç ve detayları görüntüle',
                accent: Color(0xFFFF7A18),
                fullWidth: true,
              ),
              if (hasCreatedAt) ...[
                const SizedBox(height: 10),
                _HeroInfoChip(
                  icon: Icons.schedule_rounded,
                  text: rawCreatedAt,
                  accent: const Color(0xFF4F7CFF),
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

class _EmptyWorkoutHeroCard extends StatelessWidget {
  const _EmptyWorkoutHeroCard();

  @override
  Widget build(BuildContext context) {
    return _PremiumCardSurface(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: const Color(0xFFFFF1E7),
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              size: 34,
              color: Color(0xFFFF7A18),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Aktif antrenman planın yok',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF111827),
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Eğitmenin tarafından aktif bir plan tanımlandığında burada otomatik olarak görüntülenecek.',
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

class _ArchivePlanCard extends StatelessWidget {
  final String title;
  final String? createdAt;
  final VoidCallback? onTap;

  const _ArchivePlanCard({
    required this.title,
    required this.createdAt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rawCreatedAt = createdAt;
    final createdText = (rawCreatedAt != null && rawCreatedAt.trim().isNotEmpty)
        ? rawCreatedAt
        : 'Arşiv plan';

    return _PremiumCardSurface(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFEFF5FF),
                  Color(0xFFF7FAFF),
                ],
              ),
              border: Border.all(color: const Color(0xFFDCE7FB)),
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              color: Color(0xFF4F7CFF),
              size: 24,
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
                        color: const Color(0xFF111827),
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  createdText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF667085),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF4F7CFF).withOpacity(0.10),
            ),
            child: const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF4F7CFF),
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
                  color: const Color(0xFF667085),
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF111827),
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
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: accent.withOpacity(0.14)),
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
      color: accent.withOpacity(0.10),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withOpacity(0.14)),
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
        color: color.withOpacity(0.10),
        border: Border.all(color: color.withOpacity(0.16)),
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

class _ErrorCard extends StatelessWidget {
  final String message;
  final String? subtitle;
  final VoidCallback? onRetry;

  const _ErrorCard({
    required this.message,
    this.subtitle,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final subtitleText = subtitle ?? '';

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
            message,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF111827),
                  fontWeight: FontWeight.w900,
                ),
          ),
          if (subtitleText.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitleText,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF667085),
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
            ),
          ],
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
  final VoidCallback? onTap;

  const _PremiumCardSurface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
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
            color: const Color(0xFF8DAEF5).withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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