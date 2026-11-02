import 'package:flutter/material.dart';

import '../../core/profiles/palette.dart';
import '../../core/roles.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/profile_names.dart';
import 'editor_controller.dart';

/// Barre d'outils: stylet, surligneur, gomme, lasso, formes, texte, laser,
/// image, main. Chaque encre est un rôle; la pastille montre la couleur du
/// profil actif et porte un repère (numéro, motif) pour ne pas dépendre de
/// la couleur.
class EditorToolbar extends StatelessWidget {
  const EditorToolbar({
    super.key,
    required this.controller,
    required this.palette,
    this.simplified = false,
    this.onImage,
    this.onPaste,
  });

  final EditorController controller;
  final ResolvedPalette palette;

  /// Interface simplifiée (profil D): moins d'outils, boutons plus grands.
  final bool simplified;
  final VoidCallback? onImage;
  final VoidCallback? onPaste;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ctl = controller;
    final scheme = Theme.of(context).colorScheme;
    final tools = <(EditorTool, IconData, String)>[
      (EditorTool.pen, Icons.edit_outlined, l.toolPen),
      (EditorTool.highlighter, Icons.highlight_outlined, l.toolHighlighter),
      (EditorTool.eraser, Icons.auto_fix_normal_outlined, l.toolEraser),
      if (!simplified) (EditorTool.lasso, Icons.gesture, l.toolLasso),
      if (!simplified) (EditorTool.shapes, Icons.category_outlined, l.toolShapes),
      (EditorTool.text, Icons.text_fields, l.toolText),
      if (!simplified) (EditorTool.laser, Icons.flare, l.toolLaser),
      (EditorTool.hand, Icons.pan_tool_outlined, l.toolHand),
    ];
    final iconSize = simplified ? 32.0 : 24.0;

    return Material(
      color: scheme.surfaceContainerLow,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            for (final (tool, icon, label) in tools)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Semantics(
                  selected: ctl.tool == tool,
                  child: IconButton(
                    tooltip: label,
                    iconSize: iconSize,
                    isSelected: ctl.tool == tool,
                    style: IconButton.styleFrom(
                      backgroundColor:
                          ctl.tool == tool ? scheme.primaryContainer : null,
                      side: ctl.tool == tool
                          ? BorderSide(color: scheme.primary, width: 2)
                          : null,
                    ),
                    onPressed: () => ctl.tool = tool,
                    icon: Icon(icon),
                  ),
                ),
              ),
            if (onImage != null)
              IconButton(
                tooltip: l.insertImage,
                iconSize: iconSize,
                onPressed: onImage,
                icon: const Icon(Icons.add_photo_alternate_outlined),
              ),
            const SizedBox(width: 8),
            const SizedBox(height: 32, child: VerticalDivider()),
            const SizedBox(width: 8),
            ..._options(context, l),
          ],
        ),
      ),
    );
  }

  List<Widget> _options(BuildContext context, AppLocalizations l) {
    final ctl = controller;
    Widget inks() => Row(mainAxisSize: MainAxisSize.min, children: [
          for (final r in simplified
              ? const [InkRole.inkPrimary, InkRole.accent1, InkRole.accent2, InkRole.heading]
              : InkRole.writingInks)
            RoleChip(
              role: r,
              color: palette[r],
              paper: palette.paper,
              selected: ctl.inkRole == r,
              pattern: palette.rolePatterns ? patternForRole(r) : StrokePattern.solid,
              onTap: () => ctl.update(() => ctl.inkRole = r),
            ),
        ]);
    Widget widths(List<(double, String)> presets, double current,
            void Function(double) set, Color color) =>
        Row(mainAxisSize: MainAxisSize.min, children: [
          for (final (w, label) in presets)
            _WidthChip(
              width: w,
              label: label,
              selected: (current - w).abs() < 0.01,
              color: color,
              onTap: () => ctl.update(() => set(w)),
            ),
        ]);

    switch (ctl.tool) {
      case EditorTool.pen:
        return [
          if (!simplified) ...[
            _PenTypeMenu(controller: ctl),
            const SizedBox(width: 4),
          ],
          inks(),
          const SizedBox(width: 8),
          widths([(1.6, l.widthFine), (2.4, l.widthMedium), (4.0, l.widthThick)],
              ctl.penWidth, (w) => ctl.penWidth = w, palette.ink),
          if (!simplified)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(l.holdToShape, style: Theme.of(context).textTheme.bodySmall),
            ),
        ];
      case EditorTool.shapes:
        return [
          inks(),
          const SizedBox(width: 8),
          widths([(1.6, l.widthFine), (2.4, l.widthMedium), (4.0, l.widthThick)],
              ctl.penWidth, (w) => ctl.penWidth = w, palette.ink),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(l.shapesHint, style: Theme.of(context).textTheme.bodySmall),
          ),
        ];
      case EditorTool.text:
        return [inks(), const SizedBox(width: 8), Text(l.textHint)];
      case EditorTool.highlighter:
        return [
          for (final r in InkRole.highlights)
            RoleChip(
              role: r,
              color: palette.highlight(r),
              paper: palette.paper,
              selected: ctl.highlightRole == r,
              onTap: () => ctl.update(() => ctl.highlightRole = r),
            ),
          const SizedBox(width: 8),
          widths([(12, l.widthFine), (18, l.widthMedium), (28, l.widthThick)],
              ctl.highlighterWidth, (w) => ctl.highlighterWidth = w,
              palette.highlight(ctl.highlightRole)),
        ];
      case EditorTool.eraser:
        return [
          SegmentedButton<EraserMode>(
            segments: [
              ButtonSegment(value: EraserMode.stroke, label: Text(l.eraseStroke)),
              ButtonSegment(value: EraserMode.precise, label: Text(l.erasePrecise)),
            ],
            selected: {ctl.eraserMode},
            onSelectionChanged: (s) => ctl.update(() => ctl.eraserMode = s.first),
          ),
          const SizedBox(width: 8),
          widths([(6, l.widthFine), (10, l.widthMedium), (20, l.widthThick)],
              ctl.eraserRadius, (w) => ctl.eraserRadius = w, palette.ink),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(l.eraseHighlightsOnly),
            selected: ctl.eraseHighlightsOnly,
            onSelected: (v) => ctl.update(() => ctl.eraseHighlightsOnly = v),
          ),
        ];
      case EditorTool.lasso:
        return [
          Text(l.lassoHint),
          if (onPaste != null) ...[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: onPaste,
              icon: const Icon(Icons.content_paste),
              label: Text(l.paste),
            ),
          ],
        ];
      case EditorTool.laser:
        return [Text(l.laserHint)];
      case EditorTool.hand:
        return [Text(l.handHint)];
    }
  }
}

