// =============================================================================
//  Thème CLAIR unique (le mode sombre est abandonné)
// =============================================================================
//  Effet 3D sur TOUS les boutons Material (FilledButton, ElevatedButton,
//  OutlinedButton, FloatingActionButton) :
//   • au repos  : élévation 4 → ombre portée visible (le bouton "sort" de l'écran)
//   • appuyé    : élévation 0 → l'ombre disparaît, le bouton semble s'enfoncer
//  Les cases du menu utilisent en plus le widget Relief3D (core/widgets).
// =============================================================================

import 'package:flutter/material.dart';

import 'package:gestock_pos/core/theme/app_colors.dart';

class AppTheme {
  AppTheme._();

  /// Élévation qui change selon l'état du bouton (repos / survol / appui / désactivé).
  static final WidgetStateProperty<double> _elevation3D =
      WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) return 0;
    if (states.contains(WidgetState.pressed)) return 0; // ← enfoncé
    if (states.contains(WidgetState.hovered)) return 6;
    return 4; // ← au repos, en relief
  });

  static final ButtonStyle _styleCommun = ButtonStyle(
    elevation: _elevation3D,
    shadowColor: const WidgetStatePropertyAll(Colors.black54),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
    textStyle: const WidgetStatePropertyAll(TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
    // Le texte d'un bouton ne doit jamais casser la mise en page
    minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
  );

  static ThemeData get clair {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.vente,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.vente,
      secondary: AppColors.ajouter,
      error: AppColors.supprimer,
      surface: AppColors.surface,
      onSurface: AppColors.texte,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.fond,

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.texte,
        elevation: 2,
        scrolledUnderElevation: 4,
        shadowColor: Colors.black26,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.texte),
      ),

      // Boutons en relief
      filledButtonTheme: FilledButtonThemeData(style: _styleCommun),
      elevatedButtonTheme: ElevatedButtonThemeData(style: _styleCommun),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _styleCommun.copyWith(
          backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.ajouter, // "+" = vert
        foregroundColor: Colors.white,
        elevation: 6,
        highlightElevation: 0, // s'enfonce quand on appuie
        shape: StadiumBorder(),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 3,
        shadowColor: Colors.black26,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.bordure),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.bordure),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.vente, width: 2),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        elevation: 8,
        shadowColor: Colors.black38,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.vente.withValues(alpha: 0.12),
        height: 68,
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600, overflow: TextOverflow.ellipsis),
        ),
      ),

      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      dividerTheme: const DividerThemeData(color: AppColors.bordure, space: 1),
    );
  }
}
