// =============================================================================
//  CartProvider — état du panier (ChangeNotifier + package provider)
// =============================================================================
//  Chaque modification (ajout, quantité, remise…) appelle notifyListeners() :
//  tous les widgets qui "écoutent" le panier se redessinent automatiquement
//  (liste, badge, totaux en bas de l'écran).
//
//  CALCUL DES TOTAUX
//   Total HT brut   = Σ montant HT des lignes (après remise ligne)
//   Remise globale  = Total HT brut × Remise globale %
//   Total HT net    = Total HT brut − Remise globale
//   Total TVA       = Σ TVA des lignes × (1 − Remise globale %)
//                     (la remise globale réduit aussi la base de TVA,
//                      chaque ligne gardant son propre taux 0 / 9 / 19 %)
//   Total TTC       = Total HT net + Total TVA
// =============================================================================

import 'package:flutter/foundation.dart';

import 'package:gestock_pos/core/constants/type_tarif.dart';
import 'package:gestock_pos/core/utils/formatters.dart';
import 'package:gestock_pos/data/models/article.dart';
import 'package:gestock_pos/data/models/client.dart';
import 'package:gestock_pos/data/models/ligne_panier.dart';

/// Totaux calculés du panier (objet immuable).
class TotauxPanier {
  const TotauxPanier({
    required this.htBrut,
    required this.remiseGlobale,
    required this.ht,
    required this.tva,
    required this.ttc,
  });
  final double htBrut;
  final double remiseGlobale;
  final double ht;
  final double tva;
  final double ttc;
}

class CartProvider extends ChangeNotifier {
  CartProvider({required this.controleStock});

  /// true pour les documents qui SORTENT du stock (vente, BL, facture) :
  /// on interdit de vendre plus que la quantité disponible.
  final bool controleStock;

  final List<LignePanier> _lignes = [];
  Client? _client;
  double _remiseGlobalePct = 0;
  TypeTarif _tarif = TypeTarif.detail; // v2 : Détail ou Gros

  // ------------------------------- Lecture --------------------------------
  List<LignePanier> get lignes => List.unmodifiable(_lignes);
  Client? get client => _client;
  TypeTarif get tarif => _tarif;
  double get remiseGlobalePct => _remiseGlobalePct;
  bool get estVide => _lignes.isEmpty;
  int get nbLignes => _lignes.length;

  /// Quantité déjà dans le panier pour un article (affichée sur la liste).
  double quantiteDe(String articleId) {
    for (final l in _lignes) {
      if (l.article.id == articleId) return l.quantite;
    }
    return 0;
  }

  TotauxPanier get totaux {
    double htBrut = 0;
    double tvaBrute = 0;
    for (final l in _lignes) {
      htBrut += l.montantHt;
      tvaBrute += l.montantTva;
    }
    final coef = 1 - _remiseGlobalePct / 100;
    final remise = round2(htBrut * _remiseGlobalePct / 100);
    final ht = round2(htBrut - remise);
    final tva = round2(tvaBrute * coef);
    return TotauxPanier(
      htBrut: round2(htBrut),
      remiseGlobale: remise,
      ht: ht,
      tva: tva,
      ttc: round2(ht + tva),
    );
  }

  // ----------------------------- Modification -----------------------------

  /// Ajoute un article (ou augmente sa quantité s'il est déjà dans le panier).
  /// Renvoie un message d'erreur si le stock est insuffisant, sinon null.
  String? ajouter(Article article, {double quantite = 1}) {
    final i = _lignes.indexWhere((l) => l.article.id == article.id);
    final nouvelleQte = (i >= 0 ? _lignes[i].quantite : 0) + quantite;

    final erreur = _verifierStock(article, nouvelleQte);
    if (erreur != null) return erreur;

    if (i >= 0) {
      _lignes[i].quantite = nouvelleQte;
    } else {
      _lignes.add(LignePanier(
        article: article,
        quantite: quantite,
        prixUnitaireHt: article.prixHtPour(_tarif), // prix selon Détail / Gros
        tauxTva: article.tauxTva,
      ));
    }
    notifyListeners();
    return null;
  }

  /// Change la quantité d'une ligne (0 ou moins = suppression).
  String? modifierQuantite(String articleId, double quantite) {
    final i = _lignes.indexWhere((l) => l.article.id == articleId);
    if (i < 0) return null;
    if (quantite <= 0) {
      supprimer(articleId);
      return null;
    }
    final erreur = _verifierStock(_lignes[i].article, quantite);
    if (erreur != null) return erreur;
    _lignes[i].quantite = quantite;
    notifyListeners();
    return null;
  }

  void modifierPrix(String articleId, double prixHt) {
    final i = _lignes.indexWhere((l) => l.article.id == articleId);
    if (i < 0 || prixHt < 0) return;
    _lignes[i].prixUnitaireHt = prixHt;
    notifyListeners();
  }

  void modifierRemise(String articleId, double pct) {
    final i = _lignes.indexWhere((l) => l.article.id == articleId);
    if (i < 0) return;
    _lignes[i].remisePct = pct.clamp(0, 100).toDouble();
    notifyListeners();
  }

  void definirRemiseGlobale(double pct) {
    _remiseGlobalePct = pct.clamp(0, 100).toDouble();
    notifyListeners();
  }

  void supprimer(String articleId) {
    _lignes.removeWhere((l) => l.article.id == articleId);
    notifyListeners();
  }

  /// Change le client ; son tarif par défaut (Détail / Gros) est appliqué.
  void definirClient(Client client) {
    _client = client;
    changerTarif(client.typeTarif, notifier: false);
    notifyListeners();
  }

  /// v2 : bascule Détail ↔ Gros. Les lignes déjà dans le panier sont
  /// recalculées au nouveau tarif (une modification manuelle de prix est
  /// alors remplacée par le prix du tarif choisi).
  void changerTarif(TypeTarif t, {bool notifier = true}) {
    _tarif = t;
    for (final l in _lignes) {
      l.prixUnitaireHt = l.article.prixHtPour(t);
    }
    if (notifier) notifyListeners();
  }

  /// Vide les lignes et la remise (le client choisi est conservé).
  void vider() {
    _lignes.clear();
    _remiseGlobalePct = 0;
    notifyListeners();
  }

  String? _verifierStock(Article a, double quantiteVoulue) {
    if (!controleStock) return null;
    if (quantiteVoulue > a.stock) {
      return a.enRupture
          ? '« ${a.designation} » est en rupture de stock.'
          : 'Stock insuffisant pour « ${a.designation} » '
              '(disponible : ${fmtQte(a.stock)} ${a.unite}).';
    }
    return null;
  }
}
