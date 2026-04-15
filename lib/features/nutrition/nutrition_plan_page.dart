import 'package:flutter/material.dart';
import 'package:edoras_member_app/core/theme/app_colors.dart';
import 'package:edoras_member_app/core/api/api_client.dart';
import 'package:edoras_member_app/features/nutrition/data/beslenme_api.dart';

class NutritionPlanPage extends StatefulWidget {
  final ApiClient apiClient;

  const NutritionPlanPage({
    super.key,
    required this.apiClient,
  });

  @override
  State<NutritionPlanPage> createState() => NutritionPlanPageState();
}

class NutritionPlanPageState extends State<NutritionPlanPage> {
  late final BeslenmeApi _besApi;

  bool _loading = true;
  bool _toggling = false;
  String? _error;

  String _tarih = _today();
  Map<String, dynamic>? _planData;

  Map<int, List<Map<String, dynamic>>> _itemsByMeal = {
    1: [],
    2: [],
    3: [],
    4: [],
    5: [],
  };

  double? _targetKcal;
  double? _targetProtein;
  double? _targetKarb;
  double? _targetYag;

  @override
  void initState() {
    super.initState();
    _besApi = BeslenmeApi(apiClient: widget.apiClient);
    _load();
  }

  Future<void> reload() => _load();

