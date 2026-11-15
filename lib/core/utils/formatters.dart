// Outils de formatage et de calcul utilisés partout dans l'application.

import 'package:intl/intl.dart';

/// Format monétaire : 1 234,50 DA
final NumberFormat _monnaie =
    NumberFormat.currency(locale: 'fr_FR', symbol: 'DA', decimalDigits: 2);

/// Format quantité : 3 / 2,5 / 0,125 (jusqu'à 3 décimales, pour le vrac en kg)
final NumberFormat _quantite = NumberFormat('#,##0.###', 'fr_FR');

String fmtMonnaie(num valeur) => _monnaie.format(valeur);
String fmtQte(num valeur) => _quantite.format(valeur);
String fmtDate(DateTime d) => DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(d);

/// Arrondi commercial à 2 décimales.
///
/// Remarque : on stocke les montants en REAL (double) pour rester simple.
/// Pour une rigueur comptable absolue, on peut stocker des centimes en
/// INTEGER ; il suffira de changer ce helper et les modèles.
double round2(num v) => (v * 100).roundToDouble() / 100;

/// Convertit une saisie utilisateur en nombre : accepte "12,5", "12.5", "1 200".
double? parseNombre(String saisie) => double.tryParse(saisie
    // \s couvre aussi les espaces insécables du format français (U+00A0, U+202F)
    .replaceAll(RegExp(r'\s'), '')
    .replaceAll('DA', '')
    .replaceAll(',', '.'));
