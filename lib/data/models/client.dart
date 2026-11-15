// Modèle Client : représente une ligne de la table `clients`.
// v2 : type de tarif par défaut (Détail / Gros) + conversion vers la base.

import 'package:gestock_pos/core/constants/app_constants.dart';
import 'package:gestock_pos/core/constants/type_tarif.dart';

class Client {
  const Client({
    required this.id,
    required this.nom,
    this.code,
    this.telephone,
    this.whatsapp,
    this.email,
    this.adresse,
    this.nif,
    this.rc,
    this.solde = 0,
    this.plafondCredit = 0,
    this.typeTarif = TypeTarif.detail,
  });

  final String id;
  final String? code;
  final String nom;
  final String? telephone;
  final String? whatsapp;
  final String? email;
  final String? adresse;
  final String? nif;
  final String? rc;
  final double solde;          // ce que le client nous doit
  final double plafondCredit;  // 0 = illimité
  final TypeTarif typeTarif;   // tarif proposé automatiquement au POS

  bool get estComptoir => id == kClientComptoirId;
  bool get encoursDepasse => plafondCredit > 0 && solde > plafondCredit;

  /// Numéro à utiliser pour WhatsApp (repli sur le téléphone).
  String? get numeroWhatsApp =>
      (whatsapp?.trim().isNotEmpty ?? false) ? whatsapp : telephone;

  factory Client.fromMap(Map<String, Object?> m) => Client(
        id: m['id'] as String,
        code: m['code'] as String?,
        nom: m['nom'] as String,
        telephone: m['telephone'] as String?,
        whatsapp: m['whatsapp'] as String?,
        email: m['email'] as String?,
        adresse: m['adresse'] as String?,
        nif: m['nif'] as String?,
        rc: m['rc'] as String?,
        solde: (m['solde'] as num?)?.toDouble() ?? 0,
        plafondCredit: (m['plafond_credit'] as num?)?.toDouble() ?? 0,
        typeTarif: TypeTarif.depuisCode(m['type_tarif'] as String?),
      );

  /// Colonnes modifiables depuis la fiche (le solde n'est changé que par les
  /// ventes et les règlements, jamais à la main).
  Map<String, Object?> toMap() => {
        'id': id,
        'code': code,
        'nom': nom,
        'telephone': _vide(telephone),
        'whatsapp': _vide(whatsapp),
        'email': _vide(email),
        'adresse': _vide(adresse),
        'nif': _vide(nif),
        'rc': _vide(rc),
        'plafond_credit': plafondCredit,
        'type_tarif': typeTarif.code,
      };

  static String? _vide(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
}