  static String _today() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    final s = v.toString().replaceAll(',', '.').trim();
    return double.tryParse(s) ?? 0;
  }

  double _sumField(String key) {
    double sum = 0;
    for (final meal in _itemsByMeal.keys) {
      for (final it in _itemsByMeal[meal] ?? const []) {
        final v = it[key];
        if (v is num) {
          sum += v.toDouble();
        } else if (v != null) {
          sum += _toDouble(v);
        }
      }
    }
    return sum;
  }

  double get _toplamKalori => _sumField('kalori');
  double get _toplamProtein => _sumField('protein');
  double get _toplamKarb => _sumField('karbonhidrat');
  double get _toplamYag => _sumField('yag');

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final planRes =
          await widget.apiClient.dio.get('/user/nutrition_plan_current.php');
      final planData = _extractDataMap(planRes.data);

      Map<int, List<Map<String, dynamic>>> mapped = {
        1: [],
        2: [],
        3: [],
        4: [],
        5: [],
      };

      try {
        final gunlukData = await _besApi.gunlukGet(tarih: _tarih);
        final raw = gunlukData['items_by_meal'];

        if (raw is Map) {
          final itemsByMealRaw = raw.cast<String, dynamic>();
          for (final entry in itemsByMealRaw.entries) {
            final meal = int.tryParse(entry.key) ?? 0;
            if (meal < 1 || meal > 5) continue;

            final list = (entry.value as List? ?? const [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();

            mapped[meal] = list;
          }
        }
      } catch (_) {
        // Tick verisi gelmezse ekran çalışmaya devam etsin.
      }

      double? targetKcal;
      double? targetProtein;
      double? targetKarb;
      double? targetYag;

      try {
        final meData = await widget.apiClient.getProfileMe();
        final targets = meData['targets'];

        if (targets is Map) {
          final t = Map<String, dynamic>.from(targets);
          targetKcal =
              t['target_kcal'] != null ? _toDouble(t['target_kcal']) : null;
          targetProtein =
              t['protein_g'] != null ? _toDouble(t['protein_g']) : null;
          targetKarb = t['karb_g'] != null ? _toDouble(t['karb_g']) : null;
          targetYag = t['yag_g'] != null ? _toDouble(t['yag_g']) : null;
        }
      } catch (_) {
        // Hedefler gelmezse de ekran çalışsın.
      }

      if (!mounted) return;
      setState(() {
        _planData = planData;
        _itemsByMeal = mapped;
        _targetKcal = targetKcal;
        _targetProtein = targetProtein;
        _targetKarb = targetKarb;
        _targetYag = targetYag;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Map<String, dynamic> _extractDataMap(dynamic raw) {
    final map =
        (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

    final inner = (map['data'] is Map)
        ? Map<String, dynamic>.from(map['data'])
        : <String, dynamic>{};

    return inner.isNotEmpty ? inner : map;
  }

  Future<void> _pickDate() async {
    final parts = _tarih.split('-');
    DateTime initial = DateTime.now();

    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) {
        initial = DateTime(y, m, d);
      }
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );

    if (!mounted || picked == null) return;

    final y = picked.year.toString().padLeft(4, '0');
    final m = picked.month.toString().padLeft(2, '0');
    final d = picked.day.toString().padLeft(2, '0');

    setState(() => _tarih = '$y-$m-$d');
    await _load();
  }

  String _norm(String s) {
    return s
        .toLowerCase()
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ç', 'c')
        .replaceAll('ı', 'i')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  int? _tryInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }

  double? _tryDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  final s = v.toString().replaceAll(',', '.').trim();
  if (s.isEmpty) return null;
  return double.tryParse(s);
}

  bool _isConsumedInMeal(int mealNo, Map<String, dynamic> planItem) {
    final planBesinId = _tryInt(planItem['besin_id'] ?? planItem['besinId']);
    if (planBesinId != null && planBesinId > 0) {
      final list = _itemsByMeal[mealNo] ?? const [];
      for (final it in list) {
        final logBesinId = _tryInt(it['besin_id']);
        if (logBesinId != null && logBesinId == planBesinId) {
          return true;
        }
      }
    }

    final planYemek = (planItem['yemek'] ?? planItem['ad'] ?? '').toString();
    final planN = _norm(planYemek);
    if (planN.isEmpty) return false;

    final list = _itemsByMeal[mealNo] ?? const [];
    for (final it in list) {
      final besinAd = (it['besin_ad'] ?? '').toString();
      final besinN = _norm(besinAd);
      if (besinN.isEmpty) continue;

      if (planN == besinN) return true;
      if (planN.contains(besinN) || besinN.contains(planN)) return true;
    }

    return false;
  }

 

  int _mealKeyToNo(String raw) {
    final s = _norm(raw).replaceAll(' ', '');

    if (s.startsWith('kahvalti') || s.startsWith('sabah')) return 1;
    if (s.contains('araogun')) {
      if (s.contains('1')) return 2;
      if (s.contains('2')) return 4;
      return 2;
    }
    if (s.startsWith('ogle') || s.startsWith('oglen')) return 3;
    if (s.startsWith('aksam')) return 5;

    return 3;
  }

  String _mealTitle(int mealNo) {
    switch (mealNo) {
      case 1:
        return 'Kahvaltı';
      case 2:
        return 'Ara Öğün 1';
      case 3:
        return 'Öğlen';
      case 4:
        return 'Ara Öğün 2';
      case 5:
        return 'Akşam';
      default:
        return 'Öğün';
    }
  }

  int? _extractPlanBesinId(Map<String, dynamic> item) {
  return _tryInt(item['besin_id'] ?? item['besinId']);
}

int? _extractPlanPorsiyonId(Map<String, dynamic> item) {
  return _tryInt(
    item['porsiyon_id'] ??
        item['porsiyonId'] ??
        item['default_porsiyon_id'] ??
        item['defaultPorsiyonId'],
  );
}

double? _extractPlanGram(Map<String, dynamic> item) {
  final miktar = _tryDouble(item['miktar']);
  final birim = (item['birim'] ?? '').toString().toLowerCase().trim();

  if (miktar == null || miktar <= 0) return null;

  if (birim.contains('gr') || birim == 'g' || birim.contains('gram')) {
    return miktar;
  }

  return null;
}

double _extractPlanAdet(Map<String, dynamic> item) {
  final adet = _tryDouble(item['adet']);
  if (adet != null && adet > 0) return adet;

  final miktar = _tryDouble(item['miktar']);
  final birim = (item['birim'] ?? '').toString().toLowerCase().trim();

  if (miktar != null && miktar > 0) {
    if (birim.contains('adet')) return miktar;
    if (birim.contains('porsiyon')) return miktar;
  }

  return 1;
}

Future<void> _toggleConsumed(int mealNo, Map<String, dynamic> planItem) async {
  if (_toggling) return;

  final consumed = _isConsumedInMeal(mealNo, planItem);

  final besinId = _extractPlanBesinId(planItem);
  if (besinId == null || besinId <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('besin_id yok')),
    );
    return;
  }

  final oldState = <int, List<Map<String, dynamic>>>{};
  for (final entry in _itemsByMeal.entries) {
    oldState[entry.key] = entry.value
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  final porsiyonId = _extractPlanPorsiyonId(planItem);
  final gram = _extractPlanGram(planItem);
  final adet = _extractPlanAdet(planItem);

  setState(() {
    _toggling = true;

    if (consumed) {
      _itemsByMeal[mealNo]?.removeWhere((e) {
        return _tryInt(e['besin_id']) == besinId;
      });
    } else {
      _itemsByMeal[mealNo] ??= [];
      _itemsByMeal[mealNo]!.add({
        'id': -DateTime.now().millisecondsSinceEpoch,
        'besin_id': besinId,
        'besin_ad': (planItem['yemek'] ?? '').toString(),
        'kalori': _tryDouble(planItem['kalori']) ?? 0,
        'protein': _tryDouble(planItem['protein']) ?? 0,
        'karbonhidrat': _tryDouble(planItem['karbonhidrat']) ?? 0,
        'yag': _tryDouble(planItem['yag']) ?? 0,
      });
    }
  });

  try {
    if (consumed) {
      await _besApi.gunlukSil(
        tarih: _tarih,
        meal: mealNo,
        besinId: besinId,
      );
    } else {
      final res = await _besApi.gunlukEkle(
        tarih: _tarih,
        meal: mealNo,
        besinId: besinId,
        porsiyonId: porsiyonId,
        adet: adet,
        gram: gram,
        besinAd: (planItem['yemek'] ?? planItem['ad'] ?? '').toString(),
        kalori: _tryDouble(planItem['kalori']),
        protein: _tryDouble(planItem['protein']),
        karbonhidrat: _tryDouble(planItem['karbonhidrat']),
        yag: _tryDouble(planItem['yag']),
      );

      final realOgeId = _tryInt(res['oge_id']);
      if (realOgeId != null && realOgeId > 0) {
        final list = _itemsByMeal[mealNo] ?? [];
        for (var i = 0; i < list.length; i++) {
          final it = list[i];
          if (_tryInt(it['besin_id']) == besinId && (_tryInt(it['id']) ?? 0) < 0) {
            list[i] = {
              ...it,
              'id': realOgeId,
            };
            break;
          }
        }
      }
    }
  } catch (e) {
    if (!mounted) return;

    setState(() {
      _itemsByMeal = oldState;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('İşlem yapılamadı: $e')),
    );
  } finally {
    if (mounted) {
      setState(() {
        _toggling = false;
      });
    }
  }
}

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Stack(
          children: [
            _NutritionBrightBackground(),
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
            const _NutritionBrightBackground(),
            SafeArea(
              child: _ErrorBox(msg: _error!, onRetry: _load),
            ),
          ],
        ),
      );
    }

    final planData = _planData ?? const <String, dynamic>{};
    final hasPlan =
        planData['has_plan'] == true || planData['hasPlan'] == true;

    if (!hasPlan) {
      return Scaffold(
        body: Stack(
          children: [
            const _NutritionBrightBackground(),
            SafeArea(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    _NutritionTopBar(
                      title: 'Beslenme',
                      onRefresh: _load,
                    ),
                    const SizedBox(height: 14),
                    const _NoPlanCard(),
                  ],
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
          const _NutritionBrightBackground(),
          SafeArea(
            child: Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _load,
                  child: _NutritionPremiumView(
                    tarih: _tarih,
                    onPickDate: _pickDate,
                    onRefresh: _load,
                    planData: planData,
                    targetKcal: _targetKcal,
                    targetProtein: _targetProtein,
                    targetKarb: _targetKarb,
                    targetYag: _targetYag,
                    toplamKalori: _toplamKalori,
                    toplamProtein: _toplamProtein,
                    toplamKarb: _toplamKarb,
                    toplamYag: _toplamYag,
                    mealKeyToNo: _mealKeyToNo,
                    mealTitle: _mealTitle,
                    isConsumedInMeal: _isConsumedInMeal,
                    onToggleConsumed: _toggleConsumed,
                  ),
                ),
                if (_toggling)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        color: Colors.black.withOpacity(0.04),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF4F7CFF),
                          ),
                        ),
                      ),
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

