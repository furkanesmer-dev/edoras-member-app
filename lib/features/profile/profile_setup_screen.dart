import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';

class ProfileSetupScreen extends StatefulWidget {
  final ApiClient apiClient;
  final Map<String, dynamic> meData; // {profile, subscription, targets}
  final Future<void> Function() onSaved;

  const ProfileSetupScreen({
    super.key,
    required this.apiClient,
    required this.meData,
    required this.onSaved,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _saving = false;
  String? _error;

  String? _cinsiyet; // erkek/kadin
  DateTime? _dogumTarihi;

  String _aktivite = 'orta';
  String _kiloHedefi = 'koru';
  String _hedefTempo = 'orta';

  final _boyCtrl = TextEditingController();
  final _kiloCtrl = TextEditingController();
  final _belCtrl = TextEditingController();
  final _boyunCtrl = TextEditingController();
  final _basenCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();

    final pRaw = widget.meData['profile'];
    final p = (pRaw is Map) ? pRaw.cast<String, dynamic>() : <String, dynamic>{};

    _cinsiyet = _str(p['cinsiyet']);
    _aktivite = _str(p['aktivite_seviyesi']) ?? 'orta';
    _kiloHedefi = _str(p['kilo_hedefi']) ?? 'koru';
    _hedefTempo = _str(p['hedef_tempo']) ?? 'orta';

    final dogum = _str(p['dogum_tarihi']);
    if (dogum != null && dogum.length >= 10) {
      final parsed = DateTime.tryParse(dogum.substring(0, 10));
      if (parsed != null) _dogumTarihi = parsed;
    }

    _boyCtrl.text = _numText(p['boy_cm']);
    _kiloCtrl.text = _numText(p['kilo_kg']);
    _belCtrl.text = _numText(p['bel_cevresi']);
    _boyunCtrl.text = _numText(p['boyun_cevresi']);
    _basenCtrl.text = _numText(p['basen_cevresi']);
  }

  @override
  void dispose() {
    _boyCtrl.dispose();
    _kiloCtrl.dispose();
    _belCtrl.dispose();
    _boyunCtrl.dispose();
    _basenCtrl.dispose();
    super.dispose();
  }

  String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  String _numText(dynamic v) {
    if (v == null) return '';
    if (v is num) return v.toString();
    return v.toString().trim();
  }

  double? _parseNum(String v) {
    final s = v.trim().replaceAll(',', '.');
    return double.tryParse(s);
  }

  String? _req(String? v) {
    if (v == null || v.trim().isEmpty) return 'Zorunlu';
    return null;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _dogumTarihi ?? DateTime(now.year - 25, 1, 1);

    final dt = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1940, 1, 1),
      lastDate: DateTime(now.year - 10, 12, 31),
    );

