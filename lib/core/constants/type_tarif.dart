// Type de vente : au DÉTAIL (particuliers) ou en GROS (revendeurs).
// Chaque article a un prix pour chacun des deux types.

enum TypeTarif {
  detail('DETAIL', 'Détail'),
  gros('GROS', 'Gros');

  const TypeTarif(this.code, this.libelle);
  final String code;
  final String libelle;

  static TypeTarif depuisCode(String? code) =>
      code == gros.code ? TypeTarif.gros : TypeTarif.detail;
}
