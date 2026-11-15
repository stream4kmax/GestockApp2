// Petits widgets réutilisés par plusieurs écrans.

import 'package:flutter/material.dart';

import 'package:gestock_pos/core/theme/app_colors.dart';
import 'package:gestock_pos/core/utils/formatters.dart';

/// Pastille de stock : vert = OK, orange = sous le seuil, rouge = rupture.
class StockChip extends StatelessWidget {
  const StockChip({super.key, required this.disponible, required this.seuil, required this.unite});
  final double disponible;
  final double seuil;
  final String unite;

  @override
  Widget build(BuildContext context) {
    final (Color couleur, String texte) = disponible <= 0
        ? (AppColors.supprimer, 'Rupture')
        : disponible <= seuil
            ? (AppColors.alerte, 'Stock : ${fmtQte(disponible)} $unite')
            : (AppColors.ajouter, 'Stock : ${fmtQte(disponible)} $unite');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: couleur.withValues(alpha: 0.35)),
      ),
      child: Text(texte,
          maxLines: 1, style: TextStyle(fontSize: 11, color: couleur, fontWeight: FontWeight.w700)),
    );
  }
}

/// Champ de recherche standard.
class ChampRecherche extends StatelessWidget {
  const ChampRecherche({super.key, required this.controller, required this.onChanged, this.hint = 'Rechercher…'});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
      ),
    );
  }
}

/// Écran vide avec icône et message.
class EtatVide extends StatelessWidget {
  const EtatVide({super.key, required this.icone, required this.message});
  final IconData icone;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icone, size: 64, color: AppColors.texteSecondaire.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.texteSecondaire)),
          ]),
        ),
      );
}

/// Boîte de confirmation de suppression (bouton ROUGE).
Future<bool> confirmerSuppression(BuildContext context, String quoi) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.delete_forever, color: AppColors.supprimer, size: 40),
      title: Text('Supprimer $quoi ?'),
      content: const Text('Cette action ne peut pas être annulée depuis l\'application.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.supprimer),
          onPressed: () => Navigator.pop(ctx, true),
          icon: const Icon(Icons.delete),
          label: const Text('Supprimer'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Message en bas de l'écran (vert = succès, rouge = erreur).
void afficherMessage(BuildContext context, String texte, {bool erreur = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(texte),
      backgroundColor: erreur ? AppColors.supprimer : AppColors.ajouter,
    ));
}

/// Validateur de nombre pour les formulaires (virgule ou point acceptés).
String? validerNombre(String? v, {bool obligatoire = true, double min = 0}) {
  if (v == null || v.trim().isEmpty) return obligatoire ? 'Obligatoire' : null;
  final n = parseNombre(v);
  if (n == null) return 'Nombre invalide';
  if (n < min) return 'Doit être ≥ ${fmtQte(min)}';
  return null;
}
