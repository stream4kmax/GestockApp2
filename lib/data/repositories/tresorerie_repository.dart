// =============================================================================
//  TresorerieRepository — caisse et règlements
// =============================================================================
//  • Caisse : mouvements (entrées +1 / sorties −1), solde, totaux par période,
//    ajout manuel (apport, dépense, retrait).
//  • Règlements client / fournisseur : enregistrement avec AFFECTATION
//    AUTOMATIQUE aux documents non soldés, du plus ancien au plus récent
//    (méthode FIFO). Ainsi l'« État de paiement » reste toujours juste.
// =============================================================================

import 'package:gestock_pos/core/constants/mode_paiement.dart';
import 'package:gestock_pos/core/database/database_helper.dart';
import 'package:gestock_pos/core/settings/app_settings.dart';
import 'package:gestock_pos/core/utils/formatters.dart';
import 'package:gestock_pos/core/utils/ids.dart';

class MouvementCaisse {
  const MouvementCaisse({
    required this.id,
    required this.date,
    required this.sens,
    required this.montant,
    required this.libelle,
    this.sourceType,
  });
  final String id;
  final DateTime date;
  final int sens;
  final double montant;
  final String libelle;
  final String? sourceType; // REGLEMENT, APPORT, DEPENSE, RETRAIT

  factory MouvementCaisse.fromMap(Map<String, Object?> m) => MouvementCaisse(
        id: m['id'] as String,
        date: DateTime.parse(m['date_mvt'] as String),
        sens: (m['sens'] as num).toInt(),
        montant: (m['montant'] as num).toDouble(),
        libelle: m['libelle'] as String,
        sourceType: m['source_type'] as String?,
      );
}

class TotauxCaisse {
  const TotauxCaisse(this.entrees, this.sorties);
  final double entrees;
  final double sorties;
  double get net => entrees - sorties;
}

class Reglement {
  const Reglement({
    required this.id,
    required this.date,
    required this.tiersNom,
    required this.sens,
    required this.montant,
    required this.mode,
    this.reference,
    this.documentNumero,
  });
  final String id;
  final DateTime date;
  final String tiersNom;
  final int sens;
  final double montant;
  final String mode;
  final String? reference;
  final String? documentNumero;

  String get modeLibelle =>
      ModePaiement.values.where((m) => m.code == mode).map((m) => m.libelle).firstOrNull ?? mode;
}

class TresorerieRepository {
  // --------------------------------------------------------------- CAISSE

