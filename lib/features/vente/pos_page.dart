// =============================================================================
//  PosPage — écran de vente (Vente électronique, BL, Facture, Avoir…)
// =============================================================================
//  Disposition (téléphone) :
//   ┌──────────────────────────────┐
//   │ AppBar : type de document    │
//   │ Client : Client comptoir  ▸  │
//   ├──────────────────────────────┤
//   │ 🔍 Recherche / code-barres   │
//   │ Liste des articles (tap = +1)│
//   ├──────────────────────────────┤
//   │ HT · TVA · TTC  [Panier][OK] │  ← barre des totaux
//   └──────────────────────────────┘
//
//  Le panier (CartProvider) est créé PAR écran : chaque document a son propre
//  panier, et il est détruit automatiquement quand on quitte l'écran.
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gestock_pos/core/constants/app_constants.dart';
import 'package:gestock_pos/core/constants/type_document.dart';
import 'package:gestock_pos/core/constants/type_tarif.dart';
import 'package:gestock_pos/core/theme/app_colors.dart';
import 'package:gestock_pos/core/utils/formatters.dart';
import 'package:gestock_pos/core/widgets/communs.dart';
import 'package:gestock_pos/core/widgets/message_sheet.dart';
import 'package:gestock_pos/core/widgets/relief_3d.dart';
import 'package:gestock_pos/data/models/article.dart';
import 'package:gestock_pos/data/models/client.dart';
import 'package:gestock_pos/data/models/paiement.dart';
import 'package:gestock_pos/data/repositories/article_repository.dart';
import 'package:gestock_pos/data/repositories/client_repository.dart';
import 'package:gestock_pos/data/repositories/reference_repository.dart';
import 'package:gestock_pos/data/repositories/vente_repository.dart';
import 'package:gestock_pos/features/vente/cart_provider.dart';
import 'package:gestock_pos/features/vente/widgets/article_tile.dart';
import 'package:gestock_pos/features/vente/widgets/cart_sheet.dart';
import 'package:gestock_pos/features/vente/widgets/paiement_dialog.dart';
import 'package:gestock_pos/services/messaging_service.dart';

class PosPage extends StatelessWidget {
  const PosPage({super.key, required this.type});
  final TypeDocument type;

  @override
  Widget build(BuildContext context) {
    // Fournit un panier neuf à cet écran et à tous ses descendants.
    return ChangeNotifierProvider(
      create: (_) => CartProvider(controleStock: type.controleStock),
      child: _PosView(type: type),
    );
  }
}

class _PosView extends StatefulWidget {
  const _PosView({required this.type});
  final TypeDocument type;

  @override
  State<_PosView> createState() => _PosViewState();
}

class _PosViewState extends State<_PosView> {
  final _articleRepo = ArticleRepository();
  final _clientRepo = ClientRepository();
  final _venteRepo = VenteRepository();

  final _rechercheCtrl = TextEditingController();
  final _rechercheFocus = FocusNode();
  Timer? _debounce; // évite une requête SQL à chaque lettre tapée

  List<Article> _articles = [];
  Client? _clientComptoir;
  bool _chargement = true;
  bool _enregistrement = false;

