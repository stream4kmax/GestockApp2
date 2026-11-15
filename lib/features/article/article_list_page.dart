// =============================================================================
//  ArticleListPage — liste des articles + alertes de rupture (v2)
// =============================================================================
//  • Bandeau d'alerte rouge/orange en haut : nb de ruptures et d'articles sous
//    le seuil (appui = filtre "Alertes")
//  • Filtres : Tous / Alertes / Ruptures
//  • Chaque carte : désignation, prix DÉTAIL et GROS (TTC), stock, fournisseur
//  • Appui = modifier ; menu ⋮ = modifier / supprimer (rouge)
//  • Bouton vert « + Ajouter » pour créer un article
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:gestock_pos/core/theme/app_colors.dart';
import 'package:gestock_pos/core/utils/formatters.dart';
import 'package:gestock_pos/core/widgets/communs.dart';
import 'package:gestock_pos/data/models/article.dart';
import 'package:gestock_pos/data/repositories/article_repository.dart';
import 'package:gestock_pos/features/article/article_form_page.dart';

class ArticleListPage extends StatefulWidget {
  const ArticleListPage({super.key, this.titre = 'Articles', this.filtreInitial = FiltreStock.tous});
  final String titre;
  final FiltreStock filtreInitial;

  @override
  State<ArticleListPage> createState() => _ArticleListPageState();
}

class _ArticleListPageState extends State<ArticleListPage> {
  final _repo = ArticleRepository();
  final _recherche = TextEditingController();
  Timer? _debounce;

  late FiltreStock _filtre = widget.filtreInitial;
  List<Article> _articles = [];
  ({int ruptures, int sousSeuil}) _alertes = (ruptures: 0, sousSeuil: 0);
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _recherche.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() => _chargement = true);
    final res = await _repo.rechercher(_recherche.text, filtre: _filtre);
    final alertes = await _repo.compterAlertes();
    if (!mounted) return;
    setState(() {
      _articles = res;
      _alertes = alertes;
      _chargement = false;
    });
  }

  void _onRecherche(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _charger);
    setState(() {});
  }

  Future<void> _ouvrirFormulaire([Article? article]) async {
    final modifie = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ArticleFormPage(article: article)),
    );
    if (modifie == true) _charger();
  }

  Future<void> _supprimer(Article a) async {
    if (!await confirmerSuppression(context, '« ${a.designation} »')) return;
    await _repo.supprimer(a.id);
    if (!mounted) return;
    afficherMessage(context, 'Article supprimé');
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    final totalAlertes = _alertes.ruptures + _alertes.sousSeuil;
    return Scaffold(
      appBar: AppBar(title: Text(widget.titre)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _ouvrirFormulaire(),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: Column(
        children: [
          ChampRecherche(controller: _recherche, onChanged: _onRecherche, hint: 'Nom, code ou code-barres…'),

          // --- Bandeau d'alerte de rupture ---
          if (totalAlertes > 0)
            Card(
              color: _alertes.ruptures > 0 ? const Color(0xFFFFEBEE) : const Color(0xFFFFF3E0),
              child: ListTile(
                leading: Icon(Icons.warning_amber_rounded,
                    color: _alertes.ruptures > 0 ? AppColors.supprimer : AppColors.alerte, size: 32),
                title: Text(
                  '${_alertes.ruptures} en rupture · ${_alertes.sousSeuil} sous le seuil',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('À réapprovisionner auprès des fournisseurs'),
                trailing: const Icon(Icons.filter_list),
                onTap: () {
                  setState(() => _filtre = FiltreStock.alerte);
                  _charger();
                },
              ),
            ),

          // --- Filtres ---
          SingleChildScrollView(
            scrollDirection: Axis.horizontal, // défile si l'écran est étroit
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                for (final (f, libelle) in [
                  (FiltreStock.tous, 'Tous'),
                  (FiltreStock.alerte, 'Alertes ($totalAlertes)'),
                  (FiltreStock.rupture, 'Ruptures (${_alertes.ruptures})'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(libelle),
                      selected: _filtre == f,
                      elevation: 2,
                      pressElevation: 0,
                      onSelected: (_) {
                        setState(() => _filtre = f);
                        _charger();
                      },
                    ),
                  ),
              ],
            ),
          ),

          // --- Liste ---
          Expanded(
            child: _chargement
                ? const Center(child: CircularProgressIndicator())
                : _articles.isEmpty
                    ? const EtatVide(icone: Icons.inventory_2_outlined, message: 'Aucun article')
                    : RefreshIndicator(
                        onRefresh: _charger,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 96), // place pour le bouton +
                          itemCount: _articles.length,
                          itemBuilder: (_, i) => _CarteArticle(
                            article: _articles[i],
                            onTap: () => _ouvrirFormulaire(_articles[i]),
                            onSupprimer: () => _supprimer(_articles[i]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _CarteArticle extends StatelessWidget {
  const _CarteArticle({required this.article, required this.onTap, required this.onSupprimer});
  final Article article;
  final VoidCallback onTap;
  final VoidCallback onSupprimer;

  @override
  Widget build(BuildContext context) {
    final a = article;
    final couleurBord = a.enRupture
        ? AppColors.supprimer
        : a.sousSeuil
            ? AppColors.alerte
            : Colors.transparent;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(border: Border(left: BorderSide(color: couleurBord, width: 5))),
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.designation,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      '${a.code}${a.fournisseurNom != null ? ' · ${a.fournisseurNom}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.texteSecondaire),
                    ),
                    const SizedBox(height: 6),
                    // Wrap : passe à la ligne si l'écran est trop étroit
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _Prix('Détail', a.prixVenteTtc, AppColors.vente),
                        _Prix('Gros', a.prixGrosTtc, AppColors.achat),
                        StockChip(disponible: a.stock, seuil: a.stockMin, unite: a.unite),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) => v == 'mod' ? onTap() : onSupprimer(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'mod', child: ListTile(leading: Icon(Icons.edit), title: Text('Modifier'))),
                  PopupMenuItem(
                    value: 'sup',
                    child: ListTile(
                      leading: Icon(Icons.delete, color: AppColors.supprimer),
                      title: Text('Supprimer', style: TextStyle(color: AppColors.supprimer)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Prix extends StatelessWidget {
  const _Prix(this.libelle, this.montant, this.couleur);
  final String libelle;
  final double montant;
  final Color couleur;

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(children: [
          TextSpan(text: '$libelle ', style: const TextStyle(fontSize: 11, color: AppColors.texteSecondaire)),
          TextSpan(
              text: fmtMonnaie(montant),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: couleur)),
        ]),
      );
}
