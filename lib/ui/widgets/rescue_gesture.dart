import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/profile_controller.dart';

/// Geste de secours (section 7): un triple toucher n'importe où revient au
/// profil par défaut de l'élève si un réglage rend la page illisible.
class RescueGesture extends StatefulWidget {
  const RescueGesture({super.key, required this.child});

  final Widget child;

  static final _events = StreamController<DateTime>.broadcast();

  /// Émis quand le geste est reconnu (l'éditeur retire alors les points
  /// d'encre laissés par les trois touchers).
  static Stream<DateTime> get events => _events.stream;

  @override
  State<RescueGesture> createState() => _RescueGestureState();
}

class _RescueGestureState extends State<RescueGesture> {
  static const _maxTapDuration = Duration(milliseconds: 300);
  static const _maxGap = Duration(milliseconds: 450);
  static const _slop = 14.0;

  final Map<int, (DateTime, Offset)> _down = {};
  final List<DateTime> _taps = [];
  Offset? _firstTapAt;

  void _onDown(PointerDownEvent e) {
    // Doigt seulement: des points écrits vite au stylet (« ... ») ne
    // doivent pas déclencher le geste.
    if (e.kind != PointerDeviceKind.touch) return;
    _down[e.pointer] = (DateTime.now(), e.position);
  }

  void _onUp(PointerUpEvent e) {
    final d = _down.remove(e.pointer);
    if (d == null) return;
    final now = DateTime.now();
    final isTap = now.difference(d.$1) < _maxTapDuration &&
        (e.position - d.$2).distance < _slop;
    if (!isTap) {
      _taps.clear();
      return;
    }
    if (_taps.isNotEmpty &&
        (now.difference(_taps.last) > _maxGap ||
            (e.position - _firstTapAt!).distance > 80)) {
      _taps.clear();
    }
    if (_taps.isEmpty) _firstTapAt = e.position;
    _taps.add(now);
    if (_taps.length >= 3) {
      _taps.clear();
      _rescue();
    }
  }

  Future<void> _rescue() async {
    final pc = context.read<ProfileController>();
    final l = AppLocalizations.of(context);
    RescueGesture._events.add(DateTime.now());
    await pc.rescue();
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Semantics(
          liveRegion: true,
          child: Text(l.rescueApplied(pc.rescueProfile.name)),
        ),
      ));
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onDown,
        onPointerUp: _onUp,
        onPointerCancel: (e) => _down.remove(e.pointer),
        child: widget.child,
      );
}
