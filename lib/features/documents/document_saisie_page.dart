// =============================================================================
//  DocumentSaisiePage — saisie d'un document d'achat ou d'un bon de stock
// =============================================================================
//  Un seul écran pour 6 documents (le TypeDocument décide du comportement) :
//   • Bon de réception (BR)      : +stock, dette fournisseur, paiement possible
//   • Facture d'achat (FA)       : +stock, dette fournisseur, paiement possible
//   • Bon de retour fournisseur  : −stock, remboursement possible
//   • Bon de commande fournisseur: aucun effet (envoi WhatsApp au fournisseur)
//   • Bon d'entrée / de sortie   : ±stock, avec un MOTIF (inventaire, casse…)
//
//  Les prix saisis sont des prix d'ACHAT HT. Pour BR / FA, le dernier prix
//  d'achat peut mettre à jour la fiche article (case à cocher).
// =============================================================================

import 'package:flutter/material.dart';

import 'package:gestock_pos/core/constants/type_document.dart';
import 'package:gestock_pos/core/theme/app_colors.dart';
import 'package:gestock_pos/core/utils/formatters.dart';
import 'package:gestock_pos/core/widgets/communs.dart';
import 'package:gestock_pos/core/widgets/message_sheet.dart';
import 'package:gestock_pos/core/widgets/relief_3d.dart';
import 'package:gestock_pos/data/models/article.dart';
import 'package:gestock_pos/data/models/fournisseur.dart';
import 'package:gestock_pos/data/models/ligne_panier.dart';
import 'package:gestock_pos/data/models/paiement.dart';
import 'package:gestock_pos/data/repositories/achat_repository.dart';
import 'package:gestock_pos/data/repositories/article_repository.dart';
import 'package:gestock_pos/data/repositories/document_repository.dart';
import 'package:gestock_pos/data/repositories/fournisseur_repository.dart';
import 'package:gestock_pos/data/repositories/reference_repository.dart';
import 'package:gestock_pos/features/documents/article_picker_sheet.dart';
import 'package:gestock_pos/features/vente/widgets/paiement_dialog.dart';
import 'package:gestock_pos/services/messaging_service.dart';

class DocumentSaisiePage extends StatefulWidget {
  const DocumentSaisiePage({
    super.key,
    required this.type,
    this.fournisseurInitialId,
    this.lignesInitiales,
    this.documentSourceId,
  });

  final TypeDocument type;
  final String? fournisseurInitialId;
  final List<LigneDetail>? lignesInitiales; // ex. lignes du bon de commande
  final String? documentSourceId;

  @override
  State<DocumentSaisiePage> createState() => _DocumentSaisiePageState();
}

class _DocumentSaisiePageState extends State<DocumentSaisiePage> {
  final _articleRepo = ArticleRepository();
  final List<LignePanier> _lignes = [];
  final _motif = TextEditingController();
  final _notes = TextEditingController();
  Fournisseur? _fournisseur;
  bool _majPrixAchat = true;
  bool _enregistrement = false;
  bool _pret = false;

  TypeDocument get _type => widget.type;
  bool get _estBonStock => _type == TypeDocument.bonEntree || _type == TypeDocument.bonSortie;
  bool get _estAchat => _type == TypeDocument.receptionFournisseur || _type == TypeDocument.factureAchat;
  bool get _estCommande => _type == TypeDocument.commandeFournisseur;

  /// Vert = entrée en stock, rouge = sortie, bleu = commande (sans effet).
  Color get _couleur => _type.effetStock > 0
      ? AppColors.ajouter
      : _type.effetStock < 0
          ? AppColors.supprimer
          : AppColors.vente;

