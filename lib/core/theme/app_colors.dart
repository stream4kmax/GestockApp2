// =============================================================================
//  Palette de l'application (thème clair uniquement)
// =============================================================================
//  Règle simple, appliquée partout :
//   • BLEU  = Vente / action principale
//   • VERT  = Ajouter / Valider / Enregistrer
//   • ROUGE = Supprimer / Danger / Rupture
//   • ORANGE = Alerte (stock sous le seuil, crédit)
// =============================================================================

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Fonds
  static const Color fond = Color(0xFFF3F5F9);        // gris très clair (blanc cassé)
  static const Color surface = Colors.white;          // cartes, cases
  static const Color bordure = Color(0xFFE1E6EE);

  // Textes
  static const Color texte = Color(0xFF1C2430);       // presque noir
  static const Color texteSecondaire = Color(0xFF5F6B7A);

  // Actions
  static const Color vente = Color(0xFF1565C0);       // bleu
  static const Color ajouter = Color(0xFF2E7D32);     // vert
  static const Color supprimer = Color(0xFFC62828);   // rouge
  static const Color alerte = Color(0xFFEF6C00);      // orange

  // Couleurs des modules
  static const Color achat = Color(0xFF00897B);
  static const Color article = Color(0xFF6D4C41);
  static const Color tresorerie = Color(0xFF6A1B9A);
  static const Color parametres = Color(0xFF455A64);
  static const Color outils = Color(0xFF0277BD);

  // Messagerie
  static const Color whatsapp = Color(0xFF25D366);
  static const Color sms = Color(0xFF1E88E5);

  /// Assombrit une couleur (utilisé pour le "socle" des effets 3D).
  static Color assombrir(Color c, [double quantite = 0.18]) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - quantite).clamp(0.0, 1.0)).toColor();
  }

  /// Éclaircit une couleur (reflet du haut des boutons 3D).
  static Color eclaircir(Color c, [double quantite = 0.10]) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + quantite).clamp(0.0, 1.0)).toColor();
  }
}
