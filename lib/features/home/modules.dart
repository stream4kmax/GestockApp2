// =============================================================================
//  Déclaration des 6 modules et de leurs sous-menus (v2)
// =============================================================================
//  Nouveautés v2 (écrans branchés) :
//   • Vente      : + Clients (fiche, WhatsApp / SMS)
//   • Achat      : + Fournisseurs (liste, fiche, articles fournis, commande)
//   • Article    : Liste des articles (CRUD), État du stock, Articles en rupture
//   • Trésorerie : Relance client, En cours dépassé, Relance fournisseur
//  Un SousModule sans builder affiche « Bientôt disponible ».
// =============================================================================

import 'package:flutter/material.dart';

import 'package:gestock_pos/core/constants/type_document.dart';
import 'package:gestock_pos/core/theme/app_colors.dart';
import 'package:gestock_pos/data/repositories/article_repository.dart';
import 'package:gestock_pos/data/repositories/client_repository.dart';
import 'package:gestock_pos/features/article/article_list_page.dart';
import 'package:gestock_pos/features/clients/client_list_page.dart';
import 'package:gestock_pos/features/fournisseurs/fournisseur_list_page.dart';
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
      const SousModule('Bon de réception', Icons.move_to_inbox),
      const SousModule('Bon de retour', Icons.outbox),
      const SousModule('Facture', Icons.receipt),
      const SousModule('Bon de commande', Icons.playlist_add_check),
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
      const SousModule('Bon d\'entrée', Icons.add_box),
      const SousModule('Bon de sortie', Icons.indeterminate_check_box),
      const SousModule('Mouvements de stock', Icons.swap_vert),
      SousModule('Articles en rupture', Icons.warning_amber_rounded,
          (_) => const ArticleListPage(titre: 'Articles en rupture', filtreInitial: FiltreStock.alerte)),
      const SousModule('Achat par article', Icons.trending_down),
      const SousModule('Vente par article', Icons.trending_up),
      const SousModule('Familles d\'articles', Icons.category),
    ],
  ),

  // 4. TRÉSORERIE -------------------------------------------------------------
  ModuleApp(
    libelle: 'Trésorerie',
    icone: Icons.account_balance_wallet_outlined,
    iconeActive: Icons.account_balance_wallet,
    couleur: AppColors.tresorerie,
    sousModules: [
      const SousModule('Mouvement caisse', Icons.compare_arrows),
      const SousModule('État de caisse', Icons.savings),
      const SousModule('Règlement client', Icons.price_check),
      const SousModule('État de paiement client', Icons.fact_check),
      SousModule('Relance client', Icons.notifications_active,
          (_) => const ClientListPage(titre: 'Relance client', filtreInitial: FiltreClient.debiteurs)),
      SousModule('En cours dépassé', Icons.report_gmailerrorred,
          (_) => const ClientListPage(titre: 'En cours dépassé', filtreInitial: FiltreClient.encoursDepasse)),
      const SousModule('Règlement fournisseur', Icons.payments),
      SousModule('Relance fournisseur', Icons.campaign, (_) => const FournisseurListPage()),
    ],
  ),

  // 5. PARAMÈTRES -------------------------------------------------------------
  const ModuleApp(
    libelle: 'Paramètres',
    icone: Icons.settings_outlined,
    iconeActive: Icons.settings,
    couleur: AppColors.parametres,
    sousModules: [
      SousModule('Société', Icons.business),
      SousModule('Taxes', Icons.percent),
      SousModule('Commerciaux', Icons.badge),
      SousModule('Point de vente', Icons.storefront),
    ],
  ),

  // 6. OUTILS -----------------------------------------------------------------
  const ModuleApp(
    libelle: 'Outils',
    icone: Icons.handyman_outlined,
    iconeActive: Icons.handyman,
    couleur: AppColors.outils,
    sousModules: [
      SousModule('Imprimante', Icons.print),
      SousModule('Calculatrice', Icons.calculate),
      SousModule('Options', Icons.tune),
    ],
  ),
];
