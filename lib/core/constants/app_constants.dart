// Constantes globales de l'application.

/// Client générique utilisé pour les ventes au comptoir (client anonyme).
/// Il est créé automatiquement au premier lancement (database_seed.dart).
/// Règle métier : pas de vente à crédit pour ce client.
const String kClientComptoirId = 'CLIENT-COMPTOIR';

/// Code du point de vente de CET appareil.
/// Il est intégré dans la numérotation des documents (VC-PV1-2026-00001)
/// pour que deux téléphones ne produisent jamais le même numéro de facture.
/// À rendre paramétrable dans Paramètres > Point de vente.
const String kPointVenteCode = 'PV1';
const String kPointVenteId = 'PV-1';
