// =============================================================================
//  ArticleFormPage — créer / modifier / supprimer un article (v2)
// =============================================================================
//  Champs : Désignation, Code (proposé automatiquement), Code-barres, Unité,
//  Famille, Fournisseur, Prix d'achat HT, Prix de vente DÉTAIL HT,
//  Prix de vente GROS HT, TVA, Stock initial (création) / Stock actuel
//  (modification = ajustement d'inventaire), Seuil d'alerte.
//
//  Aperçu en direct : prix TTC et bénéfice unitaire (vente − achat) pour le
//  détail et le gros, avec avertissement si on vend à perte.
// =============================================================================

import 'package:flutter/material.dart';

import 'package:gestock_pos/core/theme/app_colors.dart';
import 'package:gestock_pos/core/utils/formatters.dart';
import 'package:gestock_pos/core/utils/ids.dart';
import 'package:gestock_pos/core/widgets/communs.dart';
import 'package:gestock_pos/core/widgets/relief_3d.dart';
import 'package:gestock_pos/data/models/article.dart';
import 'package:gestock_pos/data/models/fournisseur.dart';
import 'package:gestock_pos/data/repositories/article_repository.dart';
import 'package:gestock_pos/data/repositories/fournisseur_repository.dart';
import 'package:gestock_pos/data/repositories/reference_repository.dart';

class ArticleFormPage extends StatefulWidget {
  const ArticleFormPage({super.key, this.article, this.fournisseurIdParDefaut});

  /// null = création ; sinon modification.
  final Article? article;

  /// Pré-sélectionne un fournisseur (création depuis la fiche fournisseur).
  final String? fournisseurIdParDefaut;

  @override
  State<ArticleFormPage> createState() => _ArticleFormPageState();
}

class _ArticleFormPageState extends State<ArticleFormPage> {
  final _form = GlobalKey<FormState>();
  final _repo = ArticleRepository();

  // Contrôleurs des champs texte
  final _designation = TextEditingController();
  final _code = TextEditingController();
  final _codeBarre = TextEditingController();
  final _prixAchat = TextEditingController();
  final _prixDetail = TextEditingController();
  final _prixGros = TextEditingController();
  final _stock = TextEditingController(text: '0');
  final _stockMin = TextEditingController(text: '0');

  String _unite = 'U';
  String? _familleId;
  String? _fournisseurId;
  double _tva = 19;

  List<Taxe> _taxes = [];
  List<Famille> _familles = [];
  List<Fournisseur> _fournisseurs = [];
  bool _pret = false;
  bool _enregistrement = false;

  static const _unites = ['U', 'kg', 'g', 'L', 'm', 'Carton', 'Paquet', 'Boîte'];

  bool get _creation => widget.article == null;

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  Future<void> _initialiser() async {
    final ref = ReferenceRepository();
    _taxes = await ref.taxes();
    _familles = await ref.familles();
    _fournisseurs = await FournisseurRepository().listeSimple();

    final a = widget.article;
    if (a != null) {
      _designation.text = a.designation;
      _code.text = a.code;
      _codeBarre.text = a.codeBarre ?? '';
      _prixAchat.text = a.prixAchatHt.toStringAsFixed(2);
      _prixDetail.text = a.prixVenteHt.toStringAsFixed(2);
      _prixGros.text = a.prixGrosHt.toStringAsFixed(2);
      _stock.text = fmtQte(a.stock).replaceAll(' ', '').replaceAll(' ', '');
      _stockMin.text = fmtQte(a.stockMin);
      _unite = _unites.contains(a.unite) ? a.unite : 'U';
      _familleId = a.familleId;
      _fournisseurId = a.fournisseurId;
      _tva = a.tauxTva;
    } else {
      _code.text = await _repo.prochainCode();
      _fournisseurId = widget.fournisseurIdParDefaut;
      final defaut = _taxes.where((t) => t.parDefaut);
      if (defaut.isNotEmpty) _tva = defaut.first.taux;
    }
    // Sécurité : une valeur absente des listes ferait planter le Dropdown
    if (!_familles.any((f) => f.id == _familleId)) _familleId = null;
    if (!_fournisseurs.any((f) => f.id == _fournisseurId)) _fournisseurId = null;
    if (!_taxes.any((t) => t.taux == _tva)) _taxes = [..._taxes, Taxe('X', 'TVA ${fmtQte(_tva)} %', _tva, false)];

    if (mounted) setState(() => _pret = true);
  }

