// =============================================================================
//  Types de documents commerciaux
// =============================================================================
//  TOUS les documents (vente, achat, stock) sont stockés dans UNE SEULE table
//  `documents` + `document_lignes`. C'est le type qui détermine le
//  comportement :
//
//   • effetStock  : +1 = entrée en stock, -1 = sortie, 0 = aucun effet
//   • effetCompte : +1 = augmente ce que le tiers nous doit (vente),
//                   -1 = diminue (avoir / retour), 0 = aucun effet
//                   (proforma, bon de commande = simples propositions)
//
//  Avantage : un seul écran (PosPage) et un seul repository savent gérer
//  Vente comptoir, BL, Facture, Retour, Avoir, Proforma… sans dupliquer le code.
// =============================================================================

enum TypeDocument {
  // ----------------------------- VENTE -----------------------------------
  venteComptoir('VC', 'Vente électronique (POS)', effetStock: -1, effetCompte: 1),
  bonLivraison('BL', 'Bon de livraison', effetStock: -1, effetCompte: 1),
  // Facture directe. Si la facture est créée À PARTIR d'un BL (document_source_id),
  // le stock a déjà été déduit par le BL : le repository ne le déduira pas une 2e fois.
  factureVente('FV', 'Facture', effetStock: -1, effetCompte: 1),
  retourClient('RC', 'Bon de retour client', effetStock: 1, effetCompte: -1),
  commandeClient('CC', 'Bon de commande client', effetStock: 0, effetCompte: 0),
  proforma('PF', 'Facture proforma', effetStock: 0, effetCompte: 0),
  avoir('AV', 'Avoir', effetStock: 1, effetCompte: -1),

  // ----------------------------- ACHAT -----------------------------------
  receptionFournisseur('BR', 'Bon de réception', effetStock: 1, effetCompte: 1),
  retourFournisseur('RF', 'Bon de retour fournisseur', effetStock: -1, effetCompte: -1),
  factureAchat('FA', 'Facture d\'achat', effetStock: 1, effetCompte: 1),
  commandeFournisseur('CF', 'Bon de commande fournisseur', effetStock: 0, effetCompte: 0),

  // ----------------------------- STOCK -----------------------------------
  bonEntree('BE', 'Bon d\'entrée', effetStock: 1, effetCompte: 0),
  bonSortie('BS', 'Bon de sortie', effetStock: -1, effetCompte: 0),

  // ------------------------ SOLDES ANTÉRIEURS (v2c) -----------------------
  // Dettes qui existaient AVANT l'utilisation de l'application. Elles comptent
  // dans le solde et l'état de paiement, mais PAS dans le chiffre d'affaires,
  // le bénéfice ni le stock.
  soldeInitialClient('SC', 'Crédit antérieur client', effetStock: 0, effetCompte: 1),
  soldeInitialFournisseur('SF', 'Dette antérieure fournisseur', effetStock: 0, effetCompte: 1);

  const TypeDocument(this.prefixe, this.libelle,
      {required this.effetStock, required this.effetCompte});

  /// Préfixe stocké en base (colonne documents.type_doc) et utilisé dans le numéro.
  final String prefixe;
  final String libelle;
  final int effetStock;
  final int effetCompte;

  /// Faut-il demander un paiement à la validation ?
  bool get avecPaiement => effetCompte != 0;

  /// Faut-il bloquer la vente si le stock est insuffisant ?
  bool get controleStock => effetStock < 0;

  bool get estVente => const [
        venteComptoir, bonLivraison, factureVente, retourClient,
        commandeClient, proforma, avoir,
      ].contains(this);

  /// Retrouve un type à partir du préfixe lu en base.
  static TypeDocument depuisPrefixe(String p) =>
      TypeDocument.values.firstWhere((t) => t.prefixe == p);
}
