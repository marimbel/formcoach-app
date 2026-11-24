import 'package:flutter/material.dart';

const brandGreen = Color(0xFF2E7D5B);
const dangerRed = Color(0xFFD63B3B);

/// Semantic colors not covered by ColorScheme (alert cards, stat numbers).
class FcColors extends ThemeExtension<FcColors> {
  final Color card, cardBorder, success, successSoft, danger, dangerSoft, info, infoSoft, warning;
  const FcColors({
    required this.warning,
    required this.card,
    required this.cardBorder,
    required this.success,
    required this.successSoft,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.infoSoft,
  });

  static const light = FcColors(
    warning: Color(0xFFD99100),
    card: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFE5E9E7),
    success: brandGreen,
    successSoft: Color(0xFFE6F3EC),
    danger: dangerRed,
    dangerSoft: Color(0xFFFDECEC),
    info: Color(0xFF2F6FB5),
    infoSoft: Color(0xFFE7F0FA),
  );
  static const dark = FcColors(
    warning: Color(0xFFF2B33D),
    card: Color(0xFF1C2421),
    cardBorder: Color(0xFF2B3631),
    success: Color(0xFF5CC495),
    successSoft: Color(0xFF173126),
    danger: Color(0xFFFF7A72),
    dangerSoft: Color(0xFF3A1E1D),
    info: Color(0xFF7FB2EA),
    infoSoft: Color(0xFF1A2938),
  );

  @override
  FcColors copyWith() => this;

  @override
  FcColors lerp(ThemeExtension<FcColors>? other, double t) => t < 0.5 ? this : (other as FcColors? ?? this);
}

extension FcTheme on BuildContext {
  FcColors get fc => Theme.of(this).extension<FcColors>() ?? FcColors.light;
}

ThemeData buildTheme(Brightness b) {
  final light = b == Brightness.light;
  final scheme = ColorScheme.fromSeed(seedColor: brandGreen, brightness: b).copyWith(
    primary: light ? brandGreen : const Color(0xFF5CC495),
    surface: light ? const Color(0xFFF6F7F6) : const Color(0xFF121816),
  );
  final fc = light ? FcColors.light : FcColors.dark;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    extensions: [fc],
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      color: fc.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: fc.cardBorder)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: fc.successSoft,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
          color: s.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant)),
    ),
    listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 16)),
    textTheme: const TextTheme(bodyLarge: TextStyle(fontSize: 17), bodyMedium: TextStyle(fontSize: 15)),
  );
}
