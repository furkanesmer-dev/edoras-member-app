class Targets {
  final int targetKcal;
  final int proteinG;
  final int carbG;
  final int fatG;
  final String? formula;
  final int? bmr;
  final int? tdee;
  final bool? isManualOverride;

  Targets({
    required this.targetKcal,
    required this.proteinG,
    required this.carbG,
    required this.fatG,
    this.formula,
    this.bmr,
    this.tdee,
    this.isManualOverride,
  });

  factory Targets.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) => v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);

    return Targets(
      targetKcal: asInt(json['target_kcal']),
      proteinG: asInt(json['protein_g']),
      carbG: asInt(json['karb_g']),
      fatG: asInt(json['yag_g']),
      formula: json['formula']?.toString(),
      bmr: json['bmr'] == null ? null : asInt(json['bmr']),
      tdee: json['tdee'] == null ? null : asInt(json['tdee']),
      isManualOverride: json['is_manual_override'] == null
          ? null
          : (json['is_manual_override'].toString() == '1'),
    );
  }
}

class MemberProfile {
  final int id;
  final String? ad;
  final String? soyad;
  final String? eposta;
  final String? tel;
  final String? fotoYolu;

  final double? kiloKg;
  final double? boyCm;
  final double? belCevresi;
  final double? basenCevresi;
  final double? boyunCevresi;
  final double? yagOrani;
  final double? vki;
  final String? vkiDurum;

  final String? cinsiyet; // 'erkek'|'kadin'
  final String? dogumTarihi; // 'YYYY-MM-DD'
  final String? aktiviteSeviyesi; // sedanter/hafif/orta/yuksek/cok_yuksek
  final String? kiloHedefi; // kilo_ver/koru/kilo_al
  final String? hedefTempo; // yavas/orta/hizli

  final String? sporHedefi;
  final String? sporDeneyimi;
  final int? yas;
  final String? saglikSorunlari;

  MemberProfile({
    required this.id,
    this.ad,
    this.soyad,
    this.eposta,
    this.tel,
    this.fotoYolu,
    this.kiloKg,
    this.boyCm,
    this.belCevresi,
    this.basenCevresi,
    this.boyunCevresi,
    this.yagOrani,
    this.vki,
    this.vkiDurum,
    this.cinsiyet,
    this.dogumTarihi,
    this.aktiviteSeviyesi,
    this.kiloHedefi,
    this.hedefTempo,
    this.sporHedefi,
    this.sporDeneyimi,
    this.yas,
    this.saglikSorunlari,
  });

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.'));
  }

  factory MemberProfile.fromJson(Map<String, dynamic> json) {
    return MemberProfile(
      id: (json['id'] as num?)?.toInt() ?? 0,
      ad: json['ad']?.toString(),
      soyad: json['soyad']?.toString(),
      eposta: json['eposta_adresi']?.toString(),
      tel: json['tel_no']?.toString(),
      fotoYolu: json['foto_yolu']?.toString(),
      kiloKg: MemberProfile._asDouble(json['kilo_kg']),
      boyCm: MemberProfile._asDouble(json['boy_cm']),
      belCevresi: MemberProfile._asDouble(json['bel_cevresi']),
      basenCevresi: MemberProfile._asDouble(json['basen_cevresi']),
      boyunCevresi: MemberProfile._asDouble(json['boyun_cevresi']),
      yagOrani: MemberProfile._asDouble(json['yag_orani']),
      vki: MemberProfile._asDouble(json['vucut_kitle_indeksi']),
      vkiDurum: json['vki_durum']?.toString(),
      cinsiyet: json['cinsiyet']?.toString(),
      dogumTarihi: json['dogum_tarihi']?.toString(),
      aktiviteSeviyesi: json['aktivite_seviyesi']?.toString(),
      kiloHedefi: json['kilo_hedefi']?.toString(),
      hedefTempo: json['hedef_tempo']?.toString(),
      sporHedefi: json['spor_hedefi']?.toString(),
      sporDeneyimi: json['spor_deneyimi']?.toString(),
      yas: json['yas'] == null ? null : int.tryParse(json['yas'].toString()),
      saglikSorunlari: json['saglik_sorunlari']?.toString(),
    );
  }

  bool get isOnboardingComplete {
    // “En mantıklı minimum”: Mifflin + TDEE + hedef için gerekenler
    return (cinsiyet?.isNotEmpty ?? false) &&
        (dogumTarihi?.isNotEmpty ?? false || (yas != null && yas! > 0)) &&
        (boyCm != null && boyCm! > 0) &&
        (kiloKg != null && kiloKg! > 0) &&
        (aktiviteSeviyesi?.isNotEmpty ?? false) &&
        (kiloHedefi?.isNotEmpty ?? false) &&
        (hedefTempo?.isNotEmpty ?? false);
  }
}

class ProfileMeResponse {
  final MemberProfile profile;
  final Map<String, dynamic> subscription;
  final Targets? targets;

  ProfileMeResponse({
    required this.profile,
    required this.subscription,
    required this.targets,
  });

  factory ProfileMeResponse.fromJson(Map<String, dynamic> json) {
    final profileRaw = json['profile'];
    if (profileRaw is! Map) throw Exception('profile verisi eksik veya geçersiz');
    final profile = MemberProfile.fromJson(Map<String, dynamic>.from(profileRaw));

    final subRaw = json['subscription'];
    final subscription = (subRaw is Map) ? Map<String, dynamic>.from(subRaw) : <String, dynamic>{};

    final targetsJson = json['targets'];
    final targets = (targetsJson is Map)
        ? Targets.fromJson(Map<String, dynamic>.from(targetsJson))
        : null;

    return ProfileMeResponse(
      profile: profile,
      subscription: subscription,
      targets: targets,
    );
  }
}