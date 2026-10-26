import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/color/hex.dart';
import '../../core/color/oklch.dart';
import '../../core/profiles/contrast_targets.dart';
import '../../l10n/app_localizations.dart';
import 'contrast_badge.dart';

/// Sélecteur de couleur en OKLCH (luminosité, saturation, teinte), avec le
/// contraste sur le fond affiché en direct.
Future<Color?> showOklchPicker(
  BuildContext context, {
  required String title,
  required Color initial,
  required Color background,
  required ContrastRange range,
}) =>
    showModalBottomSheet<Color>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _OklchPicker(
        title: title,
        initial: initial,
        background: background,
        range: range,
      ),
    );

class _OklchPicker extends StatefulWidget {
  const _OklchPicker({
    required this.title,
    required this.initial,
    required this.background,
    required this.range,
  });
  final String title;
  final Color initial, background;
  final ContrastRange range;

  @override
  State<_OklchPicker> createState() => _OklchPickerState();
}

class _OklchPickerState extends State<_OklchPicker> {
  late Oklch _c = Oklch.fromColor(widget.initial);
  late final _hex = TextEditingController(text: colorToHex(widget.initial));

  Color get _color => _c.toColor();

  void _set(Oklch c) {
    setState(() => _c = c);
    _hex.text = colorToHex(_color);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final color = _color;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Container(
              height: 88,
              decoration: BoxDecoration(
                color: widget.background,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                l.sampleWord,
                style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: ContrastBadge(
                foreground: color,
                background: widget.background,
                range: widget.range,
              ),
            ),
            _slider(l.lightness, _c.l, 0, 1, (v) => _set(_c.copyWith(l: v))),
            _slider(l.saturation, _c.c, 0, 0.3, (v) => _set(_c.copyWith(c: v))),
            _slider(l.hue, _c.h, 0, 360, (v) => _set(_c.copyWith(h: v))),
            TextField(
              controller: _hex,
              decoration: InputDecoration(labelText: l.hexCode),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[#0-9a-fA-F]')),
                LengthLimitingTextInputFormatter(7),
              ],
              onSubmitted: (v) {
                try {
                  setState(() => _c = Oklch.fromColor(colorFromHex(v)));
                } on FormatException {
                  // valeur ignorée
                }
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l.cancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, color),
                  child: Text(l.apply),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max,
          ValueChanged<double> onChanged) =>
      Row(
        children: [
          SizedBox(width: 110, child: Text(label)),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              label: value.toStringAsFixed(2),
              semanticFormatterCallback: (v) => '$label ${v.toStringAsFixed(2)}',
              onChanged: onChanged,
            ),
          ),
        ],
      );
}
