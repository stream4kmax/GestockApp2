// Génération d'identifiants et d'horodatages.
//
// Pourquoi des UUID et pas des entiers auto-incrémentés ?
// → Plusieurs téléphones créent des données hors ligne en même temps.
//   Avec des entiers, deux appareils créeraient tous les deux "l'article n°15"
//   et la synchronisation écraserait l'un par l'autre. Un UUID est unique
//   au monde : aucun conflit possible lors de la fusion dans Firestore.

import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();

/// Nouvel identifiant unique (ex. "3f2b8c1e-…").
String nouvelId() => _uuid.v4();

/// Horodatage technique en UTC (sert à la synchro "dernier modifié gagne").
String maintenantUtc() => DateTime.now().toUtc().toIso8601String();

/// Date "métier" en heure locale (date d'une vente, d'un règlement…).
String maintenantLocal() => DateTime.now().toIso8601String();
