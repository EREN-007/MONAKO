import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @ok.
  ///
  /// In fr, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @apply.
  ///
  /// In fr, this message translates to:
  /// **'Appliquer'**
  String get apply;

  /// No description provided for @save.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get delete;

  /// No description provided for @close.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get close;

  /// No description provided for @back.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get back;

  /// No description provided for @next.
  ///
  /// In fr, this message translates to:
  /// **'Suivant'**
  String get next;

  /// No description provided for @add.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get add;

  /// No description provided for @edit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get edit;

  /// No description provided for @rename.
  ///
  /// In fr, this message translates to:
  /// **'Renommer'**
  String get rename;

  /// No description provided for @name.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get name;

  /// No description provided for @keep.
  ///
  /// In fr, this message translates to:
  /// **'Garder'**
  String get keep;

  /// No description provided for @or.
  ///
  /// In fr, this message translates to:
  /// **'ou'**
  String get or;

  /// No description provided for @selected.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionné'**
  String get selected;

  /// No description provided for @share.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get share;

  /// No description provided for @settings.
  ///
  /// In fr, this message translates to:
  /// **'Réglages'**
  String get settings;

  /// No description provided for @about.
  ///
  /// In fr, this message translates to:
  /// **'À propos'**
  String get about;

  /// No description provided for @language.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get language;

  /// No description provided for @systemLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue du système'**
  String get systemLanguage;

  /// No description provided for @errorGeneric.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue : {error}'**
  String errorGeneric(String error);

  /// No description provided for @moreActions.
  ///
  /// In fr, this message translates to:
  /// **'Plus d’actions'**
  String get moreActions;

  /// No description provided for @welcomeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue dans Monako'**
  String get welcomeTitle;

  /// No description provided for @welcomeBody.
  ///
  /// In fr, this message translates to:
  /// **'Vos notes s’affichent dans les couleurs qui reposent vos yeux. Le fichier ne change jamais : chacun voit la même note dans ses propres couleurs.'**
  String get welcomeBody;

  /// No description provided for @medicalNoticeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Message important'**
  String get medicalNoticeTitle;

  /// No description provided for @medicalNotice.
  ///
  /// In fr, this message translates to:
  /// **'Cet outil améliore le confort de lecture. Il ne remplace pas un examen de la vue et ne soigne aucune maladie.'**
  String get medicalNotice;

  /// No description provided for @medicalAdvice.
  ///
  /// In fr, this message translates to:
  /// **'En cas de douleur ou de baisse de vision soudaine, consultez rapidement un professionnel de la vue (optométriste ou ophtalmologiste).'**
  String get medicalAdvice;

  /// No description provided for @privacyNoticeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Votre vie privée'**
  String get privacyNoticeTitle;

  /// No description provided for @privacySummary.
  ///
  /// In fr, this message translates to:
  /// **'Vos réglages d’affichage peuvent révéler un besoin de santé : ils restent privés dans votre compte, chiffrés, et ne sont jamais partagés avec de la publicité. On ne vous demande jamais le nom d’une maladie.'**
  String get privacySummary;

  /// No description provided for @readPrivacyPolicy.
  ///
  /// In fr, this message translates to:
  /// **'Lire la politique de confidentialité'**
  String get readPrivacyPolicy;

  /// No description provided for @consentLabel.
  ///
  /// In fr, this message translates to:
  /// **'J’ai lu ces messages et j’accepte la politique de confidentialité.'**
  String get consentLabel;

  /// No description provided for @stepOf.
  ///
  /// In fr, this message translates to:
  /// **'Étape {current} sur {total}'**
  String stepOf(int current, int total);

  /// No description provided for @q1Title.
  ///
  /// In fr, this message translates to:
  /// **'La lumière blanche de l’écran vous gêne-t-elle ?'**
  String get q1Title;

  /// No description provided for @q1Hurts.
  ///
  /// In fr, this message translates to:
  /// **'Oui, la lumière me fait mal ou m’éblouit'**
  String get q1Hurts;

  /// No description provided for @q1Sometimes.
  ///
  /// In fr, this message translates to:
  /// **'Parfois, surtout le soir ou après un moment'**
  String get q1Sometimes;

  /// No description provided for @q1Fine.
  ///
  /// In fr, this message translates to:
  /// **'Non, la lumière ne me gêne pas'**
  String get q1Fine;

  /// No description provided for @q2Title.
  ///
  /// In fr, this message translates to:
  /// **'Qu’est-ce qui rend la lecture difficile ?'**
  String get q2Title;

  /// No description provided for @q2Help.
  ///
  /// In fr, this message translates to:
  /// **'Cochez tout ce qui s’applique, ou rien.'**
  String get q2Help;

  /// No description provided for @symptomBlends.
  ///
  /// In fr, this message translates to:
  /// **'Le texte se fond dans le fond'**
  String get symptomBlends;

  /// No description provided for @symptomColors.
  ///
  /// In fr, this message translates to:
  /// **'Je confonds des couleurs'**
  String get symptomColors;

  /// No description provided for @symptomBlurry.
  ///
  /// In fr, this message translates to:
  /// **'Le texte est flou ou fait des halos'**
  String get symptomBlurry;

  /// No description provided for @symptomField.
  ///
  /// In fr, this message translates to:
  /// **'Je vois mal au centre ou sur les côtés'**
  String get symptomField;

  /// No description provided for @q3Title.
  ///
  /// In fr, this message translates to:
  /// **'Quand étudiez-vous le plus ?'**
  String get q3Title;

  /// No description provided for @q3Day.
  ///
  /// In fr, this message translates to:
  /// **'Le jour'**
  String get q3Day;

  /// No description provided for @q3Evening.
  ///
  /// In fr, this message translates to:
  /// **'Le soir ou la nuit'**
  String get q3Evening;

  /// No description provided for @q3Both.
  ///
  /// In fr, this message translates to:
  /// **'Les deux'**
  String get q3Both;

  /// No description provided for @chooseTitle.
  ///
  /// In fr, this message translates to:
  /// **'Quel affichage vous soulage ?'**
  String get chooseTitle;

  /// No description provided for @chooseHelp.
  ///
  /// In fr, this message translates to:
  /// **'Lisez quelques secondes chaque exemple, puis gardez celui qui vous soulage le plus.'**
  String get chooseHelp;

  /// No description provided for @keepThisProfile.
  ///
  /// In fr, this message translates to:
  /// **'Garder ce profil'**
  String get keepThisProfile;

  /// No description provided for @changeLaterHint.
  ///
  /// In fr, this message translates to:
  /// **'Vous pourrez changer de profil à tout moment, en moins de 2 secondes, avec la pastille profil.'**
  String get changeLaterHint;

  /// No description provided for @needA.
  ///
  /// In fr, this message translates to:
  /// **'Sensibilité à la lumière'**
  String get needA;

  /// No description provided for @needB.
  ///
  /// In fr, this message translates to:
  /// **'Faible contraste'**
  String get needB;

  /// No description provided for @needC.
  ///
  /// In fr, this message translates to:
  /// **'Couleurs'**
  String get needC;

  /// No description provided for @needD.
  ///
  /// In fr, this message translates to:
  /// **'Vision réduite'**
  String get needD;

  /// No description provided for @needE.
  ///
  /// In fr, this message translates to:
  /// **'Flou et distorsion'**
  String get needE;

  /// No description provided for @needNone.
  ///
  /// In fr, this message translates to:
  /// **'Affichage standard'**
  String get needNone;

  /// No description provided for @presetStandard.
  ///
  /// In fr, this message translates to:
  /// **'Standard (noir sur blanc)'**
  String get presetStandard;

  /// No description provided for @presetA1.
  ///
  /// In fr, this message translates to:
  /// **'Lumière, sombre'**
  String get presetA1;

  /// No description provided for @presetA2.
  ///
  /// In fr, this message translates to:
  /// **'Lumière, sépia doux'**
  String get presetA2;

  /// No description provided for @presetB.
  ///
  /// In fr, this message translates to:
  /// **'Faible contraste'**
  String get presetB;

  /// No description provided for @presetC.
  ///
  /// In fr, this message translates to:
  /// **'Couleurs'**
  String get presetC;

  /// No description provided for @presetD.
  ///
  /// In fr, this message translates to:
  /// **'Vision réduite'**
  String get presetD;

  /// No description provided for @presetE.
  ///
  /// In fr, this message translates to:
  /// **'Flou et distorsion'**
  String get presetE;

  /// No description provided for @profilesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Profils enregistrés'**
  String get profilesTitle;

  /// No description provided for @visualProfiles.
  ///
  /// In fr, this message translates to:
  /// **'Profils visuels'**
  String get visualProfiles;

  /// No description provided for @presetProfiles.
  ///
  /// In fr, this message translates to:
  /// **'Profils prédéfinis'**
  String get presetProfiles;

  /// No description provided for @myProfiles.
  ///
  /// In fr, this message translates to:
  /// **'Mes profils'**
  String get myProfiles;

  /// No description provided for @manageProfiles.
  ///
  /// In fr, this message translates to:
  /// **'Gérer les profils'**
  String get manageProfiles;

  /// No description provided for @changeProfile.
  ///
  /// In fr, this message translates to:
  /// **'Changer de profil'**
  String get changeProfile;

  /// No description provided for @profilePillSemantics.
  ///
  /// In fr, this message translates to:
  /// **'Profil d’affichage : {name}. Toucher pour changer.'**
  String profilePillSemantics(String name);

  /// No description provided for @linkProfileToNotebook.
  ///
  /// In fr, this message translates to:
  /// **'Imposer ce profil à ce cahier'**
  String get linkProfileToNotebook;

  /// No description provided for @linkProfileToNotebookHelp.
  ///
  /// In fr, this message translates to:
  /// **'Le cahier s’ouvrira toujours avec ce profil.'**
  String get linkProfileToNotebookHelp;

  /// No description provided for @quickAdjust.
  ///
  /// In fr, this message translates to:
  /// **'Réglages rapides'**
  String get quickAdjust;

  /// No description provided for @backgroundBrightness.
  ///
  /// In fr, this message translates to:
  /// **'Luminosité du fond'**
  String get backgroundBrightness;

  /// No description provided for @contrast.
  ///
  /// In fr, this message translates to:
  /// **'Contraste'**
  String get contrast;

  /// No description provided for @textSizeValue.
  ///
  /// In fr, this message translates to:
  /// **'Taille du texte : {size} pt'**
  String textSizeValue(int size);

  /// No description provided for @profileTiresMe.
  ///
  /// In fr, this message translates to:
  /// **'Ce profil me fatigue'**
  String get profileTiresMe;

  /// No description provided for @profileTiresMeHelp.
  ///
  /// In fr, this message translates to:
  /// **'Proposer un réglage plus doux'**
  String get profileTiresMeHelp;

  /// No description provided for @softerPreviewText.
  ///
  /// In fr, this message translates to:
  /// **'Voici un réglage plus doux (moins de contraste, teinte plus chaude). Le garder ?'**
  String get softerPreviewText;

  /// No description provided for @softerName.
  ///
  /// In fr, this message translates to:
  /// **'{name} (doux)'**
  String softerName(String name);

  /// No description provided for @adjustedName.
  ///
  /// In fr, this message translates to:
  /// **'{name} (ajusté)'**
  String adjustedName(String name);

  /// No description provided for @rescueApplied.
  ///
  /// In fr, this message translates to:
  /// **'Profil de secours rétabli : {name}'**
  String rescueApplied(String name);

  /// No description provided for @rescueProfile.
  ///
  /// In fr, this message translates to:
  /// **'Profil de secours'**
  String get rescueProfile;

  /// No description provided for @useRescueProfile.
  ///
  /// In fr, this message translates to:
  /// **'Revenir au profil de secours (ou triple toucher)'**
  String get useRescueProfile;

  /// No description provided for @rescueProfileHelp.
  ///
  /// In fr, this message translates to:
  /// **'Rétabli par un triple toucher n’importe où, si un réglage rend la page illisible.'**
  String get rescueProfileHelp;

  /// No description provided for @contrastOk.
  ///
  /// In fr, this message translates to:
  /// **'dans la plage'**
  String get contrastOk;

  /// No description provided for @contrastTooLow.
  ///
  /// In fr, this message translates to:
  /// **'contraste trop faible'**
  String get contrastTooLow;

  /// No description provided for @contrastTooHigh.
  ///
  /// In fr, this message translates to:
  /// **'contraste trop élevé'**
  String get contrastTooHigh;

  /// No description provided for @contrastSemantics.
  ///
  /// In fr, this message translates to:
  /// **'Contraste {ratio}, {status}'**
  String contrastSemantics(String ratio, String status);

  /// No description provided for @combineNeeds.
  ///
  /// In fr, this message translates to:
  /// **'Combiner des besoins'**
  String get combineNeeds;

  /// No description provided for @combineHelp.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez 2 profils ou plus (par exemple Lumière + Couleurs). Le fond vient du profil Lumière, les teintes du profil Couleurs.'**
  String get combineHelp;

  /// No description provided for @combineCount.
  ///
  /// In fr, this message translates to:
  /// **'Combiner ({count})'**
  String combineCount(int count);

  /// No description provided for @fusionConflictTitle.
  ///
  /// In fr, this message translates to:
  /// **'Réglages contradictoires'**
  String get fusionConflictTitle;

  /// No description provided for @conflictCappedByLight.
  ///
  /// In fr, this message translates to:
  /// **'Le besoin « faible contraste » demande plus de contraste que ce que tolère la sensibilité à la lumière. Le réglage le plus sûr pour vos yeux (plage de la lumière) est retenu.'**
  String get conflictCappedByLight;

  /// No description provided for @conflictNoOverlap.
  ///
  /// In fr, this message translates to:
  /// **'Ces besoins n’ont pas de plage de contraste commune. Le réglage le plus doux est retenu.'**
  String get conflictNoOverlap;

  /// No description provided for @conflictBackground.
  ///
  /// In fr, this message translates to:
  /// **'Un profil a un fond clair et l’autre un fond sombre. Le fond du profil Lumière (ou du premier) est retenu.'**
  String get conflictBackground;

  /// No description provided for @useSafest.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser le réglage le plus sûr'**
  String get useSafest;

  /// No description provided for @newProfile.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau profil'**
  String get newProfile;

  /// No description provided for @customizeCopy.
  ///
  /// In fr, this message translates to:
  /// **'Personnaliser (copie)'**
  String get customizeCopy;

  /// No description provided for @exportProfile.
  ///
  /// In fr, this message translates to:
  /// **'Exporter le profil (JSON)'**
  String get exportProfile;

  /// No description provided for @exportForOptometrist.
  ///
  /// In fr, this message translates to:
  /// **'Fiche pour l’optométriste (PDF)'**
  String get exportForOptometrist;

  /// No description provided for @importProfile.
  ///
  /// In fr, this message translates to:
  /// **'Importer un profil'**
  String get importProfile;

  /// No description provided for @profileImported.
  ///
  /// In fr, this message translates to:
  /// **'Profil importé : {name}'**
  String profileImported(String name);

  /// No description provided for @profileOptions.
  ///
  /// In fr, this message translates to:
  /// **'Options du profil {name}'**
  String profileOptions(String name);

  /// No description provided for @profileSheetTitle.
  ///
  /// In fr, this message translates to:
  /// **'Profil visuel Monako'**
  String get profileSheetTitle;

  /// No description provided for @needsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Besoins'**
  String get needsLabel;

  /// No description provided for @contrastRangeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Plage de contraste'**
  String get contrastRangeLabel;

  /// No description provided for @roleColumn.
  ///
  /// In fr, this message translates to:
  /// **'Rôle'**
  String get roleColumn;

  /// No description provided for @colorColumn.
  ///
  /// In fr, this message translates to:
  /// **'Couleur'**
  String get colorColumn;

  /// No description provided for @ratioColumn.
  ///
  /// In fr, this message translates to:
  /// **'Contraste sur le fond'**
  String get ratioColumn;

  /// No description provided for @filtersLabel.
  ///
  /// In fr, this message translates to:
  /// **'Filtres'**
  String get filtersLabel;

  /// No description provided for @strokeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Trait'**
  String get strokeLabel;

  /// No description provided for @profileSettings.
  ///
  /// In fr, this message translates to:
  /// **'Réglages du profil'**
  String get profileSettings;

  /// No description provided for @profileName.
  ///
  /// In fr, this message translates to:
  /// **'Nom du profil'**
  String get profileName;

  /// No description provided for @myProfile.
  ///
  /// In fr, this message translates to:
  /// **'Mon profil'**
  String get myProfile;

  /// No description provided for @displayNeeds.
  ///
  /// In fr, this message translates to:
  /// **'Besoins d’affichage'**
  String get displayNeeds;

  /// No description provided for @targetRange.
  ///
  /// In fr, this message translates to:
  /// **'Contraste visé : {range}'**
  String targetRange(String range);

  /// No description provided for @rangeConflict.
  ///
  /// In fr, this message translates to:
  /// **'Besoins contradictoires : la plage la plus sûre est retenue ({range}).'**
  String rangeConflict(String range);

  /// No description provided for @fixAutomatically.
  ///
  /// In fr, this message translates to:
  /// **'Corriger automatiquement'**
  String get fixAutomatically;

  /// No description provided for @fixAutomaticallyCount.
  ///
  /// In fr, this message translates to:
  /// **'Corriger automatiquement ({count} hors plage)'**
  String fixAutomaticallyCount(int count);

  /// No description provided for @outOfRangeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Contraste hors plage'**
  String get outOfRangeTitle;

  /// No description provided for @outOfRangeText.
  ///
  /// In fr, this message translates to:
  /// **'Ces couleurs sortent de la plage {range} : {roles}.'**
  String outOfRangeText(String roles, String range);

  /// No description provided for @saveAnyway.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer quand même'**
  String get saveAnyway;

  /// No description provided for @previewEverywhere.
  ///
  /// In fr, this message translates to:
  /// **'Aperçu dans toute l’app'**
  String get previewEverywhere;

  /// No description provided for @colors.
  ///
  /// In fr, this message translates to:
  /// **'Couleurs'**
  String get colors;

  /// No description provided for @filters.
  ///
  /// In fr, this message translates to:
  /// **'Filtres'**
  String get filters;

  /// No description provided for @warmTint.
  ///
  /// In fr, this message translates to:
  /// **'Teinte chaude'**
  String get warmTint;

  /// No description provided for @pdfBrightnessCap.
  ///
  /// In fr, this message translates to:
  /// **'Plafond de luminosité des PDF'**
  String get pdfBrightnessCap;

  /// No description provided for @glareReduction.
  ///
  /// In fr, this message translates to:
  /// **'Atténuation de l’éblouissement'**
  String get glareReduction;

  /// No description provided for @haloReduction.
  ///
  /// In fr, this message translates to:
  /// **'Halo réduit'**
  String get haloReduction;

  /// No description provided for @textSettings.
  ///
  /// In fr, this message translates to:
  /// **'Texte'**
  String get textSettings;

  /// No description provided for @fontSystem.
  ///
  /// In fr, this message translates to:
  /// **'Système'**
  String get fontSystem;

  /// No description provided for @fontLegible.
  ///
  /// In fr, this message translates to:
  /// **'Lisible'**
  String get fontLegible;

  /// No description provided for @fontDyslexic.
  ///
  /// In fr, this message translates to:
  /// **'Dyslexie'**
  String get fontDyslexic;

  /// No description provided for @lineHeightValue.
  ///
  /// In fr, this message translates to:
  /// **'Interligne : {value}'**
  String lineHeightValue(String value);

  /// No description provided for @wordSpacing.
  ///
  /// In fr, this message translates to:
  /// **'Espace entre les mots'**
  String get wordSpacing;

  /// No description provided for @defaultZoomValue.
  ///
  /// In fr, this message translates to:
  /// **'Zoom par défaut : {value} %'**
  String defaultZoomValue(int value);

  /// No description provided for @strokeSettings.
  ///
  /// In fr, this message translates to:
  /// **'Traits'**
  String get strokeSettings;

  /// No description provided for @strokeWidthValue.
  ///
  /// In fr, this message translates to:
  /// **'Épaisseur du trait : {value} %'**
  String strokeWidthValue(int value);

  /// No description provided for @highlightOpacity.
  ///
  /// In fr, this message translates to:
  /// **'Opacité des surlignages'**
  String get highlightOpacity;

  /// No description provided for @rolePatterns.
  ///
  /// In fr, this message translates to:
  /// **'Motifs en plus de la couleur'**
  String get rolePatterns;

  /// No description provided for @rolePatternsHelp.
  ///
  /// In fr, this message translates to:
  /// **'Pointillés et tirets pour distinguer les encres sans la couleur.'**
  String get rolePatternsHelp;

  /// No description provided for @simplifiedUi.
  ///
  /// In fr, this message translates to:
  /// **'Interface simplifiée'**
  String get simplifiedUi;

  /// No description provided for @roleHelp.
  ///
  /// In fr, this message translates to:
  /// **'Chaque rôle est enregistré dans vos notes ; seule sa couleur change d’un profil à l’autre.'**
  String get roleHelp;

  /// No description provided for @lightness.
  ///
  /// In fr, this message translates to:
  /// **'Luminosité'**
  String get lightness;

  /// No description provided for @saturation.
  ///
  /// In fr, this message translates to:
  /// **'Saturation'**
  String get saturation;

  /// No description provided for @hue.
  ///
  /// In fr, this message translates to:
  /// **'Teinte'**
  String get hue;

  /// No description provided for @hexCode.
  ///
  /// In fr, this message translates to:
  /// **'Code hexadécimal'**
  String get hexCode;

  /// No description provided for @sampleWord.
  ///
  /// In fr, this message translates to:
  /// **'Exemple'**
  String get sampleWord;

  /// No description provided for @rolePaper.
  ///
  /// In fr, this message translates to:
  /// **'Fond de la page'**
  String get rolePaper;

  /// No description provided for @rolePaperLine.
  ///
  /// In fr, this message translates to:
  /// **'Lignes et quadrillage'**
  String get rolePaperLine;

  /// No description provided for @roleInkPrimary.
  ///
  /// In fr, this message translates to:
  /// **'Encre principale'**
  String get roleInkPrimary;

  /// No description provided for @roleInkSecondary.
  ///
  /// In fr, this message translates to:
  /// **'Encre secondaire'**
  String get roleInkSecondary;

  /// No description provided for @roleAccent.
  ///
  /// In fr, this message translates to:
  /// **'Encre d’accent {n}'**
  String roleAccent(int n);

  /// No description provided for @roleHighlight.
  ///
  /// In fr, this message translates to:
  /// **'Surligneur {n}'**
  String roleHighlight(int n);

  /// No description provided for @roleHeading.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get roleHeading;

  /// No description provided for @sampleHeading.
  ///
  /// In fr, this message translates to:
  /// **'Chapitre 3 — La cellule'**
  String get sampleHeading;

  /// No description provided for @sampleBody1.
  ///
  /// In fr, this message translates to:
  /// **'La membrane protège la cellule et contrôle '**
  String get sampleBody1;

  /// No description provided for @sampleHighlighted.
  ///
  /// In fr, this message translates to:
  /// **'ce qui entre et sort'**
  String get sampleHighlighted;

  /// No description provided for @sampleBody2.
  ///
  /// In fr, this message translates to:
  /// **'. Le noyau contient l’ADN.'**
  String get sampleBody2;

  /// No description provided for @sampleAccent1.
  ///
  /// In fr, this message translates to:
  /// **'À retenir'**
  String get sampleAccent1;

  /// No description provided for @sampleAccent2.
  ///
  /// In fr, this message translates to:
  /// **'Définition'**
  String get sampleAccent2;

  /// No description provided for @sampleAccent3.
  ///
  /// In fr, this message translates to:
  /// **'Exemple'**
  String get sampleAccent3;

  /// No description provided for @sampleMargin.
  ///
  /// In fr, this message translates to:
  /// **'Note en marge : relire pour l’examen.'**
  String get sampleMargin;

  /// No description provided for @samplePreviewSemantics.
  ///
  /// In fr, this message translates to:
  /// **'Aperçu d’une note dans ce profil'**
  String get samplePreviewSemantics;

  /// No description provided for @searchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un cahier ou du texte'**
  String get searchHint;

  /// No description provided for @clearSearch.
  ///
  /// In fr, this message translates to:
  /// **'Effacer la recherche'**
  String get clearSearch;

  /// No description provided for @allNotebooks.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get allNotebooks;

  /// No description provided for @folderOptions.
  ///
  /// In fr, this message translates to:
  /// **'Options du dossier'**
  String get folderOptions;

  /// No description provided for @newNotebook.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau cahier'**
  String get newNotebook;

  /// No description provided for @untitledNotebook.
  ///
  /// In fr, this message translates to:
  /// **'Cahier sans titre'**
  String get untitledNotebook;

  /// No description provided for @newFolder.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau dossier'**
  String get newFolder;

  /// No description provided for @importPdfOrImage.
  ///
  /// In fr, this message translates to:
  /// **'Importer un PDF ou une image'**
  String get importPdfOrImage;

  /// No description provided for @emptyLibrary.
  ///
  /// In fr, this message translates to:
  /// **'Créez votre premier cahier ou importez un cours en PDF.'**
  String get emptyLibrary;

  /// No description provided for @noResults.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat.'**
  String get noResults;

  /// No description provided for @deleteFolder.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le dossier'**
  String get deleteFolder;

  /// No description provided for @deleteFolderHelp.
  ///
  /// In fr, this message translates to:
  /// **'Les cahiers ne sont pas supprimés.'**
  String get deleteFolderHelp;

  /// No description provided for @notebookOptions.
  ///
  /// In fr, this message translates to:
  /// **'Options du cahier'**
  String get notebookOptions;

  /// No description provided for @moveToFolder.
  ///
  /// In fr, this message translates to:
  /// **'Déplacer vers un dossier'**
  String get moveToFolder;

  /// No description provided for @noFolder.
  ///
  /// In fr, this message translates to:
  /// **'Aucun dossier'**
  String get noFolder;

  /// No description provided for @coverColor.
  ///
  /// In fr, this message translates to:
  /// **'Couleur de couverture'**
  String get coverColor;

  /// No description provided for @deleteNotebook.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le cahier'**
  String get deleteNotebook;

  /// No description provided for @deleteNotebookConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer « {title} » sur tous vos appareils ?'**
  String deleteNotebookConfirm(String title);

  /// No description provided for @notebookSemantics.
  ///
  /// In fr, this message translates to:
  /// **'Cahier {title}, {pages} pages, modifié le {date}'**
  String notebookSemantics(String title, int pages, String date);

  /// No description provided for @notebookMissing.
  ///
  /// In fr, this message translates to:
  /// **'Ce cahier n’existe plus.'**
  String get notebookMissing;

  /// No description provided for @importing.
  ///
  /// In fr, this message translates to:
  /// **'Import de {name}…'**
  String importing(String name);

  /// No description provided for @importDone.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 page importée} other{{count} pages importées}}'**
  String importDone(int count);

  /// No description provided for @importFailed.
  ///
  /// In fr, this message translates to:
  /// **'Import impossible : {error}'**
  String importFailed(String error);

  /// No description provided for @syncLocalOnly.
  ///
  /// In fr, this message translates to:
  /// **'Mode local : sauvegarde sur cet appareil'**
  String get syncLocalOnly;

  /// No description provided for @syncSignedOut.
  ///
  /// In fr, this message translates to:
  /// **'Non connecté : sauvegarde locale seulement'**
  String get syncSignedOut;

  /// No description provided for @syncDone.
  ///
  /// In fr, this message translates to:
  /// **'Synchronisé'**
  String get syncDone;

  /// No description provided for @syncRunning.
  ///
  /// In fr, this message translates to:
  /// **'Synchronisation…'**
  String get syncRunning;

  /// No description provided for @syncOffline.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne : les changements seront envoyés plus tard'**
  String get syncOffline;

  /// No description provided for @syncError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de synchronisation : {error}'**
  String syncError(String error);

  /// No description provided for @undo.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get undo;

  /// No description provided for @redo.
  ///
  /// In fr, this message translates to:
  /// **'Rétablir'**
  String get redo;

  /// No description provided for @toolPen.
  ///
  /// In fr, this message translates to:
  /// **'Stylet'**
  String get toolPen;

  /// No description provided for @toolHighlighter.
  ///
  /// In fr, this message translates to:
  /// **'Surligneur'**
  String get toolHighlighter;

  /// No description provided for @toolText.
  ///
  /// In fr, this message translates to:
  /// **'Texte'**
  String get toolText;

  /// No description provided for @toolEraser.
  ///
  /// In fr, this message translates to:
  /// **'Gomme'**
  String get toolEraser;

  /// No description provided for @toolSelect.
  ///
  /// In fr, this message translates to:
  /// **'Sélection'**
  String get toolSelect;

  /// No description provided for @toolHand.
  ///
  /// In fr, this message translates to:
  /// **'Déplacer la vue'**
  String get toolHand;

  /// No description provided for @widthFine.
  ///
  /// In fr, this message translates to:
  /// **'Trait fin'**
  String get widthFine;

  /// No description provided for @widthMedium.
  ///
  /// In fr, this message translates to:
  /// **'Trait moyen'**
  String get widthMedium;

  /// No description provided for @widthThick.
  ///
  /// In fr, this message translates to:
  /// **'Trait épais'**
  String get widthThick;

  /// No description provided for @selectHint.
  ///
  /// In fr, this message translates to:
  /// **'Tracez un rectangle autour des éléments.'**
  String get selectHint;

  /// No description provided for @deleteSelection.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la sélection'**
  String get deleteSelection;

  /// No description provided for @eraserHint.
  ///
  /// In fr, this message translates to:
  /// **'Glissez sur un trait pour l’effacer.'**
  String get eraserHint;

  /// No description provided for @handHint.
  ///
  /// In fr, this message translates to:
  /// **'Glissez pour déplacer, pincez pour zoomer.'**
  String get handHint;

  /// No description provided for @pageOf.
  ///
  /// In fr, this message translates to:
  /// **'Page {current} / {total}'**
  String pageOf(int current, int total);

  /// No description provided for @pageSemantics.
  ///
  /// In fr, this message translates to:
  /// **'Page {current} sur {total}'**
  String pageSemantics(int current, int total);

  /// No description provided for @previousPage.
  ///
  /// In fr, this message translates to:
  /// **'Page précédente'**
  String get previousPage;

  /// No description provided for @nextPage.
  ///
  /// In fr, this message translates to:
  /// **'Page suivante'**
  String get nextPage;

  /// No description provided for @addPage.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une page'**
  String get addPage;

  /// No description provided for @deletePage.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la page'**
  String get deletePage;

  /// No description provided for @deletePageConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer cette page et ses annotations ?'**
  String get deletePageConfirm;

  /// No description provided for @pageTemplate.
  ///
  /// In fr, this message translates to:
  /// **'Gabarit de page'**
  String get pageTemplate;

  /// No description provided for @templateBlank.
  ///
  /// In fr, this message translates to:
  /// **'Blanc'**
  String get templateBlank;

  /// No description provided for @templateLined.
  ///
  /// In fr, this message translates to:
  /// **'Ligné'**
  String get templateLined;

  /// No description provided for @templateGrid.
  ///
  /// In fr, this message translates to:
  /// **'Quadrillé'**
  String get templateGrid;

  /// No description provided for @templateDotted.
  ///
  /// In fr, this message translates to:
  /// **'Pointillé'**
  String get templateDotted;

  /// No description provided for @exportNormal.
  ///
  /// In fr, this message translates to:
  /// **'Exporter en PDF normal (noir sur blanc)'**
  String get exportNormal;

  /// No description provided for @exportInProfile.
  ///
  /// In fr, this message translates to:
  /// **'Exporter en PDF dans mon profil'**
  String get exportInProfile;

  /// No description provided for @shareNotebook.
  ///
  /// In fr, this message translates to:
  /// **'Partager le cahier'**
  String get shareNotebook;

  /// No description provided for @readAloud.
  ///
  /// In fr, this message translates to:
  /// **'Lire à voix haute'**
  String get readAloud;

  /// No description provided for @stopReading.
  ///
  /// In fr, this message translates to:
  /// **'Arrêter la lecture'**
  String get stopReading;

  /// No description provided for @recognizeText.
  ///
  /// In fr, this message translates to:
  /// **'Reconnaître le texte (OCR)'**
  String get recognizeText;

  /// No description provided for @showRecognizedText.
  ///
  /// In fr, this message translates to:
  /// **'Afficher le texte reconnu'**
  String get showRecognizedText;

  /// No description provided for @showOriginal.
  ///
  /// In fr, this message translates to:
  /// **'Voir l’original'**
  String get showOriginal;

  /// No description provided for @documentFilter.
  ///
  /// In fr, this message translates to:
  /// **'Filtre du document'**
  String get documentFilter;

  /// No description provided for @importIntoNotebook.
  ///
  /// In fr, this message translates to:
  /// **'Importer un PDF ou une image ici'**
  String get importIntoNotebook;

  /// No description provided for @assetUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Fichier pas encore disponible sur cet appareil.'**
  String get assetUnavailable;

  /// No description provided for @ocrRunning.
  ///
  /// In fr, this message translates to:
  /// **'Reconnaissance du texte…'**
  String get ocrRunning;

  /// No description provided for @ocrFailed.
  ///
  /// In fr, this message translates to:
  /// **'Texte illisible : la page garde le filtre de couleur seulement.'**
  String get ocrFailed;

  /// No description provided for @ocrDone.
  ///
  /// In fr, this message translates to:
  /// **'Texte reconnu : il est maintenant recherchable et lisible à voix haute.'**
  String get ocrDone;

  /// No description provided for @addText.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter du texte'**
  String get addText;

  /// No description provided for @editText.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le texte'**
  String get editText;

  /// No description provided for @textLabel.
  ///
  /// In fr, this message translates to:
  /// **'Texte'**
  String get textLabel;

  /// No description provided for @dictate.
  ///
  /// In fr, this message translates to:
  /// **'Dicter'**
  String get dictate;

  /// No description provided for @stopDictation.
  ///
  /// In fr, this message translates to:
  /// **'Arrêter la dictée'**
  String get stopDictation;

  /// No description provided for @dictationUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Dictée vocale indisponible sur cet appareil.'**
  String get dictationUnavailable;

  /// No description provided for @recolorMode.
  ///
  /// In fr, this message translates to:
  /// **'Recoloration'**
  String get recolorMode;

  /// No description provided for @recolorFull.
  ///
  /// In fr, this message translates to:
  /// **'Complète'**
  String get recolorFull;

  /// No description provided for @recolorBackground.
  ///
  /// In fr, this message translates to:
  /// **'Fond seulement'**
  String get recolorBackground;

  /// No description provided for @recolorOff.
  ///
  /// In fr, this message translates to:
  /// **'Désactivée'**
  String get recolorOff;

  /// No description provided for @brightnessCapAuto.
  ///
  /// In fr, this message translates to:
  /// **'Plafond de luminosité du profil'**
  String get brightnessCapAuto;

  /// No description provided for @brightnessCapValue.
  ///
  /// In fr, this message translates to:
  /// **'Plafond de luminosité : {value} %'**
  String brightnessCapValue(int value);

  /// No description provided for @imagesTreatment.
  ///
  /// In fr, this message translates to:
  /// **'Images et schémas'**
  String get imagesTreatment;

  /// No description provided for @imagesIntact.
  ///
  /// In fr, this message translates to:
  /// **'Intactes'**
  String get imagesIntact;

  /// No description provided for @imagesDimmed.
  ///
  /// In fr, this message translates to:
  /// **'Atténuées'**
  String get imagesDimmed;

  /// No description provided for @imagesRecolored.
  ///
  /// In fr, this message translates to:
  /// **'Recolorées'**
  String get imagesRecolored;

  /// No description provided for @textContrastAuto.
  ///
  /// In fr, this message translates to:
  /// **'Contraste du texte automatique'**
  String get textContrastAuto;

  /// No description provided for @originalNeverModified.
  ///
  /// In fr, this message translates to:
  /// **'Le fichier original n’est jamais modifié : seul l’affichage change.'**
  String get originalNeverModified;

  /// No description provided for @shareExplanation.
  ///
  /// In fr, this message translates to:
  /// **'Votre camarade verra ce cahier dans ses propres couleurs. Votre profil visuel n’est jamais partagé.'**
  String get shareExplanation;

  /// No description provided for @email.
  ///
  /// In fr, this message translates to:
  /// **'Courriel'**
  String get email;

  /// No description provided for @permissionRead.
  ///
  /// In fr, this message translates to:
  /// **'Lecture'**
  String get permissionRead;

  /// No description provided for @permissionEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modification'**
  String get permissionEdit;

  /// No description provided for @removeAccess.
  ///
  /// In fr, this message translates to:
  /// **'Retirer l’accès'**
  String get removeAccess;

  /// No description provided for @shareUserNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun compte Monako avec ce courriel.'**
  String get shareUserNotFound;

  /// No description provided for @account.
  ///
  /// In fr, this message translates to:
  /// **'Compte'**
  String get account;

  /// No description provided for @accountWhy.
  ///
  /// In fr, this message translates to:
  /// **'Un compte synchronise vos notes et vos profils entre vos appareils. Sans compte, tout reste sur cet appareil.'**
  String get accountWhy;

  /// No description provided for @signInWithApple.
  ///
  /// In fr, this message translates to:
  /// **'Continuer avec Apple'**
  String get signInWithApple;

  /// No description provided for @password.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get password;

  /// No description provided for @passwordHelp.
  ///
  /// In fr, this message translates to:
  /// **'Au moins 8 caractères.'**
  String get passwordHelp;

  /// No description provided for @signIn.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get signIn;

  /// No description provided for @createAccount.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte'**
  String get createAccount;

  /// No description provided for @haveAccount.
  ///
  /// In fr, this message translates to:
  /// **'J’ai déjà un compte'**
  String get haveAccount;

  /// No description provided for @noAccount.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de compte ? Créer un compte'**
  String get noAccount;

  /// No description provided for @sendMagicLink.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir un lien de connexion'**
  String get sendMagicLink;

  /// No description provided for @magicLinkSent.
  ///
  /// In fr, this message translates to:
  /// **'Lien envoyé : ouvrez votre courriel sur cet appareil.'**
  String get magicLinkSent;

  /// No description provided for @forgotPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié'**
  String get forgotPassword;

  /// No description provided for @resetSent.
  ///
  /// In fr, this message translates to:
  /// **'Courriel de réinitialisation envoyé.'**
  String get resetSent;

  /// No description provided for @checkEmailConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez votre courriel pour confirmer votre compte.'**
  String get checkEmailConfirm;

  /// No description provided for @continueWithoutAccount.
  ///
  /// In fr, this message translates to:
  /// **'Continuer sans compte'**
  String get continueWithoutAccount;

  /// No description provided for @signOut.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get signOut;

  /// No description provided for @signOutHelp.
  ///
  /// In fr, this message translates to:
  /// **'Vos notes restent dans votre compte et sont retirées de cet appareil.'**
  String get signOutHelp;

  /// No description provided for @neverSynced.
  ///
  /// In fr, this message translates to:
  /// **'Jamais synchronisé'**
  String get neverSynced;

  /// No description provided for @lastSynced.
  ///
  /// In fr, this message translates to:
  /// **'Dernière synchronisation : {time}'**
  String lastSynced(String time);

  /// No description provided for @syncNow.
  ///
  /// In fr, this message translates to:
  /// **'Synchroniser maintenant'**
  String get syncNow;

  /// No description provided for @localModeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mode local'**
  String get localModeTitle;

  /// No description provided for @localModeHelp.
  ///
  /// In fr, this message translates to:
  /// **'Cette version n’est pas reliée à un serveur : vos notes sont sauvegardées sur cet appareil.'**
  String get localModeHelp;

  /// No description provided for @exportMyData.
  ///
  /// In fr, this message translates to:
  /// **'Exporter mes données'**
  String get exportMyData;

  /// No description provided for @exportMyDataHelp.
  ///
  /// In fr, this message translates to:
  /// **'Notes, profils et réglages dans un fichier JSON.'**
  String get exportMyDataHelp;

  /// No description provided for @deleteAccount.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer mon compte'**
  String get deleteAccount;

  /// No description provided for @deleteAccountHelp.
  ///
  /// In fr, this message translates to:
  /// **'Efface immédiatement vos notes, profils et fichiers.'**
  String get deleteAccountHelp;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Cette action efface définitivement toutes vos notes, vos profils et vos fichiers, sur tous vos appareils.'**
  String get deleteAccountConfirm;

  /// No description provided for @deleteWord.
  ///
  /// In fr, this message translates to:
  /// **'SUPPRIMER'**
  String get deleteWord;

  /// No description provided for @typeDelete.
  ///
  /// In fr, this message translates to:
  /// **'Tapez SUPPRIMER pour confirmer'**
  String get typeDelete;

  /// No description provided for @accountDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Compte supprimé.'**
  String get accountDeleted;

  /// No description provided for @redoComfortTest.
  ///
  /// In fr, this message translates to:
  /// **'Refaire le test de confort'**
  String get redoComfortTest;

  /// No description provided for @automaticModes.
  ///
  /// In fr, this message translates to:
  /// **'Modes automatiques'**
  String get automaticModes;

  /// No description provided for @autoNight.
  ///
  /// In fr, this message translates to:
  /// **'Profil de nuit automatique'**
  String get autoNight;

  /// No description provided for @autoNightHelp.
  ///
  /// In fr, this message translates to:
  /// **'De {start} h à {end} h'**
  String autoNightHelp(int start, int end);

  /// No description provided for @nightProfile.
  ///
  /// In fr, this message translates to:
  /// **'Profil de nuit'**
  String get nightProfile;

  /// No description provided for @nightHours.
  ///
  /// In fr, this message translates to:
  /// **'Heures de nuit'**
  String get nightHours;

  /// No description provided for @nightStart.
  ///
  /// In fr, this message translates to:
  /// **'Début'**
  String get nightStart;

  /// No description provided for @nightEnd.
  ///
  /// In fr, this message translates to:
  /// **'Fin'**
  String get nightEnd;

  /// No description provided for @eveningWarmth.
  ///
  /// In fr, this message translates to:
  /// **'Filtre chaud en fin de journée'**
  String get eveningWarmth;

  /// No description provided for @eveningWarmthHelp.
  ///
  /// In fr, this message translates to:
  /// **'La teinte se réchauffe progressivement de 18 h à 22 h.'**
  String get eveningWarmthHelp;

  /// No description provided for @pauseReminder.
  ///
  /// In fr, this message translates to:
  /// **'Pauses visuelles 20-20-20'**
  String get pauseReminder;

  /// No description provided for @pauseReminderHelp.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les 20 minutes, un rappel discret.'**
  String get pauseReminderHelp;

  /// No description provided for @pauseReminderText.
  ///
  /// In fr, this message translates to:
  /// **'Pause visuelle : regardez au loin (6 m) pendant 20 secondes.'**
  String get pauseReminderText;

  /// No description provided for @writing.
  ///
  /// In fr, this message translates to:
  /// **'Écriture'**
  String get writing;

  /// No description provided for @fingerDrawing.
  ///
  /// In fr, this message translates to:
  /// **'Écrire avec le doigt'**
  String get fingerDrawing;

  /// No description provided for @fingerDrawingHelp.
  ///
  /// In fr, this message translates to:
  /// **'Désactivé : seul le stylet écrit, le doigt fait défiler.'**
  String get fingerDrawingHelp;

  /// No description provided for @privacyPolicyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Politique de confidentialité'**
  String get privacyPolicyTitle;

  /// No description provided for @accessibilityTitle.
  ///
  /// In fr, this message translates to:
  /// **'Déclaration d’accessibilité'**
  String get accessibilityTitle;

  /// No description provided for @privacyPolicyText.
  ///
  /// In fr, this message translates to:
  /// **'Politique de confidentialité de Monako (langage simple)\n\n1. Ce que nous recueillons\n• Votre courriel, si vous créez un compte.\n• Vos notes (traits, textes, surlignages) et les PDF ou images que vous importez.\n• Vos profils visuels (couleurs, tailles, filtres) et vos réglages.\nNous ne vous demandons jamais le nom d’une maladie. Nous ne recueillons aucune donnée publicitaire et n’utilisons aucun outil de suivi.\n\n2. Pourquoi\nUniquement pour afficher vos notes dans vos couleurs et les synchroniser entre vos appareils.\n\n3. Données sensibles\nUn profil visuel peut révéler un besoin de santé. Il est donc :\n• stocké dans votre compte privé, accessible à vous seul (même quand vous partagez un cahier, votre profil n’est jamais partagé) ;\n• chiffré pendant le transfert (HTTPS) et au repos (serveur et appareil) ;\n• jamais vendu, jamais partagé avec de la publicité.\nLa reconnaissance de texte (OCR) se fait sur votre appareil.\n\n4. Hébergement\nLes données sont hébergées par Supabase (base de données Postgres, stockage de fichiers et authentification).\n\n5. Vos droits\n• Exporter toutes vos données (Réglages › Exporter mes données).\n• Supprimer votre compte : vos notes, profils et fichiers sont effacés immédiatement (au plus tard en 30 jours dans les sauvegardes).\n• Vous déconnecter : les données sont retirées de l’appareil.\n\n6. Élèves mineurs\nSi vous avez moins de 14 ans (Québec) ou si votre école l’exige, un parent ou tuteur doit consentir à la création du compte.\n\n7. Cadre légal\nLoi sur la protection des renseignements personnels et les documents électroniques (LPRPDE) et, au Québec, Loi 25. Pour toute question : contactez le responsable de la protection des renseignements personnels indiqué dans la fiche de l’app.'**
  String get privacyPolicyText;

  /// No description provided for @accessibilityText.
  ///
  /// In fr, this message translates to:
  /// **'Déclaration d’accessibilité\n\nMonako vise la conformité aux Règles pour l’accessibilité des contenus Web (WCAG) 2.2, niveau AA, pour toute son interface.\n\nCe que l’app offre :\n• Toute l’interface est recolorée par votre profil : jamais de blanc ni de noir purs imposés.\n• Cibles tactiles d’au moins 44 pt / 48 dp.\n• Compatibilité VoiceOver (iOS) et TalkBack (Android) : chaque bouton a un nom.\n• Respect de la taille de texte du système.\n• Aucun clignotement ; fondus de 200 ms au maximum.\n• Aucune information portée par la couleur seule : chaque encre a un numéro, un motif ou une icône.\n• Interface en français et en anglais.\n• Geste de secours : un triple toucher rétablit un profil lisible.\n\nLimites connues :\n• Un PDF scanné de mauvaise qualité sans texte reconnu n’a que le filtre de couleur.\n• Les graphiques avec légendes colorées peuvent perdre en sens après recoloration : utilisez « Voir l’original ».\n\nSignaler un problème : écrivez-nous depuis la fiche de l’app. Nous répondons dans un délai de 10 jours ouvrables.'**
  String get accessibilityText;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
