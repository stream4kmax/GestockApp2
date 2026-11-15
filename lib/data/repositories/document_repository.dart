// Lecture de l'historique des documents (fiche client, renvoi d'une facture).

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
  });
  final String id;
  final String numero;
  final TypeDocument type;
  final DateTime date;
  final double totalHt;
  final double totalTva;
  final double totalTtc;
  final double montantPaye;

  double get resteAPayer => totalTtc - montantPaye;

  factory DocumentResume.fromMap(Map<String, Object?> m) => DocumentResume(
        id: m['id'] as String,
        numero: m['numero'] as String,
        type: TypeDocument.depuisPrefixe(m['type_doc'] as String),
        date: DateTime.parse(m['date_doc'] as String),
        totalHt: (m['total_ht'] as num).toDouble(),
        totalTva: (m['total_tva'] as num).toDouble(),
        totalTtc: (m['total_ttc'] as num).toDouble(),
        montantPaye: (m['montant_paye'] as num).toDouble(),
      );
}

/// Ligne simplifiée, suffisante pour un message récapitulatif.
class LigneResume {
  const LigneResume(this.designation, this.quantite, this.montantTtc);
  final String designation;
  final double quantite;
  final double montantTtc;
}

class DocumentRepository {
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
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('document_lignes',
        where: 'document_id = ? AND deleted = 0', whereArgs: [documentId], orderBy: 'ordre');
    return rows
        .map((r) => LigneResume(r['designation'] as String, (r['quantite'] as num).toDouble(),
            (r['montant_ttc'] as num).toDouble()))
        .toList();
  }
}