  @override
  void initState() {
    super.initState();
    _chargerClientParDefaut();
    _chargerArticles();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _rechercheCtrl.dispose();
    _rechercheFocus.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  //  Chargement des données
  // --------------------------------------------------------------------------

  Future<void> _chargerClientParDefaut() async {
    _clientComptoir = await _clientRepo.parId(kClientComptoirId);
    if (!mounted || _clientComptoir == null) return;
    context.read<CartProvider>().definirClient(_clientComptoir!);
  }

  Future<void> _chargerArticles([String recherche = '']) async {
    setState(() => _chargement = true);
    final resultat = await _articleRepo.rechercher(recherche);
    if (!mounted) return;
    setState(() {
      _articles = resultat;
      _chargement = false;
    });
  }

  /// Recherche "en direct" : on attend 300 ms après la dernière frappe.
  void _onRechercheChange(String valeur) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _chargerArticles(valeur));
    setState(() {}); // pour afficher/masquer le bouton ✕
  }

  /// Touche Entrée. Les douchettes Bluetooth/USB se comportent comme un
  /// clavier : elles "tapent" le code-barres puis Entrée → ajout direct au panier.
  Future<void> _onRechercheValidee(String valeur) async {
    final article = await _articleRepo.parCodeBarre(valeur);
    if (article != null) {
      _ajouter(article);
      _rechercheCtrl.clear();
      _chargerArticles();
    }
    _rechercheFocus.requestFocus(); // prêt pour le scan suivant
  }

  // --------------------------------------------------------------------------
  //  Actions sur le panier
  // --------------------------------------------------------------------------

  void _ajouter(Article article) {
    final erreur = context.read<CartProvider>().ajouter(article);
    if (erreur != null) _message(erreur, erreur: true);
  }

  Future<void> _ouvrirPanier() async {
    final cart = context.read<CartProvider>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      // La feuille est une nouvelle "route" : elle n'hérite pas du Provider de
      // cet écran. On lui transmet donc le MÊME panier avec .value.
      builder: (_) => ChangeNotifierProvider.value(value: cart, child: const CartSheet()),
    );
  }

  Future<void> _confirmerVider() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vider le panier ?'),
        content: const Text('Toutes les lignes seront supprimées.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Vider')),
        ],
      ),
    );
    if (ok == true && mounted) context.read<CartProvider>().vider();
  }

  Future<void> _choisirClient() async {
    final clients = await _clientRepo.tous();
    if (!mounted) return;
    final choisi = await showModalBottomSheet<Client>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          for (final c in clients)
            ListTile(
              leading: Icon(c.estComptoir ? Icons.storefront : Icons.person_outline),
              title: Text(c.nom),
              subtitle: c.estComptoir
                  ? const Text('Vente anonyme, paiement comptant')
                  : Text('Solde : ${fmtMonnaie(c.solde)}'
                      '${c.encoursDepasse ? '  ⚠ En cours dépassé' : ''}',
                      style: c.encoursDepasse ? TextStyle(color: Theme.of(ctx).colorScheme.error) : null),
              onTap: () => Navigator.pop(ctx, c),
            ),
        ],
      ),
    );
    if (choisi != null && mounted) context.read<CartProvider>().definirClient(choisi);
  }

  // --------------------------------------------------------------------------
  //  Validation du document
  // --------------------------------------------------------------------------

  Future<void> _valider() async {
    final cart = context.read<CartProvider>();
    final client = cart.client;
    if (client == null || cart.estVide) return;
    final totaux = cart.totaux;

    // 1. Paiement (pas de paiement pour une proforma ou un bon de commande)
    var paiement = Paiement.aucun;
    if (widget.type.avecPaiement) {
      final p = await showDialog<Paiement>(
        context: context,
        builder: (_) => PaiementDialog(
          total: totaux.ttc,
          creditAutorise: !client.estComptoir,
          titre: widget.type.effetCompte < 0 ? 'Remboursement' : 'Encaissement',
        ),
      );
      if (p == null) return; // l'utilisateur a annulé
      paiement = p;
    }

    // 2. Enregistrement en base (transaction)
    setState(() => _enregistrement = true);
    try {
      final doc = await _venteRepo.enregistrer(
        type: widget.type,
        client: client,
        lignes: cart.lignes,
        totaux: totaux,
        paiement: paiement,
        typeTarif: cart.tarif,
      );
      if (!mounted) return;

      // 3. Confirmation + envoi WhatsApp / SMS. Le message est construit
      //    MAINTENANT, tant que les lignes sont encore dans le panier.
      final societe = await ReferenceRepository().raisonSociale();
      final message = MessagingService.messageFacture(
        nomClient: client.nom,
        typeDocument: widget.type.libelle,
        numero: doc.numero,
        date: DateTime.now(),
        lignes: [for (final l in cart.lignes) LigneMessage(l.article.designation, l.quantite, l.montantTtc)],
        totalHt: totaux.ht,
        totalTva: totaux.tva,
        totalTtc: totaux.ttc,
        montantPaye: paiement.encaisse(totaux.ttc),
        societe: societe,
      );
      if (!mounted) return;
      await _afficherSucces(doc, totaux, paiement, client, message);

      // 4. Prêt pour la vente suivante : panier vide, client comptoir, stock à jour
      cart.vider();
      if (_clientComptoir != null) cart.definirClient(_clientComptoir!);
      _chargerArticles(_rechercheCtrl.text);
    } catch (e) {
      _message('Erreur : $e', erreur: true);
    } finally {
      if (mounted) setState(() => _enregistrement = false);
    }
  }

  /// Fenêtre de confirmation avec les DEUX boutons d'envoi : WhatsApp et SMS.
  Future<void> _afficherSucces(
      DocumentEnregistre doc, TotauxPanier t, Paiement p, Client client, String message) {
    final rendu = p.rendu(t.ttc);

    Future<void> envoyer(BuildContext ctx, {required bool whatsapp}) => MessageSheet.ouvrir(
          ctx,
          titre: 'Envoyer ${doc.numero}',
          // Client comptoir : pas de numéro → l'utilisateur le saisit dans la feuille
          numero: whatsapp ? client.numeroWhatsApp : (client.telephone ?? client.whatsapp),
          tiersType: 'C',
          tiersId: client.id,
          documentId: doc.id,
          modeles: [ModeleMessage('Facture', 'FACTURE', message)],
        );

    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: AppColors.ajouter, size: 52),
        title: Text('${widget.type.libelle} enregistré(e)', textAlign: TextAlign.center),
        // SingleChildScrollView : jamais de débordement, même clavier ouvert
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(doc.numero, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Total TTC : ${fmtMonnaie(t.ttc)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              if (rendu > 0)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Rendu monnaie : ${fmtMonnaie(rendu)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ajouter)),
                ),
              const SizedBox(height: 16),
              const Text('Envoyer le récapitulatif au client :',
                  style: TextStyle(color: AppColors.texteSecondaire)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: Bouton3D(
                    libelle: 'WhatsApp',
                    icone: Icons.chat,
                    couleur: AppColors.whatsapp,
                    hauteur: 46,
                    onPressed: () => envoyer(ctx, whatsapp: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Bouton3D(
                    libelle: 'SMS',
                    icone: Icons.sms,
                    couleur: AppColors.sms,
                    hauteur: 46,
                    onPressed: () => envoyer(ctx, whatsapp: false),
                  ),
                ),
              ]),
            ],
          ),
        ),
        actions: [
          // ÉTAPE 3 : bouton "Partager PDF" (facture PDF + partage natif Android)
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.vente),
            onPressed: () => Navigator.pop(ctx),
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Nouvelle vente'),
          ),
        ],
      ),
    );
  }

  void _message(String texte, {bool erreur = false}) => afficherMessage(context, texte, erreur: erreur);

  // --------------------------------------------------------------------------
  //  Interface
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    // Couleur de la barre selon le type : bleu = vente, rouge = retour / avoir
    final couleurType = widget.type.effetCompte < 0 ? AppColors.supprimer : AppColors.vente;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.type.libelle, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Vider le panier',
            icon: const Icon(Icons.remove_shopping_cart_outlined, color: AppColors.supprimer),
            onPressed: cart.estVide ? null : _confirmerVider,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: _BarreClient(client: cart.client, onTap: _choisirClient),
        ),
      ),
      body: Column(
        children: [
          // Champ de recherche / scan
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _rechercheCtrl,
              focusNode: _rechercheFocus,
              textInputAction: TextInputAction.search,
              onChanged: _onRechercheChange,
              onSubmitted: _onRechercheValidee,
              decoration: InputDecoration(
                hintText: 'Nom, code ou code-barres…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _rechercheCtrl.text.isEmpty
                    ? const Icon(Icons.qr_code_scanner)
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _rechercheCtrl.clear();
                          _onRechercheChange('');
                        },
                      ),
              ),
            ),
          ),

          // v2 : choix du type de vente (Détail / Gros)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Row(children: [
              const Text('Tarif :', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: 10),
              Expanded(
                child: SegmentedButton<TypeTarif>(
                  segments: const [
                    ButtonSegment(value: TypeTarif.detail, label: Text('Détail'), icon: Icon(Icons.person)),
                    ButtonSegment(value: TypeTarif.gros, label: Text('Gros'), icon: Icon(Icons.inventory)),
                  ],
                  selected: {cart.tarif},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => context.read<CartProvider>().changerTarif(s.first),
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected)
                        ? (cart.tarif == TypeTarif.gros ? AppColors.achat : AppColors.vente)
                        : AppColors.surface),
                    foregroundColor: WidgetStateProperty.resolveWith(
                        (st) => st.contains(WidgetState.selected) ? Colors.white : AppColors.texte),
                    elevation: const WidgetStatePropertyAll(2),
                    shadowColor: const WidgetStatePropertyAll(Colors.black26),
                  ),
                ),
              ),
            ]),
          ),

          // Liste des articles
          Expanded(
            child: _chargement
                ? const Center(child: CircularProgressIndicator())
                : _articles.isEmpty
                    ? const EtatVide(icone: Icons.search_off, message: 'Aucun article trouvé')
                    : RefreshIndicator(
                        onRefresh: () => _chargerArticles(_rechercheCtrl.text),
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 8),
                          itemCount: _articles.length,
                          itemBuilder: (_, i) {
                            final a = _articles[i];
                            return ArticleTile(
                              article: a,
                              tarif: cart.tarif,
                              quantiteDansPanier: cart.quantiteDe(a.id),
                              onTap: () => _ajouter(a),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      bottomNavigationBar: _BarreTotaux(
        totaux: cart.totaux,
        nbLignes: cart.nbLignes,
        couleur: couleurType,
        libelleValider: widget.type.avecPaiement ? 'Encaisser' : 'Enregistrer',
        enCours: _enregistrement,
        onPanier: _ouvrirPanier,
        onValider: cart.estVide || _enregistrement ? null : _valider,
      ),
    );
  }
}

