import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

enum LegalText { privacy, medical, accessibility }

/// Politique de confidentialité en langage simple, message médical et
/// déclaration d'accessibilité (section 11).
Future<void> showLegalText(BuildContext context, LegalText which) {
  final l = AppLocalizations.of(context);
  final (title, body) = switch (which) {
    LegalText.privacy => (l.privacyPolicyTitle, l.privacyPolicyText),
    LegalText.medical => (l.medicalNoticeTitle, '${l.medicalNotice}\n\n${l.medicalAdvice}'),
    LegalText.accessibility => (l.accessibilityTitle, l.accessibilityText),
  };
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: SelectableText(body),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
