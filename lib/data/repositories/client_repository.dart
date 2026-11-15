// ClientRepository — liste, recherche, création, modification, suppression.

import 'package:gestock_pos/core/constants/app_constants.dart';
import 'package:gestock_pos/core/database/database_helper.dart';
import 'package:gestock_pos/core/utils/ids.dart';
import 'package:gestock_pos/data/models/client.dart';

enum FiltreClient { tous, debiteurs, encoursDepasse }

class ClientRepository {
  /// Tous les clients (le client comptoir en premier), avec recherche et filtre.
  Future<List<Client>> tous({String recherche = '', FiltreClient filtre = FiltreClient.tous}) async {
    final db = await DatabaseHelper.instance.database;
    final conditions = <String>['deleted = 0'];
    final args = <Object?>[];
    final q = recherche.trim();
    if (q.isNotEmpty) {
      conditions.add('(nom LIKE ? OR telephone LIKE ? OR code LIKE ?)');
      args.addAll(['%$q%', '%$q%', '%$q%']);
    }
    switch (filtre) {
      case FiltreClient.debiteurs:
        conditions.add('solde > 0');
      case FiltreClient.encoursDepasse:
        conditions.add('plafond_credit > 0 AND solde > plafond_credit');
      case FiltreClient.tous:
        break;
    }
    final rows = await db.query(
      'clients',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: "CASE WHEN id = '$kClientComptoirId' THEN 0 ELSE 1 END, nom COLLATE NOCASE",
    );
    return rows.map(Client.fromMap).toList();
  }

  Future<Client?> parId(String id) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('clients', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Client.fromMap(rows.first);
  }

  Future<String> creer(Client c) async {
    final db = await DatabaseHelper.instance.database;
    final now = maintenantUtc();
    final id = c.id.isEmpty ? nouvelId() : c.id;
    final map = c.toMap()..['id'] = id;
    await db.insert('clients', {...map, 'created_at': now, 'updated_at': now, 'sync_status': 1});
    return id;
  }

  Future<void> modifier(Client c) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('clients', {...c.toMap(), 'updated_at': maintenantUtc(), 'sync_status': 1},
        where: 'id = ?', whereArgs: [c.id]);
  }

  /// Suppression logique (le client comptoir ne peut pas être supprimé).
  Future<void> supprimer(String id) async {
    if (id == kClientComptoirId) throw Exception('Le client comptoir ne peut pas être supprimé.');
    final db = await DatabaseHelper.instance.database;
    await db.update('clients', {'deleted': 1, 'updated_at': maintenantUtc(), 'sync_status': 1},
        where: 'id = ?', whereArgs: [id]);
  }
}
