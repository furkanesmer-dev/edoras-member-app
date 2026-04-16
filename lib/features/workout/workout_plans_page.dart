import 'package:flutter/material.dart';
import 'package:edoras_member_app/core/api/api_client.dart';
import 'workout_plan_detail_page.dart';

class WorkoutPlansPage extends StatefulWidget {
  final ApiClient apiClient;
  final bool embedded;

  const WorkoutPlansPage({
    super.key,
    required this.apiClient,
    this.embedded = false,
  });

  @override
  State<WorkoutPlansPage> createState() => WorkoutPlansPageState();
}

class WorkoutPlansPageState extends State<WorkoutPlansPage> {
  bool _loading = true;
  String? _error;

  int? _activeId;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> reload() => _load();

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

      final activeId = data['active_id'];
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
        _activeId = (activeId is num)
            ? activeId.toInt()
            : int.tryParse(activeId?.toString() ?? '');
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
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutPlanDetailPage(
          apiClient: widget.apiClient,
          planId: id,
        ),
      ),
    );

    if (changed == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const _ArchiveLoadingView()
        : (_error != null)
            ? _ArchiveErrorView(msg: _error!, onRetry: _load)
            : _ArchivePlansBody(
                items: _items,
                activeId: _activeId,
                onOpenDetail: _openDetail,
              );

    if (widget.embedded) return body;

    return Scaffold(
      body: body,
    );
  }
}

class _ArchivePlansBody extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final int? activeId;
  final void Function(int planId) onOpenDetail;

  const _ArchivePlansBody({
    required this.items,
    required this.activeId,
    required this.onOpenDetail,
  });

  bool _isActiveItem(Map<String, dynamic> it) {
    final id = (it['id'] is num)
        ? (it['id'] as num).toInt()
        : int.tryParse(it['id']?.toString() ?? '');

    final byActiveId = (activeId != null && id != null && id == activeId);

    final isActiveField = it['is_active'];
    final byField =
        (isActiveField == true) || (isActiveField?.toString() == '1');

    return byActiveId || byField;
  }

  String _formatDate(dynamic raw) {
    final s = raw?.toString().trim() ?? '';
    if (s.isEmpty) return '—';

    try {
      final normalized = s.contains('T') ? s : s.replaceFirst(' ', 'T');
      final dt = DateTime.parse(normalized).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}.'
          '${dt.month.toString().padLeft(2, '0')}.'
          '${dt.year}';
    } catch (_) {
      return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final archived = <Map<String, dynamic>>[];
    for (final it in items) {
      if (!_isActiveItem(it)) {
        archived.add(it);
      }
    }

    return Stack(
      children: [
        const _BrightWorkoutBackground(),
        SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {},
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                const _ArchiveTopBar(),
                const SizedBox(height: 14),
                const SizedBox(height: 16),
                if (archived.isEmpty)
                  const _ArchiveEmptyState()
                else
                  ...archived.map((it) {
                    final id = (it['id'] is num)
                        ? (it['id'] as num).toInt()
                        : int.tryParse(it['id']?.toString() ?? '') ?? 0;

                    final title = (it['plan_name'] ??
                            it['name'] ??
                            it['title'] ??
                            'Plan')
                        .toString();

                    final createdAt = _formatDate(it['created_at']);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ArchivePlanCard(
                        title: title,
                        createdAt: createdAt,
                        onTap: () {
                          if (id > 0) onOpenDetail(id);
                        },
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ArchiveTopBar extends StatelessWidget {
  const _ArchiveTopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (Navigator.canPop(context))
          _CircleIconButton(
            icon: Icons.arrow_back_rounded,
            accent: const Color(0xFF4F7CFF),
            onTap: () => Navigator.pop(context),
          ),
        if (Navigator.canPop(context)) const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Geçmiş Planlar',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF111827),
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
          ),
        ),
      ],
    );
  }
}

class _ArchivePlanCard extends StatelessWidget {
  final String title;
  final String createdAt;
  final VoidCallback onTap;

  const _ArchivePlanCard({
    required this.title,
    required this.createdAt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE7ECF3)),
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
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFF1E7),
                      Color(0xFFFFF8F1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF8DEC7)),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: Color(0xFFFF7A18),
                ),
              ),
              const SizedBox(width: 14),
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
                    const SizedBox(height: 4),
                    Text(
                      createdAt,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF667085),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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

class _ArchiveEmptyState extends StatelessWidget {
  const _ArchiveEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE7ECF3)),
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
              Icons.archive_outlined,
              size: 34,
              color: Color(0xFF4F7CFF),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Arşiv planın bulunmuyor',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF111827),
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Önceki antrenman planların oluştuğunda burada listelenecek.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF667085),
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _ArchiveLoadingView extends StatelessWidget {
  const _ArchiveLoadingView();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const _BrightWorkoutBackground(),
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: const [
              _LoadingCard(height: 58),
              SizedBox(height: 14),
              _LoadingCard(height: 180),
              SizedBox(height: 14),
              _LoadingCard(height: 92),
              SizedBox(height: 12),
              _LoadingCard(height: 92),
              SizedBox(height: 12),
              _LoadingCard(height: 92),
            ],
          ),
        ),
      ],
    );
  }
}

class _ArchiveErrorView extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;

  const _ArchiveErrorView({
    required this.msg,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xFFE7ECF3)),
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
                    'Arşiv planları yüklenemedi',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF111827),
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    msg,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF667085),
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
                        backgroundColor: const Color(0xFF111827),
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

class _LoadingCard extends StatelessWidget {
  final double height;

  const _LoadingCard({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE7ECF3)),
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

Map<String, dynamic> _ensureMap(dynamic data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  return <String, dynamic>{};
}