// =============================================================================
//  RapportRepository — mouvements de stock, achats et ventes par article
// =============================================================================

import 'package:gestock_pos/core/constants/type_document.dart';
import 'package:gestock_pos/core/database/database_helper.dart';

class MouvementStock {
  const MouvementStock({
    required this.date,
    required this.articleNom,
    required this.unite,
    required this.typeDoc,
    required this.sens,
    required this.quantite,
    this.stockApres,
    this.documentNumero,
    this.tiersNom,
  });
  final DateTime date;
  final String articleNom;
  final String unite;
  final String typeDoc;
  final int sens;
  final double quantite;
  final double? stockApres;
  final String? documentNumero;
  final String? tiersNom;

  /// Libellé lisible du type de mouvement.
  String get typeLibelle {
    if (typeDoc == 'SI') return 'Stock initial';
    if (typeDoc == 'AJ') return 'Ajustement d\'inventaire';
    try {
      return TypeDocument.depuisPrefixe(typeDoc).libelle;
    } catch (_) {
      return typeDoc;
    }
  }
}

/// Une ligne de rapport « par article ».
class LigneRapport {
  const LigneRapport({
    required this.articleId,
    required this.designation,
    required this.unite,
    required this.quantite,
    required this.montantHt,
    required this.montantTtc,
    required this.cout,
    required this.nbDocuments,
  });
  final String articleId;
  final String designation;
  final String unite;
  final double quantite;
  final double montantHt;
  final double montantTtc;
  final double cout;       // Σ quantité × prix d'achat (ventes)
  final int nbDocuments;

  double get benefice => montantHt - cout;
}

enum SensMouvement { tous, entrees, sorties }

class RapportRepository {
  Future<List<MouvementStock>> mouvements({
    required DateTime debut,
    required DateTime fin,
    String recherche = '',
    SensMouvement sens = SensMouvement.tous,
    String? articleId,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final cond = <String>['m.deleted = 0', 'm.date_mvt >= ?', 'm.date_mvt < ?'];
    final args = <Object?>[debut.toIso8601String(), fin.toIso8601String()];
    if (recherche.trim().isNotEmpty) {
      cond.add('a.designation LIKE ?');
      args.add('%${recherche.trim()}%');
    }
    if (sens == SensMouvement.entrees) cond.add('m.sens > 0');
    if (sens == SensMouvement.sorties) cond.add('m.sens < 0');
    if (articleId != null) {
      cond.add('m.article_id = ?');
      args.add(articleId);
    }
    final rows = await db.rawQuery('''
      SELECT m.*, a.designation, a.unite, d.numero, d.tiers_nom
      FROM mouvements_stock m
      JOIN articles a ON a.id = m.article_id
      LEFT JOIN documents d ON d.id = m.document_id
      WHERE ${cond.join(' AND ')}
      ORDER BY m.date_mvt DESC LIMIT 500
    ''', args);
    return rows
        .map((r) => MouvementStock(
              date: DateTime.parse(r['date_mvt'] as String),
              articleNom: r['designation'] as String,
              unite: (r['unite'] as String?) ?? 'U',
              typeDoc: r['type_doc'] as String,
              sens: (r['sens'] as num).toInt(),
              quantite: (r['quantite'] as num).toDouble(),
              stockApres: (r['stock_apres'] as num?)?.toDouble(),
              documentNumero: r['numero'] as String?,
              tiersNom: r['tiers_nom'] as String?,
            ))
        .toList();
  }

  /// Ventes par article (retours et avoirs déduits) ou achats par article
  /// (retours fournisseurs déduits), sur une période.
  Future<List<LigneRapport>> parArticle({
    required bool ventes,
    required DateTime debut,
    required DateTime fin,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final types = ventes ? "('VC','BL','FV','RC','AV')" : "('BR','FA','RF')";
    final signe = ventes
        ? "CASE WHEN d.type_doc IN ('RC','AV') THEN -1 ELSE 1 END"
        : "CASE WHEN d.type_doc = 'RF' THEN -1 ELSE 1 END";
    // Ventes : une facture issue d'un BL n'est pas recomptée
    final source = ventes ? 'AND d.document_source_id IS NULL' : '';

    final rows = await db.rawQuery('''
      SELECT l.article_id, l.designation, COALESCE(a.unite, 'U') AS unite,
        SUM($signe * l.quantite)                     AS qte,
        SUM($signe * l.montant_ht)                   AS ht,
        SUM($signe * l.montant_ttc)                  AS ttc,
        SUM($signe * l.quantite * l.prix_achat_ht)   AS cout,
        COUNT(DISTINCT d.id)                         AS nb
      FROM document_lignes l
      JOIN documents d ON d.id = l.document_id
      LEFT JOIN articles a ON a.id = l.article_id
      WHERE l.deleted = 0 AND d.deleted = 0 AND d.statut <> 'ANNULE'
        AND d.type_doc IN $types $source
        AND d.date_doc >= ? AND d.date_doc < ?
      GROUP BY l.article_id
      ORDER BY ht DESC
    ''', [debut.toIso8601String(), fin.toIso8601String()]);

    return rows
        .map((r) => LigneRapport(
              articleId: (r['article_id'] as String?) ?? '',
              designation: r['designation'] as String,
              unite: r['unite'] as String,
              quantite: (r['qte'] as num? ?? 0).toDouble(),
              montantHt: (r['ht'] as num? ?? 0).toDouble(),
              montantTtc: (r['ttc'] as num? ?? 0).toDouble(),
              cout: (r['cout'] as num? ?? 0).toDouble(),
              nbDocuments: (r['nb'] as num? ?? 0).toInt(),
            ))
        .toList();
  }
}
