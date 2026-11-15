// =============================================================================
//  DashboardRepository — statistiques par période (Jour / Mois / Année)
// =============================================================================
//  Chiffre d'affaires = Σ TTC des ventes (VC, BL, factures directes)
//                       − Σ TTC des retours clients et avoirs
//  Bénéfice           = Σ (CA HT) − Σ (quantité × prix d'achat HT figé)
//                     = prix de vente − prix d'achat, comme demandé.
//  On calcule le bénéfice sur le HT : la TVA appartient à l'État, pas au commerçant.
//  Le prix d'achat est COPIÉ dans chaque ligne de vente (document_lignes.prix_achat_ht) :
//  si le prix d'achat change demain, le bénéfice d'hier reste exact.
// =============================================================================

import 'package:sqflite/sqflite.dart';

import 'package:gestock_pos/core/database/database_helper.dart';

enum Periode { jour, mois, annee }

extension PeriodeX on Periode {
  String get libelle => switch (this) {
        Periode.jour => 'Jour',
        Periode.mois => 'Mois',
        Periode.annee => 'Année',
      };

  /// Bornes [début, fin[ de la période contenant `ref`.
  (DateTime, DateTime) bornes(DateTime ref) => switch (this) {
        Periode.jour => (DateTime(ref.year, ref.month, ref.day), DateTime(ref.year, ref.month, ref.day + 1)),
        Periode.mois => (DateTime(ref.year, ref.month), DateTime(ref.year, ref.month + 1)),
        Periode.annee => (DateTime(ref.year), DateTime(ref.year + 1)),
      };
}

class StatsPeriode {
  const StatsPeriode({
    required this.chiffreAffairesTtc,
    required this.chiffreAffairesHt,
    required this.benefice,
    required this.nbVentes,
    required this.encaisse,
  });
  final double chiffreAffairesTtc;
  final double chiffreAffairesHt;
  final double benefice;
  final int nbVentes;
  final double encaisse;

  /// Taux de marge sur le CA HT, en %.
  double get tauxMarge => chiffreAffairesHt == 0 ? 0 : benefice / chiffreAffairesHt * 100;
}

class TableauDeBord {
  const TableauDeBord({required this.periode, required this.beneficeMois, required this.nbAlertesStock});
  final StatsPeriode periode;   // selon le filtre choisi
  final double beneficeMois;    // toujours affiché
  final int nbAlertesStock;
}

class DashboardRepository {
  // Documents comptés comme ventes (+1) ou retours (−1). Une facture issue d'un
  // BL est exclue (document_source_id non nul) pour ne pas compter deux fois.
  static const String _filtre = '''
    d.deleted = 0 AND d.statut = 'VALIDE' AND d.document_source_id IS NULL
    AND d.type_doc IN ('VC','BL','FV','RC','AV')
    AND d.date_doc >= ? AND d.date_doc < ?
  ''';
  static const String _signe = "CASE WHEN d.type_doc IN ('RC','AV') THEN -1 ELSE 1 END";

  Future<StatsPeriode> stats(DateTime debut, DateTime fin) async {
    final db = await DatabaseHelper.instance.database;
    final args = [debut.toIso8601String(), fin.toIso8601String()];

    final entetes = await db.rawQuery('''
      SELECT
        COALESCE(SUM($_signe * d.total_ttc), 0)    AS ca_ttc,
        COALESCE(SUM($_signe * d.total_ht), 0)     AS ca_ht,
        COALESCE(SUM($_signe * d.montant_paye), 0) AS encaisse,
        SUM(CASE WHEN d.type_doc IN ('VC','BL','FV') THEN 1 ELSE 0 END) AS nb
      FROM documents d WHERE $_filtre
    ''', args);

    final couts = await db.rawQuery('''
      SELECT COALESCE(SUM($_signe * l.quantite * l.prix_achat_ht), 0) AS cout
      FROM document_lignes l JOIN documents d ON d.id = l.document_id
      WHERE l.deleted = 0 AND $_filtre
    ''', args);

    final e = entetes.first;
    final caHt = (e['ca_ht'] as num).toDouble();
    final cout = (couts.first['cout'] as num).toDouble();
    return StatsPeriode(
      chiffreAffairesTtc: (e['ca_ttc'] as num).toDouble(),
      chiffreAffairesHt: caHt,
      benefice: caHt - cout,
      nbVentes: (e['nb'] as num?)?.toInt() ?? 0,
      encaisse: (e['encaisse'] as num).toDouble(),
    );
  }

  /// Tout ce que la page d'accueil affiche, en un seul appel.
  Future<TableauDeBord> charger(Periode periode, {DateTime? date}) async {
    final ref = date ?? DateTime.now();
    final (debut, fin) = periode.bornes(ref);
    final (debutMois, finMois) = Periode.mois.bornes(ref);

    final stats = await this.stats(debut, fin);
    final mois = periode == Periode.mois ? stats : await this.stats(debutMois, finMois);

    final db = await DatabaseHelper.instance.database;
    final alertes = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM articles WHERE deleted = 0 AND actif = 1 AND stock <= stock_min',
        )) ??
        0;

    return TableauDeBord(periode: stats, beneficeMois: mois.benefice, nbAlertesStock: alertes);
  }
}