class _PenTypeMenu extends StatelessWidget {
  const _PenTypeMenu({required this.controller});
  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ctl = controller;
    String label(PenType p) => switch (p) {
          PenType.ball => l.penBall,
          PenType.fountain => l.penFountain,
          PenType.brush => l.penBrush,
          PenType.shape => l.toolShapes,
        };
    IconData icon(PenType p) => switch (p) {
          PenType.ball => Icons.create_outlined,
          PenType.fountain => Icons.history_edu,
          PenType.brush => Icons.brush_outlined,
          PenType.shape => Icons.category_outlined,
        };
    return PopupMenuButton<PenType>(
      tooltip: l.penType(label(ctl.penType)),
      onSelected: (p) => ctl.update(() => ctl.penType = p),
      itemBuilder: (_) => [
        for (final p in const [PenType.fountain, PenType.ball, PenType.brush])
          CheckedPopupMenuItem(value: p, checked: ctl.penType == p, child: Text(label(p))),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon(ctl.penType), size: 20),
          const SizedBox(width: 6),
          Text(label(ctl.penType)),
          const Icon(Icons.arrow_drop_down),
        ]),
      ),
    );
  }
}

/// Pastille d'un rôle d'encre ou de surlignage.
class RoleChip extends StatelessWidget {
  const RoleChip({
    super.key,
    required this.role,
    required this.color,
    required this.paper,
    required this.selected,
    required this.onTap,
    this.pattern = StrokePattern.solid,
  });

  final InkRole role;
  final Color color, paper;
  final bool selected;
  final VoidCallback onTap;
  final StrokePattern pattern;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = roleLabel(context, role);
    final fill = role.isHighlight ? Color.alphaBlend(color, paper) : color;
    final mark = switch (pattern) {
      StrokePattern.solid => roleMark(role),
      StrokePattern.dashed => '- -',
      StrokePattern.dotted => '···',
      StrokePattern.dashDot => '-·',
    };
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: onTap,
          radius: 26,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: fill,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? scheme.onSurface : scheme.outlineVariant,
                    width: selected ? 3 : 1,
                  ),
                ),
                child: Text(
                  mark,
                  style: TextStyle(
                    color: role.isHighlight ? scheme.onSurface : paper,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WidthChip extends StatelessWidget {
  const _WidthChip({
    required this.width,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final double width;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final h = width.clamp(2.0, 14.0) * 1.6;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: onTap,
          radius: 26,
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: selected
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Theme.of(context).colorScheme.onSurface, width: 2),
                  )
                : null,
            child: Container(
              width: 22,
              height: h,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(h / 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