class _NutritionPremiumView extends StatelessWidget {
  final String tarih;
  final VoidCallback onPickDate;
  final VoidCallback onRefresh;
  final Map<String, dynamic> planData;

  final double? targetKcal;
  final double? targetProtein;
  final double? targetKarb;
  final double? targetYag;

  final double toplamKalori;
  final double toplamProtein;
  final double toplamKarb;
  final double toplamYag;

  final int Function(String) mealKeyToNo;
  final String Function(int) mealTitle;
  final bool Function(int mealNo, Map<String, dynamic> planItem) isConsumedInMeal;
  final Future<void> Function(int mealNo, Map<String, dynamic> planItem)
      onToggleConsumed;

  const _NutritionPremiumView({
    required this.tarih,
    required this.onPickDate,
    required this.onRefresh,
    required this.planData,
    required this.targetKcal,
    required this.targetProtein,
    required this.targetKarb,
    required this.targetYag,
    required this.toplamKalori,
    required this.toplamProtein,
    required this.toplamKarb,
    required this.toplamYag,
    required this.mealKeyToNo,
    required this.mealTitle,
    required this.isConsumedInMeal,
    required this.onToggleConsumed,
  });

  static String _s(dynamic v, [String fallback = '']) {
    final t = v?.toString().trim();
    return (t == null || t.isEmpty) ? fallback : t;
  }

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    final s = v.toString().replaceAll(',', '.').trim();
    return double.tryParse(s) ?? 0;
  }

  String _fmt0(double v) => v.toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    final programRaw = planData['program'];
    final program = (programRaw is Map)
        ? Map<String, dynamic>.from(programRaw)
        : <String, dynamic>{};

    final hedef = _s(program['hedef']);
    final notlar = _s(program['notlar']);
    final createdAt = _s(planData['created_at'] ?? program['created_at']);

    final byOgunRaw = planData['by_ogun'];
    final byOgun = (byOgunRaw is Map)
        ? Map<String, dynamic>.from(byOgunRaw)
        : <String, dynamic>{};

    final entries = byOgun.entries.toList()
      ..sort(
        (a, b) => mealKeyToNo(a.key.toString())
            .compareTo(mealKeyToNo(b.key.toString())),
      );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        _NutritionTopBar(
          title: 'Beslenme',
          onRefresh: onRefresh,
        ),
        const SizedBox(height: 14),
        _TopBannerCard(
          tarih: tarih,
          onPickDate: onPickDate,
          hedef: hedef,
          createdAt: createdAt,
          notlar: notlar,
        ),
        const SizedBox(height: 14),
        _MainKcalCard(
          consumed: toplamKalori,
          target: targetKcal,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MacroMiniCard(
                title: 'Protein',
                value: toplamProtein,
                target: targetProtein,
                unit: 'g',
                icon: Icons.fitness_center_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MacroMiniCard(
                title: 'Karb',
                value: toplamKarb,
                target: targetKarb,
                unit: 'g',
                icon: Icons.grain_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MacroMiniCard(
                title: 'Yağ',
                value: toplamYag,
                target: targetYag,
                unit: 'g',
                icon: Icons.opacity_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _SectionHeader(
          title: 'Öğünler',
          subtitle: entries.isEmpty
              ? 'Bu gün için gösterilecek öğün bulunmuyor.'
              : 'Planındaki öğünleri ve tüketim durumunu aşağıdan takip et.',
          icon: Icons.restaurant_rounded,
          accent: const Color(0xFF00A86B),
        ),
        const SizedBox(height: 10),
        if (entries.isEmpty)
          const _EmptyPlanContentCard()
        else
          ...entries.map((entry) {
            final ogunKey = entry.key.toString();
            final itemsRaw = entry.value;
            final List<dynamic> items = itemsRaw is List ? itemsRaw : const [];

            double kcal = 0;
            double carb = 0;
            double pro = 0;
            double fat = 0;
            int doneCount = 0;

            for (final it in items) {
              final m = (it is Map)
                  ? Map<String, dynamic>.from(it)
                  : <String, dynamic>{};

              kcal += _d(m['kalori']);
              carb += _d(m['karbonhidrat']);
              pro += _d(m['protein']);
              fat += _d(m['yag']);

              final mealNo = mealKeyToNo(ogunKey);
              if (isConsumedInMeal(mealNo, m)) {
                doneCount++;
              }
            }

            final mealNo = mealKeyToNo(ogunKey);
            final title = mealTitle(mealNo);

            return _MealSectionCard(
              title: title,
              doneCount: doneCount,
              totalCount: items.length,
              subtitle:
                  'Kcal ${_fmt0(kcal)} • P ${_fmt0(pro)}g • K ${_fmt0(carb)}g • Y ${_fmt0(fat)}g',
              items: items,
              mealNo: mealNo,
              isConsumedInMeal: isConsumedInMeal,
              onToggleConsumed: onToggleConsumed,
            );
          }),
      ],
    );
  }
}

