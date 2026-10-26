import 'package:flutter/material.dart';

import '../core/color/contrast.dart';
import '../core/color/oklch.dart';
import '../core/profiles/visual_profile.dart';
import '../core/roles.dart';

/// Thème de toute l'interface, calculé à partir du profil actif: une barre
/// d'outils blanche autour d'une page sombre ruinerait l'effet (section 7).
/// Jamais de blanc ni de noir purs forcés par l'interface.
ThemeData buildTheme(VisualProfile p) {
  final paper = p.paper;
  final ink = p.ink;
  final dark = isDarkColor(paper);
  final po = Oklch.fromColor(paper);

  Color shift(double dl) =>
      po.copyWith(l: (po.l + (dark ? dl : -dl)).clamp(0.0, 1.0)).toColor();

  final primary = p.color(InkRole.heading);
  final scheme = ColorScheme(
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: primary,
    onPrimary: paper,
    primaryContainer: shift(0.10),
    onPrimaryContainer: ink,
    secondary: p.color(InkRole.accent2),
    onSecondary: paper,
    secondaryContainer: shift(0.08),
    onSecondaryContainer: ink,
    tertiary: p.color(InkRole.accent3),
    onTertiary: paper,
    error: p.color(InkRole.accent1),
    onError: paper,
    errorContainer: shift(0.08),
    onErrorContainer: p.color(InkRole.accent1),
    surface: paper,
    onSurface: ink,
    onSurfaceVariant: p.color(InkRole.inkSecondary),
    surfaceContainerLowest: shift(0.01),
    surfaceContainerLow: shift(0.025),
    surfaceContainer: shift(0.04),
    surfaceContainerHigh: shift(0.055),
    surfaceContainerHighest: shift(0.07),
    outline: p.color(InkRole.inkSecondary).withValues(alpha: 0.7),
    outlineVariant: p.color(InkRole.paperLine),
    shadow: dark ? shift(-0.05) : const Color(0x33000000),
    scrim: const Color(0x99000000),
    inverseSurface: ink,
    onInverseSurface: paper,
    inversePrimary: paper,
  );

  final family = p.text.font.family;
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: family,
    // Cibles tactiles d'au moins 48 dp.
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    scaffoldBackgroundColor: paper,
    // Fondus courts, aucune animation rapide ni glissement.
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: _FadeTransitionBuilder(),
      TargetPlatform.iOS: _FadeTransitionBuilder(),
      TargetPlatform.macOS: _FadeTransitionBuilder(),
      TargetPlatform.linux: _FadeTransitionBuilder(),
      TargetPlatform.windows: _FadeTransitionBuilder(),
      TargetPlatform.fuchsia: _FadeTransitionBuilder(),
    }),
  );
  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: shift(0.03),
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: ink,
      displayColor: p.color(InkRole.heading),
      fontFamily: family,
    ),
    cardTheme: CardThemeData(
      color: shift(0.04),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.color(InkRole.paperLine)),
      ),
    ),
    dividerTheme: DividerThemeData(color: p.color(InkRole.paperLine)),
    sliderTheme: const SliderThemeData(showValueIndicator: ShowValueIndicator.onDrag),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 600),
      decoration: BoxDecoration(
        color: ink,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: TextStyle(color: paper, fontFamily: family),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: ink,
      contentTextStyle: TextStyle(color: paper, fontFamily: family),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Matrice de teinte chaude (réduction du bleu), [t] de 0 à 1.
List<double> warmTintMatrix(double t) {
  final g = 1 - 0.12 * t, b = 1 - 0.55 * t;
  return [
    1, 0, 0, 0, 0, //
    0, g, 0, 0, 0, //
    0, 0, b, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}

class _FadeTransitionBuilder extends PageTransitionsBuilder {
  const _FadeTransitionBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      FadeTransition(opacity: animation, child: child);
}
