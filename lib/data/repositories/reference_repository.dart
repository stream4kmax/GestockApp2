// Données de référence pour les listes déroulantes : taxes, familles, société.

import 'package:gestock_pos/core/database/database_helper.dart';

class Taxe {
  const Taxe(this.id, this.libelle, this.taux, this.parDefaut);
  final String id;
  final String libelle;
  final double taux;
  final bool parDefaut;
}

class Famille {
  const Famille(this.id, this.libelle);
  final String id;
  final String libelle;
}

class ReferenceRepository {
  Future<List<Taxe>> taxes() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('taxes', where: 'deleted = 0', orderBy: 'taux DESC');
    return rows
        .map((r) => Taxe(r['id'] as String, r['libelle'] as String, (r['taux'] as num).toDouble(),
            (r['par_defaut'] as int) == 1))
        .toList();
  }

  Future<List<Famille>> familles() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('familles', where: 'deleted = 0', orderBy: 'libelle COLLATE NOCASE');
    return rows.map((r) => Famille(r['id'] as String, r['libelle'] as String)).toList();
  }

  /// Nom commercial affiché en signature des messages.
  Future<String> raisonSociale() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('societe', columns: ['raison_sociale'], limit: 1);
    return rows.isEmpty ? '' : (rows.first['raison_sociale'] as String? ?? '');
  }
}
