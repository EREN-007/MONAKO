// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Annuler';

  @override
  String get apply => 'Appliquer';

  @override
  String get save => 'Enregistrer';

  @override
  String get delete => 'Supprimer';

  @override
  String get close => 'Fermer';

  @override
  String get back => 'Retour';

  @override
  String get next => 'Suivant';

  @override
  String get add => 'Ajouter';

  @override
  String get edit => 'Modifier';

  @override
  String get rename => 'Renommer';

  @override
  String get name => 'Nom';

  @override
  String get keep => 'Garder';

  @override
  String get or => 'ou';

  @override
  String get selected => 'Sélectionné';

  @override
  String get share => 'Partager';

  @override
  String get settings => 'Réglages';

  @override
  String get about => 'À propos';

  @override
  String get language => 'Langue';

  @override
  String get systemLanguage => 'Langue du système';

  @override
  String errorGeneric(String error) {
    return 'Une erreur est survenue : $error';
  }

  @override
  String get moreActions => 'Plus d’actions';

  @override
  String get welcomeTitle => 'Bienvenue dans Monako';

  @override
  String get welcomeBody =>
      'Vos notes s’affichent dans les couleurs qui reposent vos yeux. Le fichier ne change jamais : chacun voit la même note dans ses propres couleurs.';

  @override
  String get medicalNoticeTitle => 'Message important';

  @override
  String get medicalNotice =>
      'Cet outil améliore le confort de lecture. Il ne remplace pas un examen de la vue et ne soigne aucune maladie.';

  @override
  String get medicalAdvice =>
      'En cas de douleur ou de baisse de vision soudaine, consultez rapidement un professionnel de la vue (optométriste ou ophtalmologiste).';

  @override
  String get privacyNoticeTitle => 'Votre vie privée';

  @override
  String get privacySummary =>
      'Vos réglages d’affichage peuvent révéler un besoin de santé : ils restent privés dans votre compte, chiffrés, et ne sont jamais partagés avec de la publicité. On ne vous demande jamais le nom d’une maladie.';

  @override
  String get readPrivacyPolicy => 'Lire la politique de confidentialité';

  @override
  String get consentLabel =>
      'J’ai lu ces messages et j’accepte la politique de confidentialité.';

  @override
  String stepOf(int current, int total) {
    return 'Étape $current sur $total';
  }

  @override
  String get q1Title => 'La lumière blanche de l’écran vous gêne-t-elle ?';

  @override
  String get q1Hurts => 'Oui, la lumière me fait mal ou m’éblouit';

  @override
  String get q1Sometimes => 'Parfois, surtout le soir ou après un moment';

  @override
  String get q1Fine => 'Non, la lumière ne me gêne pas';

  @override
  String get q2Title => 'Qu’est-ce qui rend la lecture difficile ?';

  @override
  String get q2Help => 'Cochez tout ce qui s’applique, ou rien.';

  @override
  String get symptomBlends => 'Le texte se fond dans le fond';

  @override
  String get symptomColors => 'Je confonds des couleurs';

  @override
  String get symptomBlurry => 'Le texte est flou ou fait des halos';

  @override
  String get symptomField => 'Je vois mal au centre ou sur les côtés';

  @override
  String get q3Title => 'Quand étudiez-vous le plus ?';

  @override
  String get q3Day => 'Le jour';

  @override
  String get q3Evening => 'Le soir ou la nuit';

  @override
  String get q3Both => 'Les deux';

  @override
  String get chooseTitle => 'Quel affichage vous soulage ?';

  @override
  String get chooseHelp =>
      'Lisez quelques secondes chaque exemple, puis gardez celui qui vous soulage le plus.';

  @override
  String get keepThisProfile => 'Garder ce profil';

  @override
  String get changeLaterHint =>
      'Vous pourrez changer de profil à tout moment, en moins de 2 secondes, avec la pastille profil.';

  @override
  String get needA => 'Sensibilité à la lumière';

  @override
  String get needB => 'Faible contraste';

  @override
  String get needC => 'Couleurs';

  @override
  String get needD => 'Vision réduite';

  @override
  String get needE => 'Flou et distorsion';

  @override
  String get needNone => 'Affichage standard';

  @override
  String get presetStandard => 'Standard (noir sur blanc)';

  @override
  String get presetA1 => 'Lumière, sombre';

  @override
  String get presetA2 => 'Lumière, sépia doux';

  @override
  String get presetB => 'Faible contraste';

  @override
  String get presetC => 'Couleurs';

  @override
  String get presetD => 'Vision réduite';

  @override
  String get presetE => 'Flou et distorsion';

  @override
  String get profilesTitle => 'Profils enregistrés';

  @override
  String get visualProfiles => 'Profils visuels';

  @override
  String get presetProfiles => 'Profils prédéfinis';

  @override
  String get myProfiles => 'Mes profils';

  @override
  String get manageProfiles => 'Gérer les profils';

  @override
  String get changeProfile => 'Changer de profil';

  @override
  String profilePillSemantics(String name) {
    return 'Profil d’affichage : $name. Toucher pour changer.';
  }

  @override
  String get linkProfileToNotebook => 'Imposer ce profil à ce cahier';

  @override
  String get linkProfileToNotebookHelp =>
      'Le cahier s’ouvrira toujours avec ce profil.';

  @override
  String get quickAdjust => 'Réglages rapides';

  @override
  String get backgroundBrightness => 'Luminosité du fond';

  @override
  String get contrast => 'Contraste';

  @override
  String textSizeValue(int size) {
    return 'Taille du texte : $size pt';
  }

  @override
  String get profileTiresMe => 'Ce profil me fatigue';

  @override
  String get profileTiresMeHelp => 'Proposer un réglage plus doux';

  @override
  String get softerPreviewText =>
      'Voici un réglage plus doux (moins de contraste, teinte plus chaude). Le garder ?';

  @override
  String softerName(String name) {
    return '$name (doux)';
  }

  @override
  String adjustedName(String name) {
    return '$name (ajusté)';
  }

  @override
  String rescueApplied(String name) {
    return 'Profil de secours rétabli : $name';
  }

  @override
  String get rescueProfile => 'Profil de secours';

  @override
  String get useRescueProfile =>
      'Revenir au profil de secours (ou triple toucher)';

  @override
  String get rescueProfileHelp =>
      'Rétabli par un triple toucher n’importe où, si un réglage rend la page illisible.';

  @override
  String get contrastOk => 'dans la plage';

  @override
  String get contrastTooLow => 'contraste trop faible';

  @override
  String get contrastTooHigh => 'contraste trop élevé';

  @override
  String contrastSemantics(String ratio, String status) {
    return 'Contraste $ratio, $status';
  }

  @override
  String get combineNeeds => 'Combiner des besoins';

  @override
  String get combineHelp =>
      'Choisissez 2 profils ou plus (par exemple Lumière + Couleurs). Le fond vient du profil Lumière, les teintes du profil Couleurs.';

  @override
  String combineCount(int count) {
    return 'Combiner ($count)';
  }

  @override
  String get fusionConflictTitle => 'Réglages contradictoires';

  @override
  String get conflictCappedByLight =>
      'Le besoin « faible contraste » demande plus de contraste que ce que tolère la sensibilité à la lumière. Le réglage le plus sûr pour vos yeux (plage de la lumière) est retenu.';

  @override
  String get conflictNoOverlap =>
      'Ces besoins n’ont pas de plage de contraste commune. Le réglage le plus doux est retenu.';

  @override
  String get conflictBackground =>
      'Un profil a un fond clair et l’autre un fond sombre. Le fond du profil Lumière (ou du premier) est retenu.';

  @override
  String get useSafest => 'Utiliser le réglage le plus sûr';

  @override
  String get newProfile => 'Nouveau profil';

  @override
  String get customizeCopy => 'Personnaliser (copie)';

  @override
  String get exportProfile => 'Exporter le profil (JSON)';

  @override
  String get exportForOptometrist => 'Fiche pour l’optométriste (PDF)';

  @override
  String get importProfile => 'Importer un profil';

  @override
  String profileImported(String name) {
    return 'Profil importé : $name';
  }

  @override
  String profileOptions(String name) {
    return 'Options du profil $name';
  }

  @override
  String get profileSheetTitle => 'Profil visuel Monako';

  @override
  String get needsLabel => 'Besoins';

  @override
  String get contrastRangeLabel => 'Plage de contraste';

  @override
  String get roleColumn => 'Rôle';

  @override
  String get colorColumn => 'Couleur';

  @override
  String get ratioColumn => 'Contraste sur le fond';

  @override
  String get filtersLabel => 'Filtres';

  @override
  String get strokeLabel => 'Trait';

  @override
  String get profileSettings => 'Réglages du profil';

  @override
  String get profileName => 'Nom du profil';

  @override
  String get myProfile => 'Mon profil';

  @override
  String get displayNeeds => 'Besoins d’affichage';

  @override
  String targetRange(String range) {
    return 'Contraste visé : $range';
  }

  @override
  String rangeConflict(String range) {
    return 'Besoins contradictoires : la plage la plus sûre est retenue ($range).';
  }

  @override
  String get fixAutomatically => 'Corriger automatiquement';

  @override
  String fixAutomaticallyCount(int count) {
    return 'Corriger automatiquement ($count hors plage)';
  }

  @override
  String get outOfRangeTitle => 'Contraste hors plage';

  @override
  String outOfRangeText(String roles, String range) {
    return 'Ces couleurs sortent de la plage $range : $roles.';
  }

  @override
  String get saveAnyway => 'Enregistrer quand même';

  @override
  String get previewEverywhere => 'Aperçu dans toute l’app';

  @override
  String get colors => 'Couleurs';

  @override
  String get filters => 'Filtres';

  @override
  String get warmTint => 'Teinte chaude';

  @override
  String get pdfBrightnessCap => 'Plafond de luminosité des PDF';

  @override
  String get glareReduction => 'Atténuation de l’éblouissement';

  @override
  String get haloReduction => 'Halo réduit';

  @override
  String get textSettings => 'Texte';

  @override
  String get fontSystem => 'Système';

  @override
  String get fontLegible => 'Lisible';

  @override
  String get fontDyslexic => 'Dyslexie';

  @override
  String lineHeightValue(String value) {
    return 'Interligne : $value';
  }

  @override
  String get wordSpacing => 'Espace entre les mots';

  @override
  String defaultZoomValue(int value) {
    return 'Zoom par défaut : $value %';
  }

  @override
  String get strokeSettings => 'Traits';

  @override
  String strokeWidthValue(int value) {
    return 'Épaisseur du trait : $value %';
  }

  @override
  String get highlightOpacity => 'Opacité des surlignages';

  @override
  String get rolePatterns => 'Motifs en plus de la couleur';

  @override
  String get rolePatternsHelp =>
      'Pointillés et tirets pour distinguer les encres sans la couleur.';

  @override
  String get simplifiedUi => 'Interface simplifiée';

  @override
  String get roleHelp =>
      'Chaque rôle est enregistré dans vos notes ; seule sa couleur change d’un profil à l’autre.';

  @override
  String get lightness => 'Luminosité';

  @override
  String get saturation => 'Saturation';

  @override
  String get hue => 'Teinte';

  @override
  String get hexCode => 'Code hexadécimal';

  @override
  String get sampleWord => 'Exemple';

  @override
  String get rolePaper => 'Fond de la page';

  @override
  String get rolePaperLine => 'Lignes et quadrillage';

  @override
  String get roleInkPrimary => 'Encre principale';

  @override
  String get roleInkSecondary => 'Encre secondaire';

  @override
  String roleAccent(int n) {
    return 'Encre d’accent $n';
  }

  @override
  String roleHighlight(int n) {
    return 'Surligneur $n';
  }

  @override
  String get roleHeading => 'Titre';

  @override
  String get sampleHeading => 'Chapitre 3 — La cellule';

  @override
  String get sampleBody1 => 'La membrane protège la cellule et contrôle ';

  @override
  String get sampleHighlighted => 'ce qui entre et sort';

  @override
  String get sampleBody2 => '. Le noyau contient l’ADN.';

  @override
  String get sampleAccent1 => 'À retenir';

  @override
  String get sampleAccent2 => 'Définition';

  @override
  String get sampleAccent3 => 'Exemple';

  @override
  String get sampleMargin => 'Note en marge : relire pour l’examen.';

  @override
  String get samplePreviewSemantics => 'Aperçu d’une note dans ce profil';

  @override
  String get searchHint => 'Rechercher un cahier ou du texte';

  @override
  String get clearSearch => 'Effacer la recherche';

  @override
  String get allNotebooks => 'Tous';

  @override
  String get folderOptions => 'Options du dossier';

  @override
  String get newNotebook => 'Nouveau cahier';

  @override
  String get untitledNotebook => 'Cahier sans titre';

  @override
  String get newFolder => 'Nouveau dossier';

  @override
  String get importPdfOrImage => 'Importer un PDF ou une image';

  @override
  String get emptyLibrary =>
      'Créez votre premier cahier ou importez un cours en PDF.';

  @override
  String get noResults => 'Aucun résultat.';

  @override
  String get deleteFolder => 'Supprimer le dossier';

  @override
  String get deleteFolderHelp => 'Les cahiers ne sont pas supprimés.';

  @override
  String get notebookOptions => 'Options du cahier';

  @override
  String get moveToFolder => 'Déplacer vers un dossier';

  @override
  String get noFolder => 'Aucun dossier';

  @override
  String get coverColor => 'Couleur de couverture';

  @override
  String get deleteNotebook => 'Supprimer le cahier';

  @override
  String deleteNotebookConfirm(String title) {
    return 'Supprimer « $title » sur tous vos appareils ?';
  }

  @override
  String notebookSemantics(String title, int pages, String date) {
    return 'Cahier $title, $pages pages, modifié le $date';
  }

  @override
  String get notebookMissing => 'Ce cahier n’existe plus.';

  @override
  String importing(String name) {
    return 'Import de $name…';
  }

  @override
  String importDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages importées',
      one: '1 page importée',
    );
    return '$_temp0';
  }

  @override
  String importFailed(String error) {
    return 'Import impossible : $error';
  }

  @override
  String get syncLocalOnly => 'Mode local : sauvegarde sur cet appareil';

  @override
  String get syncSignedOut => 'Non connecté : sauvegarde locale seulement';

  @override
  String get syncDone => 'Synchronisé';

  @override
  String get syncRunning => 'Synchronisation…';

  @override
  String get syncOffline =>
      'Hors ligne : les changements seront envoyés plus tard';

  @override
  String syncError(String error) {
    return 'Erreur de synchronisation : $error';
  }

  @override
  String get undo => 'Annuler';

  @override
  String get redo => 'Rétablir';

  @override
  String get toolPen => 'Stylet';

  @override
  String get toolHighlighter => 'Surligneur';

  @override
  String get toolText => 'Texte';

  @override
  String get toolEraser => 'Gomme';

  @override
  String get toolSelect => 'Sélection';

  @override
  String get toolHand => 'Déplacer la vue';

  @override
  String get widthFine => 'Trait fin';

  @override
  String get widthMedium => 'Trait moyen';

  @override
  String get widthThick => 'Trait épais';

  @override
  String get selectHint => 'Tracez un rectangle autour des éléments.';

  @override
  String get deleteSelection => 'Supprimer la sélection';

  @override
  String get eraserHint => 'Glissez sur un trait pour l’effacer.';

  @override
  String get handHint => 'Glissez pour déplacer, pincez pour zoomer.';

  @override
  String pageOf(int current, int total) {
    return 'Page $current / $total';
  }

  @override
  String pageSemantics(int current, int total) {
    return 'Page $current sur $total';
  }

  @override
  String get previousPage => 'Page précédente';

  @override
  String get nextPage => 'Page suivante';

  @override
  String get addPage => 'Ajouter une page';

  @override
  String get deletePage => 'Supprimer la page';

  @override
  String get deletePageConfirm => 'Supprimer cette page et ses annotations ?';

  @override
  String get pageTemplate => 'Gabarit de page';

  @override
  String get templateBlank => 'Blanc';

  @override
  String get templateLined => 'Ligné';

  @override
  String get templateGrid => 'Quadrillé';

  @override
  String get templateDotted => 'Pointillé';

  @override
  String get exportNormal => 'Exporter en PDF normal (noir sur blanc)';

  @override
  String get exportInProfile => 'Exporter en PDF dans mon profil';

  @override
  String get shareNotebook => 'Partager le cahier';

  @override
  String get readAloud => 'Lire à voix haute';

  @override
  String get stopReading => 'Arrêter la lecture';

  @override
  String get recognizeText => 'Reconnaître le texte (OCR)';

  @override
  String get showRecognizedText => 'Afficher le texte reconnu';

  @override
  String get showOriginal => 'Voir l’original';

  @override
  String get documentFilter => 'Filtre du document';

  @override
  String get importIntoNotebook => 'Importer un PDF ou une image ici';

  @override
  String get assetUnavailable =>
      'Fichier pas encore disponible sur cet appareil.';

  @override
  String get ocrRunning => 'Reconnaissance du texte…';

  @override
  String get ocrFailed =>
      'Texte illisible : la page garde le filtre de couleur seulement.';

  @override
  String get ocrDone =>
      'Texte reconnu : il est maintenant recherchable et lisible à voix haute.';

  @override
  String get addText => 'Ajouter du texte';

  @override
  String get editText => 'Modifier le texte';

  @override
  String get textLabel => 'Texte';

  @override
  String get dictate => 'Dicter';

  @override
  String get stopDictation => 'Arrêter la dictée';

  @override
  String get dictationUnavailable =>
      'Dictée vocale indisponible sur cet appareil.';

  @override
  String get recolorMode => 'Recoloration';

  @override
  String get recolorFull => 'Complète';

  @override
  String get recolorBackground => 'Fond seulement';

  @override
  String get recolorOff => 'Désactivée';

  @override
  String get brightnessCapAuto => 'Plafond de luminosité du profil';

  @override
  String brightnessCapValue(int value) {
    return 'Plafond de luminosité : $value %';
  }

  @override
  String get imagesTreatment => 'Images et schémas';

  @override
  String get imagesIntact => 'Intactes';

  @override
  String get imagesDimmed => 'Atténuées';

  @override
  String get imagesRecolored => 'Recolorées';

  @override
  String get textContrastAuto => 'Contraste du texte automatique';

  @override
  String get originalNeverModified =>
      'Le fichier original n’est jamais modifié : seul l’affichage change.';

  @override
  String get shareExplanation =>
      'Votre camarade verra ce cahier dans ses propres couleurs. Votre profil visuel n’est jamais partagé.';

  @override
  String get email => 'Courriel';

  @override
  String get permissionRead => 'Lecture';

  @override
  String get permissionEdit => 'Modification';

  @override
  String get removeAccess => 'Retirer l’accès';

  @override
  String get shareUserNotFound => 'Aucun compte Monako avec ce courriel.';

  @override
  String get account => 'Compte';

  @override
  String get accountWhy =>
      'Un compte synchronise vos notes et vos profils entre vos appareils. Sans compte, tout reste sur cet appareil.';

  @override
  String get signInWithApple => 'Continuer avec Apple';

  @override
  String get password => 'Mot de passe';

  @override
  String get passwordHelp => 'Au moins 8 caractères.';

  @override
  String get signIn => 'Se connecter';

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get haveAccount => 'J’ai déjà un compte';

  @override
  String get noAccount => 'Pas encore de compte ? Créer un compte';

  @override
  String get sendMagicLink => 'Recevoir un lien de connexion';

  @override
  String get magicLinkSent =>
      'Lien envoyé : ouvrez votre courriel sur cet appareil.';

  @override
  String get forgotPassword => 'Mot de passe oublié';

  @override
  String get resetSent => 'Courriel de réinitialisation envoyé.';

  @override
  String get checkEmailConfirm =>
      'Vérifiez votre courriel pour confirmer votre compte.';

  @override
  String get continueWithoutAccount => 'Continuer sans compte';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get signOutHelp =>
      'Vos notes restent dans votre compte et sont retirées de cet appareil.';

  @override
  String get neverSynced => 'Jamais synchronisé';

  @override
  String lastSynced(String time) {
    return 'Dernière synchronisation : $time';
  }

  @override
  String get syncNow => 'Synchroniser maintenant';

  @override
  String get localModeTitle => 'Mode local';

  @override
  String get localModeHelp =>
      'Cette version n’est pas reliée à un serveur : vos notes sont sauvegardées sur cet appareil.';

  @override
  String get exportMyData => 'Exporter mes données';

  @override
  String get exportMyDataHelp =>
      'Notes, profils et réglages dans un fichier JSON.';

  @override
  String get deleteAccount => 'Supprimer mon compte';

  @override
  String get deleteAccountHelp =>
      'Efface immédiatement vos notes, profils et fichiers.';

  @override
  String get deleteAccountConfirm =>
      'Cette action efface définitivement toutes vos notes, vos profils et vos fichiers, sur tous vos appareils.';

  @override
  String get deleteWord => 'SUPPRIMER';

  @override
  String get typeDelete => 'Tapez SUPPRIMER pour confirmer';

  @override
  String get accountDeleted => 'Compte supprimé.';

  @override
  String get redoComfortTest => 'Refaire le test de confort';

  @override
  String get automaticModes => 'Modes automatiques';

  @override
  String get autoNight => 'Profil de nuit automatique';

  @override
  String autoNightHelp(int start, int end) {
    return 'De $start h à $end h';
  }

  @override
  String get nightProfile => 'Profil de nuit';

  @override
  String get nightHours => 'Heures de nuit';

  @override
  String get nightStart => 'Début';

  @override
  String get nightEnd => 'Fin';

  @override
  String get eveningWarmth => 'Filtre chaud en fin de journée';

  @override
  String get eveningWarmthHelp =>
      'La teinte se réchauffe progressivement de 18 h à 22 h.';

  @override
  String get pauseReminder => 'Pauses visuelles 20-20-20';

  @override
  String get pauseReminderHelp => 'Toutes les 20 minutes, un rappel discret.';

  @override
  String get pauseReminderText =>
      'Pause visuelle : regardez au loin (6 m) pendant 20 secondes.';

  @override
  String get writing => 'Écriture';

  @override
  String get fingerDrawing => 'Écrire avec le doigt';

  @override
  String get fingerDrawingHelp =>
      'Désactivé : seul le stylet écrit, le doigt fait défiler.';

  @override
  String get privacyPolicyTitle => 'Politique de confidentialité';

  @override
  String get accessibilityTitle => 'Déclaration d’accessibilité';

  @override
  String get privacyPolicyText =>
      'Politique de confidentialité de Monako (langage simple)\n\n1. Ce que nous recueillons\n• Votre courriel, si vous créez un compte.\n• Vos notes (traits, textes, surlignages) et les PDF ou images que vous importez.\n• Vos profils visuels (couleurs, tailles, filtres) et vos réglages.\nNous ne vous demandons jamais le nom d’une maladie. Nous ne recueillons aucune donnée publicitaire et n’utilisons aucun outil de suivi.\n\n2. Pourquoi\nUniquement pour afficher vos notes dans vos couleurs et les synchroniser entre vos appareils.\n\n3. Données sensibles\nUn profil visuel peut révéler un besoin de santé. Il est donc :\n• stocké dans votre compte privé, accessible à vous seul (même quand vous partagez un cahier, votre profil n’est jamais partagé) ;\n• chiffré pendant le transfert (HTTPS) et au repos (serveur et appareil) ;\n• jamais vendu, jamais partagé avec de la publicité.\nLa reconnaissance de texte (OCR) se fait sur votre appareil.\n\n4. Hébergement\nLes données sont hébergées par Supabase (base de données Postgres, stockage de fichiers et authentification).\n\n5. Vos droits\n• Exporter toutes vos données (Réglages › Exporter mes données).\n• Supprimer votre compte : vos notes, profils et fichiers sont effacés immédiatement (au plus tard en 30 jours dans les sauvegardes).\n• Vous déconnecter : les données sont retirées de l’appareil.\n\n6. Élèves mineurs\nSi vous avez moins de 14 ans (Québec) ou si votre école l’exige, un parent ou tuteur doit consentir à la création du compte.\n\n7. Cadre légal\nLoi sur la protection des renseignements personnels et les documents électroniques (LPRPDE) et, au Québec, Loi 25. Pour toute question : contactez le responsable de la protection des renseignements personnels indiqué dans la fiche de l’app.';

  @override
  String get accessibilityText =>
      'Déclaration d’accessibilité\n\nMonako vise la conformité aux Règles pour l’accessibilité des contenus Web (WCAG) 2.2, niveau AA, pour toute son interface.\n\nCe que l’app offre :\n• Toute l’interface est recolorée par votre profil : jamais de blanc ni de noir purs imposés.\n• Cibles tactiles d’au moins 44 pt / 48 dp.\n• Compatibilité VoiceOver (iOS) et TalkBack (Android) : chaque bouton a un nom.\n• Respect de la taille de texte du système.\n• Aucun clignotement ; fondus de 200 ms au maximum.\n• Aucune information portée par la couleur seule : chaque encre a un numéro, un motif ou une icône.\n• Interface en français et en anglais.\n• Geste de secours : un triple toucher rétablit un profil lisible.\n\nLimites connues :\n• Un PDF scanné de mauvaise qualité sans texte reconnu n’a que le filtre de couleur.\n• Les graphiques avec légendes colorées peuvent perdre en sens après recoloration : utilisez « Voir l’original ».\n\nSignaler un problème : écrivez-nous depuis la fiche de l’app. Nous répondons dans un délai de 10 jours ouvrables.';
}