/// Bandeau cliquable sous l'AppBar affichant le client sélectionné.
class _BarreClient extends StatelessWidget {
  const _BarreClient({required this.client, required this.onTap});
  final Client? client;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = client;
    return Material(
      color: AppColors.vente.withValues(alpha: 0.06),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 46,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(c?.estComptoir ?? true ? Icons.storefront : Icons.person, size: 20, color: AppColors.vente),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(c?.nom ?? 'Choisir un client',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                if (c != null && !c.estComptoir)
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Solde ${fmtMonnaie(c.solde)}',
                          style: TextStyle(
                              fontSize: 12, color: c.encoursDepasse ? AppColors.supprimer : AppColors.texteSecondaire)),
                    ),
                  ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Barre du bas : totaux + boutons Panier et Encaisser (en relief).
/// LayoutBuilder : sur un écran étroit (< 360 px), les totaux passent au-dessus
/// des boutons au lieu de les écraser → plus aucun débordement.
class _BarreTotaux extends StatelessWidget {
  const _BarreTotaux({
    required this.totaux,
    required this.nbLignes,
    required this.couleur,
    required this.libelleValider,
    required this.enCours,
    required this.onPanier,
    required this.onValider,
  });

  final TotauxPanier totaux;
  final int nbLignes;
  final Color couleur;
  final String libelleValider;
  final bool enCours;
  final VoidCallback onPanier;
  final VoidCallback? onValider;

