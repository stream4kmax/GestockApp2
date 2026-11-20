// =============================================================================
//  Déclaration des 6 modules et de leurs sous-menus (v2)
// =============================================================================
//  Étape 2b : TOUS les écrans sont branchés (plus aucun « Bientôt disponible »).
//   • Les documents (achat, bons de stock) ouvrent un HISTORIQUE avec un
//     bouton « + Nouveau » ; la saisie se fait dans DocumentSaisiePage.
//   • Les petites tables (taxes, commerciaux, familles, points de vente)
//     utilisent l'écran générique CrudSimplePage.
//  Un SousModule sans builder affiche « Bientôt disponible ».
// =============================================================================

import 'package:flutter/material.dart';

import 'package:gestock_pos/core/constants/type_document.dart';
import 'package:gestock_pos/core/theme/app_colors.dart';
import 'package:gestock_pos/data/repositories/article_repository.dart';
import 'package:gestock_pos/data/repositories/client_repository.dart';
import 'package:gestock_pos/features/article/article_list_page.dart';
import 'package:gestock_pos/features/article/mouvements_stock_page.dart';
import 'package:gestock_pos/features/article/rapport_article_page.dart';
import 'package:gestock_pos/features/clients/client_list_page.dart';
import 'package:gestock_pos/features/documents/document_list_page.dart';
import 'package:gestock_pos/features/fournisseurs/fournisseur_list_page.dart';
import 'package:gestock_pos/features/outils/calculatrice_page.dart';
import 'package:gestock_pos/features/outils/imprimante_page.dart';
import 'package:gestock_pos/features/outils/options_page.dart';
import 'package:gestock_pos/features/parametres/configs_crud.dart';
import 'package:gestock_pos/features/parametres/crud_simple_page.dart';
import 'package:gestock_pos/features/parametres/societe_page.dart';
import 'package:gestock_pos/features/tresorerie/etat_caisse_page.dart';
import 'package:gestock_pos/features/tresorerie/etat_paiement_page.dart';
import 'package:gestock_pos/features/tresorerie/mouvement_caisse_page.dart';
import 'package:gestock_pos/features/tresorerie/reglement_page.dart';
import 'package:gestock_pos/features/vente/pos_page.dart';

class SousModule {
  const SousModule(this.libelle, this.icone, [this.builder]);
  final String libelle;
  final IconData icone;
  final WidgetBuilder? builder;
}

class ModuleApp {
  const ModuleApp({
    required this.libelle,
    required this.icone,
    required this.iconeActive,
    required this.couleur,
    required this.sousModules,
    this.avecTableauDeBord = false,
  });
  final String libelle;
  final IconData icone;
  final IconData iconeActive;
  final Color couleur;
  final List<SousModule> sousModules;
  final bool avecTableauDeBord;
}

WidgetBuilder _pos(TypeDocument t) => (_) => PosPage(type: t);

/// Historique d'un type de document avec bouton « + Nouveau ».
WidgetBuilder _docs(String titre, TypeDocument t, Color couleur) =>
    (_) => DocumentListPage(titre: titre, types: [t], typeNouveau: t, couleur: couleur);

WidgetBuilder _crud(ConfigCrud c) => (_) => CrudSimplePage(config: c);