  @override
  void dispose() {
    for (final c in [_designation, _code, _codeBarre, _prixAchat, _prixDetail, _prixGros, _stock, _stockMin]) {
      c.dispose();
    }
    super.dispose();
  }

  double _n(TextEditingController c) => parseNombre(c.text) ?? 0;

  /// 12.0 → "12" ; 2.5 → "2.5" (format simple, facile à modifier au clavier)
  static String _brut(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  Future<void> _enregistrer() async {
    if (!_form.currentState!.validate()) return;
    final code = _code.text.trim();
    if (await _repo.codeExiste(code, saufId: widget.article?.id)) {
      if (mounted) afficherMessage(context, 'Le code « $code » est déjà utilisé.', erreur: true);
      return;
    }
    setState(() => _enregistrement = true);

    final article = Article(
      id: widget.article?.id ?? nouvelId(),
      code: code,
      codeBarre: _codeBarre.text.trim(),
      designation: _designation.text.trim(),
      familleId: _familleId,
      fournisseurId: _fournisseurId,
      unite: _unite,
      prixAchatHt: _n(_prixAchat),
      prixVenteHt: _n(_prixDetail),
      prixGrosHt: _n(_prixGros),
      tauxTva: _tva,
      stockMin: _n(_stockMin),
    );

    try {
      if (_creation) {
        await _repo.creer(article, stockInitial: _n(_stock));
      } else {
        await _repo.modifier(article, nouveauStock: _n(_stock));
      }
      if (!mounted) return;
      afficherMessage(context, _creation ? 'Article ajouté' : 'Article modifié');
      Navigator.pop(context, true); // true = la liste doit se recharger
    } catch (e) {
      if (mounted) afficherMessage(context, 'Erreur : $e', erreur: true);
    } finally {
      if (mounted) setState(() => _enregistrement = false);
    }
  }

  Future<void> _supprimer() async {
    final a = widget.article!;
    if (!await confirmerSuppression(context, '« ${a.designation} »')) return;
    await _repo.supprimer(a.id);
    if (!mounted) return;
    afficherMessage(context, 'Article supprimé');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_creation ? 'Nouvel article' : 'Modifier l\'article'),
        actions: [
          if (!_creation)
            IconButton(
              tooltip: 'Supprimer',
              icon: const Icon(Icons.delete, color: AppColors.supprimer),
              onPressed: _supprimer,
            ),
        ],
      ),
      body: !_pret
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              // Recalcule l'aperçu (TTC / bénéfice) à chaque frappe
              onChanged: () => setState(() {}),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                children: [
                  _Section('Identification', [
                    TextFormField(
                      controller: _designation,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Nom de l\'article *', prefixIcon: Icon(Icons.label)),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                    ),
                    _Ligne2(
                      TextFormField(
                        controller: _code,
                        decoration: const InputDecoration(labelText: 'Code *'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                      ),
                      TextFormField(
                        controller: _codeBarre,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Code-barres'),
                      ),
                    ),
                    _Ligne2(
                      DropdownButtonFormField<String>(
                        value: _unite,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Unité'),
                        items: [for (final u in _unites) DropdownMenuItem(value: u, child: Text(u))],
                        onChanged: (v) => setState(() => _unite = v ?? 'U'),
                      ),
                      DropdownButtonFormField<String?>(
                        value: _familleId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Famille'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('—')),
                          for (final f in _familles)
                            DropdownMenuItem(value: f.id, child: Text(f.libelle, overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) => setState(() => _familleId = v),
                      ),
                    ),
                    DropdownButtonFormField<String?>(
                      value: _fournisseurId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Fournisseur principal', prefixIcon: Icon(Icons.local_shipping)),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Aucun')),
                        for (final f in _fournisseurs)
                          DropdownMenuItem(value: f.id, child: Text(f.nom, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => setState(() => _fournisseurId = v),
                    ),
                  ]),

                  _Section('Prix (hors taxes)', [
                    TextFormField(
                      controller: _prixAchat,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Prix d\'achat HT *', suffixText: 'DA', prefixIcon: Icon(Icons.shopping_basket)),
                      validator: (v) => validerNombre(v),
                    ),
                    _Ligne2(
                      TextFormField(
                        controller: _prixDetail,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Vente DÉTAIL HT *', suffixText: 'DA'),
                        validator: (v) => validerNombre(v),
                      ),
                      TextFormField(
                        controller: _prixGros,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Vente GROS HT *', suffixText: 'DA'),
                        validator: (v) => validerNombre(v),
                      ),
                    ),
                    DropdownButtonFormField<double>(
                      value: _tva,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'TVA', prefixIcon: Icon(Icons.percent)),
                      items: [for (final t in _taxes) DropdownMenuItem(value: t.taux, child: Text(t.libelle))],
                      onChanged: (v) => setState(() => _tva = v ?? 0),
                    ),
                    _ApercuPrix(
                      achat: _n(_prixAchat),
                      detail: _n(_prixDetail),
                      gros: _n(_prixGros),
                      tva: _tva,
                    ),
                  ]),

