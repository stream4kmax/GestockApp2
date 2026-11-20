// =============================================================================
//  SoldeRepository — crédits clients et dettes fournisseurs ANTÉRIEURS
// =============================================================================
//  Problème : avant d'utiliser l'application, un client vous devait déjà
//  15 000 DA. Comment le reprendre proprement ?
//
//  Solution : un document spécial « Crédit antérieur client » (SC) ou
//  « Dette antérieure fournisseur » (SF) :
//   ✔ augmente le solde du tiers et apparaît dans l'état de paiement,
//     les relances WhatsApp et le règlement (soldé EN PREMIER) ;
//   ✘ ne touche ni au stock, ni au chiffre d'affaires, ni au bénéfice.
//
//  « Ajuster le solde » permet ensuite de corriger : hausse = nouveau document
//  SC/SF ; baisse = règlement « Ajustement » (sans mouvement de caisse).
// =============================================================================

import 'package:gestock_pos/core/constants/type_document.dart';
import 'package:gestock_pos/core/database/database_helper.dart';
import 'package:gestock_pos/core/database/numerotation.dart';
import 'package:gestock_pos/core/settings/app_settings.dart';
import 'package:gestock_pos/core/utils/formatters.dart';
import 'package:gestock_pos/core/utils/ids.dart';
import 'package:gestock_pos/data/repositories/tresorerie_repository.dart';

class SoldeRepository {
  /// Crée le document de solde initial et augmente le solde du tiers.
  /// tiersType : 'C' (client, ce qu'il VOUS doit) ou 'F' (ce que VOUS devez).
  Future<String> creerSoldeInitial({
    required String tiersType,
    required String tiersId,
    required String tiersNom,
    required double montant,
    String? notes,
  }) async {
    final m = round2(montant);
    if (m <= 0) throw Exception('Le montant doit être supérieur à 0.');
    final client = tiersType == 'C';
    final type = client ? TypeDocument.soldeInitialClient : TypeDocument.soldeInitialFournisseur;
    final libelle = client ? 'Crédit antérieur' : 'Dette antérieure';

    final db = await DatabaseHelper.instance.database;
    return db.transaction<String>((txn) async {
      final now = maintenantUtc();
      final date = maintenantLocal();
      final docId = nouvelId();
      Map<String, Object?> h(Map<String, Object?> x) =>
          {...x, 'created_at': now, 'updated_at': now, 'sync_status': 1};

      final numero = await prochainNumero(txn, type);
      await txn.insert('documents', h({
        'id': docId,
        'numero': numero,
        'type_doc': type.prefixe,
        'date_doc': date,
        'tiers_type': tiersType,
        'tiers_id': tiersId,
        'tiers_nom': tiersNom,
        'point_vente_id': AppSettings.instance.pointVenteId,
        'statut': 'VALIDE',
        'total_ht_brut': m,
        'total_ht': m,
        'total_tva': 0,
        'total_ttc': m,
        'montant_paye': 0,
        'notes': (notes == null || notes.trim().isEmpty)
            ? '$libelle (avant l\'utilisation de l\'application)'
            : notes.trim(),
      }));
      // Une ligne descriptive, pour les messages et la fiche du document
      await txn.insert('document_lignes', h({
        'id': nouvelId(),
        'document_id': docId,
        'article_id': null,
        'designation': libelle,
        'quantite': 1,
        'prix_unitaire_ht': m,
        'prix_achat_ht': 0,
        'remise_pct': 0,
        'taux_tva': 0,
        'montant_ht': m,
        'montant_tva': 0,
        'montant_ttc': m,
        'ordre': 0,
      }));
      await txn.rawUpdate(
        'UPDATE ${client ? 'clients' : 'fournisseurs'} SET solde = solde + ?, updated_at = ?, sync_status = 1 WHERE id = ?',
        [m, now, tiersId],
      );
      return numero;
    });
  }

  /// Met le solde du tiers à `nouveauSolde` (hausse ou baisse).
  /// Renvoie un message décrivant ce qui a été fait.
  Future<String> ajusterSolde({
    required String tiersType,
    required String tiersId,
    required String tiersNom,
    required double soldeActuel,
    required double nouveauSolde,
    String? motif,
  }) async {
    final ecart = round2(nouveauSolde - soldeActuel);
    if (ecart == 0) return 'Aucun changement.';
    if (ecart > 0) {
      final numero = await creerSoldeInitial(
        tiersType: tiersType,
        tiersId: tiersId,
        tiersNom: tiersNom,
        montant: ecart,
        notes: motif == null || motif.trim().isEmpty ? 'Ajustement de solde (+)' : motif,
      );
      return 'Solde augmenté de ${fmtMonnaie(ecart)} ($numero)';
    }
    await TresorerieRepository().reduireSolde(
      tiersType: tiersType,
      tiersId: tiersId,
      tiersNom: tiersNom,
      montant: -ecart,
      motif: motif == null || motif.trim().isEmpty ? 'Ajustement de solde (−)' : motif,
    );
    return 'Solde diminué de ${fmtMonnaie(-ecart)}';
  }
}
