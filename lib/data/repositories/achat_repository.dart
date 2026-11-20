// =============================================================================
//  AchatRepository — documents fournisseurs et bons de stock
// =============================================================================
//  Types gérés : Bon de réception (BR), Retour fournisseur (RF),
//  Facture d'achat (FA), Bon de commande fournisseur (CF),
//  Bon d'entrée (BE), Bon de sortie (BS).
//
//  Même principe que VenteRepository : UNE transaction pour tout.
//   1. Numéro  2. En-tête  3. Lignes  4. Stock + journal des mouvements
//   5. Mise à jour du prix d'achat des articles (BR / FA, si demandé)
//   6. Paiement au fournisseur : règlement + sortie de caisse (espèces)
//   7. Solde fournisseur (ce que NOUS lui devons)
//   8. Document d'origine (bon de commande) marqué « TRANSFORMÉ »
//
//  Sens des règlements : +1 = argent reçu, −1 = argent versé.
//  Pour un achat on PAIE (−1) ; pour un retour fournisseur on est REMBOURSÉ (+1).
// =============================================================================

import 'package:gestock_pos/core/constants/mode_paiement.dart';
import 'package:gestock_pos/core/constants/type_document.dart';
import 'package:gestock_pos/core/database/database_helper.dart';
import 'package:gestock_pos/core/database/numerotation.dart';
import 'package:gestock_pos/core/settings/app_settings.dart';
import 'package:gestock_pos/core/utils/formatters.dart';
import 'package:gestock_pos/core/utils/ids.dart';
import 'package:gestock_pos/data/models/fournisseur.dart';
import 'package:gestock_pos/data/models/ligne_panier.dart';
import 'package:gestock_pos/data/models/paiement.dart';
import 'package:gestock_pos/data/repositories/vente_repository.dart' show DocumentEnregistre;

/// Totaux d'un document d'achat (pas de remise globale côté achat).
class TotauxAchat {
  const TotauxAchat(this.ht, this.tva, this.ttc);
  final double ht;
  final double tva;
  final double ttc;

  factory TotauxAchat.depuis(List<LignePanier> lignes) {
    double ht = 0, tva = 0;
    for (final l in lignes) {
      ht += l.montantHt;
      tva += l.montantTva;
    }
    return TotauxAchat(round2(ht), round2(tva), round2(ht + tva));
  }
}

