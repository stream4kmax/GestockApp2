// Numérotation des documents, partagée par les ventes, les achats et les bons
// de stock : TYPE-POINTDEVENTE-ANNÉE-NUMÉRO, ex. BR-PV1-2026-00007.
// Le compteur repart à 1 chaque année et est propre à chaque point de vente.

import 'package:sqflite/sqflite.dart';

import 'package:gestock_pos/core/constants/type_document.dart';
import 'package:gestock_pos/core/settings/app_settings.dart';

Future<String> prochainNumero(Transaction txn, TypeDocument type) async {
  final annee = DateTime.now().year;
  final pv = AppSettings.instance.pointVenteCode;
  final rows = await txn.query(
    'compteurs',
    where: 'type_doc = ? AND point_vente = ? AND annee = ?',
    whereArgs: [type.prefixe, pv, annee],
  );
  final suivant = rows.isEmpty ? 1 : (rows.first['dernier'] as int) + 1;
  await txn.insert(
    'compteurs',
    {'type_doc': type.prefixe, 'point_vente': pv, 'annee': annee, 'dernier': suivant},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
  return '${type.prefixe}-$pv-$annee-${suivant.toString().padLeft(5, '0')}';
}
