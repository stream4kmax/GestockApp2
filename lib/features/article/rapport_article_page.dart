// =============================================================================
//  RapportArticlePage — « Vente par article » et « Achat par article »
// =============================================================================
//  Pour la période choisie, chaque article avec : quantité, montant HT / TTC,
//  nombre de documents et, pour les ventes, le BÉNÉFICE (vente − achat).
//  Les retours et avoirs sont déduits. Tri : du plus gros montant au plus petit.
// =============================================================================

import 'package:flutter/material.dart';

import 'package:gestock_pos/core/theme/app_colors.dart';
import 'package:gestock_pos/core/utils/formatters.dart';
import 'package:gestock_pos/core/widgets/communs.dart';
import 'package:gestock_pos/core/widgets/periode_selecteur.dart';
import 'package:gestock_pos/core/widgets/relief_3d.dart';
import 'package:gestock_pos/data/repositories/dashboard_repository.dart';
import 'package:gestock_pos/data/repositories/rapport_repository.dart';

class RapportArticlePage extends StatefulWidget {
  const RapportArticlePage({super.key, required this.ventes});

  /// true = Vente par article ; false = Achat par article.
  final bool ventes;

  @override
  State<RapportArticlePage> createState() => _RapportArticlePageState();
}

class _RapportArticlePageState extends State<RapportArticlePage> {
  final _repo = RapportRepository();
  Periode? _periode = Periode.mois;
  String _recherche = '';
  List<LigneRapport> _lignes = [];
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final (debut, fin) = bornesPeriode(_periode);
    final res = await _repo.parArticle(ventes: widget.ventes, debut: debut, fin: fin);
    if (!mounted) return;
    setState(() {
      _lignes = res;
      _chargement = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final couleur = widget.ventes ? AppColors.vente : AppColors.achat;
    final visibles = _recherche.isEmpty
        ? _lignes
        : _lignes.where((l) => l.designation.toLowerCase().contains(_recherche.toLowerCase())).toList();
    final totalHt = visibles.fold<double>(0, (s, l) => s + l.montantHt);
    final totalBenef = visibles.fold<double>(0, (s, l) => s + l.benefice);
    final maxHt = visibles.isEmpty ? 1.0 : visibles.map((l) => l.montantHt.abs()).reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(title: Text(widget.ventes ? 'Vente par article' : 'Achat par article')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            decoration: const InputDecoration(hintText: 'Filtrer par article…', prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() => _recherche = v.trim()),
          ),
        ),
        PeriodeSelecteur(
          valeur: _periode,
          onChanged: (p) {
            setState(() => _periode = p);
            _charger();
          },
        ),
        // Totaux en relief
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: Row(children: [
            Expanded(child: _Total(widget.ventes ? 'Ventes HT' : 'Achats HT', fmtMonnaie(totalHt), couleur)),
            if (widget.ventes) ...[
              const SizedBox(width: 10),
              Expanded(
                child: _Total('Bénéfice', fmtMonnaie(totalBenef), totalBenef >= 0 ? AppColors.ajouter : AppColors.supprimer),
              ),
            ],
          ]),
        ),
        Expanded(
          child: _chargement
              ? const Center(child: CircularProgressIndicator())
              : visibles.isEmpty
                  ? EtatVide(
                      icone: widget.ventes ? Icons.trending_up : Icons.trending_down,
                      message: 'Aucune donnée sur cette période')
                  : RefreshIndicator(
                      onRefresh: _charger,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: visibles.length,
                        itemBuilder: (_, i) {
                          final l = visibles[i];
                          final marge = l.montantHt == 0 ? 0 : l.benefice / l.montantHt * 100;
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Text('${i + 1}. ', style: TextStyle(fontWeight: FontWeight.w800, color: couleur)),
                                  Expanded(
                                    child: Text(l.designation,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w700)),
                                  ),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(fmtMonnaie(l.montantHt),
                                          style: TextStyle(fontWeight: FontWeight.w800, color: couleur)),
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 6),
                                // Barre proportionnelle au montant (repère visuel)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: maxHt <= 0 ? 0 : (l.montantHt.abs() / maxHt).clamp(0.0, 1.0),
                                    minHeight: 6,
                                    color: couleur,
                                    backgroundColor: couleur.withValues(alpha: 0.1),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(spacing: 12, runSpacing: 2, children: [
                                  Text('Qté : ${fmtQte(l.quantite)} ${l.unite}', style: const TextStyle(fontSize: 12)),
                                  Text('TTC : ${fmtMonnaie(l.montantTtc)}', style: const TextStyle(fontSize: 12)),
                                  Text('${l.nbDocuments} doc.', style: const TextStyle(fontSize: 12)),
                                  if (widget.ventes)
                                    Text('Bénéfice : ${fmtMonnaie(l.benefice)} (${fmtQte(round2(marge))} %)',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: l.benefice >= 0 ? AppColors.ajouter : AppColors.supprimer)),
                                ]),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ]),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total(this.libelle, this.valeur, this.couleur);
  final String libelle;
  final String valeur;
  final Color couleur;

  @override
  Widget build(BuildContext context) => Relief3D(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(libelle, style: const TextStyle(fontSize: 12, color: AppColors.texteSecondaire)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(valeur, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: couleur)),
          ),
        ]),
      );
}
