// Résultat de la boîte de dialogue d'encaissement.

import 'dart:math' as math;

import 'package:gestock_pos/core/constants/mode_paiement.dart';
import 'package:gestock_pos/core/utils/formatters.dart';

class Paiement {
  const Paiement({required this.mode, required this.montantRecu});

  /// Aucun paiement (proforma, bon de commande…).
  static const Paiement aucun = Paiement(mode: ModePaiement.credit, montantRecu: 0);

  final ModePaiement mode;

  /// Somme remise par le client (peut dépasser le total : on rend la monnaie).
  final double montantRecu;

  /// Ce qui est réellement encaissé : jamais plus que le total du document.
  double encaisse(double total) =>
      mode == ModePaiement.credit ? 0 : round2(math.min(montantRecu, total));

  /// Monnaie à rendre au client.
  double rendu(double total) =>
      mode == ModePaiement.credit ? 0 : round2(math.max(0, montantRecu - total));
}
