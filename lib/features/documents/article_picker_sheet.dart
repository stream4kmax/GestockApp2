// =============================================================================
//  ArticlePickerSheet — choisir des articles à ajouter à un document
// =============================================================================
//  La feuille reste ouverte : on peut ajouter plusieurs articles à la suite.
//  Un badge indique la quantité déjà ajoutée. Lecteur de codes-barres pris
//  en charge (saisie + Entrée).
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:gestock_pos/core/theme/app_colors.dart';
import 'package:gestock_pos/core/utils/formatters.dart';
import 'package:gestock_pos/core/widgets/communs.dart';
import 'package:gestock_pos/data/models/article.dart';
import 'package:gestock_pos/data/repositories/article_repository.dart';

class ArticlePickerSheet extends StatefulWidget {
  const ArticlePickerSheet({super.key, required this.onChoisir, required this.quantiteDe});

  final void Function(Article) onChoisir;
  final double Function(String articleId) quantiteDe;

  static Future<void> ouvrir(BuildContext context,
      {required void Function(Article) onChoisir, required double Function(String) quantiteDe}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9,
        child: ArticlePickerSheet(onChoisir: onChoisir, quantiteDe: quantiteDe),
      ),
    );
  }

  @override
  State<ArticlePickerSheet> createState() => _ArticlePickerSheetState();
}

class _ArticlePickerSheetState extends State<ArticlePickerSheet> {
  final _repo = ArticleRepository();
  final _recherche = TextEditingController();
  Timer? _debounce;
  List<Article> _articles = [];

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
    final res = await _repo.rechercher(_recherche.text);
    if (mounted) setState(() => _articles = res);
  }

  void _choisir(Article a) {
    widget.onChoisir(a);
    setState(() {}); // met à jour le badge
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Row(children: [
            const Expanded(
              child: Text('Ajouter des articles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.ajouter),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check),
              label: const Text('Terminé'),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _recherche,
            autofocus: false,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(hintText: 'Nom, code ou code-barres…', prefixIcon: Icon(Icons.search)),
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), _charger);
            },
            onSubmitted: (v) async {
              final a = await _repo.parCodeBarre(v);
              if (a != null) {
                _choisir(a);
                _recherche.clear();
                _charger();
              }
            },
          ),
        ),
        Expanded(
          child: _articles.isEmpty
              ? const EtatVide(icone: Icons.search_off, message: 'Aucun article')
              : ListView.builder(
                  itemCount: _articles.length,
                  itemBuilder: (_, i) {
                    final a = _articles[i];
                    final q = widget.quantiteDe(a.id);
                    return ListTile(
                      onTap: () => _choisir(a),
                      leading: Badge(
                        isLabelVisible: q > 0,
                        backgroundColor: AppColors.ajouter,
                        label: Text(fmtQte(q)),
                        child: const Icon(Icons.add_circle, color: AppColors.ajouter, size: 32),
                      ),
                      title: Text(a.designation, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        StockChip(disponible: a.stock, seuil: a.stockMin, unite: a.unite),
                        Text('Achat ${fmtMonnaie(a.prixAchatHt)} HT', style: const TextStyle(fontSize: 12)),
                      ]),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
