// =============================================================================
//  ArticleRepository — CRUD complet des articles (v2)
// =============================================================================
//  • Créer   : l'article + un mouvement de stock "SI" (stock initial)
//  • Modifier: les infos + un mouvement "AJ" (ajustement) si le stock change
//  • Supprimer : suppression LOGIQUE (deleted = 1) pour garder l'historique des
//    factures et pour que la suppression se propage aux autres appareils.
// =============================================================================

import 'package:sqflite/sqflite.dart';

import 'package:gestock_pos/core/database/database_helper.dart';
import 'package:gestock_pos/core/utils/ids.dart';
import 'package:gestock_pos/data/models/article.dart';

/// Filtres de la liste des articles.
enum FiltreStock { tous, alerte, rupture }

class ArticleRepository {
  // Requête de base avec le nom du fournisseur (jointure)
  static const String _select = '''
    SELECT a.*, f.nom AS fournisseur_nom
    FROM articles a
    LEFT JOIN fournisseurs f ON f.id = a.fournisseur_id
  ''';

  // ------------------------------------------------------------------ Lecture

  /// Recherche (POS et liste des articles) avec filtre de stock optionnel.
  Future<List<Article>> rechercher(
    String saisie, {
    FiltreStock filtre = FiltreStock.tous,
    int limite = 300,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final q = saisie.trim();
    final conditions = <String>['a.deleted = 0', 'a.actif = 1'];
    final args = <Object?>[];

    if (q.isNotEmpty) {
      conditions.add('(a.designation LIKE ? OR a.code LIKE ? OR a.code_barre = ?)');
      args.addAll(['%$q%', '%$q%', q]);
    }
    switch (filtre) {
      case FiltreStock.alerte:
        conditions.add('a.stock <= a.stock_min'); // rupture + sous le seuil
      case FiltreStock.rupture:
        conditions.add('a.stock <= 0');
      case FiltreStock.tous:
        break;
    }

    final rows = await db.rawQuery(
      '$_select WHERE ${conditions.join(' AND ')} '
      'ORDER BY a.designation COLLATE NOCASE LIMIT $limite',
      args,
    );
    return rows.map(Article.fromMap).toList();
  }

  /// Recherche exacte par code-barres ou code (douchette).
  Future<Article?> parCodeBarre(String code) async {
    final c = code.trim();
    if (c.isEmpty) return null;
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
      '$_select WHERE a.deleted = 0 AND a.actif = 1 AND (a.code_barre = ? OR a.code = ?) LIMIT 1',
      [c, c],
    );
    return rows.isEmpty ? null : Article.fromMap(rows.first);
  }

  /// Articles fournis par un fournisseur (les plus urgents en premier).
  Future<List<Article>> parFournisseur(String fournisseurId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
      '$_select WHERE a.deleted = 0 AND a.fournisseur_id = ? '
      'ORDER BY (a.stock <= a.stock_min) DESC, a.designation COLLATE NOCASE',
      [fournisseurId],
    );
    return rows.map(Article.fromMap).toList();
  }

  /// Nombre de ruptures et d'articles sous le seuil (bandeau d'alerte).
  Future<({int ruptures, int sousSeuil})> compterAlertes() async {
    final db = await DatabaseHelper.instance.database;
    final r = await db.rawQuery('''
      SELECT SUM(CASE WHEN stock <= 0 THEN 1 ELSE 0 END) AS ruptures,
             SUM(CASE WHEN stock > 0 AND stock <= stock_min THEN 1 ELSE 0 END) AS sous_seuil
      FROM articles WHERE deleted = 0 AND actif = 1
    ''');
    return (
      ruptures: (r.first['ruptures'] as num?)?.toInt() ?? 0,
      sousSeuil: (r.first['sous_seuil'] as num?)?.toInt() ?? 0,
    );
  }

  /// Propose le prochain code libre : A001, A002…
  Future<String> prochainCode() async {
    final db = await DatabaseHelper.instance.database;
    var n = (Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM articles')) ?? 0) + 1;
    while (true) {
      final code = 'A${n.toString().padLeft(3, '0')}';
      if (!await codeExiste(code)) return code;
      n++;
    }
  }

  Future<bool> codeExiste(String code, {String? saufId}) async {
    final db = await DatabaseHelper.instance.database;
    final r = await db.query('articles',
        columns: ['id'],
        where: saufId == null ? 'code = ?' : 'code = ? AND id <> ?',
        whereArgs: saufId == null ? [code] : [code, saufId],
        limit: 1);
    return r.isNotEmpty;
  }

  // ------------------------------------------------------------- Écriture

  /// Crée un article avec son stock initial.
  Future<void> creer(Article a, {required double stockInitial}) async {
    final db = await DatabaseHelper.instance.database;
    final maintenant = maintenantUtc();
    await db.transaction((txn) async {
      await txn.insert('articles', {
        ...a.toMap(),
        'stock': stockInitial,
        'created_at': maintenant,
        'updated_at': maintenant,
        'sync_status': 1,
      });
      if (stockInitial != 0) {
        await _mouvement(txn, a, 'SI', stockInitial, stockInitial, maintenant);
      }
    });
  }

  /// Modifie un article. Si `nouveauStock` diffère du stock actuel, un
  /// mouvement d'ajustement (inventaire) est enregistré.
  Future<void> modifier(Article a, {double? nouveauStock}) async {
    final db = await DatabaseHelper.instance.database;
    final maintenant = maintenantUtc();
    await db.transaction((txn) async {
      await txn.update(
        'articles',
        {...a.toMap(), 'updated_at': maintenant, 'sync_status': 1},
        where: 'id = ?',
        whereArgs: [a.id],
      );
      if (nouveauStock != null) {
        final r = await txn.query('articles', columns: ['stock'], where: 'id = ?', whereArgs: [a.id]);
        final actuel = (r.first['stock'] as num).toDouble();
        final ecart = nouveauStock - actuel;
        if (ecart.abs() > 0.0001) {
          await txn.update('articles', {'stock': nouveauStock}, where: 'id = ?', whereArgs: [a.id]);
          await _mouvement(txn, a, 'AJ', ecart, nouveauStock, maintenant);
        }
      }
    });
  }

  /// Suppression logique.
  Future<void> supprimer(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'articles',
      {'deleted': 1, 'actif': 0, 'updated_at': maintenantUtc(), 'sync_status': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Journal des mouvements : quantité toujours positive, le signe va dans `sens`.
  Future<void> _mouvement(Transaction txn, Article a, String type, double qteSignee,
      double stockApres, String maintenant) {
    return txn.insert('mouvements_stock', {
      'id': nouvelId(),
      'article_id': a.id,
      'date_mvt': maintenantLocal(),
      'type_doc': type, // SI = stock initial, AJ = ajustement d'inventaire
      'sens': qteSignee >= 0 ? 1 : -1,
      'quantite': qteSignee.abs(),
      'stock_apres': stockApres,
      'cout_unitaire': a.prixAchatHt,
      'created_at': maintenant,
      'updated_at': maintenant,
      'sync_status': 1,
    });
  }
}