  Future<List<MouvementCaisse>> mouvementsCaisse(DateTime debut, DateTime fin) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'mouvements_caisse',
      where: 'deleted = 0 AND date_mvt >= ? AND date_mvt < ?',
      whereArgs: [debut.toIso8601String(), fin.toIso8601String()],
      orderBy: 'date_mvt DESC',
    );
    return rows.map(MouvementCaisse.fromMap).toList();
  }

  /// Solde de caisse depuis le début (Σ entrées − Σ sorties).
  Future<double> soldeCaisse() async {
    final db = await DatabaseHelper.instance.database;
    final r = await db.rawQuery('SELECT COALESCE(SUM(sens * montant), 0) AS s FROM mouvements_caisse WHERE deleted = 0');
    return (r.first['s'] as num).toDouble();
  }

  Future<TotauxCaisse> totauxCaisse(DateTime debut, DateTime fin) async {
    final db = await DatabaseHelper.instance.database;
    final r = await db.rawQuery('''
      SELECT COALESCE(SUM(CASE WHEN sens > 0 THEN montant ELSE 0 END), 0) AS e,
             COALESCE(SUM(CASE WHEN sens < 0 THEN montant ELSE 0 END), 0) AS s
      FROM mouvements_caisse WHERE deleted = 0 AND date_mvt >= ? AND date_mvt < ?
    ''', [debut.toIso8601String(), fin.toIso8601String()]);
    return TotauxCaisse((r.first['e'] as num).toDouble(), (r.first['s'] as num).toDouble());
  }

  /// Totaux des règlements reçus par mode (espèces, chèque…) sur la période.
  Future<Map<String, double>> encaissementsParMode(DateTime debut, DateTime fin) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT mode, COALESCE(SUM(sens * montant), 0) AS total FROM reglements
      WHERE deleted = 0 AND tiers_type = 'C' AND date_reg >= ? AND date_reg < ?
      GROUP BY mode ORDER BY total DESC
    ''', [debut.toIso8601String(), fin.toIso8601String()]);
    return {for (final r in rows) r['mode'] as String: (r['total'] as num).toDouble()};
  }

  /// Ajout manuel : apport (+), dépense (−), retrait (−).
  Future<void> ajouterMouvementCaisse({
    required int sens,
    required double montant,
    required String libelle,
    required String sourceType,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final now = maintenantUtc();
    await db.insert('mouvements_caisse', {
      'id': nouvelId(),
      'date_mvt': maintenantLocal(),
      'point_vente_id': AppSettings.instance.pointVenteId,
      'sens': sens,
      'montant': round2(montant),
      'libelle': libelle,
      'source_type': sourceType,
      'created_at': now,
      'updated_at': now,
      'sync_status': 1,
    });
  }

  /// Suppression d'un mouvement MANUEL (les règlements ne se suppriment pas ici).
  Future<void> supprimerMouvementCaisse(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('mouvements_caisse', {'deleted': 1, 'updated_at': maintenantUtc(), 'sync_status': 1},
        where: "id = ? AND source_type <> 'REGLEMENT'", whereArgs: [id]);
  }

  // ----------------------------------------------------------- RÈGLEMENTS

  /// Enregistre un règlement libre d'un client (tiersType 'C') ou à un
  /// fournisseur ('F') et l'affecte aux documents non soldés (FIFO).
  /// Renvoie le nombre de documents soldés ou partiellement réglés.
  Future<int> enregistrerReglement({
    required String tiersType,
    required String tiersId,
    required String tiersNom,
    required double montant,
    required ModePaiement mode,
    String? reference,
    String? notes,
  }) async {
    if (montant <= 0) throw Exception('Le montant doit être supérieur à 0.');
    final client = tiersType == 'C';
    final sens = client ? 1 : -1; // client : on reçoit ; fournisseur : on verse
    final table = client ? 'clients' : 'fournisseurs';
    // Documents qui créent une dette du tiers (ventes) ou envers lui (achats)
    final types = client ? "('VC','BL','FV')" : "('BR','FA')";

    final db = await DatabaseHelper.instance.database;
    return db.transaction<int>((txn) async {
      final now = maintenantUtc();
      final date = maintenantLocal();
      final regId = nouvelId();
      Map<String, Object?> h(Map<String, Object?> m) =>
          {...m, 'created_at': now, 'updated_at': now, 'sync_status': 1};

      await txn.insert('reglements', h({
        'id': regId,
        'date_reg': date,
        'tiers_type': tiersType,
        'tiers_id': tiersId,
        'sens': sens,
        'montant': round2(montant),
        'mode': mode.code,
        'reference': reference,
        'notes': notes,
      }));

      if (mode == ModePaiement.especes) {
        await txn.insert('mouvements_caisse', h({
          'id': nouvelId(),
          'date_mvt': date,
          'point_vente_id': AppSettings.instance.pointVenteId,
          'sens': sens,
          'montant': round2(montant),
          'libelle': '${client ? 'Règlement client' : 'Règlement fournisseur'} — $tiersNom',
          'source_type': 'REGLEMENT',
          'source_id': regId,
        }));
      }

      // Le solde du tiers diminue du montant réglé
      await txn.rawUpdate('UPDATE $table SET solde = solde - ?, updated_at = ?, sync_status = 1 WHERE id = ?',
          [round2(montant), now, tiersId]);

      // Affectation FIFO aux documents non soldés
      final docs = await txn.rawQuery('''
        SELECT id, total_ttc, montant_paye FROM documents
        WHERE deleted = 0 AND statut <> 'ANNULE' AND tiers_id = ? AND type_doc IN $types
          AND total_ttc - montant_paye > 0.009
        ORDER BY date_doc ASC
      ''', [tiersId]);

      var reste = round2(montant);
      var nbDocs = 0;
      for (final d in docs) {
        if (reste <= 0) break;
        final du = round2((d['total_ttc'] as num).toDouble() - (d['montant_paye'] as num).toDouble());
        final part = reste < du ? reste : du;
        await txn.rawUpdate(
            'UPDATE documents SET montant_paye = montant_paye + ?, updated_at = ?, sync_status = 1 WHERE id = ?',
            [part, now, d['id']]);
        reste = round2(reste - part);
        nbDocs++;
      }
      return nbDocs;
    });
  }

  Future<List<Reglement>> reglementsRecents(String tiersType, {int limite = 50}) async {
    final db = await DatabaseHelper.instance.database;
    final table = tiersType == 'C' ? 'clients' : 'fournisseurs';
    final rows = await db.rawQuery('''
      SELECT r.*, t.nom AS tiers_nom, d.numero AS doc_numero
      FROM reglements r
      LEFT JOIN $table t ON t.id = r.tiers_id
      LEFT JOIN documents d ON d.id = r.document_id
      WHERE r.deleted = 0 AND r.tiers_type = ?
      ORDER BY r.date_reg DESC LIMIT $limite
    ''', [tiersType]);
    return rows
        .map((r) => Reglement(
              id: r['id'] as String,
              date: DateTime.parse(r['date_reg'] as String),
              tiersNom: (r['tiers_nom'] as String?) ?? '—',
              sens: (r['sens'] as num).toInt(),
              montant: (r['montant'] as num).toDouble(),
              mode: r['mode'] as String,
              reference: r['reference'] as String?,
              documentNumero: r['doc_numero'] as String?,
            ))
        .toList();
  }
}
