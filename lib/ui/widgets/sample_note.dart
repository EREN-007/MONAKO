import 'package:flutter/material.dart';

import '../../core/profiles/palette.dart';
import '../../core/profiles/visual_profile.dart';
import '../../core/roles.dart';
import '../../l10n/app_localizations.dart';

/// Texte exemple dessiné dans un profil donné: titre, texte, encres
/// d'accent (avec motif si le profil l'active) et surlignage.
class SampleNote extends StatelessWidget {
  const SampleNote({super.key, required this.profile, this.compact = false});

  final VisualProfile profile;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final palette = ResolvedPalette.of(profile);
    final scale = profile.text.sizeMultiplier * (compact ? 0.85 : 1);
    final family = profile.text.font.family;
    TextStyle style(InkRole r, {double size = 16, FontWeight? weight}) => TextStyle(
          color: palette[r],
          fontSize: size * scale,
          fontWeight: weight,
          height: profile.text.lineHeight,
          wordSpacing: size * scale * profile.text.wordSpacing,
          fontFamily: family,
        );

    TextDecorationStyle? deco(InkRole r) {
      if (!palette.rolePatterns) return null;
      return switch (patternForRole(r)) {
        StrokePattern.dashed => TextDecorationStyle.dashed,
        StrokePattern.dotted => TextDecorationStyle.dotted,
        StrokePattern.dashDot => TextDecorationStyle.wavy,
        StrokePattern.solid => TextDecorationStyle.solid,
      };
    }

    TextStyle accent(InkRole r) {
      final d = deco(r);
      return style(r, weight: FontWeight.w600).copyWith(
        decoration: d == null ? null : TextDecoration.underline,
        decorationStyle: d,
        decorationColor: palette[r],
        decorationThickness: 2,
      );
    }

    return Semantics(
      label: l.samplePreviewSemantics,
      child: Container(
        padding: EdgeInsets.all(compact ? 14 : 20),
        decoration: BoxDecoration(
          color: palette.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette[InkRole.paperLine], width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.sampleHeading, style: style(InkRole.heading, size: 22, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text.rich(TextSpan(children: [
              TextSpan(text: l.sampleBody1, style: style(InkRole.inkPrimary)),
              TextSpan(
                text: l.sampleHighlighted,
                style: style(InkRole.inkPrimary).copyWith(
                  background: Paint()..color = palette.highlight(InkRole.highlight1),
                ),
              ),
              TextSpan(text: l.sampleBody2, style: style(InkRole.inkPrimary)),
            ])),
            const SizedBox(height: 6),
            Text.rich(TextSpan(children: [
              TextSpan(text: l.sampleAccent1, style: accent(InkRole.accent1)),
              TextSpan(text: ' · ', style: style(InkRole.inkSecondary)),
              TextSpan(text: l.sampleAccent2, style: accent(InkRole.accent2)),
              TextSpan(text: ' · ', style: style(InkRole.inkSecondary)),
              TextSpan(text: l.sampleAccent3, style: accent(InkRole.accent3)),
            ])),
            if (!compact) ...[
              const SizedBox(height: 6),
              Text(l.sampleMargin, style: style(InkRole.inkSecondary, size: 14)),
            ],
          ],
        ),
      ),
    );
  }
}