    if (dt != null) setState(() => _dogumTarihi = dt);
  }

  bool _needBasen() => _cinsiyet == 'kadin';

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    setState(() => _error = null);

    if (!_formKey.currentState!.validate()) return;

    if (_cinsiyet == null) {
      setState(() => _error = 'Cinsiyet seçiniz.');
      return;
    }
    if (_dogumTarihi == null) {
      setState(() => _error = 'Doğum tarihi seçiniz.');
      return;
    }
    if (_needBasen() && _basenCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Kadın için basen ölçüsü gereklidir.');
      return;
    }

    final payload = <String, dynamic>{
      'cinsiyet': _cinsiyet,
      'dogum_tarihi':
          '${_dogumTarihi!.year.toString().padLeft(4, '0')}-${_dogumTarihi!.month.toString().padLeft(2, '0')}-${_dogumTarihi!.day.toString().padLeft(2, '0')}',
      'boy_cm': _parseNum(_boyCtrl.text),
      'kilo_kg': _parseNum(_kiloCtrl.text),
      'bel_cevresi': _parseNum(_belCtrl.text),
      'boyun_cevresi': _parseNum(_boyunCtrl.text),
      'basen_cevresi': _basenCtrl.text.trim().isEmpty ? null : _parseNum(_basenCtrl.text),
      'aktivite_seviyesi': _aktivite,
      'kilo_hedefi': _kiloHedefi,
      'hedef_tempo': _hedefTempo,
    }..removeWhere((k, v) => v == null);

    setState(() => _saving = true);
    try {
      await widget.apiClient.updateProfile(payload);
      await widget.onSaved();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final dateText = _dogumTarihi == null
        ? 'Seç'
        : '${_dogumTarihi!.day.toString().padLeft(2, '0')}.${_dogumTarihi!.month.toString().padLeft(2, '0')}.${_dogumTarihi!.year}';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),

                    Center(
                      child: ColorFiltered(
                        colorFilter: isDark
                            ? const ColorFilter.matrix([
                                -1, 0, 0, 0, 255,
                                0, -1, 0, 0, 255,
                                0, 0, -1, 0, 255,
                                0, 0, 0, 1, 0,
                              ])
                            : const ColorFilter.mode(
                                Colors.transparent, BlendMode.multiply),
                        child: Image.asset(
                          'assets/icons/edoras_logo_black_transparent_1024.png',
                          height: 110,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        'Profilini Tamamla',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                              color: isDark ? AppColors.darkText : Colors.black,
                            ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    _InfoCard(
                      text: 'Beslenme hedefini doğru hesaplayabilmemiz için birkaç bilgiyi tamamlaman gerekiyor.',
                    ),

                    const SizedBox(height: 12),

                    if (_error != null) ...[
                      _ErrorCard(text: _error!),
                      const SizedBox(height: 12),
                    ],

                    // --- Form Alanları ---
                    _NiceDropdown<String>(
                      value: _cinsiyet,
                      label: 'Cinsiyet',
                      items: const [
                        DropdownMenuItem(value: 'erkek', child: Text('Erkek')),
                        DropdownMenuItem(value: 'kadin', child: Text('Kadın')),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) {
                              setState(() {
                                _cinsiyet = v;
                                if (!_needBasen()) _basenCtrl.text = '';
                              });
                            },
                      validator: (v) => v == null ? 'Zorunlu' : null,
                    ),

                    const SizedBox(height: 14),

                    // Doğum tarihi (tıklanabilir)
                    InkWell(
                      onTap: _saving ? null : _pickDate,
                      borderRadius: BorderRadius.circular(18),
                      child: InputDecorator(
                        decoration: _niceDecoration(context, 'Doğum Tarihi', icon: Icons.calendar_month),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(dateText),
                            Icon(Icons.calendar_month, color: scheme.onSurfaceVariant),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    _NiceField(
                      controller: _boyCtrl,
                      label: 'Boy (cm)',
                      icon: Icons.height,
                      keyboardType: TextInputType.number,
                      validator: _req,
                    ),
                    const SizedBox(height: 14),

                    _NiceField(
                      controller: _kiloCtrl,
                      label: 'Kilo (kg)',
                      icon: Icons.monitor_weight_outlined,
                      keyboardType: TextInputType.number,
                      validator: _req,
                    ),
                    const SizedBox(height: 14),

                    _NiceField(
                      controller: _belCtrl,
                      label: 'Bel (cm)',
                      icon: Icons.straighten,
                      keyboardType: TextInputType.number,
                      validator: _req,
                    ),
                    const SizedBox(height: 14),

                    _NiceField(
                      controller: _boyunCtrl,
                      label: 'Boyun (cm)',
                      icon: Icons.straighten,
                      keyboardType: TextInputType.number,
                      validator: _req,
                    ),
                    const SizedBox(height: 14),

                    _NiceField(
                      controller: _basenCtrl,
                      label: 'Basen (cm) (Kadın için)',
                      icon: Icons.straighten,
                      keyboardType: TextInputType.number,
                      enabled: _needBasen(),
                      helperText: _needBasen() ? 'Kadınlarda yağ oranı hesabı için gereklidir.' : null,
                    ),

                    const SizedBox(height: 16),

                    _NiceDropdown<String>(
                      value: _aktivite,
                      label: 'Aktivite Seviyesi',
                      items: const [
                        DropdownMenuItem(value: 'sedanter', child: Text('Sedanter')),
                        DropdownMenuItem(value: 'hafif', child: Text('Hafif Aktif')),
                        DropdownMenuItem(value: 'orta', child: Text('Orta Aktif')),
                        DropdownMenuItem(value: 'yuksek', child: Text('Yüksek Aktif')),
                        DropdownMenuItem(value: 'cok_yuksek', child: Text('Çok Yüksek Aktif')),
                      ],
                      onChanged: _saving ? null : (v) => setState(() => _aktivite = v ?? 'orta'),
                    ),

                    const SizedBox(height: 14),

                    _NiceDropdown<String>(
                      value: _kiloHedefi,
                      label: 'Kilo Hedefi',
                      items: const [
                        DropdownMenuItem(value: 'kilo_ver', child: Text('Kilo Verme')),
                        DropdownMenuItem(value: 'koru', child: Text('Koru')),
                        DropdownMenuItem(value: 'kilo_al', child: Text('Kilo Alma')),
                      ],
                      onChanged: _saving ? null : (v) => setState(() => _kiloHedefi = v ?? 'koru'),
                    ),

                    const SizedBox(height: 14),

                    _NiceDropdown<String>(
                      value: _hedefTempo,
                      label: 'Hedef Temposu',
                      items: const [
                        DropdownMenuItem(value: 'yavas', child: Text('Yavaş')),
                        DropdownMenuItem(value: 'orta', child: Text('Orta')),
                        DropdownMenuItem(value: 'hizli', child: Text('Hızlı')),
                      ],
                      onChanged: _saving ? null : (v) => setState(() => _hedefTempo = v ?? 'orta'),
                    ),

                    const SizedBox(height: 18),

                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: scheme.primary,
                          foregroundColor: Colors.white, // ✅ yazı garanti
                          disabledBackgroundColor: scheme.primary.withValues(alpha: 0.6),
                          disabledForegroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Kaydet ve Devam Et',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* -------------------- UI Helpers (Login/Register stili) -------------------- */

InputDecoration _niceDecoration(BuildContext context, String label, {IconData? icon, String? helperText}) {
  final scheme = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return InputDecoration(
    labelText: label,
    helperText: helperText,
    prefixIcon: icon != null ? Icon(icon) : null,
    filled: true,
    fillColor: isDark ? AppColors.darkSurface2 : const Color(0xFFF2F4F7),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: isDark ? AppColors.darkBorder : scheme.outlineVariant),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFE4E7EC)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: scheme.primary, width: 1.2),
    ),
  );
}

class _NiceField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? helperText;
  final bool enabled;
  final String? Function(String?)? validator;

  const _NiceField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.helperText,
    this.enabled = true,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator,
      decoration: _niceDecoration(context, label, icon: icon, helperText: helperText),
    );
  }
}

class _NiceDropdown<T> extends StatelessWidget {
  final T? value;
  final String label;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?)? onChanged;
  final String? Function(T?)? validator;

  const _NiceDropdown({
    required this.value,
    required this.label,
    required this.items,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
      decoration: _niceDecoration(context, label, icon: Icons.tune),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String text;
  const _InfoCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(height: 1.25, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String text;
  const _ErrorCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: scheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: scheme.error, height: 1.25, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}