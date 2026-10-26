import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../../l10n/app_localizations.dart';

/// Réglages du filtre de recoloration, par document (section 10):
/// recoloration complète / fond seulement / désactivée, plafond de
/// luminosité, traitement des images, contraste du texte.
Future<void> showDocumentFilterSheet(BuildContext context, ImportedAsset asset) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(assetId: asset.id),
    );

class _FilterSheet extends StatelessWidget {
  const _FilterSheet({required this.assetId});
  final String assetId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final repo = context.watch<NotesRepository>();
    final asset = repo.asset(assetId);
    if (asset == null) return const SizedBox.shrink();
    final f = asset.filter;
    void set(RecolorSettings s) => repo.updateAsset(asset.copyWith(filter: s));

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.documentFilter, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(l.recolorMode),
            const SizedBox(height: 4),
            SegmentedButton<RecolorMode>(
              segments: [
                ButtonSegment(value: RecolorMode.full, label: Text(l.recolorFull), icon: const Icon(Icons.format_color_fill)),
                ButtonSegment(value: RecolorMode.backgroundOnly, label: Text(l.recolorBackground), icon: const Icon(Icons.wallpaper)),
                ButtonSegment(value: RecolorMode.off, label: Text(l.recolorOff), icon: const Icon(Icons.block)),
              ],
              selected: {f.mode},
              onSelectionChanged: (s) => set(f.copyWith(mode: s.first)),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.brightnessCapAuto),
              value: f.brightnessCap == null,
              onChanged: (auto) => set(auto
                  ? f.copyWith(clearBrightnessCap: true)
                  : f.copyWith(brightnessCap: 0.8)),
            ),
            if (f.brightnessCap != null) ...[
              Text(l.brightnessCapValue((f.brightnessCap! * 100).round())),
              Slider(
                value: f.brightnessCap!,
                min: 0.3,
                max: 1,
                divisions: 14,
                semanticFormatterCallback: (v) => '${(v * 100).round()} %',
                onChanged: (v) => set(f.copyWith(brightnessCap: v)),
              ),
            ],
            const SizedBox(height: 8),
            Text(l.imagesTreatment),
            const SizedBox(height: 4),
            SegmentedButton<ImageTreatment>(
              segments: [
                ButtonSegment(value: ImageTreatment.intact, label: Text(l.imagesIntact)),
                ButtonSegment(value: ImageTreatment.dimmed, label: Text(l.imagesDimmed)),
                ButtonSegment(value: ImageTreatment.recolored, label: Text(l.imagesRecolored)),
              ],
              selected: {f.images},
              onSelectionChanged: (s) => set(f.copyWith(images: s.first)),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.textContrastAuto),
              value: f.textContrast == null,
              onChanged: (auto) => set(auto
                  ? f.copyWith(clearTextContrast: true)
                  : f.copyWith(textContrast: 0.5)),
            ),
            if (f.textContrast != null)
              Slider(
                value: f.textContrast!,
                min: 0,
                max: 1,
                divisions: 10,
                semanticFormatterCallback: (v) => '${(v * 100).round()} %',
                onChanged: (v) => set(f.copyWith(textContrast: v)),
              ),
            const SizedBox(height: 8),
            Text(l.originalNeverModified,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