                  _Section('Stock', [
                    _Ligne2(
                      TextFormField(
                        controller: _stock,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: InputDecoration(
                          labelText: _creation ? 'Stock initial' : 'Stock actuel',
                          suffixText: _unite,
                          helperText: _creation ? null : 'Modifier = ajustement',
                        ),
                        validator: (v) => validerNombre(v, min: -999999),
                      ),
                      TextFormField(
                        controller: _stockMin,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Seuil d\'alerte',
                          suffixText: _unite,
                          helperText: 'Alerte rupture',
                        ),
                        validator: (v) => validerNombre(v),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
      // Boutons fixes en bas : Supprimer (rouge) + Enregistrer (vert)
      bottomNavigationBar: !_pret
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    if (!_creation) ...[
                      Expanded(
                        child: Bouton3D(
                          libelle: 'Supprimer',
                          icone: Icons.delete,
                          couleur: AppColors.supprimer,
                          onPressed: _supprimer,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: 2,
                      child: Bouton3D(
                        libelle: _creation ? 'Ajouter l\'article' : 'Enregistrer',
                        icone: Icons.check,
                        couleur: AppColors.ajouter,
                        chargement: _enregistrement,
                        onPressed: _enregistrer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Carte de section avec titre.
class _Section extends StatelessWidget {
  const _Section(this.titre, this.enfants);
  final String titre;
  final List<Widget> enfants;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(titre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.vente)),
              const SizedBox(height: 12),
              for (final e in enfants) Padding(padding: const EdgeInsets.only(bottom: 12), child: e),
            ],
          ),
        ),
      );
}

/// Deux champs côte à côte ; empilés si l'écran est trop étroit (< 360 px).
class _Ligne2 extends StatelessWidget {
  const _Ligne2(this.a, this.b);
  final Widget a;
  final Widget b;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => c.maxWidth < 360
            ? Column(children: [a, const SizedBox(height: 12), b])
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: a),
                const SizedBox(width: 12),
                Expanded(child: b),
              ]),
      );
}

/// Aperçu calculé : TTC et bénéfice unitaire pour le détail et le gros.
class _ApercuPrix extends StatelessWidget {
  const _ApercuPrix({required this.achat, required this.detail, required this.gros, required this.tva});
  final double achat;
  final double detail;
  final double gros;
  final double tva;

  @override
  Widget build(BuildContext context) {
    Widget colonne(String titre, double ht, Color couleur) {
      final benef = round2(ht - achat);
      final perte = benef < 0;
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: couleur.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: couleur.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titre, style: TextStyle(fontWeight: FontWeight.w800, color: couleur)),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('TTC ${fmtMonnaie(round2(ht * (1 + tva / 100)))}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  perte ? 'Perte ${fmtMonnaie(-benef)}' : 'Bénéfice ${fmtMonnaie(benef)}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: perte ? AppColors.supprimer : AppColors.ajouter),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(children: [
      colonne('Détail', detail, AppColors.vente),
      const SizedBox(width: 10),
      colonne('Gros', gros, AppColors.achat),
    ]);
  }
}
