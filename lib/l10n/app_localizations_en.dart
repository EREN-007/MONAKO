// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get apply => 'Apply';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get close => 'Close';

  @override
  String get back => 'Back';

  @override
  String get next => 'Next';

  @override
  String get add => 'Add';

  @override
  String get edit => 'Edit';

  @override
  String get rename => 'Rename';

  @override
  String get name => 'Name';

  @override
  String get keep => 'Keep';

  @override
  String get or => 'or';

  @override
  String get selected => 'Selected';

  @override
  String get share => 'Share';

  @override
  String get settings => 'Settings';

  @override
  String get about => 'About';

  @override
  String get language => 'Language';

  @override
  String get systemLanguage => 'System language';

  @override
  String errorGeneric(String error) {
    return 'Something went wrong: $error';
  }

  @override
  String get moreActions => 'More actions';

  @override
  String get welcomeTitle => 'Welcome to Monako';

  @override
  String get welcomeBody =>
      'Your notes appear in the colours that are easiest on your eyes. The file never changes: everyone sees the same note in their own colours.';

  @override
  String get medicalNoticeTitle => 'Important notice';

  @override
  String get medicalNotice =>
      'This tool improves reading comfort. It does not replace an eye exam and does not heal any condition.';

  @override
  String get medicalAdvice =>
      'If you feel pain or notice a sudden loss of vision, see an eye care professional (optometrist or ophthalmologist) promptly.';

  @override
  String get privacyNoticeTitle => 'Your privacy';

  @override
  String get privacySummary =>
      'Your display settings may reveal a health need: they stay private in your account, encrypted, and are never shared with advertisers. You are never asked to name a condition.';

  @override
  String get readPrivacyPolicy => 'Read the privacy policy';

  @override
  String get consentLabel =>
      'I have read these notices and accept the privacy policy.';

  @override
  String stepOf(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get q1Title => 'Does the white light of the screen bother you?';

  @override
  String get q1Hurts => 'Yes, the light hurts or dazzles me';

  @override
  String get q1Sometimes => 'Sometimes, especially at night or after a while';

  @override
  String get q1Fine => 'No, the light does not bother me';

  @override
  String get q2Title => 'What makes reading difficult?';

  @override
  String get q2Help => 'Check everything that applies, or nothing.';

  @override
  String get symptomBlends => 'The text blends into the background';

  @override
  String get symptomColors => 'I mix up colours';

  @override
  String get symptomBlurry => 'The text is blurry or has halos';

  @override
  String get symptomField => 'I see poorly in the centre or on the sides';

  @override
  String get q3Title => 'When do you study the most?';

  @override
  String get q3Day => 'During the day';

  @override
  String get q3Evening => 'In the evening or at night';

  @override
  String get q3Both => 'Both';

  @override
  String get chooseTitle => 'Which display feels best?';

  @override
  String get chooseHelp =>
      'Read each sample for a few seconds, then keep the one that feels most comfortable.';

  @override
  String get keepThisProfile => 'Keep this profile';

  @override
  String get changeLaterHint =>
      'You can switch profiles at any time, in under 2 seconds, with the profile button.';

  @override
  String get needA => 'Light sensitivity';

  @override
  String get needB => 'Low contrast';

  @override
  String get needC => 'Colours';

  @override
  String get needD => 'Reduced vision';

  @override
  String get needE => 'Blur and distortion';

  @override
  String get needNone => 'Standard display';

  @override
  String get presetStandard => 'Standard (black on white)';

  @override
  String get presetA1 => 'Light, dark';

  @override
  String get presetA2 => 'Light, soft sepia';

  @override
  String get presetB => 'Low contrast';

  @override
  String get presetC => 'Colours';

  @override
  String get presetD => 'Reduced vision';

  @override
  String get presetE => 'Blur and distortion';

  @override
  String get profilesTitle => 'Saved profiles';

  @override
  String get visualProfiles => 'Visual profiles';

  @override
  String get presetProfiles => 'Preset profiles';

  @override
  String get myProfiles => 'My profiles';

  @override
  String get manageProfiles => 'Manage profiles';

  @override
  String get changeProfile => 'Change profile';

  @override
  String profilePillSemantics(String name) {
    return 'Display profile: $name. Tap to change.';
  }

  @override
  String get linkProfileToNotebook => 'Use this profile for this notebook';

  @override
  String get linkProfileToNotebookHelp =>
      'The notebook will always open with this profile.';

  @override
  String get quickAdjust => 'Quick adjustments';

  @override
  String get backgroundBrightness => 'Background brightness';

  @override
  String get contrast => 'Contrast';

  @override
  String textSizeValue(int size) {
    return 'Text size: $size pt';
  }

  @override
  String get profileTiresMe => 'This profile tires me';

  @override
  String get profileTiresMeHelp => 'Suggest a gentler setting';

  @override
  String get softerPreviewText =>
      'Here is a gentler setting (less contrast, warmer tint). Keep it?';

  @override
  String softerName(String name) {
    return '$name (gentle)';
  }

  @override
  String adjustedName(String name) {
    return '$name (adjusted)';
  }

  @override
  String rescueApplied(String name) {
    return 'Rescue profile restored: $name';
  }

  @override
  String get rescueProfile => 'Rescue profile';

  @override
  String get useRescueProfile => 'Back to the rescue profile (or triple tap)';

  @override
  String get rescueProfileHelp =>
      'Restored by a triple tap anywhere if a setting makes the page unreadable.';

  @override
  String get contrastOk => 'within range';

  @override
  String get contrastTooLow => 'contrast too low';

  @override
  String get contrastTooHigh => 'contrast too high';

  @override
  String contrastSemantics(String ratio, String status) {
    return 'Contrast $ratio, $status';
  }

  @override
  String get combineNeeds => 'Combine needs';

  @override
  String get combineHelp =>
      'Choose 2 or more profiles (for example Light + Colours). The background comes from the Light profile, the hues from the Colours profile.';

  @override
  String combineCount(int count) {
    return 'Combine ($count)';
  }

  @override
  String get fusionConflictTitle => 'Conflicting settings';

  @override
  String get conflictCappedByLight =>
      'The low-contrast need asks for more contrast than light sensitivity tolerates. The safest setting for your eyes (the light range) is used.';

  @override
  String get conflictNoOverlap =>
      'These needs have no common contrast range. The gentlest setting is used.';

  @override
  String get conflictBackground =>
      'One profile has a light background and the other a dark one. The background of the Light profile (or the first one) is used.';

  @override
  String get useSafest => 'Use the safest setting';

  @override
  String get newProfile => 'New profile';

  @override
  String get customizeCopy => 'Customise (copy)';

  @override
  String get exportProfile => 'Export profile (JSON)';

  @override
  String get exportForOptometrist => 'Sheet for the optometrist (PDF)';

  @override
  String get importProfile => 'Import a profile';

  @override
  String profileImported(String name) {
    return 'Profile imported: $name';
  }

  @override
  String profileOptions(String name) {
    return 'Options for profile $name';
  }

  @override
  String get profileSheetTitle => 'Monako visual profile';

  @override
  String get needsLabel => 'Needs';

  @override
  String get contrastRangeLabel => 'Contrast range';

  @override
  String get roleColumn => 'Role';

  @override
  String get colorColumn => 'Colour';

  @override
  String get ratioColumn => 'Contrast on paper';

  @override
  String get filtersLabel => 'Filters';

  @override
  String get strokeLabel => 'Stroke';

  @override
  String get profileSettings => 'Profile settings';

  @override
  String get profileName => 'Profile name';

  @override
  String get myProfile => 'My profile';

  @override
  String get displayNeeds => 'Display needs';

  @override
  String targetRange(String range) {
    return 'Target contrast: $range';
  }

  @override
  String rangeConflict(String range) {
    return 'Conflicting needs: the safest range is used ($range).';
  }

  @override
  String get fixAutomatically => 'Fix automatically';

  @override
  String fixAutomaticallyCount(int count) {
    return 'Fix automatically ($count out of range)';
  }

  @override
  String get outOfRangeTitle => 'Contrast out of range';

  @override
  String outOfRangeText(String roles, String range) {
    return 'These colours are outside the $range range: $roles.';
  }

  @override
  String get saveAnyway => 'Save anyway';

  @override
  String get previewEverywhere => 'Preview in the whole app';

  @override
  String get colors => 'Colours';

  @override
  String get filters => 'Filters';

  @override
  String get warmTint => 'Warm tint';

  @override
  String get pdfBrightnessCap => 'PDF brightness cap';

  @override
  String get glareReduction => 'Glare reduction';

  @override
  String get haloReduction => 'Halo reduction';

  @override
  String get textSettings => 'Text';

  @override
  String get fontSystem => 'System';

  @override
  String get fontLegible => 'Legible';

  @override
  String get fontDyslexic => 'Dyslexia';

  @override
  String lineHeightValue(String value) {
    return 'Line spacing: $value';
  }

  @override
  String get wordSpacing => 'Word spacing';

  @override
  String defaultZoomValue(int value) {
    return 'Default zoom: $value%';
  }

  @override
  String get strokeSettings => 'Strokes';

  @override
  String strokeWidthValue(int value) {
    return 'Stroke width: $value%';
  }

  @override
  String get highlightOpacity => 'Highlight opacity';

  @override
  String get rolePatterns => 'Patterns in addition to colour';

  @override
  String get rolePatternsHelp =>
      'Dots and dashes to tell inks apart without colour.';

  @override
  String get simplifiedUi => 'Simplified interface';

  @override
  String get roleHelp =>
      'Each role is stored in your notes; only its colour changes from one profile to another.';

  @override
  String get lightness => 'Lightness';

  @override
  String get saturation => 'Saturation';

  @override
  String get hue => 'Hue';

  @override
  String get hexCode => 'Hex code';

  @override
  String get sampleWord => 'Sample';

  @override
  String get rolePaper => 'Page background';

  @override
  String get rolePaperLine => 'Lines and grid';

  @override
  String get roleInkPrimary => 'Main ink';

  @override
  String get roleInkSecondary => 'Secondary ink';

  @override
  String roleAccent(int n) {
    return 'Accent ink $n';
  }

  @override
  String roleHighlight(int n) {
    return 'Highlighter $n';
  }

  @override
  String get roleHeading => 'Heading';

  @override
  String get sampleHeading => 'Chapter 3 — The cell';

  @override
  String get sampleBody1 => 'The membrane protects the cell and controls ';

  @override
  String get sampleHighlighted => 'what goes in and out';

  @override
  String get sampleBody2 => '. The nucleus contains DNA.';

  @override
  String get sampleAccent1 => 'Remember';

  @override
  String get sampleAccent2 => 'Definition';

  @override
  String get sampleAccent3 => 'Example';

  @override
  String get sampleMargin => 'Margin note: review for the exam.';

  @override
  String get samplePreviewSemantics => 'Preview of a note in this profile';

  @override
  String get searchHint => 'Search notebooks or text';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get allNotebooks => 'All';

  @override
  String get folderOptions => 'Folder options';

  @override
  String get newNotebook => 'New notebook';

  @override
  String get untitledNotebook => 'Untitled notebook';

  @override
  String get newFolder => 'New folder';

  @override
  String get importPdfOrImage => 'Import a PDF or image';

  @override
  String get emptyLibrary =>
      'Create your first notebook or import a course PDF.';

  @override
  String get noResults => 'No results.';

  @override
  String get deleteFolder => 'Delete folder';

  @override
  String get deleteFolderHelp => 'Notebooks are not deleted.';

  @override
  String get notebookOptions => 'Notebook options';

  @override
  String get moveToFolder => 'Move to folder';

  @override
  String get noFolder => 'No folder';

  @override
  String get coverColor => 'Cover colour';

  @override
  String get deleteNotebook => 'Delete notebook';

  @override
  String deleteNotebookConfirm(String title) {
    return 'Delete “$title” on all your devices?';
  }

  @override
  String notebookSemantics(String title, int pages, String date) {
    return 'Notebook $title, $pages pages, modified $date';
  }

  @override
  String get notebookMissing => 'This notebook no longer exists.';

  @override
  String importing(String name) {
    return 'Importing $name…';
  }

  @override
  String importDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages imported',
      one: '1 page imported',
    );
    return '$_temp0';
  }

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get syncLocalOnly => 'Local mode: saved on this device';

  @override
  String get syncSignedOut => 'Signed out: saved locally only';

  @override
  String get syncDone => 'Synced';

  @override
  String get syncRunning => 'Syncing…';

  @override
  String get syncOffline => 'Offline: changes will be sent later';

  @override
  String syncError(String error) {
    return 'Sync error: $error';
  }

  @override
  String get undo => 'Undo';

  @override
  String get redo => 'Redo';

  @override
  String get toolPen => 'Pen';

  @override
  String get toolHighlighter => 'Highlighter';

  @override
  String get toolText => 'Text';

  @override
  String get toolEraser => 'Eraser';

  @override
  String get toolSelect => 'Select';

  @override
  String get toolHand => 'Move view';

  @override
  String get widthFine => 'Fine stroke';

  @override
  String get widthMedium => 'Medium stroke';

  @override
  String get widthThick => 'Thick stroke';

  @override
  String get selectHint => 'Draw a rectangle around items.';

  @override
  String get deleteSelection => 'Delete selection';

  @override
  String get eraserHint => 'Drag over a stroke to erase it.';

  @override
  String get handHint => 'Drag to move, pinch to zoom.';

  @override
  String pageOf(int current, int total) {
    return 'Page $current / $total';
  }

  @override
  String pageSemantics(int current, int total) {
    return 'Page $current of $total';
  }

  @override
  String get previousPage => 'Previous page';

  @override
  String get nextPage => 'Next page';

  @override
  String get addPage => 'Add page';

  @override
  String get deletePage => 'Delete page';

  @override
  String get deletePageConfirm => 'Delete this page and its annotations?';

  @override
  String get pageTemplate => 'Page template';

  @override
  String get templateBlank => 'Blank';

  @override
  String get templateLined => 'Lined';

  @override
  String get templateGrid => 'Grid';

  @override
  String get templateDotted => 'Dotted';

  @override
  String get exportNormal => 'Export standard PDF (black on white)';

  @override
  String get exportInProfile => 'Export PDF in my profile';

  @override
  String get shareNotebook => 'Share notebook';

  @override
  String get readAloud => 'Read aloud';

  @override
  String get stopReading => 'Stop reading';

  @override
  String get recognizeText => 'Recognise text (OCR)';

  @override
  String get showRecognizedText => 'Show recognised text';

  @override
  String get showOriginal => 'See the original';

  @override
  String get documentFilter => 'Document filter';

  @override
  String get importIntoNotebook => 'Import a PDF or image here';

  @override
  String get assetUnavailable => 'File not yet available on this device.';

  @override
  String get ocrRunning => 'Recognising text…';

  @override
  String get ocrFailed =>
      'Text unreadable: the page keeps the colour filter only.';

  @override
  String get ocrDone =>
      'Text recognised: it is now searchable and can be read aloud.';

  @override
  String get addText => 'Add text';

  @override
  String get editText => 'Edit text';

  @override
  String get textLabel => 'Text';

  @override
  String get dictate => 'Dictate';

  @override
  String get stopDictation => 'Stop dictation';

  @override
  String get dictationUnavailable =>
      'Voice dictation is not available on this device.';

  @override
  String get recolorMode => 'Recolouring';

  @override
  String get recolorFull => 'Full';

  @override
  String get recolorBackground => 'Background only';

  @override
  String get recolorOff => 'Off';

  @override
  String get brightnessCapAuto => 'Use the profile brightness cap';

  @override
  String brightnessCapValue(int value) {
    return 'Brightness cap: $value%';
  }

  @override
  String get imagesTreatment => 'Images and diagrams';

  @override
  String get imagesIntact => 'Intact';

  @override
  String get imagesDimmed => 'Dimmed';

  @override
  String get imagesRecolored => 'Recoloured';

  @override
  String get textContrastAuto => 'Automatic text contrast';

  @override
  String get originalNeverModified =>
      'The original file is never modified: only the display changes.';

  @override
  String get shareExplanation =>
      'Your classmate will see this notebook in their own colours. Your visual profile is never shared.';

  @override
  String get email => 'Email';

  @override
  String get permissionRead => 'Read';

  @override
  String get permissionEdit => 'Edit';

  @override
  String get removeAccess => 'Remove access';

  @override
  String get shareUserNotFound => 'No Monako account with this email.';

  @override
  String get account => 'Account';

  @override
  String get accountWhy =>
      'An account syncs your notes and profiles between your devices. Without an account, everything stays on this device.';

  @override
  String get signInWithApple => 'Continue with Apple';

  @override
  String get password => 'Password';

  @override
  String get passwordHelp => 'At least 8 characters.';

  @override
  String get signIn => 'Sign in';

  @override
  String get createAccount => 'Create account';

  @override
  String get haveAccount => 'I already have an account';

  @override
  String get noAccount => 'No account yet? Create one';

  @override
  String get sendMagicLink => 'Email me a sign-in link';

  @override
  String get magicLinkSent => 'Link sent: open your email on this device.';

  @override
  String get forgotPassword => 'Forgot password';

  @override
  String get resetSent => 'Password reset email sent.';

  @override
  String get checkEmailConfirm => 'Check your email to confirm your account.';

  @override
  String get continueWithoutAccount => 'Continue without an account';

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutHelp =>
      'Your notes stay in your account and are removed from this device.';

  @override
  String get neverSynced => 'Never synced';

  @override
  String lastSynced(String time) {
    return 'Last synced: $time';
  }

  @override
  String get syncNow => 'Sync now';

  @override
  String get localModeTitle => 'Local mode';

  @override
  String get localModeHelp =>
      'This build is not connected to a server: your notes are saved on this device.';

  @override
  String get exportMyData => 'Export my data';

  @override
  String get exportMyDataHelp => 'Notes, profiles and settings in a JSON file.';

  @override
  String get deleteAccount => 'Delete my account';

  @override
  String get deleteAccountHelp =>
      'Immediately erases your notes, profiles and files.';

  @override
  String get deleteAccountConfirm =>
      'This permanently erases all your notes, profiles and files, on all your devices.';

  @override
  String get deleteWord => 'DELETE';

  @override
  String get typeDelete => 'Type DELETE to confirm';

  @override
  String get accountDeleted => 'Account deleted.';

  @override
  String get redoComfortTest => 'Retake the comfort test';

  @override
  String get automaticModes => 'Automatic modes';

  @override
  String get autoNight => 'Automatic night profile';

  @override
  String autoNightHelp(int start, int end) {
    return 'From $start:00 to $end:00';
  }

  @override
  String get nightProfile => 'Night profile';

  @override
  String get nightHours => 'Night hours';

  @override
  String get nightStart => 'Start';

  @override
  String get nightEnd => 'End';

  @override
  String get eveningWarmth => 'Warm filter in the evening';

  @override
  String get eveningWarmthHelp =>
      'The tint gradually warms from 6 pm to 10 pm.';

  @override
  String get pauseReminder => '20-20-20 eye breaks';

  @override
  String get pauseReminderHelp => 'A gentle reminder every 20 minutes.';

  @override
  String get pauseReminderText =>
      'Eye break: look far away (20 feet) for 20 seconds.';

  @override
  String get writing => 'Writing';

  @override
  String get fingerDrawing => 'Write with your finger';

  @override
  String get fingerDrawingHelp =>
      'Off: only the pencil writes, your finger scrolls.';

  @override
  String get privacyPolicyTitle => 'Privacy policy';

  @override
  String get accessibilityTitle => 'Accessibility statement';

  @override
  String get privacyPolicyText =>
      'Monako privacy policy (plain language)\n\n1. What we collect\n• Your email address, if you create an account.\n• Your notes (strokes, text, highlights) and the PDFs or images you import.\n• Your visual profiles (colours, sizes, filters) and your settings.\nWe never ask you to name a condition. We collect no advertising data and use no tracking tools.\n\n2. Why\nOnly to show your notes in your colours and sync them between your devices.\n\n3. Sensitive data\nA visual profile may reveal a health need. It is therefore:\n• stored in your private account, accessible only to you (even when you share a notebook, your profile is never shared);\n• encrypted in transit (HTTPS) and at rest (server and device);\n• never sold, never shared with advertisers.\nText recognition (OCR) happens on your device.\n\n4. Hosting\nData is hosted by Supabase (Postgres database, file storage and authentication).\n\n5. Your rights\n• Export all your data (Settings › Export my data).\n• Delete your account: your notes, profiles and files are erased immediately (within 30 days at most in backups).\n• Sign out: data is removed from the device.\n\n6. Minors\nIf you are under 14 (Quebec) or if your school requires it, a parent or guardian must consent to the account creation.\n\n7. Legal framework\nPersonal Information Protection and Electronic Documents Act (PIPEDA) and, in Quebec, Law 25. For any question, contact the privacy officer listed on the app\'s store page.';

  @override
  String get accessibilityText =>
      'Accessibility statement\n\nMonako aims to conform to the Web Content Accessibility Guidelines (WCAG) 2.2, level AA, across its interface.\n\nWhat the app offers:\n• The whole interface is recoloured by your profile: never forced pure white or pure black.\n• Touch targets of at least 44 pt / 48 dp.\n• VoiceOver (iOS) and TalkBack (Android) support: every button has a name.\n• Respects the system text size.\n• No flashing; fades of 200 ms at most.\n• No information conveyed by colour alone: each ink has a number, a pattern or an icon.\n• Interface in French and English.\n• Rescue gesture: a triple tap restores a readable profile.\n\nKnown limitations:\n• A poor-quality scanned PDF without recognised text only gets the colour filter.\n• Charts with colour legends may lose meaning after recolouring: use “See the original”.\n\nReport a problem: write to us from the app\'s store page. We reply within 10 business days.';
}