class AchatRepository {
  Future<DocumentEnregistre> enregistrer({
    required TypeDocument type,
    required List<LignePanier> lignes,
    Fournisseur? fournisseur,
    Paiement paiement = Paiement.aucun,
    bool majPrixAchat = true,
    String? motif,           // bons d'entrée / de sortie : raison du mouvement
    String? notes,
    String? documentSourceId, // ex. bon de commande réceptionné
  }) async {
    if (lignes.isEmpty) throw Exception('Ajoutez au moins un article.');
    if (type.effetCompte != 0 && fournisseur == null) {
      throw Exception('Choisissez un fournisseur.');
    }
    final totaux = TotauxAchat.depuis(lignes);
    final regle = paiement.encaisse(totaux.ttc); // montant réellement payé
    final resteDu = round2(totaux.ttc - regle);

    final db = await DatabaseHelper.instance.database;
    return db.transaction<DocumentEnregistre>((txn) async {
      final maintenant = maintenantUtc();
      final dateDoc = maintenantLocal();
      final docId = nouvelId();
      Map<String, Object?> h(Map<String, Object?> m) =>
          {...m, 'created_at': maintenant, 'updated_at': maintenant, 'sync_status': 1};

      // Contrôle du stock pour les SORTIES (retour fournisseur, bon de sortie)
      if (type.effetStock < 0 && !AppSettings.instance.stockNegatifAutorise) {
        for (final l in lignes) {
          final r = await txn.query('articles', columns: ['stock'], where: 'id = ?', whereArgs: [l.article.id]);
          final stock = (r.first['stock'] as num).toDouble();
          if (l.quantite > stock) {
            throw Exception('Stock insuffisant pour « ${l.article.designation} » (disponible : ${fmtQte(stock)}).');
          }
        }
      }

      // 1. Numéro
      final numero = await prochainNumero(txn, type);

      // 2. En-tête
      await txn.insert('documents', h({
        'id': docId,
        'numero': numero,
        'type_doc': type.prefixe,
        'date_doc': dateDoc,
        'tiers_type': fournisseur == null ? null : 'F',
        'tiers_id': fournisseur?.id,
        'tiers_nom': fournisseur?.nom ?? motif,
        'point_vente_id': AppSettings.instance.pointVenteId,
        'document_source_id': documentSourceId,
        'statut': 'VALIDE',
        'total_ht_brut': totaux.ht,
        'total_ht': totaux.ht,
        'total_tva': totaux.tva,
        'total_ttc': totaux.ttc,
        'montant_paye': regle,
        'mode_paiement': type.avecPaiement ? paiement.mode.code : null,
        'notes': [if (motif != null && motif.isNotEmpty) motif, if (notes != null && notes.isNotEmpty) notes]
            .join(' — '),
      }));

      // 3, 4, 5. Lignes, stock, prix d'achat
      var ordre = 0;
      for (final l in lignes) {
        await txn.insert('document_lignes', h({
          'id': nouvelId(),
          'document_id': docId,
          'article_id': l.article.id,
          'designation': l.article.designation,
          'quantite': l.quantite,
          'prix_unitaire_ht': l.prixUnitaireHt,
          'prix_achat_ht': l.prixUnitaireHt, // côté achat, prix d'achat = prix du document
          'remise_pct': l.remisePct,
          'taux_tva': l.tauxTva,
          'montant_ht': l.montantHt,
          'montant_tva': l.montantTva,
          'montant_ttc': l.montantTtc,
          'ordre': ordre++,
        }));

        if (type.effetStock != 0) {
          await txn.rawUpdate(
            'UPDATE articles SET stock = stock + ?, updated_at = ?, sync_status = 1 WHERE id = ?',
            [type.effetStock * l.quantite, maintenant, l.article.id],
          );
          final r = await txn.query('articles', columns: ['stock'], where: 'id = ?', whereArgs: [l.article.id]);
          await txn.insert('mouvements_stock', h({
            'id': nouvelId(),
            'article_id': l.article.id,
            'date_mvt': dateDoc,
            'type_doc': type.prefixe,
            'document_id': docId,
            'sens': type.effetStock,
            'quantite': l.quantite,
            'stock_apres': (r.first['stock'] as num).toDouble(),
            'cout_unitaire': l.prixUnitaireHt,
          }));
        }

        // Le dernier prix d'achat devient le prix d'achat de référence de l'article
        final estAchat = type == TypeDocument.receptionFournisseur || type == TypeDocument.factureAchat;
        if (estAchat && majPrixAchat && l.prixUnitaireHt > 0) {
          await txn.update(
            'articles',
            {'prix_achat_ht': l.prixUnitaireHt, 'updated_at': maintenant, 'sync_status': 1},
            where: 'id = ?',
            whereArgs: [l.article.id],
          );
        }
      }

      // 6. Paiement
      if (type.avecPaiement && fournisseur != null && regle > 0) {
        final sens = -type.effetCompte; // achat : on paie (−1) ; retour : on est remboursé (+1)
        final regId = nouvelId();
        await txn.insert('reglements', h({
          'id': regId,
          'date_reg': dateDoc,
          'tiers_type': 'F',
          'tiers_id': fournisseur.id,
          'document_id': docId,
          'sens': sens,
          'montant': regle,
          'mode': paiement.mode.code,
        }));
        if (paiement.mode == ModePaiement.especes) {
          await txn.insert('mouvements_caisse', h({
            'id': nouvelId(),
            'date_mvt': dateDoc,
            'point_vente_id': AppSettings.instance.pointVenteId,
            'sens': sens,
            'montant': regle,
            'libelle': '${type.libelle} $numero — ${fournisseur.nom}',
            'source_type': 'REGLEMENT',
            'source_id': regId,
          }));
        }
      }

      // 7. Solde fournisseur : achat → +reste dû ; retour → −reste dû
      if (type.avecPaiement && fournisseur != null && resteDu != 0) {
        await txn.rawUpdate(
          'UPDATE fournisseurs SET solde = solde + ?, updated_at = ?, sync_status = 1 WHERE id = ?',
          [type.effetCompte * resteDu, maintenant, fournisseur.id],
        );
      }

      // 8. Le bon de commande d'origine est marqué comme transformé
      if (documentSourceId != null) {
        await txn.update('documents', {'statut': 'TRANSFORME', 'updated_at': maintenant, 'sync_status': 1},
            where: 'id = ?', whereArgs: [documentSourceId]);
      }

      return DocumentEnregistre(id: docId, numero: numero);
    });
  }
}
