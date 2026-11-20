// =============================================================================
//  VenteRepository — enregistrement d'un document de vente
// =============================================================================
//  Tout se fait dans UNE transaction SQLite : si une seule étape échoue
//  (coupure, erreur…), rien n'est enregistré. On ne peut donc jamais avoir
//  une facture sans ses lignes, ou un stock déduit sans facture.
//
//  Étapes :
//   1. Numéro du document (VC-PV1-2026-00001)
//   2. En-tête dans `documents`
//   3. Lignes dans `document_lignes`
//   4. Stock : mise à jour de l'article + journal `mouvements_stock`
//   5. Paiement : `reglements` + `mouvements_caisse` (si espèces)
//   6. Solde du client (reste dû)
// =============================================================================


import 'package:gestock_pos/core/constants/mode_paiement.dart';
import 'package:gestock_pos/core/constants/type_document.dart';
import 'package:gestock_pos/core/constants/type_tarif.dart';
import 'package:gestock_pos/core/database/database_helper.dart';
import 'package:gestock_pos/core/database/numerotation.dart';
import 'package:gestock_pos/core/settings/app_settings.dart';
import 'package:gestock_pos/core/utils/formatters.dart';
import 'package:gestock_pos/core/utils/ids.dart';
import 'package:gestock_pos/data/models/client.dart';
import 'package:gestock_pos/data/models/ligne_panier.dart';
import 'package:gestock_pos/data/models/paiement.dart';
import 'package:gestock_pos/features/vente/cart_provider.dart';

/// Résultat renvoyé à l'écran après l'enregistrement.
class DocumentEnregistre {
  const DocumentEnregistre({required this.id, required this.numero});
  final String id;
  final String numero;
}

class VenteRepository {
  Future<DocumentEnregistre> enregistrer({
    required TypeDocument type,
    required Client client,
    required List<LignePanier> lignes,
    required TotauxPanier totaux,
    required Paiement paiement,
    TypeTarif typeTarif = TypeTarif.detail, // v2 : vente au détail ou en gros
    String? documentSourceId, // ex. Facture générée depuis un BL
    String? notes,
  }) async {
    // ---------- Contrôles métier AVANT d'écrire quoi que ce soit ----------
    if (lignes.isEmpty) {
      throw Exception('Le panier est vide.');
    }
    final encaisse = paiement.encaisse(totaux.ttc);
    final resteDu = round2(totaux.ttc - encaisse);
    if (type.avecPaiement && client.estComptoir && resteDu > 0) {
      throw Exception('Pas de crédit possible pour le client comptoir.');
    }

    // Un document transformé (Facture issue d'un BL) ne bouge pas le stock une 2e fois.
    final effetStock = documentSourceId != null ? 0 : type.effetStock;

    final db = await DatabaseHelper.instance.database;

    return db.transaction<DocumentEnregistre>((txn) async {
      final maintenant = maintenantUtc();
      final dateDoc = maintenantLocal();
      final docId = nouvelId();

      // Colonnes de synchro : la ligne est "à envoyer" au cloud (sync_status = 1)
      Map<String, Object?> h(Map<String, Object?> m) =>
          {...m, 'created_at': maintenant, 'updated_at': maintenant, 'sync_status': 1};

      // 1. Numérotation
      final numero = await prochainNumero(txn, type); // numérotation partagée (numerotation.dart)

      // 2. En-tête
      await txn.insert('documents', h({
        'id': docId,
        'numero': numero,
        'type_doc': type.prefixe,
        'date_doc': dateDoc,
        'tiers_type': 'C',
        'tiers_id': client.id,
        'tiers_nom': client.nom,
        'point_vente_id': AppSettings.instance.pointVenteId,
        'document_source_id': documentSourceId,
        'statut': 'VALIDE',
        'total_ht_brut': totaux.htBrut,
        'remise_globale': totaux.remiseGlobale,
        'total_ht': totaux.ht,
        'total_tva': totaux.tva,
        'timbre': 0, // droit de timbre : à activer dans Paramètres > Taxes
        'total_ttc': totaux.ttc,
        'montant_paye': encaisse,
        'mode_paiement': type.avecPaiement ? paiement.mode.code : null,
        'notes': notes,
        'type_tarif': typeTarif.code,
      }));

      // 3 & 4. Lignes + stock
      var ordre = 0;
      for (final l in lignes) {
        await txn.insert('document_lignes', h({
          'id': nouvelId(),
          'document_id': docId,
          'article_id': l.article.id,
          'designation': l.article.designation,
          'quantite': l.quantite,
          'prix_unitaire_ht': l.prixUnitaireHt,
          // v2 : prix d'achat figé au moment de la vente → bénéfice exact
          'prix_achat_ht': l.article.prixAchatHt,
          'remise_pct': l.remisePct,
          'taux_tva': l.tauxTva,
          'montant_ht': l.montantHt,
          'montant_tva': l.montantTva,
          'montant_ttc': l.montantTtc,
          'ordre': ordre++,
        }));

        if (effetStock != 0) {
          // Mise à jour ATOMIQUE en SQL (stock = stock ± qté) : pas de risque
          // d'écraser une valeur lue trop tôt.
          await txn.rawUpdate(
            'UPDATE articles SET stock = stock + ?, updated_at = ?, sync_status = 1 WHERE id = ?',
            [effetStock * l.quantite, maintenant, l.article.id],
          );
          final r = await txn.query('articles',
              columns: ['stock'], where: 'id = ?', whereArgs: [l.article.id]);
          final stockApres = (r.first['stock'] as num).toDouble();

          await txn.insert('mouvements_stock', h({
            'id': nouvelId(),
            'article_id': l.article.id,
            'date_mvt': dateDoc,
            'type_doc': type.prefixe,
            'document_id': docId,
            'sens': effetStock,
            'quantite': l.quantite,
            'stock_apres': stockApres,
            'cout_unitaire': l.article.prixAchatHt,
          }));
        }
      }

      // 5. Paiement (vente : le client paie, sens +1 / avoir-retour : on rembourse, sens −1)
      if (type.avecPaiement && encaisse > 0) {
        final reglementId = nouvelId();
        await txn.insert('reglements', h({
          'id': reglementId,
          'date_reg': dateDoc,
          'tiers_type': 'C',
          'tiers_id': client.id,
          'document_id': docId,
          'sens': type.effetCompte,
          'montant': encaisse,
          'mode': paiement.mode.code,
        }));

        // Seules les espèces passent physiquement par la caisse.
        if (paiement.mode == ModePaiement.especes) {
          await txn.insert('mouvements_caisse', h({
            'id': nouvelId(),
            'date_mvt': dateDoc,
            'point_vente_id': AppSettings.instance.pointVenteId,
            'sens': type.effetCompte,
            'montant': encaisse,
            'libelle': '${type.libelle} $numero',
            'source_type': 'REGLEMENT',
            'source_id': reglementId,
          }));
        }
      }

      // 6. Solde client : vente → +reste dû ; avoir/retour → −reste dû
      if (type.avecPaiement && !client.estComptoir && resteDu != 0) {
        await txn.rawUpdate(
          'UPDATE clients SET solde = solde + ?, updated_at = ?, sync_status = 1 WHERE id = ?',
          [type.effetCompte * resteDu, maintenant, client.id],
        );
      }

      return DocumentEnregistre(id: docId, numero: numero);
    });
  }
}
