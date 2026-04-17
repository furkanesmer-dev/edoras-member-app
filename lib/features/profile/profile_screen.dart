import 'dart:io';

import 'package:flutter/material.dart';
import 'package:edoras_member_app/core/api/api_client.dart';
import 'package:edoras_member_app/core/config/app_config.dart';
import 'package:edoras_member_app/core/storage/token_storage.dart';
import 'package:edoras_member_app/core/theme/app_colors.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ProfileScreen extends StatefulWidget {
  final ApiClient apiClient;
  final TokenStorage tokenStorage;

  const ProfileScreen({
    super.key,
    required this.apiClient,
    required this.tokenStorage,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _subscription;
  Map<String, dynamic>? _targets;

  Map<String, dynamic>? _profileInitial;

  final _formKey = GlobalKey<FormState>();

  final _kiloCtrl = TextEditingController();
  final _boyCtrl = TextEditingController();
  final _belCtrl = TextEditingController();
  final _basenCtrl = TextEditingController();
  final _boyunCtrl = TextEditingController();

  String? _cinsiyet;
  DateTime? _dogumTarihi;
  String? _aktivite;
  String? _kiloHedefi;
  String? _hedefTempo;

  final _scrollCtrl = ScrollController();

  final _picker = ImagePicker();
  bool _photoUploading = false;
  String? _photoUrl;

  // PROD: site base URL, AppConfig.baseUrl üzerinden türetiliyor.
  static String get _siteBase {
    final base = AppConfig.baseUrl;
    final uri = Uri.tryParse(base);
    if (uri == null) return base;
    return '${uri.scheme}://${uri.host}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _kiloCtrl.dispose();
    _boyCtrl.dispose();
    _belCtrl.dispose();
    _basenCtrl.dispose();
    _boyunCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final data = await widget.apiClient.getProfileMe();

      final profile = (data['profile'] is Map)
          ? Map<String, dynamic>.from(data['profile'])
          : <String, dynamic>{};
      final subscription = (data['subscription'] is Map)
          ? Map<String, dynamic>.from(data['subscription'])
          : <String, dynamic>{};
      final targets = (data['targets'] is Map)
          ? Map<String, dynamic>.from(data['targets'])
          : null;

      _profile = profile;
      _subscription = subscription;
      _targets = targets;

      _profileInitial = Map<String, dynamic>.from(profile);

      _fillFormFromProfile(profile);

      final fotoYolu = _asStringOrNull(profile['foto_yolu']);
      _photoUrl = _toFullPhotoUrl(fotoYolu);

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Bir hata oluştu. Lütfen tekrar deneyin.";
      });
    }
  }

  void _fillFormFromProfile(Map<String, dynamic> p) {
    _kiloCtrl.text = _numToText(p['kilo_kg']);
    _boyCtrl.text = _numToText(p['boy_cm']);
    _belCtrl.text = _numToText(p['bel_cevresi']);
    _basenCtrl.text = _numToText(p['basen_cevresi']);
    _boyunCtrl.text = _numToText(p['boyun_cevresi']);

    _cinsiyet = _asStringOrNull(p['cinsiyet']);
    _aktivite = _asStringOrNull(p['aktivite_seviyesi']);
    _kiloHedefi = _asStringOrNull(p['kilo_hedefi']);
    _hedefTempo = _asStringOrNull(p['hedef_tempo']);

    final dt = _asStringOrNull(p['dogum_tarihi']);
    _dogumTarihi = _parseYmd(dt);
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Hesabınızdan çıkmak istiyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await widget.tokenStorage.clear();

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e) {
      _showSnack('Çıkış yapılamadı.');
    }
  }

  Future<void> _save() async {
    if (_saving) return;

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      _showSnack('Lütfen hatalı alanları düzelt.');
      return;
    }

    final payload = _buildDiffPayload();
    if (payload.isEmpty) {
      _showSnack('Değişiklik yok.');
      return;
    }

    if (mounted) setState(() => _saving = true);

    try {
      await widget.apiClient.updateProfile(payload);
      _showSnack('Profil kaydedildi.');
      await _load();
    } catch (e) {
      _showSnack('Kaydedilemedi. Lütfen tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, dynamic> _buildDiffPayload() {
    final init = _profileInitial ?? {};
    final payload = <String, dynamic>{};

    _putIfChangedNum(payload, init, 'kilo_kg', _kiloCtrl.text);
    _putIfChangedNum(payload, init, 'boy_cm', _boyCtrl.text);
    _putIfChangedNum(payload, init, 'bel_cevresi', _belCtrl.text);
    _putIfChangedNum(payload, init, 'basen_cevresi', _basenCtrl.text);
    _putIfChangedNum(payload, init, 'boyun_cevresi', _boyunCtrl.text);

    _putIfChangedStr(payload, init, 'cinsiyet', _cinsiyet);
    _putIfChangedStr(payload, init, 'aktivite_seviyesi', _aktivite);
    _putIfChangedStr(payload, init, 'kilo_hedefi', _kiloHedefi);
    _putIfChangedStr(payload, init, 'hedef_tempo', _hedefTempo);

    final initDob = _asStringOrNull(init['dogum_tarihi']);
    final newDob = _dogumTarihi == null ? null : _formatYmd(_dogumTarihi!);
    if ((initDob ?? '') != (newDob ?? '')) {
      if (newDob != null && newDob.isNotEmpty) {
        payload['dogum_tarihi'] = newDob;
      }
    }

    return payload;
  }

  void _putIfChangedNum(
    Map<String, dynamic> out,
    Map<String, dynamic> init,
    String key,
    String text,
  ) {
    final t = text.trim();
    if (t.isEmpty) return;

    final initText = _numToText(init[key]);
    final normalized = t.replaceAll(',', '.');
    final initNorm = initText.replaceAll(',', '.');
    if (initNorm == normalized) return;

    out[key] = normalized;
  }

  void _putIfChangedStr(
    Map<String, dynamic> out,
    Map<String, dynamic> init,
    String key,
    String? value,
  ) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return;

    final initV = (_asStringOrNull(init[key]) ?? '').trim();
    if (initV == v) return;

    out[key] = v;
  }

  Future<File> _compressImage(File input) async {
    final dir = await getTemporaryDirectory();
    final targetPath = p.join(
      dir.path,
      'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    final result = await FlutterImageCompress.compressAndGetFile(
      input.absolute.path,
      targetPath,
      quality: 80,
      minWidth: 1080,
      minHeight: 1080,
      format: CompressFormat.jpeg,
    );

    if (result == null) return input;
    return File(result.path);
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    if (_photoUploading) return;

    try {
      final xfile = await _picker.pickImage(
        source: source,
        imageQuality: 100,
      );
      if (xfile == null) return;

      if (!mounted) return;
      setState(() => _photoUploading = true);

      final original = File(xfile.path);
      final compressed = await _compressImage(original);

      final data = await widget.apiClient.uploadProfilePhoto(compressed);

      final urlRaw = (data['photo_url'] ?? '').toString().trim();
      final pathRaw = (data['photo_path'] ?? '').toString().trim();

      if (urlRaw.isEmpty && pathRaw.isEmpty) {
        throw Exception('Sunucudan photo_url/photo_path gelmedi.');
      }

      final full = urlRaw.isNotEmpty ? urlRaw : (_toFullPhotoUrl(pathRaw) ?? '');
      if (full.isEmpty) {
        throw Exception('Fotoğraf URL üretilemedi.');
      }

      final bust = 'v=${DateTime.now().millisecondsSinceEpoch}';
      final finalUrl = full.contains('?') ? '$full&$bust' : '$full?$bust';

      _profile ??= {};
      if (pathRaw.isNotEmpty) {
        _profile!['foto_yolu'] = pathRaw;
      }

      if (!mounted) return;
      setState(() {
        _photoUrl = finalUrl;
        _photoUploading = false;
      });

      _showSnack('Profil fotoğrafı güncellendi.');
    } catch (e) {
      if (mounted) setState(() => _photoUploading = false);
      _showSnack('Fotoğraf yüklenemedi.');
    }
  }

  String? _toFullPhotoUrl(String? fotoYolu) {
    final v = (fotoYolu ?? '').trim();
    if (v.isEmpty) return null;

    if (v.startsWith('http://') || v.startsWith('https://')) return v;

    final cleaned = v.startsWith('/') ? v.substring(1) : v;
    return '$_siteBase/$cleaned';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildLoading();
    if (_error != null) return _buildError();

    final p = _profile ?? {};
    final sub = _subscription ?? {};
    final targets = _targets;

    final ad = _asStringOrNull(p['ad']) ?? '';
    final soyad = _asStringOrNull(p['soyad']) ?? '';
    final fullName = '$ad $soyad'.trim();

    final email = _asStringOrNull(p['eposta_adresi']);
    final phone = _asStringOrNull(p['tel_no']);

    final vki = p['vucut_kitle_indeksi'];
    final vkiDurum = _asStringOrNull(p['vki_durum']);
    final yag = p['yag_orani'];

    return Scaffold(
      body: Stack(
        children: [
          const _BrightProfileBackground(),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _PremiumProfileHero(
                        fullName: fullName.isEmpty ? 'Üye' : fullName,
                        email: email,
                        phone: phone,
                        photoUrl: _photoUrl,
                        isUploading: _photoUploading,
                        onAvatarTap: _openPhotoSheet,
                        onLogout: _logout,
                      ),
                      const SizedBox(height: 14),
                      _PremiumSubscriptionCard(subscription: sub),
                      const SizedBox(height: 14),
                      _PremiumBodyInfoCard(
                        kiloCtrl: _kiloCtrl,
                        boyCtrl: _boyCtrl,
                        belCtrl: _belCtrl,
                        basenCtrl: _basenCtrl,
                        boyunCtrl: _boyunCtrl,
                        vki: vki,
                        vkiDurum: vkiDurum,
                        yagOrani: yag,
                      ),
                      const SizedBox(height: 14),
                      _PremiumCalorieInputsCard(
                        cinsiyet: _cinsiyet,
                        aktivite: _aktivite,
                        kiloHedefi: _kiloHedefi,
                        hedefTempo: _hedefTempo,
                        dogumTarihi: _dogumTarihi,
                        onCinsiyetChanged: (v) => setState(() => _cinsiyet = v),
                        onAktiviteChanged: (v) => setState(() => _aktivite = v),
                        onKiloHedefiChanged: (v) => setState(() => _kiloHedefi = v),
                        onHedefTempoChanged: (v) => setState(() => _hedefTempo = v),
                        onPickDob: _pickDob,
                        targets: targets,
                      ),
                      const SizedBox(height: 18),
                      _SaveButton(
                        saving: _saving,
                        onPressed: _saving ? null : _save,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Not: Yağ oranı ve bazı değerler sistem tarafından otomatik hesaplanabilir.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextSub : AppColors.lightTextSub,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPhotoSheet() async {
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurface
            : Colors.white,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SheetActionTile(
                  icon: Icons.photo_library_outlined,
                  title: 'Galeriden Fotoğraf Seç',
                  accent: const Color(0xFF4F7CFF),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadPhoto(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 8),
                _SheetActionTile(
                  icon: Icons.photo_camera_outlined,
                  title: 'Kamerayla Çek',
                  accent: const Color(0xFFFF7A18),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadPhoto(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 8),
                _SheetActionTile(
                  icon: Icons.delete_outline_rounded,
                  title: 'Fotoğrafı Kaldır',
                  accent: const Color(0xFFEF4444),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showSnack('Fotoğraf kaldırma (endpoint) sonraki adım.');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoading() {
    return const Scaffold(
      body: Stack(
        children: [
          _BrightProfileBackground(),
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

  Widget _buildError() {
    return Scaffold(
      body: Stack(
        children: [
          const _BrightProfileBackground(),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _ErrorCard(
                  message: _error ?? 'Bilinmeyen hata',
                  onRetry: _load,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _dogumTarihi ?? DateTime(now.year - 25, 1, 1);
    final firstDate = DateTime(1900, 1, 1);
    final lastDate = DateTime(now.year - 10, 12, 31);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstDate) ? firstDate : initial,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Doğum Tarihi Seç',
      cancelText: 'İptal',
      confirmText: 'Seç',
    );

    if (picked != null) {
      setState(() => _dogumTarihi = DateTime(picked.year, picked.month, picked.day));
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _numToText(dynamic v) {
    if (v == null) return '';
    if (v is num) {
      final s = v.toString();
      if (s.endsWith('.0')) return s.substring(0, s.length - 2);
      return s;
    }
    final s = v.toString().trim();
    if (s == 'null') return '';
    return s;
  }

  String? _asStringOrNull(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty || s == 'null') return null;
    return s;
  }

  DateTime? _parseYmd(String? ymd) {
    if (ymd == null || ymd.isEmpty) return null;
    final parts = ymd.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  String _formatYmd(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class _BrightProfileBackground extends StatelessWidget {
  const _BrightProfileBackground();

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
                  color: AppColors.secondary.withValues(alpha: isDark ? 0.10 : 0.07),
                ),
              ),
            ),
            Positioned(
              bottom: 120,
              right: -40,
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

class _PremiumProfileHero extends StatelessWidget {
  final String fullName;
  final String? email;
  final String? phone;
  final String? photoUrl;
  final bool isUploading;
  final VoidCallback onAvatarTap;
  final VoidCallback onLogout;

  const _PremiumProfileHero({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.photoUrl,
    required this.isUploading,
    required this.onAvatarTap,
    required this.onLogout,
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
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF7FB2FF).withValues(alpha: 0.18),
              ),
            ),
          ),
          Positioned(
            bottom: -34,
            left: -26,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFB074).withValues(alpha: 0.14),
              ),
            ),
          ),
          Column(
            children: [
              Row(
                children: [

                  const Spacer(),
                  _CircleIconButton(
                    icon: Icons.logout_rounded,
                    accent: const Color(0xFFEF4444),
                    onTap: onLogout,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _AvatarButtonLarge(
                onTap: onAvatarTap,
                photoUrl: photoUrl,
                isUploading: isUploading,
              ),
              const SizedBox(height: 14),
              Text(
                fullName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkText : AppColors.lightText,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Profil bilgilerini güncelle, ölçülerini yönet ve hedeflerini kontrol et.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextSub : AppColors.lightTextSub,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if ((email ?? '').isNotEmpty)
                    Expanded(
                      child: _ContactInfoChip(
                        icon: Icons.email_outlined,
                        text: email!,
                        accent: const Color(0xFF4F7CFF),
                      ),
                    ),
                  if ((email ?? '').isNotEmpty && (phone ?? '').isNotEmpty)
                    const SizedBox(width: 10),
                  if ((phone ?? '').isNotEmpty)
                    Expanded(
                      child: _ContactInfoChip(
                        icon: Icons.phone_outlined,
                        text: phone!,
                        accent: const Color(0xFF14B86A),
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

class _AvatarButtonLarge extends StatelessWidget {
  final VoidCallback onTap;
  final String? photoUrl;
  final bool isUploading;

  const _AvatarButtonLarge({
    required this.onTap,
    required this.photoUrl,
    required this.isUploading,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isUploading ? null : onTap,
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 94,
            height: 94,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7AA7FF).withValues(alpha: 0.20),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipOval(
              child: (photoUrl != null && photoUrl!.isNotEmpty)
                  ? Image.network(
                      photoUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: const Color(0xFFF3F7FD),
                          alignment: Alignment.center,
                          child: const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF4F7CFF),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (ctx, __, ___) => _fallbackAvatar(ctx),
                    )
                  : _fallbackAvatar(context),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF4F7CFF),
                    Color(0xFF7AA6FF),
                  ],
                ),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F7CFF).withValues(alpha: 0.24),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: isUploading
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.edit_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackAvatar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? AppColors.darkSurface2 : const Color(0xFFF3F7FD),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        size: 46,
        color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
      ),
    );
  }
}

class _PremiumSubscriptionCard extends StatelessWidget {
  final Map<String, dynamic> subscription;

  const _PremiumSubscriptionCard({
    required this.subscription,
  });

  @override
  Widget build(BuildContext context) {
    final uyeAktif = (subscription['uye_aktif'] ?? 0).toString() == '1';
    final odeme = (subscription['odeme_alindi'] ?? 0).toString() == '1';
    final donduruldu = (subscription['donduruldu'] ?? 0).toString() == '1';

    final baslangic = _s(subscription['baslangic_tarihi']);
    final bitis = _s(subscription['bitis_tarihi']);

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
                      color: (uyeAktif ? const Color(0xFF13C67B) : const Color(0xFFEF4444))
                          .withValues(alpha: 0.24),
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
                      uyeAktif ? 'Üyelik aktif görünüyor' : 'Üyelik pasif görünüyor',
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
                color: uyeAktif ? const Color(0xFF14B86A) : const Color(0xFFEF4444),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniPill(
                text: odeme ? 'Ödeme Alındı' : 'Ödeme Yok',
                icon: odeme ? Icons.payments_rounded : Icons.money_off_csred_rounded,
                color: odeme ? const Color(0xFF4F7CFF) : const Color(0xFFEF4444),
              ),
              if (donduruldu)
                const _MiniPill(
                  text: 'Donduruldu',
                  icon: Icons.pause_circle_rounded,
                  color: Color(0xFFFF7A18),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  label: 'Başlangıç',
                  value: baslangic ?? '-',
                  icon: Icons.play_circle_outline_rounded,
                  color: const Color(0xFF4F7CFF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InfoTile(
                  label: 'Bitiş',
                  value: bitis ?? '-',
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

  String? _s(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty || s == 'null') return null;
    return s;
  }
}

class _PremiumBodyInfoCard extends StatelessWidget {
  final TextEditingController kiloCtrl;
  final TextEditingController boyCtrl;
  final TextEditingController belCtrl;
  final TextEditingController basenCtrl;
  final TextEditingController boyunCtrl;

  final dynamic vki;
  final String? vkiDurum;
  final dynamic yagOrani;

  const _PremiumBodyInfoCard({
    required this.kiloCtrl,
    required this.boyCtrl,
    required this.belCtrl,
    required this.basenCtrl,
    required this.boyunCtrl,
    required this.vki,
    required this.vkiDurum,
    required this.yagOrani,
  });

  @override
  Widget build(BuildContext context) {
    return _PremiumCardSurface(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardSectionHeader(
            title: 'Vücut Bilgileri',
            subtitle: 'Ölçülerini güncelle, sistem otomatik hesaplamaları yenilesin.',
            icon: Icons.monitor_weight_rounded,
            accent: const Color(0xFFFF7A18),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _numField(
                  controller: kiloCtrl,
                  label: 'Kilo (kg)',
                  hint: '78.5',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _numField(
                  controller: boyCtrl,
                  label: 'Boy (cm)',
                  hint: '180',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _numField(
                  controller: belCtrl,
                  label: 'Bel (cm)',
                  hint: '85',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _numField(
                  controller: basenCtrl,
                  label: 'Basen (cm)',
                  hint: '98',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _numField(
                  controller: boyunCtrl,
                  label: 'Boyun (cm)',
                  hint: '30',
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
                child: _MetricTile(
                  label: 'Yağ Oranı',
                  value: _formatNum(yagOrani, suffix: '%') ?? '-',
                  accent: const Color(0xFF14B86A),
                  icon: Icons.opacity_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'VKİ',
                  value: _formatNum(vki) ?? '-',
                  accent: const Color(0xFF4F7CFF),
                  icon: Icons.insights_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'VKİ Durum',
                  value: vkiDurum ?? '-',
                  accent: const Color(0xFFFF7A18),
                  icon: Icons.favorite_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _numField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return _PremiumTextField(
      controller: controller,
      label: label,
      hint: hint,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (val) {
        final t = (val ?? '').trim();
        if (t.isEmpty) return null;
        final normalized = t.replaceAll(',', '.');
        final n = double.tryParse(normalized);
        if (n == null) return 'Geçersiz';
        if (n <= 0) return '> 0';
        return null;
      },
    );
  }

  String? _formatNum(dynamic v, {String? suffix}) {
    if (v == null) return null;
    if (v is num) {
      final s = v.toString();
      final out = s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
      return suffix == null ? out : '$out $suffix';
    }
    final s = v.toString().trim();
    if (s.isEmpty || s == 'null') return null;
    return suffix == null ? s : '$s $suffix';
  }
}

class _PremiumCalorieInputsCard extends StatelessWidget {
  final String? cinsiyet;
  final DateTime? dogumTarihi;
  final String? aktivite;
  final String? kiloHedefi;
  final String? hedefTempo;

  final ValueChanged<String?> onCinsiyetChanged;
  final ValueChanged<String?> onAktiviteChanged;
  final ValueChanged<String?> onKiloHedefiChanged;
  final ValueChanged<String?> onHedefTempoChanged;
  final Future<void> Function() onPickDob;

  final Map<String, dynamic>? targets;

  const _PremiumCalorieInputsCard({
    required this.cinsiyet,
    required this.aktivite,
    required this.kiloHedefi,
    required this.hedefTempo,
    required this.dogumTarihi,
    required this.onCinsiyetChanged,
    required this.onAktiviteChanged,
    required this.onKiloHedefiChanged,
    required this.onHedefTempoChanged,
    required this.onPickDob,
    required this.targets,
  });

  @override
  Widget build(BuildContext context) {
    final targetKcal = _num(targets?['target_kcal']);
    final protein = _num(targets?['protein_g']);
    final karb = _num(targets?['karb_g']);
    final yag = _num(targets?['yag_g']);

    final dobText = dogumTarihi == null
        ? 'Seç'
        : '${dogumTarihi!.year.toString().padLeft(4, '0')}-'
            '${dogumTarihi!.month.toString().padLeft(2, '0')}-'
            '${dogumTarihi!.day.toString().padLeft(2, '0')}';

    final methodKey = _resolveMethodKey(targets);
    final methodInfo = _methodInfoText(methodKey);

    return _PremiumCardSurface(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardSectionHeader(
            title: 'Kalori ve Makro Hedefleri',
            subtitle: 'Profil bilgilerine göre hedefler otomatik hesaplanır.',
            icon: Icons.local_fire_department_rounded,
            accent: const Color(0xFF4F7CFF),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PremiumDropdownField<String>(
                  label: 'Cinsiyet',
                  value: cinsiyet,
                  items: const [
                    DropdownMenuItem(value: 'erkek', child: Text('Erkek')),
                    DropdownMenuItem(value: 'kadin', child: Text('Kadın')),
                  ],
                  onChanged: onCinsiyetChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DatePickerField(
                  label: 'Doğum Tarihi',
                  value: dobText,
                  onTap: onPickDob,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _PremiumDropdownField<String>(
            label: 'Aktivite Seviyesi',
            value: aktivite,
            items: const [
              DropdownMenuItem(value: 'sedanter', child: Text('Sedanter')),
              DropdownMenuItem(value: 'hafif', child: Text('Hafif Aktif')),
              DropdownMenuItem(value: 'orta', child: Text('Orta Aktif')),
              DropdownMenuItem(value: 'yuksek', child: Text('Yüksek Aktif')),
              DropdownMenuItem(value: 'cok_yuksek', child: Text('Çok Yüksek Aktif')),
            ],
            onChanged: onAktiviteChanged,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _PremiumDropdownField<String>(
                  label: 'Kilo Hedefi',
                  value: kiloHedefi,
                  items: const [
                    DropdownMenuItem(value: 'kilo_ver', child: Text('Kilo Ver')),
                    DropdownMenuItem(value: 'koru', child: Text('Koru')),
                    DropdownMenuItem(value: 'kilo_al', child: Text('Kilo Al')),
                  ],
                  onChanged: onKiloHedefiChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PremiumDropdownField<String>(
                  label: 'Hedef Tempo',
                  value: hedefTempo,
                  items: const [
                    DropdownMenuItem(value: 'yavas', child: Text('Yavaş')),
                    DropdownMenuItem(value: 'orta', child: Text('Orta')),
                    DropdownMenuItem(value: 'hizli', child: Text('Hızlı')),
                  ],
                  onChanged: onHedefTempoChanged,
                ),
              ),
            ],
          ),
          if (targets != null) ...[
            const SizedBox(height: 14),
            Container(
              height: 1,
              color: const Color(0xFFE8EEF7),
            ),
            const SizedBox(height: 14),
            _HeroTargetTile(
              icon: Icons.local_fire_department_rounded,
              label: 'Günlük Hedef Kalori',
              value: targetKcal == null ? '-' : '${targetKcal.round()}',
              suffix: 'kcal',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MacroTargetTile(
                    icon: Icons.fitness_center_rounded,
                    label: 'Protein',
                    value: protein == null ? '-' : '${protein.round()}',
                    suffix: 'g',
                    accent: const Color(0xFFFF7A18),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MacroTargetTile(
                    icon: Icons.grain_rounded,
                    label: 'Karb',
                    value: karb == null ? '-' : '${karb.round()}',
                    suffix: 'g',
                    accent: const Color(0xFF4F7CFF),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MacroTargetTile(
                    icon: Icons.opacity_rounded,
                    label: 'Yağ',
                    value: yag == null ? '-' : '${yag.round()}',
                    suffix: 'g',
                    accent: const Color(0xFF14B86A),
                  ),
                ),
              ],
            ),
            if (methodInfo != null) ...[
              const SizedBox(height: 10),
              _InfoPill(text: methodInfo),
            ],
          ],
        ],
      ),
    );
  }

  String? _resolveMethodKey(Map<String, dynamic>? t) {
    if (t == null) return null;

    const keys = <String>[
      'calc_method',
      'bmr_method',
      'formula',
      'method',
      'tdee_method',
      'bodyfat_method',
    ];

    for (final k in keys) {
      final v = t[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isEmpty) continue;
      return s;
    }
    return null;
  }

  String? _methodInfoText(String? methodKey) {
    if (methodKey == null) return null;

    final m = methodKey.toLowerCase();

    if (m.contains('katch') || m.contains('mcardle') || m.contains('lbm')) {
      return 'Hedefler, yağsız vücut kütlesini esas alan Katch–McArdle yöntemiyle hesaplandı. Bu yaklaşım yağ oranı bazlı daha kişisel sonuç verir.';
    }

    if (m.contains('mifflin') || m.contains('stjeor') || m.contains('st_jeor')) {
      return 'Hedefler, yaş-kilo-boy ve cinsiyete dayalı Mifflin–St Jeor denklemiyle hesaplandı. Aktivite seviyenle çarpılarak günlük hedefe çevrilir.';
    }

    if (m.contains('harris')) {
      return 'Hedefler, klasik Harris–Benedict denklemiyle hesaplandı. Aktivite seviyene göre günlük enerji ihtiyacı belirlenir.';
    }

    if (m.contains('navy') || m.contains('us_navy') || m.contains('bodyfat')) {
      return 'Yağ oranı, bel-boyun ve gerekli durumlarda basen ölçülerini kullanan U.S. Navy formülüyle tahmin edildi.';
    }

    return 'Hedefler, profil bilgileriniz esas alınarak sistem tarafından otomatik hesaplandı.';
  }

  double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}

class _SaveButton extends StatelessWidget {
  final bool saving;
  final VoidCallback? onPressed;

  const _SaveButton({
    required this.saving,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F7CFF).withValues(alpha: 0.22),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FilledButton.icon(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF4F7CFF),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          icon: saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_rounded),
          label: Text(
            saving ? 'Kaydediliyor...' : 'Profili Kaydet',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _PremiumTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        color: isDark ? AppColors.darkText : AppColors.lightText,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: isDark ? AppColors.darkSurface2 : const Color(0xFFFBFDFF),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFE8EEF7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFE8EEF7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF4F7CFF), width: 1.4),
        ),
      ),
    );
  }
}

class _PremiumDropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _PremiumDropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: isDark ? AppColors.darkSurface2 : const Color(0xFFFBFDFF),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFE8EEF7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFE8EEF7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF4F7CFF), width: 1.4),
        ),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final String value;
  final Future<void> Function() onTap;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: isDark ? AppColors.darkSurface2 : const Color(0xFFFBFDFF),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFE8EEF7)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFE8EEF7)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(
              Icons.calendar_today_rounded,
              size: 18,
              color: Color(0xFF4F7CFF),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;

  const _CardSectionHeader({
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
          child: Icon(icon, size: 22, color: accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkText : AppColors.lightText,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextSub : AppColors.lightTextSub,
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

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  final IconData icon;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.accent,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EEF7)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent),
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
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkText : AppColors.lightText,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                  height: 1.1,
                ),
          ),
        ],
      ),
    );
  }
}

class _HeroTargetTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String suffix;

  const _HeroTargetTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFEEF4FF),
            Color(0xFFF7FAFF),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE7FB)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF4F7CFF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: Color(0xFF4F7CFF),
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
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
                      value,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkText : AppColors.lightText,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.7,
                            height: 1,
                          ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        suffix,
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
          Icon(icon, color: const Color(0xFF4F7CFF).withValues(alpha: 0.55)),
        ],
      ),
    );
  }
}

class _MacroTargetTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String suffix;
  final Color accent;

  const _MacroTargetTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.suffix,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EEF7)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent),
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
          const SizedBox(height: 6),
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
                        height: 1,
                        letterSpacing: -0.3,
                      ),
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  suffix,
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

class _InfoPill extends StatelessWidget {
  final String text;

  const _InfoPill({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7FD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3ECF8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Color(0xFF4F7CFF),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF4B5563),
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactInfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color accent;

  const _ContactInfoChip({
    required this.icon,
    required this.text,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                    color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkText : AppColors.lightText,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
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

class _MiniPill extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;

  const _MiniPill({
    required this.text,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              height: 1,
            ),
          ),
        ],
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

class _SheetActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accent;
  final VoidCallback onTap;

  const _SheetActionTile({
    required this.icon,
    required this.title,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Icon(icon, color: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkText : AppColors.lightText,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: accent),
            ],
          ),
        ),
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
                  color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkText : AppColors.lightText,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextSub : AppColors.lightTextSub,
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
                ? Colors.black.withValues(alpha: 0.28)
                : AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}