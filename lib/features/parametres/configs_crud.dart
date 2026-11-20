// =============================================================================
//  Configurations des écrans CRUD simples
// =============================================================================
//  Taxes, Commerciaux, Points de vente, Familles d'articles : chaque écran est
//  une simple description, l'affichage est fait par CrudSimplePage.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'package:gestock_pos/core/database/database_helper.dart';
import 'package:gestock_pos/core/settings/app_settings.dart';
import 'package:gestock_pos/core/theme/app_colors.dart';
import 'package:gestock_pos/core/utils/formatters.dart';
import 'package:gestock_pos/core/utils/ids.dart';
import 'package:gestock_pos/features/parametres/crud_simple_page.dart';

String _txt(Object? v) => (v as String?) ?? '';
double _num(Object? v) => (v as num?)?.toDouble() ?? 0;

// ------------------------------------------------------------------- TAXES
final configTaxes = ConfigCrud(
  table: 'taxes',
  titre: 'Taxes (TVA)',
  singulier: 'la taxe',
  icone: Icons.percent,
  couleur: AppColors.parametres,
  orderBy: 'taux DESC',
  aide: 'Les taux proposés dans la fiche article. La taxe « par défaut » est présélectionnée '
      'pour chaque nouvel article.',
  champs: const [
    ChampCrud('libelle', 'Libellé', obligatoire: true, aide: 'Ex. TVA 19 %'),
    ChampCrud('taux', 'Taux', type: TypeChamp.nombre, obligatoire: true, suffixe: '%'),
    ChampCrud('par_defaut', 'Taxe par défaut', type: TypeChamp.booleen),
  ],
  titreLigne: (l) => _txt(l['libelle']),
  sousTitreLigne: (l) => '${fmtQte(_num(l['taux']))} %${(l['par_defaut'] as int? ?? 0) == 1 ? ' · par défaut' : ''}',
  // Une seule taxe par défaut : on décoche les autres
  apresEnregistrement: (id, v) async {
    if (v['par_defaut'] == 1) {
      final db = await DatabaseHelper.instance.database;
      await db.update('taxes', {'par_defaut': 0, 'updated_at': maintenantUtc(), 'sync_status': 1},
          where: 'id <> ? AND par_defaut = 1', whereArgs: [id]);
    }
  },
);

// -------------------------------------------------------------- COMMERCIAUX
final configCommerciaux = ConfigCrud(
  table: 'commerciaux',
  titre: 'Commerciaux',
  singulier: 'le commercial',
  icone: Icons.badge,
  couleur: AppColors.parametres,
  orderBy: 'nom COLLATE NOCASE',
  aide: 'Vendeurs et représentants. La commission servira aux états de vente par commercial.',
  champs: const [
    ChampCrud('nom', 'Nom', obligatoire: true),
    ChampCrud('telephone', 'Téléphone', type: TypeChamp.telephone),
    ChampCrud('taux_commission', 'Commission', type: TypeChamp.nombre, suffixe: '%'),
  ],
  titreLigne: (l) => _txt(l['nom']),
  sousTitreLigne: (l) => '${_txt(l['telephone']).isEmpty ? 'Pas de téléphone' : _txt(l['telephone'])}'
      ' · commission ${fmtQte(_num(l['taux_commission']))} %',
  // Les clients rattachés à ce commercial sont détachés
  apresSuppression: (id) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('clients', {'commercial_id': null, 'updated_at': maintenantUtc(), 'sync_status': 1},
        where: 'commercial_id = ?', whereArgs: [id]);
  },
);

// ---------------------------------------------------------- POINTS DE VENTE
final configPointsVente = ConfigCrud(
  table: 'points_vente',
  titre: 'Points de vente',
  singulier: 'le point de vente',
  icone: Icons.storefront,
  couleur: AppColors.parametres,
  orderBy: 'code',
  aide: 'Le CODE apparaît dans les numéros de documents (VC-PV1-2026-00001). '
      'Choisissez le point de vente de CET appareil dans Outils > Options. '
      'Donnez un code différent à chaque téléphone pour éviter les doublons.',
  champs: const [
    ChampCrud('code', 'Code (court, sans espace)', obligatoire: true, unique: true, aide: 'Ex. PV1, MAG2'),
    ChampCrud('libelle', 'Nom', obligatoire: true, aide: 'Ex. Magasin centre-ville'),
    ChampCrud('adresse', 'Adresse'),
  ],
  titreLigne: (l) => '${_txt(l['code'])} — ${_txt(l['libelle'])}',
  sousTitreLigne: (l) =>
      l['id'] == AppSettings.instance.pointVenteId ? 'Utilisé par cet appareil' : (_txt(l['adresse']).isEmpty ? '—' : _txt(l['adresse'])),
  avantSuppression: (l) async =>
      l['id'] == AppSettings.instance.pointVenteId ? 'Impossible : c\'est le point de vente de cet appareil.' : null,
  apresEnregistrement: (id, v) async => AppSettings.instance.charger(), // le code a pu changer
);

// ------------------------------------------------------------------ FAMILLES
final configFamilles = ConfigCrud(
  table: 'familles',
  titre: 'Familles d\'articles',
  singulier: 'la famille',
  icone: Icons.category,
  couleur: AppColors.article,
  aide: 'Les familles regroupent les articles (Alimentation, Boissons…). '
      'Supprimer une famille ne supprime pas ses articles.',
  selectSql: '''
    SELECT f.*, (SELECT COUNT(*) FROM articles a WHERE a.famille_id = f.id AND a.deleted = 0) AS nb
    FROM familles f WHERE f.deleted = 0 ORDER BY f.libelle COLLATE NOCASE
  ''',
  champs: const [
    ChampCrud('libelle', 'Nom de la famille', obligatoire: true),
    ChampCrud('code', 'Code', aide: 'Facultatif, ex. ALIM'),
  ],
  titreLigne: (l) => _txt(l['libelle']),
  sousTitreLigne: (l) => '${(l['nb'] as num? ?? 0).toInt()} article(s)${_txt(l['code']).isEmpty ? '' : ' · ${_txt(l['code'])}'}',
  // Les articles de la famille supprimée deviennent "sans famille"
  apresSuppression: (id) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('articles', {'famille_id': null, 'updated_at': maintenantUtc(), 'sync_status': 1},
        where: 'famille_id = ?', whereArgs: [id]);
  },
);

/// Nombre d'éléments d'une table (utilisé par la page Options).
Future<int> compter(String table) async {
  final db = await DatabaseHelper.instance.database;
  return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $table WHERE deleted = 0')) ?? 0;
}
