// =============================================================================
//  DocumentRepository — lecture des documents (tous types)
// =============================================================================
//  Utilisé par : historique des documents, fiche d'un document, fiche client,
//  état de paiement client, transformation Bon de commande → Bon de réception.
// =============================================================================

import 'package:gestock_pos/core/constants/type_document.dart';
import 'package:gestock_pos/core/database/database_helper.dart';

class DocumentResume {
  const DocumentResume({
    required this.id,
    required this.numero,
    required this.type,
    required this.date,
    required this.totalHt,
    required this.totalTva,
    required this.totalTtc,
    required this.montantPaye,
    this.tiersType,
    this.tiersId,
    this.tiersNom,
    this.statut = 'VALIDE',
    this.modePaiement,
    this.notes,
    this.documentSourceId,
  });

  final String id;
  final String numero;
  final TypeDocument type;
  final DateTime date;
  final double totalHt;
  final double totalTva;
  final double totalTtc;
  final double montantPaye;
  final String? tiersType; // 'C' client, 'F' fournisseur, null = bon de stock
  final String? tiersId;
  final String? tiersNom;
  final String statut;     // VALIDE, TRANSFORME, ANNULE
  final String? modePaiement;
  final String? notes;
  final String? documentSourceId;

  double get resteAPayer => totalTtc - montantPaye;
  bool get estSolde => resteAPayer <= 0.009;

  factory DocumentResume.fromMap(Map<String, Object?> m) => DocumentResume(
        id: m['id'] as String,
        numero: m['numero'] as String,
        type: TypeDocument.depuisPrefixe(m['type_doc'] as String),
        date: DateTime.parse(m['date_doc'] as String),
        totalHt: (m['total_ht'] as num).toDouble(),
        totalTva: (m['total_tva'] as num).toDouble(),
        totalTtc: (m['total_ttc'] as num).toDouble(),
        montantPaye: (m['montant_paye'] as num).toDouble(),
        tiersType: m['tiers_type'] as String?,
        tiersId: m['tiers_id'] as String?,
        tiersNom: m['tiers_nom'] as String?,
        statut: (m['statut'] as String?) ?? 'VALIDE',
        modePaiement: m['mode_paiement'] as String?,
        notes: m['notes'] as String?,
        documentSourceId: m['document_source_id'] as String?,
      );
}

/// Ligne simplifiée (messages récapitulatifs).
class LigneResume {
  const LigneResume(this.designation, this.quantite, this.montantTtc);
  final String designation;
  final double quantite;
  final double montantTtc;
}

/// Ligne complète (fiche document, transformation de document).
class LigneDetail {
  const LigneDetail({
    required this.articleId,
    required this.designation,
    required this.quantite,
    required this.prixUnitaireHt,
    required this.remisePct,
    required this.tauxTva,
    required this.montantHt,
    required this.montantTtc,
  });
  final String? articleId;
  final String designation;
  final double quantite;
  final double prixUnitaireHt;
  final double remisePct;
  final double tauxTva;
  final double montantHt;
  final double montantTtc;
}

class DocumentRepository {
  /// Liste filtrée des documents.
  ///  • types      : ex. [TypeDocument.receptionFournisseur]
  ///  • recherche  : numéro ou nom du tiers
  ///  • nonSoldes  : uniquement ceux dont il reste quelque chose à payer
  ///  • debut/fin  : période (optionnelle)
  Future<List<DocumentResume>> lister({
    required List<TypeDocument> types,
    String recherche = '',
    bool nonSoldes = false,
    DateTime? debut,
    DateTime? fin,
    String? tiersId,
    int limite = 300,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final conditions = <String>[
      'deleted = 0',
      "statut <> 'ANNULE'",
      'type_doc IN (${List.filled(types.length, '?').join(',')})',
    ];
    final args = <Object?>[...types.map((t) => t.prefixe)];

    final q = recherche.trim();
    if (q.isNotEmpty) {
      conditions.add('(numero LIKE ? OR tiers_nom LIKE ?)');
      args.addAll(['%$q%', '%$q%']);
    }
    if (nonSoldes) conditions.add('total_ttc - montant_paye > 0.009');
    if (debut != null) {
      conditions.add('date_doc >= ?');
      args.add(debut.toIso8601String());
    }
    if (fin != null) {
      conditions.add('date_doc < ?');
      args.add(fin.toIso8601String());
    }
    if (tiersId != null) {
      conditions.add('tiers_id = ?');
      args.add(tiersId);
    }

    final rows = await db.query('documents',
        where: conditions.join(' AND '), whereArgs: args, orderBy: 'date_doc DESC', limit: limite);
    return rows.map(DocumentResume.fromMap).toList();
  }

  Future<DocumentResume?> parId(String id) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('documents', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : DocumentResume.fromMap(rows.first);
  }

  Future<List<DocumentResume>> derniersDuClient(String clientId, {int limite = 10}) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'documents',
      where: "deleted = 0 AND tiers_type = 'C' AND tiers_id = ?",
      whereArgs: [clientId],
      orderBy: 'date_doc DESC',
      limit: limite,
    );
    return rows.map(DocumentResume.fromMap).toList();
  }

  Future<List<LigneResume>> lignes(String documentId) async {
    final detail = await lignesDetail(documentId);
    return [for (final l in detail) LigneResume(l.designation, l.quantite, l.montantTtc)];
  }

  Future<List<LigneDetail>> lignesDetail(String documentId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('document_lignes',
        where: 'document_id = ? AND deleted = 0', whereArgs: [documentId], orderBy: 'ordre');
    return rows
        .map((r) => LigneDetail(
              articleId: r['article_id'] as String?,
              designation: r['designation'] as String,
              quantite: (r['quantite'] as num).toDouble(),
              prixUnitaireHt: (r['prix_unitaire_ht'] as num).toDouble(),
              remisePct: (r['remise_pct'] as num).toDouble(),
              tauxTva: (r['taux_tva'] as num).toDouble(),
              montantHt: (r['montant_ht'] as num).toDouble(),
              montantTtc: (r['montant_ttc'] as num).toDouble(),
            ))
        .toList();
  }

  /// Numéro du document d'origine (ex. le bon de commande d'un bon de réception).
  Future<String?> numeroDe(String id) async {
    final db = await DatabaseHelper.instance.database;
    final r = await db.query('documents', columns: ['numero'], where: 'id = ?', whereArgs: [id], limit: 1);
    return r.isEmpty ? null : r.first['numero'] as String;
  }
}
