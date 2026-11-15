// Ligne de la liste d'articles du POS (v2) : prix affiché selon le tarif
// choisi (Détail / Gros), badge "dans le panier", pastille de stock.
// Mise en page sans débordement : la colonne de droite a une largeur bornée
// et ses textes rétrécissent (FittedBox) au lieu de pousser la ligne.

import 'package:flutter/material.dart';

import 'package:gestock_pos/core/constants/type_tarif.dart';
import 'package:gestock_pos/core/theme/app_colors.dart';
import 'package:gestock_pos/core/utils/formatters.dart';
import 'package:gestock_pos/core/widgets/communs.dart';
import 'package:gestock_pos/data/models/article.dart';

class ArticleTile extends StatelessWidget {
  const ArticleTile({
    super.key,
    required this.article,
    required this.quantiteDansPanier,
    required this.tarif,
    required this.onTap,
  });

  final Article article;
  final double quantiteDansPanier;
  final TypeTarif tarif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final disponible = article.stock - quantiteDansPanier;
    final couleurPrix = tarif == TypeTarif.gros ? AppColors.achat : AppColors.vente;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Badge(
                isLabelVisible: quantiteDansPanier > 0,
                backgroundColor: AppColors.vente,
                label: Text(fmtQte(quantiteDansPanier)),
                child: CircleAvatar(
                  backgroundColor: AppColors.vente.withValues(alpha: 0.10),
                  child: Text(
                    article.designation.isNotEmpty ? article.designation[0].toUpperCase() : '?',
                    style: const TextStyle(color: AppColors.vente, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(article.designation,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    StockChip(disponible: disponible, seuil: article.stockMin, unite: article.unite),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(fmtMonnaie(article.prixTtcPour(tarif)),
                          style: TextStyle(fontWeight: FontWeight.w800, color: couleurPrix, fontSize: 15)),
                    ),
                    Text('${tarif.libelle} TTC',
                        style: const TextStyle(fontSize: 11, color: AppColors.texteSecondaire)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
