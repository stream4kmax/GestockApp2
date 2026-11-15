// =============================================================================
//  SCHÉMA DE LA BASE SQLite LOCALE
// =============================================================================
//  Principes appliqués à toutes les tables "métier" :
//
//   • id TEXT (UUID)  → unique sur tous les appareils (pas de conflit de synchro)
//   • created_at / updated_at (UTC ISO-8601) → la synchro garde la version la
//     plus récente ("last write wins")
//   • deleted 0/1     → suppression LOGIQUE : on ne supprime jamais une ligne,
//     sinon les autres appareils ne sauraient pas qu'elle a disparu
//   • sync_status     → 1 = modifié localement, à envoyer au cloud
//                       0 = synchronisé
//
//  Les tables techniques locales (compteurs, parametres) n'ont pas ces colonnes.
// =============================================================================

class DatabaseSchema {
  DatabaseSchema._();

  /// Colonnes communes de synchronisation, ajoutées à chaque table métier.
  static const String _sync = '''
    created_at   TEXT    NOT NULL,
    updated_at   TEXT    NOT NULL,
    deleted      INTEGER NOT NULL DEFAULT 0,
    sync_status  INTEGER NOT NULL DEFAULT 1''';

  static const List<String> createStatements = [
    // ------------------------------------------------------------------
    // PARAMÈTRES > Société : en-tête des factures (identifiants fiscaux DZ)
    // ------------------------------------------------------------------
    '''
    CREATE TABLE societe (
      id              TEXT PRIMARY KEY,
      raison_sociale  TEXT NOT NULL,
      activite        TEXT,
      adresse         TEXT,
      telephone       TEXT,
      email           TEXT,
      nif             TEXT,          -- Numéro d'identification fiscale
      nis             TEXT,          -- Numéro d'identification statistique
      rc              TEXT,          -- Registre du commerce
      art             TEXT,          -- Article d'imposition
      rib             TEXT,
      logo_path       TEXT,          -- Chemin local du logo (pour le PDF)
      devise          TEXT NOT NULL DEFAULT 'DA',
      $_sync
    )''',

    // PARAMÈTRES > Taxes (TVA)
    '''
    CREATE TABLE taxes (
      id          TEXT PRIMARY KEY,
      libelle     TEXT NOT NULL,
      taux        REAL NOT NULL,      -- en %, ex. 19
      par_defaut  INTEGER NOT NULL DEFAULT 0,
      $_sync
    )''',

    // PARAMÈTRES > Commerciaux
    '''
    CREATE TABLE commerciaux (
      id               TEXT PRIMARY KEY,
      nom              TEXT NOT NULL,
      telephone        TEXT,
      taux_commission  REAL NOT NULL DEFAULT 0,
      $_sync
    )''',

    // PARAMÈTRES > Points de vente (magasins / caisses)
    '''
    CREATE TABLE points_vente (
      id       TEXT PRIMARY KEY,
      code     TEXT NOT NULL UNIQUE,  -- ex. PV1 (utilisé dans les numéros)
      libelle  TEXT NOT NULL,
      adresse  TEXT,
      $_sync
    )''',

    // ------------------------------------------------------------------
    // ARTICLE > Familles d'articles (arborescence possible via parent_id)
    // ------------------------------------------------------------------
    '''
    CREATE TABLE familles (
      id         TEXT PRIMARY KEY,
      code       TEXT,
      libelle    TEXT NOT NULL,
      parent_id  TEXT REFERENCES familles(id),
      $_sync
    )''',

    // ARTICLE > Liste des articles + état du stock
    '''
    CREATE TABLE articles (
      id             TEXT PRIMARY KEY,
      code           TEXT NOT NULL UNIQUE,
      code_barre     TEXT,
      designation    TEXT NOT NULL,
      famille_id     TEXT REFERENCES familles(id),
      unite          TEXT NOT NULL DEFAULT 'U',     -- U, kg, L, carton…
      prix_achat_ht  REAL NOT NULL DEFAULT 0,       -- dernier prix / PMP
      prix_vente_ht  REAL NOT NULL DEFAULT 0,       -- prix détail
      prix_gros_ht   REAL,                          -- prix grossiste (optionnel)
      taux_tva       REAL NOT NULL DEFAULT 19,
      stock          REAL NOT NULL DEFAULT 0,       -- quantité en stock (cache)
      stock_min      REAL NOT NULL DEFAULT 0,       -- seuil d'alerte "rupture"
      stock_max      REAL,
      actif          INTEGER NOT NULL DEFAULT 1,
      image_path     TEXT,
      fournisseur_id TEXT REFERENCES fournisseurs(id), -- v2 : fournisseur principal
      $_sync
    )''',

    // ------------------------------------------------------------------
    // TIERS : clients et fournisseurs
    // ------------------------------------------------------------------
    '''
    CREATE TABLE clients (
      id              TEXT PRIMARY KEY,
      code            TEXT,
      nom             TEXT NOT NULL,
      telephone       TEXT,          -- pour SMS
      whatsapp        TEXT,          -- format international : 213550000000
      email           TEXT,
      adresse         TEXT,
      nif             TEXT,
      rc              TEXT,
      solde           REAL NOT NULL DEFAULT 0,  -- > 0 : le client nous doit
      plafond_credit  REAL NOT NULL DEFAULT 0,  -- 0 = pas de limite
      commercial_id   TEXT REFERENCES commerciaux(id),
      type_tarif      TEXT NOT NULL DEFAULT 'DETAIL', -- v2 : DETAIL ou GROS par défaut
      notes           TEXT,
      $_sync
    )''',

    '''
    CREATE TABLE fournisseurs (
      id         TEXT PRIMARY KEY,
      code       TEXT,
      nom        TEXT NOT NULL,
      telephone  TEXT,
      whatsapp   TEXT,
      email      TEXT,
      adresse    TEXT,
      nif        TEXT,
      rc         TEXT,
      solde      REAL NOT NULL DEFAULT 0,  -- > 0 : nous devons au fournisseur
      $_sync
    )''',

    // ------------------------------------------------------------------
    // DOCUMENTS : en-tête commun à tous les bons / factures (voir TypeDocument)
    // ------------------------------------------------------------------
    '''
    CREATE TABLE documents (
      id                  TEXT PRIMARY KEY,
      numero              TEXT NOT NULL UNIQUE,   -- VC-PV1-2026-00001
      type_doc            TEXT NOT NULL,          -- VC, BL, FV, RC, CC, PF, AV, BR, RF, FA, CF, BE, BS
      date_doc            TEXT NOT NULL,          -- date métier (heure locale)
      tiers_type          TEXT,                   -- 'C' client, 'F' fournisseur, NULL (bons de stock)
      tiers_id            TEXT,
      tiers_nom           TEXT,                   -- copie du nom au moment du document
      commercial_id       TEXT,
      point_vente_id      TEXT,
      document_source_id  TEXT REFERENCES documents(id), -- ex. Facture créée depuis un BL
      statut              TEXT NOT NULL DEFAULT 'VALIDE', -- BROUILLON, VALIDE, ANNULE, TRANSFORME
      total_ht_brut       REAL NOT NULL DEFAULT 0,
      remise_globale      REAL NOT NULL DEFAULT 0,
      total_ht            REAL NOT NULL DEFAULT 0,
      total_tva           REAL NOT NULL DEFAULT 0,
      timbre              REAL NOT NULL DEFAULT 0, -- droit de timbre (paramétrable)
      total_ttc           REAL NOT NULL DEFAULT 0,
      montant_paye        REAL NOT NULL DEFAULT 0,
      mode_paiement       TEXT,
      echeance            TEXT,                    -- date limite de paiement
      type_tarif          TEXT NOT NULL DEFAULT 'DETAIL', -- v2 : vente au détail ou en gros
      notes               TEXT,
      $_sync
    )''',

    // Lignes des documents. Les prix/désignations sont COPIÉS : si le prix de
    // l'article change demain, l'ancienne facture reste identique.
    '''
    CREATE TABLE document_lignes (
      id                TEXT PRIMARY KEY,
      document_id       TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
      article_id        TEXT REFERENCES articles(id),
      designation       TEXT NOT NULL,
      quantite          REAL NOT NULL,
      prix_unitaire_ht  REAL NOT NULL,
      prix_achat_ht     REAL NOT NULL DEFAULT 0,  -- v2 : coût figé → calcul du bénéfice
      remise_pct        REAL NOT NULL DEFAULT 0,
      taux_tva          REAL NOT NULL DEFAULT 0,
      montant_ht        REAL NOT NULL,
      montant_tva       REAL NOT NULL,
      montant_ttc       REAL NOT NULL,
      ordre             INTEGER NOT NULL DEFAULT 0,
      $_sync
    )''',

    // ARTICLE > Mouvements de stock (journal en AJOUT SEUL : jamais modifié).
    // C'est la source de vérité : articles.stock n'est qu'un cache recalculable.
    // En multi-appareils, on synchronise les mouvements, pas le champ stock.
    '''
    CREATE TABLE mouvements_stock (
      id             TEXT PRIMARY KEY,
      article_id     TEXT NOT NULL REFERENCES articles(id),
      date_mvt       TEXT NOT NULL,
      type_doc       TEXT NOT NULL,
      document_id    TEXT REFERENCES documents(id),
      sens           INTEGER NOT NULL,       -- +1 entrée, -1 sortie
      quantite       REAL NOT NULL,          -- toujours positive
      stock_apres    REAL,                   -- stock local après le mouvement (info)
      cout_unitaire  REAL,
      $_sync
    )''',

    // ------------------------------------------------------------------
    // TRÉSORERIE
    // ------------------------------------------------------------------
    // Règlements client ET fournisseur (tiers_type = 'C' ou 'F')
    '''
    CREATE TABLE reglements (
      id           TEXT PRIMARY KEY,
      date_reg     TEXT NOT NULL,
      tiers_type   TEXT NOT NULL,
      tiers_id     TEXT NOT NULL,
      document_id  TEXT REFERENCES documents(id),  -- NULL = acompte libre
      sens         INTEGER NOT NULL DEFAULT 1,     -- +1 reçu, -1 versé/remboursé
      montant      REAL NOT NULL,
      mode         TEXT NOT NULL,                  -- ESPECES, CHEQUE, …
      reference    TEXT,                           -- n° de chèque, de virement…
      notes        TEXT,
      $_sync
    )''',

    // Mouvements de caisse (espèces) → "État de caisse" = SUM(sens * montant)
    '''
    CREATE TABLE mouvements_caisse (
      id              TEXT PRIMARY KEY,
      date_mvt        TEXT NOT NULL,
      point_vente_id  TEXT,
      sens            INTEGER NOT NULL,      -- +1 entrée, -1 sortie
      montant         REAL NOT NULL,
      libelle         TEXT NOT NULL,
      source_type     TEXT,                  -- REGLEMENT, DEPENSE, APPORT, RETRAIT
      source_id       TEXT,
      $_sync
    )''',

    // ------------------------------------------------------------------
    // MESSAGERIE : historique des envois WhatsApp / SMS / Email
    // (sert aussi au module "Relance client / fournisseur")
    // ------------------------------------------------------------------
    '''
    CREATE TABLE messages (
      id            TEXT PRIMARY KEY,
      date_envoi    TEXT NOT NULL,
      tiers_type    TEXT,
      tiers_id      TEXT,
      document_id   TEXT REFERENCES documents(id),
      canal         TEXT NOT NULL,        -- WHATSAPP, SMS, EMAIL
      objet         TEXT NOT NULL,        -- FACTURE, RELANCE, PROMO
      destinataire  TEXT NOT NULL,        -- n° ou adresse e-mail
      contenu       TEXT NOT NULL,
      piece_jointe  TEXT,                 -- chemin du PDF envoyé
      statut        TEXT NOT NULL DEFAULT 'ENVOYE',
      $_sync
    )''',

    // ------------------------------------------------------------------
    // TABLES TECHNIQUES LOCALES (non synchronisées)
    // ------------------------------------------------------------------
    // Compteur de numérotation par type / point de vente / année
    '''
    CREATE TABLE compteurs (
      type_doc     TEXT NOT NULL,
      point_vente  TEXT NOT NULL,
      annee        INTEGER NOT NULL,
      dernier      INTEGER NOT NULL,
      PRIMARY KEY (type_doc, point_vente, annee)
    )''',

    // OUTILS > Options : paires clé / valeur
    '''
    CREATE TABLE parametres (
      cle     TEXT PRIMARY KEY,
      valeur  TEXT
    )''',

    // ------------------------------------------------------------------
    // INDEX : accélèrent les recherches fréquentes
    // ------------------------------------------------------------------
    'CREATE INDEX idx_articles_designation ON articles(designation)',
    'CREATE INDEX idx_articles_code_barre ON articles(code_barre)',
    'CREATE INDEX idx_documents_type_date ON documents(type_doc, date_doc)',
    'CREATE INDEX idx_documents_tiers ON documents(tiers_type, tiers_id)',
    'CREATE INDEX idx_lignes_document ON document_lignes(document_id)',
    'CREATE INDEX idx_lignes_article ON document_lignes(article_id)',
    'CREATE INDEX idx_mvt_stock_article ON mouvements_stock(article_id, date_mvt)',
    'CREATE INDEX idx_reglements_tiers ON reglements(tiers_type, tiers_id)',
    'CREATE INDEX idx_caisse_date ON mouvements_caisse(date_mvt)',
    'CREATE INDEX idx_articles_fournisseur ON articles(fournisseur_id)',
  ];

