import 'package:flutter/material.dart';

import '../../core/color/contrast.dart';
import '../../core/profiles/contrast_targets.dart';
import '../../l10n/app_localizations.dart';

/// Ratio de contraste affiché en direct, avec une icône (jamais la couleur
/// seule) quand il sort de la plage du profil.
class ContrastBadge extends StatelessWidget {
  const ContrastBadge({
    super.key,
    required this.foreground,
    required this.background,
    required this.range,
    this.compact = false,
  });

  final Color foreground, background;
  final ContrastRange range;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ratio = contrastRatio(foreground, background);
    final ok = range.contains(ratio);
    final low = ratio < range.min;
    final scheme = Theme.of(context).colorScheme;
    final text = '${ratio.toStringAsFixed(1)}:1';
    final status = ok ? l.contrastOk : (low ? l.contrastTooLow : l.contrastTooHigh);
    return Semantics(
      label: l.contrastSemantics(text, status),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ok ? scheme.outlineVariant : scheme.error, width: ok ? 1 : 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ok ? Icons.check_circle_outline : Icons.warning_amber_rounded,
              size: 18,
              color: ok ? scheme.onSurfaceVariant : scheme.error,
            ),
            const SizedBox(width: 4),
            Text(text, style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
            if (!compact && !ok) ...[
              const SizedBox(width: 6),
              Flexible(child: Text(status, style: TextStyle(color: scheme.error))),
            ],
          ],
        ),
      ),
    );
  }
}