final List<ModuleApp> modulesApp = [
  // 1. VENTE (bleu) -----------------------------------------------------------
  ModuleApp(
    libelle: 'Vente',
    icone: Icons.point_of_sale_outlined,
    iconeActive: Icons.point_of_sale,
    couleur: AppColors.vente,
    avecTableauDeBord: true,
    sousModules: [
      SousModule('Vente électronique (POS)', Icons.shopping_cart_checkout, _pos(TypeDocument.venteComptoir)),
      SousModule('Clients', Icons.people_alt, (_) => const ClientListPage()),
      SousModule('Bon de livraison', Icons.local_shipping, _pos(TypeDocument.bonLivraison)),
      SousModule('Facture', Icons.receipt_long, _pos(TypeDocument.factureVente)),
      SousModule('Bon de retour', Icons.assignment_return, _pos(TypeDocument.retourClient)),
      SousModule('Bon de commande', Icons.shopping_bag, _pos(TypeDocument.commandeClient)),
      SousModule('Facture proforma', Icons.request_quote, _pos(TypeDocument.proforma)),
      SousModule('Avoir', Icons.money_off_csred, _pos(TypeDocument.avoir)),
      SousModule(
        'Historique des ventes',
        Icons.history,
        (_) => const DocumentListPage(
          titre: 'Historique des ventes',
          types: [
            TypeDocument.venteComptoir,
            TypeDocument.bonLivraison,
            TypeDocument.factureVente,
            TypeDocument.retourClient,
            TypeDocument.commandeClient,
            TypeDocument.proforma,
            TypeDocument.avoir,
          ],
        ),
      ),
    ],
  ),

  // 2. ACHAT ------------------------------------------------------------------
  ModuleApp(
    libelle: 'Achat',
    icone: Icons.shopping_basket_outlined,
    iconeActive: Icons.shopping_basket,
    couleur: AppColors.achat,
    sousModules: [
      SousModule('Fournisseurs', Icons.local_shipping_outlined, (_) => const FournisseurListPage()),
      SousModule('Bon de réception', Icons.move_to_inbox,
          _docs('Bons de réception', TypeDocument.receptionFournisseur, AppColors.achat)),
      SousModule('Bon de retour', Icons.outbox,
          _docs('Bons de retour fournisseur', TypeDocument.retourFournisseur, AppColors.supprimer)),
      SousModule('Facture', Icons.receipt, _docs('Factures d\'achat', TypeDocument.factureAchat, AppColors.achat)),
      SousModule('Bon de commande', Icons.playlist_add_check,
          _docs('Bons de commande fournisseur', TypeDocument.commandeFournisseur, AppColors.vente)),
    ],
  ),

  // 3. ARTICLE (STOCK) --------------------------------------------------------
  ModuleApp(
    libelle: 'Article',
    icone: Icons.inventory_2_outlined,
    iconeActive: Icons.inventory_2,
    couleur: AppColors.article,
    sousModules: [
      SousModule('Liste des articles', Icons.list_alt, (_) => const ArticleListPage()),
      SousModule('État du stock', Icons.warehouse, (_) => const ArticleListPage(titre: 'État du stock')),
      SousModule('Bon d\'entrée', Icons.add_box, _docs('Bons d\'entrée', TypeDocument.bonEntree, AppColors.ajouter)),
      SousModule('Bon de sortie', Icons.indeterminate_check_box,
          _docs('Bons de sortie', TypeDocument.bonSortie, AppColors.supprimer)),
      SousModule('Mouvements de stock', Icons.swap_vert, (_) => const MouvementsStockPage()),
      SousModule('Articles en rupture', Icons.warning_amber_rounded,
          (_) => const ArticleListPage(titre: 'Articles en rupture', filtreInitial: FiltreStock.alerte)),
      SousModule('Achat par article', Icons.trending_down, (_) => const RapportArticlePage(ventes: false)),
      SousModule('Vente par article', Icons.trending_up, (_) => const RapportArticlePage(ventes: true)),
      SousModule('Familles d\'articles', Icons.category, _crud(configFamilles)),
    ],
  ),

  // 4. TRÉSORERIE -------------------------------------------------------------
  ModuleApp(
    libelle: 'Trésorerie',
    icone: Icons.account_balance_wallet_outlined,
    iconeActive: Icons.account_balance_wallet,
    couleur: AppColors.tresorerie,
    sousModules: [
      SousModule('Mouvement caisse', Icons.compare_arrows, (_) => const MouvementCaissePage()),
      SousModule('État de caisse', Icons.savings, (_) => const EtatCaissePage()),
      SousModule('Règlement client', Icons.price_check, (_) => const ReglementPage(tiersType: 'C')),
      SousModule('État de paiement client', Icons.fact_check, (_) => const EtatPaiementPage()),
      SousModule('Relance client', Icons.notifications_active,
          (_) => const ClientListPage(titre: 'Relance client', filtreInitial: FiltreClient.debiteurs)),
      SousModule('En cours dépassé', Icons.report_gmailerrorred,
          (_) => const ClientListPage(titre: 'En cours dépassé', filtreInitial: FiltreClient.encoursDepasse)),
      SousModule('Règlement fournisseur', Icons.payments, (_) => const ReglementPage(tiersType: 'F')),
      SousModule('Relance fournisseur', Icons.campaign, (_) => const FournisseurListPage()),
      // v2c : liste des crédits clients / dettes fournisseurs antérieurs à l'appli
      SousModule(
        'Crédits antérieurs',
        Icons.history_edu,
        (_) => const DocumentListPage(
          titre: 'Crédits et dettes antérieurs',
          types: [TypeDocument.soldeInitialClient, TypeDocument.soldeInitialFournisseur],
          couleur: AppColors.tresorerie,
        ),
      ),
    ],
  ),

  // 5. PARAMÈTRES -------------------------------------------------------------
  ModuleApp(
    libelle: 'Paramètres',
    icone: Icons.settings_outlined,
    iconeActive: Icons.settings,
    couleur: AppColors.parametres,
    sousModules: [
      SousModule('Société', Icons.business, (_) => const SocietePage()),
      SousModule('Taxes', Icons.percent, _crud(configTaxes)),
      SousModule('Commerciaux', Icons.badge, _crud(configCommerciaux)),
      SousModule('Point de vente', Icons.storefront, _crud(configPointsVente)),
    ],
  ),

  // 6. OUTILS -----------------------------------------------------------------
  ModuleApp(
    libelle: 'Outils',
    icone: Icons.handyman_outlined,
    iconeActive: Icons.handyman,
    couleur: AppColors.outils,
    sousModules: [
      SousModule('Imprimante', Icons.print, (_) => const ImprimantePage()),
      SousModule('Calculatrice', Icons.calculate, (_) => const CalculatricePage()),
      SousModule('Options', Icons.tune, (_) => const OptionsPage()),
    ],
  ),
];
