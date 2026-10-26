import '../core/profiles/presets.dart';
import 'models.dart';

/// Réglages de l'utilisateur (entité User, section 9). Synchronisés dans la
/// table privée `user_settings`.
class UserSettings {
  const UserSettings({
    // Avant le test de confort: sépia doux, jamais de blanc pur.
    this.activeProfileId = Presets.a2Id,
    this.rescueProfileId = Presets.a2Id,
    this.locale,
    this.onboardingDone = false,
    this.consentAt,
    this.autoNight = false,
    this.dayProfileId,
    this.nightProfileId,
    this.nightStartHour = 20,
    this.nightEndHour = 7,
    this.eveningWarmth = false,
    this.pauseReminder = false,
    this.fingerDrawing = true,
    this.modifiedAt,
  });

  final String activeProfileId;

  /// Profil par défaut rétabli par le geste de secours (triple toucher).
  /// Toujours un profil prédéfini, donc toujours lisible.
  final String rescueProfileId;

  /// 'fr' ou 'en'; null = langue du système.
  final String? locale;
  final bool onboardingDone;

  /// Acceptation du message médical et de la politique de confidentialité.
  final DateTime? consentAt;

  /// Profil automatique selon l'heure (mode nuit, version 2).
  final bool autoNight;
  final String? dayProfileId;
  final String? nightProfileId;
  final int nightStartHour;
  final int nightEndHour;

  /// Filtre chaud progressif en fin de journée (mode pause visuelle).
  final bool eveningWarmth;

  /// Rappels 20-20-20.
  final bool pauseReminder;

  /// Dessiner au doigt (sinon: stylet/souris dessinent, doigt défile).
  final bool fingerDrawing;
  final DateTime? modifiedAt;

  UserSettings copyWith({
    String? activeProfileId,
    String? rescueProfileId,
    String? locale,
    bool clearLocale = false,
    bool? onboardingDone,
    DateTime? consentAt,
    bool? autoNight,
    String? dayProfileId,
    String? nightProfileId,
    int? nightStartHour,
    int? nightEndHour,
    bool? eveningWarmth,
    bool? pauseReminder,
    bool? fingerDrawing,
  }) =>
      UserSettings(
        activeProfileId: activeProfileId ?? this.activeProfileId,
        rescueProfileId: rescueProfileId ?? this.rescueProfileId,
        locale: clearLocale ? null : (locale ?? this.locale),
        onboardingDone: onboardingDone ?? this.onboardingDone,
        consentAt: consentAt ?? this.consentAt,
        autoNight: autoNight ?? this.autoNight,
        dayProfileId: dayProfileId ?? this.dayProfileId,
        nightProfileId: nightProfileId ?? this.nightProfileId,
        nightStartHour: nightStartHour ?? this.nightStartHour,
        nightEndHour: nightEndHour ?? this.nightEndHour,
        eveningWarmth: eveningWarmth ?? this.eveningWarmth,
        pauseReminder: pauseReminder ?? this.pauseReminder,
        fingerDrawing: fingerDrawing ?? this.fingerDrawing,
        modifiedAt: nowUtc(),
      );

  Map<String, dynamic> toRow() => {
        'active_profile_id': activeProfileId,
        'rescue_profile_id': rescueProfileId,
        'locale': locale,
        'consent_at': consentAt == null ? null : timeToJson(consentAt!),
        'prefs': {
          'onboardingDone': onboardingDone,
          'autoNight': autoNight,
          'dayProfileId': dayProfileId,
          'nightProfileId': nightProfileId,
          'nightStartHour': nightStartHour,
          'nightEndHour': nightEndHour,
          'eveningWarmth': eveningWarmth,
          'pauseReminder': pauseReminder,
          'fingerDrawing': fingerDrawing,
        },
        'modified_at': timeToJson(modifiedAt ?? nowUtc()),
      };

  factory UserSettings.fromRow(Map r) {
    final p = (r['prefs'] as Map?) ?? const {};
    return UserSettings(
      activeProfileId: (r['active_profile_id'] as String?) ?? Presets.a2Id,
      rescueProfileId: (r['rescue_profile_id'] as String?) ?? Presets.a2Id,
      locale: r['locale'] as String?,
      consentAt: r['consent_at'] == null ? null : parseTime(r['consent_at']),
      onboardingDone: p['onboardingDone'] == true,
      autoNight: p['autoNight'] == true,
      dayProfileId: p['dayProfileId'] as String?,
      nightProfileId: p['nightProfileId'] as String?,
      nightStartHour: (p['nightStartHour'] as num?)?.toInt() ?? 20,
      nightEndHour: (p['nightEndHour'] as num?)?.toInt() ?? 7,
      eveningWarmth: p['eveningWarmth'] == true,
      pauseReminder: p['pauseReminder'] == true,
      fingerDrawing: p['fingerDrawing'] != false,
      modifiedAt: r['modified_at'] == null ? null : parseTime(r['modified_at']),
    );
  }
}
