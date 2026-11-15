// Une ligne du panier (= future ligne de document).
//
// Calcul d'une ligne :
//   Montant HT  = Quantité × Prix unitaire HT × (1 − Remise % / 100)
//   Montant TVA = Montant HT × Taux TVA / 100
//   Montant TTC = Montant HT + Montant TVA

import 'package:gestock_pos/core/utils/formatters.dart';
import 'package:gestock_pos/data/models/article.dart';

class LignePanier {
  LignePanier({
    required this.article,
    required this.quantite,
    required this.prixUnitaireHt,
    required this.tauxTva,
    this.remisePct = 0,
  });

  final Article article;

  // Champs modifiables depuis le panier (quantité, prix négocié, remise).
  double quantite;
  double prixUnitaireHt;
  double tauxTva;
  double remisePct;

  double get montantHt => round2(quantite * prixUnitaireHt * (1 - remisePct / 100));
  double get montantTva => round2(montantHt * tauxTva / 100);
  double get montantTtc => round2(montantHt + montantTva);
}
