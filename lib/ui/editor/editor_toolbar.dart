import 'package:flutter/material.dart';

import '../../core/profiles/palette.dart';
import '../../core/roles.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/profile_names.dart';
import 'editor_controller.dart';

/// Barre d'outils: stylet, surligneur, texte, gomme, sélection, main.
/// Chaque encre est un rôle; la pastille montre la couleur du profil actif
/// et porte un repère (numéro, motif) pour ne pas dépendre de la couleur.
class EditorToolbar extends StatelessWidget {
  const EditorToolbar({
    super.key,
    required this.controller,
    required this.palette,
    this.simplified = false,
  });

  final EditorController controller;
  final ResolvedPalette palette;

  /// Interface simplifiée (profil D): moins d'outils, boutons plus grands.
  final bool simplified;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ctl = controller;
    final scheme = Theme.of(context).colorScheme;
    final tools = <(EditorTool, IconData, String)>[
      (EditorTool.pen, Icons.edit_outlined, l.toolPen),
      (EditorTool.highlighter, Icons.highlight_outlined, l.toolHighlighter),
      (EditorTool.text, Icons.text_fields, l.toolText),
      (EditorTool.eraser, Icons.auto_fix_normal_outlined, l.toolEraser),
      if (!simplified) (EditorTool.select, Icons.highlight_alt, l.toolSelect),
      if (!simplified) (EditorTool.hand, Icons.pan_tool_outlined, l.toolHand),
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
    switch (ctl.tool) {
      case EditorTool.pen:
      case EditorTool.text:
        return [
          for (final r in simplified
              ? const [
                  InkRole.inkPrimary,
                  InkRole.accent1,
                  InkRole.accent2,
                  InkRole.heading,
                ]
              : InkRole.writingInks)
            RoleChip(
              role: r,
              color: palette[r],
              paper: palette.paper,
              selected: ctl.inkRole == r,
              pattern:
                  palette.rolePatterns ? patternForRole(r) : StrokePattern.solid,
              onTap: () => ctl.setInkRole(r),
            ),
          if (ctl.tool == EditorTool.pen) ...[
            const SizedBox(width: 8),
            for (final (w, label) in [
              (1.6, l.widthFine),
              (2.4, l.widthMedium),
              (4.0, l.widthThick),
            ])
              _WidthChip(
                width: w,
                label: label,
                selected: (ctl.penWidth - w).abs() < 0.01,
                color: palette.ink,
                onTap: () => ctl.setPenWidth(w),
              ),
          ],
        ];
      case EditorTool.highlighter:
        return [
          for (final r in InkRole.highlights)
            RoleChip(
              role: r,
              color: palette.highlight(r),
              paper: palette.paper,
              selected: ctl.highlightRole == r,
              onTap: () => ctl.setHighlightRole(r),
            ),
        ];
      case EditorTool.select:
        if (ctl.selection.isEmpty) return [Text(l.selectHint)];
        return [
          IconButton(
            tooltip: l.deleteSelection,
            onPressed: ctl.deleteSelection,
            icon: const Icon(Icons.delete_outline),
          ),
          for (final r in InkRole.writingInks)
            RoleChip(
              role: r,
              color: palette[r],
              paper: palette.paper,
              selected: false,
              onTap: () => ctl.setSelectionRole(r),
            ),
        ];
      case EditorTool.eraser:
        return [Text(l.eraserHint)];
      case EditorTool.hand:
        return [Text(l.handHint)];
    }
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
  Widget build(BuildContext context) => Semantics(
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
                      border: Border.all(color: color, width: 2),
                    )
                  : null,
              child: Container(
                width: 22,
                height: width * 2,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(width),
                ),
              ),
            ),
          ),
        ),
      );
}