  @override
  Widget build(BuildContext context) {
    final blocTotaux = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('HT ${fmtMonnaie(totaux.ht)}  ·  TVA ${fmtMonnaie(totaux.tva)}',
              style: const TextStyle(fontSize: 12, color: AppColors.texteSecondaire)),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('TTC ${fmtMonnaie(totaux.ttc)}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.texte)),
        ),
      ],
    );

    final boutons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Panier (badge = nombre de lignes)
        SizedBox(
          width: 64,
          child: Relief3D(
            onTap: onPanier,
            rayon: 14,
            profondeur: 4,
            padding: EdgeInsets.zero,
            semanticLabel: 'Voir le panier',
            child: SizedBox(
              height: 48,
              child: Center(
                child: Badge(
                  isLabelVisible: nbLignes > 0,
                  backgroundColor: AppColors.supprimer,
                  label: Text('$nbLignes'),
                  child: const Icon(Icons.shopping_cart, color: AppColors.vente),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 150,
          child: Bouton3D(
            libelle: libelleValider,
            icone: Icons.check_circle,
            couleur: couleur,
            hauteur: 48,
            chargement: enCours,
            onPressed: onValider,
          ),
        ),
      ],
    );

    return Material(
      elevation: 12,
      color: AppColors.surface,
      shadowColor: Colors.black45,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 6),
          child: LayoutBuilder(
            builder: (context, c) => c.maxWidth < 360
                ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    blocTotaux,
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerRight, child: boutons),
                  ])
                : Row(children: [Expanded(child: blocTotaux), const SizedBox(width: 8), boutons]),
          ),
        ),
      ),
    );
  }
}
