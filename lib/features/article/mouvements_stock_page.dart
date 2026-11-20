// =============================================================================
//  MouvementsStockPage — journal de toutes les entrées et sorties de stock
// =============================================================================
//  Filtres : période, Entrées / Sorties, recherche par article.
//  Chaque ligne : date, article, type (vente, réception, bon de sortie…),
//  quantité (+ vert / − rouge), stock après le mouvement, n° de document.
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:gestock_pos/core/theme/app_colors.dart';
import 'package:gestock_pos/core/utils/formatters.dart';
import 'package:gestock_pos/core/widgets/communs.dart';
import 'package:gestock_pos/core/widgets/periode_selecteur.dart';
import 'package:gestock_pos/data/repositories/dashboard_repository.dart';
import 'package:gestock_pos/data/repositories/rapport_repository.dart';

class MouvementsStockPage extends StatefulWidget {
  const MouvementsStockPage({super.key});

  @override
  State<MouvementsStockPage> createState() => _MouvementsStockPageState();
}

class _MouvementsStockPageState extends State<MouvementsStockPage> {
  final _repo = RapportRepository();
  final _recherche = TextEditingController();
  Timer? _debounce;
  Periode? _periode = Periode.mois;
  SensMouvement _sens = SensMouvement.tous;
  List<MouvementStock> _mvts = [];
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
    final (debut, fin) = bornesPeriode(_periode);
    final res = await _repo.mouvements(debut: debut, fin: fin, recherche: _recherche.text, sens: _sens);
    if (!mounted) return;
    setState(() {
      _mvts = res;
      _chargement = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final entrees = _mvts.where((m) => m.sens > 0).length;
    final sorties = _mvts.length - entrees;
    return Scaffold(
      appBar: AppBar(title: const Text('Mouvements de stock')),
      body: Column(children: [
        ChampRecherche(
          controller: _recherche,
          hint: 'Rechercher un article…',
          onChanged: (_) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 300), _charger);
            setState(() {});
          },
        ),
        PeriodeSelecteur(
          valeur: _periode,
          onChanged: (p) {
            setState(() => _periode = p);
            _charger();
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: SegmentedButton<SensMouvement>(
            segments: const [
              ButtonSegment(value: SensMouvement.tous, label: Text('Tous')),
              ButtonSegment(value: SensMouvement.entrees, label: Text('Entrées'), icon: Icon(Icons.south_west)),
              ButtonSegment(value: SensMouvement.sorties, label: Text('Sorties'), icon: Icon(Icons.north_east)),
            ],
            selected: {_sens},
            showSelectedIcon: false,
            onSelectionChanged: (s) {
              setState(() => _sens = s.first);
              _charger();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Text('${_mvts.length} mouvement(s) · $entrees entrée(s) · $sorties sortie(s)',
              style: const TextStyle(color: AppColors.texteSecondaire)),
        ),
        Expanded(
          child: _chargement
              ? const Center(child: CircularProgressIndicator())
              : _mvts.isEmpty
                  ? const EtatVide(icone: Icons.swap_vert, message: 'Aucun mouvement sur cette période')
                  : RefreshIndicator(
                      onRefresh: _charger,
                      child: ListView.builder(
                        itemCount: _mvts.length,
                        itemBuilder: (_, i) {
                          final m = _mvts[i];
                          final entree = m.sens > 0;
                          final couleur = entree ? AppColors.ajouter : AppColors.supprimer;
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: couleur.withValues(alpha: 0.12),
                                child: Icon(entree ? Icons.south_west : Icons.north_east, color: couleur),
                              ),
                              title: Text(m.articleNom,
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text(
                                [
                                  m.typeLibelle,
                                  if (m.documentNumero != null) m.documentNumero!,
                                  if (m.tiersNom != null && m.tiersNom!.isNotEmpty) m.tiersNom!,
                                  fmtDate(m.date),
                                ].join(' · '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 100),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text('${entree ? '+' : '−'}${fmtQte(m.quantite)} ${m.unite}',
                                          style: TextStyle(fontWeight: FontWeight.w800, color: couleur)),
                                    ),
                                    if (m.stockApres != null)
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text('Stock ${fmtQte(m.stockApres!)}',
                                            style: const TextStyle(fontSize: 11, color: AppColors.texteSecondaire)),
                                      ),
                                  ],
                                ),
                              ),
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
