// =============================================================================
//  DatabaseHelper — accès unique à la base SQLite
// =============================================================================
//  Patron "Singleton" : une seule connexion ouverte pour toute l'application.
//  Utilisation : final db = await DatabaseHelper.instance.database;
// =============================================================================

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:gestock_pos/core/database/database_schema.dart';
import 'package:gestock_pos/core/database/database_seed.dart';

class DatabaseHelper {
  DatabaseHelper._(); // constructeur privé : empêche "new DatabaseHelper()"
  static final DatabaseHelper instance = DatabaseHelper._();

  static const String _nomFichier = 'gestock.db';

  /// Incrémenter ce numéro à chaque modification du schéma, puis écrire la
  /// migration correspondante dans _onUpgrade (ne jamais modifier onCreate seul,
  /// sinon les utilisateurs existants n'auraient pas les nouvelles colonnes).
  static const int _version = 2; // v2 : prix de gros, fournisseurs, bénéfice

  Database? _db;

  /// Ouvre la base au premier appel, puis renvoie toujours la même instance.
  Future<Database> get database async => _db ??= await _ouvrir();

  Future<Database> _ouvrir() async {
    final dossier = await getDatabasesPath(); // /data/data/<app>/databases
    final chemin = p.join(dossier, _nomFichier);

    return openDatabase(
      chemin,
      version: _version,
      // Active les clés étrangères (désactivées par défaut dans SQLite).
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Appelé UNE SEULE FOIS, au tout premier lancement de l'application.
  Future<void> _onCreate(Database db, int version) async {
    // Un "batch" exécute toutes les requêtes en une seule transaction : rapide
    // et atomique (soit tout est créé, soit rien).
    final batch = db.batch();
    for (final sql in DatabaseSchema.createStatements) {
      batch.execute(sql);
    }
    await batch.commit(noResult: true);

    // Données de départ : société, TVA, client comptoir, articles de démo…
    await DatabaseSeed.inserer(db);
  }

  /// Migrations entre versions. Exemple pour une future version 2 :
  ///   if (oldVersion < 2) {
  ///     await db.execute('ALTER TABLE articles ADD COLUMN emplacement TEXT');
  ///   }
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      final batch = db.batch();
      for (final sql in DatabaseSchema.migrationV2) {
        batch.execute(sql);
      }
      await batch.commit(noResult: true);
      // Fournisseurs de démonstration (seulement si la table est vide)
      await DatabaseSeed.fournisseursDemo(db);
    }
    // if (oldVersion < 3) { ... prochaine migration ... }
  }

  /// Ferme la base (utile pour les tests ou une restauration de sauvegarde).
  Future<void> fermer() async {
    await _db?.close();
    _db = null;
  }
}
