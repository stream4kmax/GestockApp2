// Modèle Article : représente une ligne de la table `articles`.
// v2 : deux prix de vente (DÉTAIL et GROS) + fournisseur principal.

import 'package:gestock_pos/core/constants/type_tarif.dart';
import 'package:gestock_pos/core/utils/formatters.dart';

class Article {
  const Article({
    required this.id,
    required this.code,
    required this.designation,
    this.codeBarre,
    this.familleId,
    this.fournisseurId,
    this.fournisseurNom,
    this.unite = 'U',
    this.prixAchatHt = 0,
    this.prixVenteHt = 0,
    this.prixGrosHt = 0,
    this.tauxTva = 19,
    this.stock = 0,
    this.stockMin = 0,
    this.actif = true,
  });

  final String id;
  final String code;
  final String? codeBarre;
  final String designation;
  final String? familleId;
  final String? fournisseurId;
  final String? fournisseurNom; // lu par jointure, non enregistré
  final String unite;
  final double prixAchatHt;
  final double prixVenteHt;     // prix DÉTAIL HT (colonne prix_vente_ht)
  final double prixGrosHt;      // prix GROS HT
  final double tauxTva;
  final double stock;
  final double stockMin;
  final bool actif;

  /// Prix HT selon le type de vente choisi au POS.
  double prixHtPour(TypeTarif t) =>
      t == TypeTarif.gros && prixGrosHt > 0 ? prixGrosHt : prixVenteHt;

  double prixTtcPour(TypeTarif t) => round2(prixHtPour(t) * (1 + tauxTva / 100));

  double get prixVenteTtc => prixTtcPour(TypeTarif.detail);
  double get prixGrosTtc => prixTtcPour(TypeTarif.gros);

  /// Bénéfice unitaire HT (prix de vente − prix d'achat).
  double margePour(TypeTarif t) => round2(prixHtPour(t) - prixAchatHt);

  bool get enRupture => stock <= 0;
  bool get sousSeuil => !enRupture && stock <= stockMin;
  bool get aReapprovisionner => stock <= stockMin;

  factory Article.fromMap(Map<String, Object?> m) => Article(
        id: m['id'] as String,
        code: m['code'] as String,
        codeBarre: m['code_barre'] as String?,
        designation: m['designation'] as String,
        familleId: m['famille_id'] as String?,
        fournisseurId: m['fournisseur_id'] as String?,
        fournisseurNom: m['fournisseur_nom'] as String?,
        unite: (m['unite'] as String?) ?? 'U',
        prixAchatHt: (m['prix_achat_ht'] as num?)?.toDouble() ?? 0,
        prixVenteHt: (m['prix_vente_ht'] as num?)?.toDouble() ?? 0,
        prixGrosHt: (m['prix_gros_ht'] as num?)?.toDouble() ?? 0,
        tauxTva: (m['taux_tva'] as num?)?.toDouble() ?? 0,
        stock: (m['stock'] as num?)?.toDouble() ?? 0,
        stockMin: (m['stock_min'] as num?)?.toDouble() ?? 0,
        actif: ((m['actif'] as int?) ?? 1) == 1,
      );

  /// Colonnes enregistrées (sans le stock : il ne change que par mouvements).
  Map<String, Object?> toMap() => {
        'id': id,
        'code': code,
        'code_barre': (codeBarre?.isEmpty ?? true) ? null : codeBarre,
        'designation': designation,
        'famille_id': familleId,
        'fournisseur_id': fournisseurId,
        'unite': unite,
        'prix_achat_ht': prixAchatHt,
        'prix_vente_ht': prixVenteHt,
        'prix_gros_ht': prixGrosHt,
        'taux_tva': tauxTva,
        'stock_min': stockMin,
        'actif': actif ? 1 : 0,
      };
}
