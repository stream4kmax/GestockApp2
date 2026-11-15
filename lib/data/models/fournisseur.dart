// Modèle Fournisseur : table `fournisseurs`.

class Fournisseur {
  const Fournisseur({
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
  final double solde; // ce que NOUS devons au fournisseur

  String? get numeroWhatsApp =>
      (whatsapp?.trim().isNotEmpty ?? false) ? whatsapp : telephone;

  factory Fournisseur.fromMap(Map<String, Object?> m) => Fournisseur(
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
      );

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
      };

  static String? _vide(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
}

/// Fournisseur + compteurs (pour la liste) : nb d'articles fournis et
/// nb d'articles à réapprovisionner (stock ≤ seuil).
class FournisseurResume {
  const FournisseurResume(this.fournisseur, this.nbArticles, this.nbAReapprovisionner);
  final Fournisseur fournisseur;
  final int nbArticles;
  final int nbAReapprovisionner;
}
