// =============================================================================
//  AppSettings — réglages de l'application (Outils > Options, Imprimante,
//  Paramètres > Point de vente)
// =============================================================================
//  Stockés dans la table locale `parametres` (clé / valeur), chargés UNE fois
//  au démarrage (main.dart) puis lus en mémoire partout dans l'app.
//  Exemple : AppSettings.instance.pointVenteCode
// =============================================================================

import 'package:sqflite/sqflite.dart';

import 'package:gestock_pos/core/constants/app_constants.dart';
import 'package:gestock_pos/core/database/database_helper.dart';

class AppSettings {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  // --- Point de vente de cet appareil (numérotation des documents) ---
  String pointVenteId = kPointVenteId;
  String pointVenteCode = kPointVenteCode;

  // --- Options ---
  bool stockNegatifAutorise = false; // autoriser la vente sans stock
  String indicatifPays = '213';      // pour WhatsApp / SMS
  bool vibrations = true;

  // --- Imprimante / ticket (utilisés à l'étape 3 pour le PDF) ---
  int largeurTicketMm = 58;          // 58, 80 ou 210 (A4)
  String enteteTicket = '';
  String piedTicket = 'Merci de votre visite !';
  int copiesTicket = 1;
  bool afficherNifTicket = true;

  /// Lit tous les réglages enregistrés (appelé dans main.dart).
  Future<void> charger() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('parametres');
    final m = {for (final r in rows) r['cle'] as String: (r['valeur'] as String?) ?? ''};

    pointVenteId = m['point_vente_id']?.isNotEmpty == true ? m['point_vente_id']! : kPointVenteId;
    // Le code est relu dans la table points_vente (source de vérité)
    final pv = await db.query('points_vente', where: 'id = ? AND deleted = 0', whereArgs: [pointVenteId], limit: 1);
    pointVenteCode = pv.isEmpty ? kPointVenteCode : pv.first['code'] as String;
    if (pv.isEmpty) pointVenteId = kPointVenteId;

    stockNegatifAutorise = m['stock_negatif_autorise'] == '1';
    indicatifPays = m['indicatif_pays']?.isNotEmpty == true ? m['indicatif_pays']! : '213';
    vibrations = m['vibrations'] != '0';
    largeurTicketMm = int.tryParse(m['ticket_largeur'] ?? '') ?? 58;
    enteteTicket = m['ticket_entete'] ?? '';
    piedTicket = m['ticket_pied'] ?? 'Merci de votre visite !';
    copiesTicket = int.tryParse(m['ticket_copies'] ?? '') ?? 1;
    afficherNifTicket = m['ticket_nif'] != '0';
  }

  /// Enregistre un réglage puis recharge tout.
  Future<void> definir(String cle, String valeur) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('parametres', {'cle': cle, 'valeur': valeur},
        conflictAlgorithm: ConflictAlgorithm.replace);
    await charger();
  }

  Future<void> definirPlusieurs(Map<String, String> valeurs) async {
    final db = await DatabaseHelper.instance.database;
    final b = db.batch();
    valeurs.forEach((cle, valeur) =>
        b.insert('parametres', {'cle': cle, 'valeur': valeur}, conflictAlgorithm: ConflictAlgorithm.replace));
    await b.commit(noResult: true);
    await charger();
  }
}