  static const _motifsEntree = ['Inventaire', 'Retour d\'exposition', 'Production', 'Don reçu', 'Correction'];
  static const _motifsSortie = ['Casse', 'Périmé', 'Perte / vol', 'Usage interne', 'Don', 'Échantillon'];

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  @override
  void dispose() {
    _motif.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _initialiser() async {
    if (widget.fournisseurInitialId != null) {
      _fournisseur = await FournisseurRepository().parId(widget.fournisseurInitialId!);
    }
    // Pré-remplissage (ex. réception d'un bon de commande)
    for (final l in widget.lignesInitiales ?? const <LigneDetail>[]) {
      if (l.articleId == null) continue;
      final a = await _articleRepo.parId(l.articleId!);
      if (a == null) continue;
      _lignes.add(LignePanier(article: a, quantite: l.quantite, prixUnitaireHt: l.prixUnitaireHt, tauxTva: l.tauxTva));
    }
    if (mounted) setState(() => _pret = true);
  }

  // ------------------------------------------------------------ Lignes

  double _quantiteDe(String id) {
    for (final l in _lignes) {
      if (l.article.id == id) return l.quantite;
    }
    return 0;
  }

  void _ajouter(Article a, {double quantite = 1}) {
    setState(() {
      final i = _lignes.indexWhere((l) => l.article.id == a.id);
      if (i >= 0) {
        _lignes[i].quantite += quantite;
      } else {
        _lignes.add(LignePanier(article: a, quantite: quantite, prixUnitaireHt: a.prixAchatHt, tauxTva: a.tauxTva));
      }
    });
  }

  /// Ajoute d'un coup les articles du fournisseur à réapprovisionner.
  Future<void> _ajouterAReapprovisionner() async {
    final f = _fournisseur;
    if (f == null) return;
    final articles = (await _articleRepo.parFournisseur(f.id)).where((a) => a.aReapprovisionner).toList();
    if (!mounted) return;
    if (articles.isEmpty) {
      afficherMessage(context, 'Aucun article de ce fournisseur n\'est sous le seuil.');
      return;
    }
    for (final a in articles) {
      if (_quantiteDe(a.id) > 0) continue;
      final cible = a.stockMin > 0 ? a.stockMin * 2 : 10.0;
      final q = cible - (a.stock < 0 ? 0.0 : a.stock);
      _ajouter(a, quantite: q < 1 ? 1.0 : q.ceilToDouble());
    }
    afficherMessage(context, '${articles.length} article(s) ajouté(s)');
  }

  Future<void> _editerLigne(LignePanier l) async {
    final qte = TextEditingController(text: _brut(l.quantite));
    final prix = TextEditingController(text: l.prixUnitaireHt.toStringAsFixed(2));
    final tva = TextEditingController(text: _brut(l.tauxTva));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.article.designation),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: qte,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Quantité', suffixText: l.article.unite)),
            const SizedBox(height: 12),
            TextField(
                controller: prix,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Prix d\'achat unitaire HT', suffixText: 'DA')),
            const SizedBox(height: 12),
            TextField(
                controller: tva,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'TVA', suffixText: '%')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Valider')),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        final q = parseNombre(qte.text) ?? l.quantite;
        if (q <= 0) {
          _lignes.remove(l);
        } else {
          l.quantite = q;
          l.prixUnitaireHt = parseNombre(prix.text) ?? l.prixUnitaireHt;
          l.tauxTva = parseNombre(tva.text) ?? l.tauxTva;
        }
      });
    }
    qte.dispose();
    prix.dispose();
    tva.dispose();
  }

  static String _brut(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  // ------------------------------------------------------------ Fournisseur

  Future<void> _choisirFournisseur() async {
    final liste = await FournisseurRepository().listeSimple();
    if (!mounted) return;
    final choisi = await showModalBottomSheet<Fournisseur>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => liste.isEmpty
          ? const SizedBox(
              height: 200,
              child: EtatVide(icone: Icons.local_shipping, message: 'Aucun fournisseur.\nCréez-en un dans Achat > Fournisseurs.'))
          : ListView(shrinkWrap: true, children: [
              for (final f in liste)
                ListTile(
                  leading: const Icon(Icons.local_shipping, color: AppColors.achat),
                  title: Text(f.nom),
                  subtitle: Text('Solde dû : ${fmtMonnaie(f.solde)}'),
                  onTap: () => Navigator.pop(ctx, f),
                ),
            ]),
    );
    if (choisi != null) setState(() => _fournisseur = choisi);
  }

  // ------------------------------------------------------------ Validation

  Future<void> _valider() async {
    if (_lignes.isEmpty) {
      afficherMessage(context, 'Ajoutez au moins un article.', erreur: true);
      return;
    }
    if (!_estBonStock && _fournisseur == null) {
      afficherMessage(context, 'Choisissez un fournisseur.', erreur: true);
      return;
    }
    if (_estBonStock && _motif.text.trim().isEmpty) {
      afficherMessage(context, 'Indiquez le motif du bon.', erreur: true);
      return;
    }
    final totaux = TotauxAchat.depuis(_lignes);

    var paiement = Paiement.aucun;
    if (_type.avecPaiement) {
      final p = await showDialog<Paiement>(
        context: context,
        builder: (_) => PaiementDialog(
          total: totaux.ttc,
          creditAutorise: true, // un fournisseur peut toujours être payé plus tard
          titre: _type.effetCompte < 0 ? 'Remboursement reçu' : 'Paiement au fournisseur',
        ),
      );
      if (p == null) return;
      paiement = p;
    }

    setState(() => _enregistrement = true);
    try {
      final doc = await AchatRepository().enregistrer(
        type: _type,
        lignes: _lignes,
        fournisseur: _fournisseur,
        paiement: paiement,
        majPrixAchat: _majPrixAchat,
        motif: _estBonStock ? _motif.text.trim() : null,
        notes: _notes.text.trim(),
        documentSourceId: widget.documentSourceId,
      );
      if (!mounted) return;
      await _succes(doc.numero, doc.id, totaux);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) afficherMessage(context, '$e'.replaceFirst('Exception: ', ''), erreur: true);
    } finally {
      if (mounted) setState(() => _enregistrement = false);
    }
  }

  Future<void> _succes(String numero, String docId, TotauxAchat t) async {
    final f = _fournisseur;
    String? message;
    if (_estCommande && f != null) {
      message = MessagingService.messageCommandeFournisseur(
        nomFournisseur: f.nom,
        societe: await ReferenceRepository().raisonSociale(),
        lignes: [for (final l in _lignes) (designation: l.article.designation, quantite: l.quantite, unite: l.article.unite)],
      );
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.check_circle, color: _couleur, size: 52),
        title: Text('${_type.libelle} enregistré', textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(numero, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(_estBonStock ? 'Valeur HT : ${fmtMonnaie(t.ht)}' : 'Total TTC : ${fmtMonnaie(t.ttc)}'),
            if (_type.effetStock != 0)
              Text(_type.effetStock > 0 ? 'Stock augmenté ✓' : 'Stock diminué ✓',
                  style: TextStyle(color: _couleur, fontWeight: FontWeight.w700)),
            if (message != null) ...[
              const SizedBox(height: 14),
              Bouton3D(
                libelle: 'Envoyer au fournisseur',
                icone: Icons.send,
                couleur: AppColors.whatsapp,
                hauteur: 46,
                onPressed: () => MessageSheet.ouvrir(ctx,
                    titre: 'Commande $numero',
                    numero: f!.numeroWhatsApp,
                    tiersType: 'F',
                    tiersId: f!.id,
                    documentId: docId,
                    modeles: [ModeleMessage('Commande', 'COMMANDE', message!)]),
              ),
            ],
          ]),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  // ------------------------------------------------------------ Interface

  @override
  Widget build(BuildContext context) {
    final totaux = TotauxAchat.depuis(_lignes);
    return Scaffold(
      appBar: AppBar(
        title: Text(_type.libelle, overflow: TextOverflow.ellipsis),
        bottom: _estBonStock
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(46),
                child: Material(
                  color: AppColors.achat.withValues(alpha: 0.07),
                  child: InkWell(
                    onTap: _choisirFournisseur,
                    child: SizedBox(
                      height: 46,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(children: [
                          const Icon(Icons.local_shipping, color: AppColors.achat, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_fournisseur?.nom ?? 'Choisir un fournisseur *',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: _fournisseur == null ? AppColors.supprimer : AppColors.texte)),
                          ),
                          const Icon(Icons.chevron_right),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
      ),
      body: !_pret
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                // Motif (bons d'entrée / sortie)
                if (_estBonStock)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        TextField(
                          controller: _motif,
                          decoration: const InputDecoration(labelText: 'Motif *', prefixIcon: Icon(Icons.edit_note)),
                        ),
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, runSpacing: 4, children: [
                          for (final m in _type == TypeDocument.bonEntree ? _motifsEntree : _motifsSortie)
                            ActionChip(label: Text(m), onPressed: () => setState(() => _motif.text = m)),
                        ]),
                      ]),
                    ),
                  ),

                // Boutons d'ajout
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(children: [
                    Expanded(
                      child: Bouton3D(
                        libelle: 'Ajouter des articles',
                        icone: Icons.add_shopping_cart,
                        couleur: AppColors.ajouter,
                        hauteur: 46,
                        onPressed: () async {
                          await ArticlePickerSheet.ouvrir(context, onChoisir: _ajouter, quantiteDe: _quantiteDe);
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
                    if (_fournisseur != null && _type.effetStock >= 0 && !_estBonStock) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Bouton3D(
                          libelle: 'À réapprovisionner',
                          icone: Icons.warning_amber_rounded,
                          couleur: AppColors.alerte,
                          hauteur: 46,
                          onPressed: _ajouterAReapprovisionner,
                        ),
                      ),
                    ],
                  ]),
                ),

                if (_lignes.isEmpty)
                  const SizedBox(height: 240, child: EtatVide(icone: Icons.playlist_add, message: 'Aucune ligne.\nAjoutez des articles.')),

                // Lignes
                for (final l in _lignes)
                  Card(
                    child: Dismissible(
                      key: ObjectKey(l),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: AppColors.supprimer,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => setState(() => _lignes.remove(l)),
                      child: ListTile(
                        onTap: () => _editerLigne(l),
                        title: Text(l.article.designation, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                            '${fmtQte(l.quantite)} ${l.article.unite} × ${fmtMonnaie(l.prixUnitaireHt)} HT · TVA ${fmtQte(l.tauxTva)} %'),
                        trailing: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 110),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(fmtMonnaie(_estBonStock ? l.montantHt : l.montantTtc),
                                style: const TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ),
                    ),
                  ),

                if (_lignes.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text('Appuyez sur une ligne pour la modifier, glissez-la vers la gauche pour la supprimer.',
                        style: TextStyle(fontSize: 12, color: AppColors.texteSecondaire)),
                  ),

                if (_estAchat)
                  SwitchListTile(
                    value: _majPrixAchat,
                    onChanged: (v) => setState(() => _majPrixAchat = v),
                    title: const Text('Mettre à jour le prix d\'achat des articles'),
                    subtitle: const Text('Le prix saisi devient le nouveau prix d\'achat (calcul du bénéfice)'),
                  ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: TextField(
                    controller: _notes,
                    decoration: const InputDecoration(labelText: 'Notes (facultatif)', prefixIcon: Icon(Icons.notes)),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: Material(
        elevation: 12,
        color: AppColors.surface,
        shadowColor: Colors.black45,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 6),
            child: Row(children: [
              Expanded(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text('${_lignes.length} ligne(s) · HT ${fmtMonnaie(totaux.ht)} · TVA ${fmtMonnaie(totaux.tva)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.texteSecondaire)),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text('TTC ${fmtMonnaie(totaux.ttc)}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 150,
                child: Bouton3D(
                  libelle: 'Valider',
                  icone: Icons.check_circle,
                  couleur: _couleur,
                  hauteur: 48,
                  chargement: _enregistrement,
                  onPressed: _lignes.isEmpty || _enregistrement ? null : _valider,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
