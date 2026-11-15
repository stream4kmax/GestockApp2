// Données insérées au premier lancement, pour que l'application soit
// utilisable immédiatement (et pour tester le POS sans rien saisir).
// Vous pourrez tout modifier ou supprimer ensuite depuis l'application.

import 'package:sqflite/sqflite.dart';

import 'package:gestock_pos/core/constants/app_constants.dart';
import 'package:gestock_pos/core/utils/ids.dart';

class DatabaseSeed {
  DatabaseSeed._();

  static Future<void> inserer(Database db) async {
    final maintenant = maintenantUtc();

    // Ajoute les colonnes created_at / updated_at à chaque ligne.
    Map<String, Object?> h(Map<String, Object?> ligne) =>
        {...ligne, 'created_at': maintenant, 'updated_at': maintenant};

    final b = db.batch();

    // --- Société (à compléter dans Paramètres > Société) ---
    b.insert('societe', h({
      'id': 'SOC-1',
      'raison_sociale': 'Ma Société SARL',
      'activite': 'Commerce de détail',
      'devise': 'DA',
    }));

    // --- Taux de TVA en vigueur en Algérie : 19 % (normal), 9 % (réduit), exonéré ---
    b.insert('taxes', h({'id': 'TVA-19', 'libelle': 'TVA 19 %', 'taux': 19, 'par_defaut': 1}));
    b.insert('taxes', h({'id': 'TVA-9', 'libelle': 'TVA 9 %', 'taux': 9}));
    b.insert('taxes', h({'id': 'TVA-0', 'libelle': 'Exonéré', 'taux': 0}));

    // --- Point de vente de cet appareil ---
    b.insert('points_vente', h({'id': kPointVenteId, 'code': kPointVenteCode, 'libelle': 'Magasin principal'}));

    // --- Familles ---
    b.insert('familles', h({'id': 'FAM-ALIM', 'code': 'ALIM', 'libelle': 'Alimentation'}));
    b.insert('familles', h({'id': 'FAM-BOIS', 'code': 'BOIS', 'libelle': 'Boissons'}));
    b.insert('familles', h({'id': 'FAM-HYG', 'code': 'HYG', 'libelle': 'Hygiène'}));

    // --- Clients ---
    b.insert('clients', h({'id': kClientComptoirId, 'code': 'C000', 'nom': 'Client comptoir'}));
    b.insert('clients', h({
      'id': nouvelId(),
      'code': 'C001',
      'nom': 'Supérette Démo',
      'telephone': '0550000000',
      'whatsapp': '213550000000',
      'email': 'client@exemple.dz',
      'plafond_credit': 50000,
    }));

    // --- Articles de démonstration (certains volontairement sous le seuil) ---
    final articles = [
      // code, désignation, famille, unité, PA HT, PV HT, TVA, stock, seuil, code-barres
      // (dernière colonne v2 : prix de GROS HT)
      ['A001', 'Huile de table 1 L', 'FAM-ALIM', 'U', 520.0, 600.0, 9.0, 40.0, 10.0, '6130000000011', 565.0],
      ['A002', 'Sucre blanc 1 kg', 'FAM-ALIM', 'U', 85.0, 95.0, 9.0, 120.0, 20.0, '6130000000028', 90.0],
      ['A003', 'Café moulu 250 g', 'FAM-ALIM', 'U', 280.0, 340.0, 19.0, 6.0, 10.0, '6130000000035', 315.0],
      ['A004', 'Eau minérale 1,5 L', 'FAM-BOIS', 'U', 30.0, 40.0, 19.0, 200.0, 48.0, '6130000000042', 35.0],
      ['A005', 'Jus d\'orange 1 L', 'FAM-BOIS', 'U', 150.0, 190.0, 19.0, 0.0, 12.0, '6130000000059', 170.0],
      ['A006', 'Savon de Marseille', 'FAM-HYG', 'U', 70.0, 95.0, 19.0, 35.0, 10.0, '6130000000066', 85.0],
      ['A007', 'Lentilles vrac', 'FAM-ALIM', 'kg', 210.0, 260.0, 0.0, 25.5, 5.0, null, 240.0],
    ];
    for (final a in articles) {
      b.insert('articles', h({
        'id': nouvelId(),
        'code': a[0],
        'designation': a[1],
        'famille_id': a[2],
        'unite': a[3],
        'prix_achat_ht': a[4],
        'prix_vente_ht': a[5],
        'taux_tva': a[6],
        'stock': a[7],
        'stock_min': a[8],
        'code_barre': a[9],
        'prix_gros_ht': a[10],
      }));
    }

    // --- Options ---
    b.insert('parametres', {'cle': 'stock_negatif_autorise', 'valeur': '0'});
    b.insert('parametres', {'cle': 'timbre_fiscal_actif', 'valeur': '0'});

    await b.commit(noResult: true);

    await fournisseursDemo(db);
  }

  /// v2 : deux fournisseurs de démonstration, reliés aux articles par famille.
  static Future<void> fournisseursDemo(Database db) async {
    final nb = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM fournisseurs')) ?? 0;
    if (nb > 0) return;
    final maintenant = maintenantUtc();
    final b = db.batch();
    b.insert('fournisseurs', {
      'id': 'FRN-1', 'code': 'F001', 'nom': 'Grossiste Alimentaire Démo',
      'telephone': '0660000000', 'whatsapp': '213660000000', 'adresse': 'Zone d\'activités',
      'created_at': maintenant, 'updated_at': maintenant,
    });
    b.insert('fournisseurs', {
      'id': 'FRN-2', 'code': 'F002', 'nom': 'Distributeur Boissons & Hygiène',
      'telephone': '0770000000', 'whatsapp': '213770000000',
      'created_at': maintenant, 'updated_at': maintenant,
    });
    b.rawUpdate("UPDATE articles SET fournisseur_id = 'FRN-1' WHERE famille_id = 'FAM-ALIM' AND fournisseur_id IS NULL");
    b.rawUpdate("UPDATE articles SET fournisseur_id = 'FRN-2' WHERE famille_id IN ('FAM-BOIS','FAM-HYG') AND fournisseur_id IS NULL");
    await b.commit(noResult: true);
  }
}