class _NutritionBrightBackground extends StatelessWidget {
  const _NutritionBrightBackground();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: Container(
        color: isDark ? AppColors.darkBg : const Color(0xFFF7FAFF),
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
                  color: AppColors.primary.withOpacity(isDark ? 0.10 : 0.06),
                ),
              ),
            ),
            Positioned(
              top: 180,
              left: -52,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success.withOpacity(isDark ? 0.08 : 0.05),
                ),
              ),
            ),
            Positioned(
              bottom: 110,
              right: -45,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary.withOpacity(isDark ? 0.08 : 0.05),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NutritionTopBar extends StatelessWidget {
  final String title;
  final VoidCallback onRefresh;

  const _NutritionTopBar({
    required this.title,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
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

class _TopBannerCard extends StatelessWidget {
  final String tarih;
  final VoidCallback onPickDate;
  final String hedef;
  final String createdAt;
  final String notlar;

  const _TopBannerCard({
    required this.tarih,
    required this.onPickDate,
    required this.hedef,
    required this.createdAt,
    required this.notlar,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return _PremiumCardSurface(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: const Color(0xFF00A86B).withOpacity(0.10),
                ),
                child: const Icon(
                  Icons.restaurant_menu_rounded,
                  color: Color(0xFF00A86B),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Beslenme Planım',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Günlük planını ve tüketim durumunu takip et',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _SoftActionButton(
                onTap: onPickDate,
                icon: Icons.calendar_month_rounded,
                label: 'Tarih',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _MetaChip(
            icon: Icons.event_rounded,
            text: 'Seçili gün: $tarih',
            accent: const Color(0xFF4F7CFF),
          ),
          if (hedef.isNotEmpty) ...[
            const SizedBox(height: 10),
            _MetaChip(
              icon: Icons.flag_rounded,
              text: 'Hedef: $hedef',
              accent: const Color(0xFFFF7A18),
            ),
          ],
          if (createdAt.isNotEmpty) ...[
            const SizedBox(height: 10),
            _MetaChip(
              icon: Icons.schedule_rounded,
              text: 'Oluşturulma: $createdAt',
              accent: const Color(0xFF14B86A),
            ),
          ],
          if (notlar.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: isDark ? AppColors.darkSurface2 : const Color(0xFFFBFDFF),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : const Color(0xFFE8EEF7),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.sticky_note_2_rounded,
                    size: 18,
                    color: Color(0xFF4F7CFF),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      notlar,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SoftActionButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String label;

  const _SoftActionButton({
    required this.onTap,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? AppColors.darkSurface2 : const Color(0xFFFBFDFF),
          border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE8EEF7)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              size: 18,
              color: Color(0xFF4F7CFF),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color accent;

  const _MetaChip({
    required this.icon,
    required this.text,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: accent.withOpacity(0.08),
        border: Border.all(color: accent.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
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

class _MainKcalCard extends StatelessWidget {
  final double consumed;
  final double? target;

  const _MainKcalCard({
    required this.consumed,
    required this.target,
  });

  String _fmt0(double v) => v.toStringAsFixed(0);

  double _pct(double consumed, double? target) {
    if (target == null || target <= 0) return 0;
    return (consumed / target).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final progress = _pct(consumed, target);

    return _PremiumCardSurface(
      padding: const EdgeInsets.all(18),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: consumed),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        builder: (context, animatedConsumed, _) {
          final animatedProgress = _pct(animatedConsumed, target);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Günlük Kalori',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.15),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Text(
                      _fmt0(animatedConsumed),
                      key: ValueKey(_fmt0(animatedConsumed)),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1,
                        letterSpacing: -0.8,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'kcal',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    target != null && target! > 0
                        ? '${_fmt0(animatedConsumed)} / ${_fmt0(target!)} kcal'
                        : '${_fmt0(animatedConsumed)} kcal',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: animatedProgress),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 12,
                      backgroundColor: isDark ? AppColors.darkSurface2 : const Color(0xFFEEF3FB),
                      color: const Color(0xFF4F7CFF),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              Text(
                target != null && target! > 0
                    ? 'Hedefin ${(progress * 100).toStringAsFixed(0)}% tamamlandı'
                    : 'Profil hedefi tanımlı değil',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MacroMiniCard extends StatelessWidget {
  final String title;
  final double value;
  final double? target;
  final String unit;
  final IconData icon;

  const _MacroMiniCard({
    required this.title,
    required this.value,
    required this.target,
    required this.unit,
    required this.icon,
  });

  String _fmt0(double v) => v.toStringAsFixed(0);

  double _pct(double consumed, double? target) {
    if (target == null || target <= 0) return 0;
    return (consumed / target).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return _PremiumCardSurface(
      padding: const EdgeInsets.all(14),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: value),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        builder: (context, animatedValue, _) {
          final progress = _pct(animatedValue, target);

          return SizedBox(
            height: 104,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.bottomCenter,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    builder: (context, p, _) {
                      return Container(
                        height: 56 * p,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: const Color(0xFF4F7CFF).withOpacity(0.08),
                        ),
                      );
                    },
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFF4F7CFF).withOpacity(0.10),
                      ),
                      child: Icon(icon, size: 18, color: const Color(0xFF4F7CFF)),
                    ),
                    const Spacer(),
                    Text(
                      title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          transitionBuilder: (child, animation) => FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.15),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          ),
                          child: Text(
                            _fmt0(animatedValue),
                            key: ValueKey('${title}_${_fmt0(animatedValue)}'),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              height: 1,
                              color: isDark ? AppColors.darkText : AppColors.lightText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            unit,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      target != null && target! > 0
                          ? '${_fmt0(target!)} $unit hedef'
                          : 'Hedef yok',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MealSectionCard extends StatelessWidget {
  final String title;
  final int doneCount;
  final int totalCount;
  final String subtitle;
  final List<dynamic> items;
  final int mealNo;
  final bool Function(int mealNo, Map<String, dynamic> planItem) isConsumedInMeal;
  final Future<void> Function(int mealNo, Map<String, dynamic> planItem)
      onToggleConsumed;

  const _MealSectionCard({
    required this.title,
    required this.doneCount,
    required this.totalCount,
    required this.subtitle,
    required this.items,
    required this.mealNo,
    required this.isConsumedInMeal,
    required this.onToggleConsumed,
  });

  static String _s(dynamic v, [String fallback = '']) {
    final t = v?.toString().trim();
    return (t == null || t.isEmpty) ? fallback : t;
  }

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    final s = v.toString().replaceAll(',', '.').trim();
    return double.tryParse(s) ?? 0;
  }

  String _fmt0(double v) => v.toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final progress =
        totalCount <= 0 ? 0.0 : (doneCount / totalCount).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: _PremiumCardSurface(
        padding: EdgeInsets.zero,
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
            title: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFF00A86B).withOpacity(0.10),
                  ),
                  child: const Icon(
                    Icons.restaurant_rounded,
                    color: Color(0xFF00A86B),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: doneCount > 0
                        ? const Color(0xFF4F7CFF).withOpacity(0.10)
                        : const Color(0xFFF5F7FB),
                    border: Border.all(
                      color: doneCount > 0
                          ? const Color(0xFF4F7CFF).withOpacity(0.20)
                          : const Color(0xFFE8EEF7),
                    ),
                  ),
                  child: Text(
                    '$doneCount/$totalCount',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: doneCount > 0
                          ? const Color(0xFF4F7CFF)
                          : (isDark ? AppColors.darkTextSub : AppColors.lightTextSub),
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: isDark ? AppColors.darkSurface2 : const Color(0xFFEEF3FB),
                      color: const Color(0xFF4F7CFF),
                    ),
                  ),
                ],
              ),
            ),
            children: items.map((it) {
              final m = (it is Map)
                  ? Map<String, dynamic>.from(it)
                  : <String, dynamic>{};

              final yemek = _s(m['yemek'], '-');
              final miktar = _d(m['miktar']);
              final birim = _s(m['birim']);
              final itemKcal = _d(m['kalori']);
              final done = isConsumedInMeal(mealNo, m);

              return GestureDetector(
                onTap: () => onToggleConsumed(mealNo, m),
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: done
                        ? const Color(0xFF4F7CFF).withOpacity(0.07)
                        : const Color(0xFFFBFDFF),
                    border: Border.all(
                      color: done
                          ? const Color(0xFF4F7CFF).withOpacity(0.18)
                          : const Color(0xFFE8EEF7),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: done
                              ? const Color(0xFF4F7CFF).withOpacity(0.12)
                              : (isDark ? AppColors.darkSurface2 : Colors.white),
                        ),
                        child: Icon(
                          done
                              ? Icons.check_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 18,
                          color: done
                              ? const Color(0xFF4F7CFF)
                              : const Color(0xFFB0BAC9),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              yemek,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppColors.darkText : AppColors.lightText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${miktar.toStringAsFixed(miktar % 1 == 0 ? 0 : 1)} ${birim.isEmpty ? '' : birim}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: isDark ? AppColors.darkSurface2 : Colors.white,
                          border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE8EEF7)),
                        ),
                        child: Text(
                          '${_fmt0(itemKcal)} kcal',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.darkText : AppColors.lightText,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _NoPlanCard extends StatelessWidget {
  const _NoPlanCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return _PremiumCardSurface(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF00A86B).withOpacity(0.10),
            ),
            child: const Icon(
              Icons.restaurant_menu_rounded,
              size: 34,
              color: Color(0xFF00A86B),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Henüz atanmış beslenme programın yok',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Eğitmenin sana bir beslenme planı tanımladığında burada görüntülenecek.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPlanContentCard extends StatelessWidget {
  const _EmptyPlanContentCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _PremiumCardSurface(
      padding: const EdgeInsets.all(18),
      child: Text(
        'Bu plan için öğün içeriği bulunamadı.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;

  const _ErrorBox({
    required this.msg,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _PremiumCardSurface(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFD14343),
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                'Beslenme verileri alınırken bir hata oluştu.',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                msg,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F7CFF),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                child: const Text(
                  'Tekrar Dene',
                  style: TextStyle(fontWeight: FontWeight.w800),
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
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.30)
                : const Color(0xFF8DAEF5).withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}