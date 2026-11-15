// FournisseurRepository — CRUD + compteurs de réapprovisionnement.

import 'package:gestock_pos/core/database/database_helper.dart';
import 'package:gestock_pos/core/utils/ids.dart';
import 'package:gestock_pos/data/models/fournisseur.dart';

class FournisseurRepository {
  /// Liste avec, pour chaque fournisseur, le nombre d'articles fournis et le
  /// nombre d'articles à réapprovisionner (stock ≤ seuil minimum).
  Future<List<FournisseurResume>> tous({String recherche = ''}) async {
    final db = await DatabaseHelper.instance.database;
    final q = recherche.trim();
    final rows = await db.rawQuery('''
      SELECT f.*,
        (SELECT COUNT(*) FROM articles a
           WHERE a.fournisseur_id = f.id AND a.deleted = 0) AS nb_articles,
        (SELECT COUNT(*) FROM articles a
           WHERE a.fournisseur_id = f.id AND a.deleted = 0 AND a.stock <= a.stock_min) AS nb_alertes
      FROM fournisseurs f
      WHERE f.deleted = 0 ${q.isEmpty ? '' : 'AND (f.nom LIKE ? OR f.telephone LIKE ?)'}
      ORDER BY nb_alertes DESC, f.nom COLLATE NOCASE
    ''', q.isEmpty ? [] : ['%$q%', '%$q%']);

    return rows
        .map((r) => FournisseurResume(
              Fournisseur.fromMap(r),
              (r['nb_articles'] as num).toInt(),
              (r['nb_alertes'] as num).toInt(),
            ))
        .toList();
  }

  /// Liste simple (pour la liste déroulante de la fiche article).
  Future<List<Fournisseur>> listeSimple() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('fournisseurs', where: 'deleted = 0', orderBy: 'nom COLLATE NOCASE');
    return rows.map(Fournisseur.fromMap).toList();
  }

  Future<Fournisseur?> parId(String id) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('fournisseurs', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Fournisseur.fromMap(rows.first);
  }

  Future<String> creer(Fournisseur f) async {
    final db = await DatabaseHelper.instance.database;
    final now = maintenantUtc();
    final id = f.id.isEmpty ? nouvelId() : f.id;
    await db.insert('fournisseurs',
        {...f.toMap(), 'id': id, 'created_at': now, 'updated_at': now, 'sync_status': 1});
    return id;
  }

  Future<void> modifier(Fournisseur f) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('fournisseurs', {...f.toMap(), 'updated_at': maintenantUtc(), 'sync_status': 1},
        where: 'id = ?', whereArgs: [f.id]);
  }

  /// Suppression logique ; les articles liés sont détachés du fournisseur.
  Future<void> supprimer(String id) async {
    final db = await DatabaseHelper.instance.database;
    final now = maintenantUtc();
    await db.transaction((txn) async {
      await txn.update('fournisseurs', {'deleted': 1, 'updated_at': now, 'sync_status': 1},
          where: 'id = ?', whereArgs: [id]);
      await txn.update('articles', {'fournisseur_id': null, 'updated_at': now, 'sync_status': 1},
          where: 'fournisseur_id = ?', whereArgs: [id]);
    });
  }
}