  // ===========================================================================
  //  MIGRATIONS : pour les téléphones qui ont déjà installé une version
  //  précédente (onCreate n'est PAS rejoué chez eux, seul onUpgrade l'est).
  // ===========================================================================
  static const List<String> migrationV2 = [
    'ALTER TABLE articles ADD COLUMN fournisseur_id TEXT REFERENCES fournisseurs(id)',
    "ALTER TABLE clients ADD COLUMN type_tarif TEXT NOT NULL DEFAULT 'DETAIL'",
    "ALTER TABLE documents ADD COLUMN type_tarif TEXT NOT NULL DEFAULT 'DETAIL'",
    'ALTER TABLE document_lignes ADD COLUMN prix_achat_ht REAL NOT NULL DEFAULT 0',
    'CREATE INDEX IF NOT EXISTS idx_articles_fournisseur ON articles(fournisseur_id)',
    // Les ventes déjà faites reçoivent le prix d'achat actuel de l'article
    // (meilleure estimation possible pour calculer leur bénéfice).
    '''UPDATE document_lignes SET prix_achat_ht =
         COALESCE((SELECT a.prix_achat_ht FROM articles a WHERE a.id = document_lignes.article_id), 0)''',
    // Prix de gros manquant → 8 % sous le prix de détail (à corriger dans la fiche article)
    'UPDATE articles SET prix_gros_ht = ROUND(prix_vente_ht * 0.92, 2) WHERE prix_gros_ht IS NULL',
  ];

  /// Liste des tables à synchroniser avec le cloud (étape 5).
  static const List<String> tablesSynchronisees = [
    'societe', 'taxes', 'commerciaux', 'points_vente', 'familles', 'articles',
    'clients', 'fournisseurs', 'documents', 'document_lignes',
    'mouvements_stock', 'reglements', 'mouvements_caisse', 'messages',
  ];
}
