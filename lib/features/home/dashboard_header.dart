// =============================================================================
//  Tableau de bord (v2)
// =============================================================================
//  • Date du jour en toutes lettres : « Dimanche 15 novembre 2026 »
//  • Filtres Jour / Mois / Année (boutons segmentés)
//  • Cartes en relief : Chiffre d'affaires, Bénéfice de la période,
//    Bénéfice du mois (toujours visible), Ventes, Alertes stock
//  • LayoutBuilder : 2 cartes par ligne sur téléphone, 4 sur tablette ;
//    FittedBox : les montants rétrécissent au lieu de déborder.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:gestock_pos/core/theme/app_colors.dart';
import 'package:gestock_pos/core/utils/formatters.dart';
import 'package:gestock_pos/core/widgets/relief_3d.dart';
import 'package:gestock_pos/data/repositories/dashboard_repository.dart';

class DashboardHeader extends StatefulWidget {
  const DashboardHeader({super.key, this.onAlertesTap});

  /// Appui sur la carte "Alertes stock" → ouvre la liste des ruptures.
  final VoidCallback? onAlertesTap;

  @override
  State<DashboardHeader> createState() => _DashboardHeaderState();
}

class _DashboardHeaderState extends State<DashboardHeader> {
  final _repo = DashboardRepository();
  Periode _periode = Periode.jour;
  late Future<TableauDeBord> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.charger(_periode);
  }

  void _changerPeriode(Periode p) => setState(() {
        _periode = p;
        _future = _repo.charger(p); // nouvelle requête seulement quand le filtre change
      });

  String get _suffixe => switch (_periode) {
        Periode.jour => 'du jour',
        Periode.mois => 'du mois',
        Periode.annee => 'de l\'année',
      };

  @override
  Widget build(BuildContext context) {
    final maintenant = DateTime.now();
    final dateTexte = DateFormat('EEEE d MMMM y', 'fr_FR').format(maintenant);
    final dateMaj = dateTexte[0].toUpperCase() + dateTexte.substring(1);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Date du jour ---
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 18, color: AppColors.vente),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(dateMaj,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.texte)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // --- Filtres Jour / Mois / Année ---
          SegmentedButton<Periode>(
            segments: [
              for (final p in Periode.values) ButtonSegment(value: p, label: Text(p.libelle)),
            ],
            selected: {_periode},
            showSelectedIcon: false,
            onSelectionChanged: (s) => _changerPeriode(s.first),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected) ? AppColors.vente : AppColors.surface),
              foregroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected) ? Colors.white : AppColors.texte),
              elevation: const WidgetStatePropertyAll(2),
              shadowColor: const WidgetStatePropertyAll(Colors.black26),
            ),
          ),
          const SizedBox(height: 12),

          // --- Cartes de statistiques ---
          FutureBuilder<TableauDeBord>(
            future: _future,
            builder: (context, snap) {
              if (snap.hasError) {
                return Text('Erreur : ${snap.error}', style: const TextStyle(color: AppColors.supprimer));
              }
              if (!snap.hasData) {
                return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
              }
              final t = snap.data!;
              final s = t.periode;
              final cartes = <Widget>[
                _CarteStat(
                  titre: 'Chiffre d\'affaires $_suffixe',
                  valeur: fmtMonnaie(s.chiffreAffairesTtc),
                  sousTitre: 'HT : ${fmtMonnaie(s.chiffreAffairesHt)}',
                  icone: Icons.point_of_sale,
                  couleur: AppColors.vente,
                ),
                _CarteStat(
                  titre: 'Bénéfice $_suffixe',
                  valeur: fmtMonnaie(s.benefice),
                  sousTitre: 'Marge : ${fmtQte(round2(s.tauxMarge))} %',
                  icone: Icons.trending_up,
                  couleur: s.benefice >= 0 ? AppColors.ajouter : AppColors.supprimer,
                ),
                _CarteStat(
                  titre: 'Bénéfice du mois',
                  valeur: fmtMonnaie(t.beneficeMois),
                  sousTitre: DateFormat('MMMM y', 'fr_FR').format(maintenant),
                  icone: Icons.calendar_month,
                  couleur: AppColors.tresorerie,
                ),
                _CarteStat(
                  titre: 'Ventes $_suffixe',
                  valeur: '${s.nbVentes}',
                  sousTitre: 'Encaissé : ${fmtMonnaie(s.encaisse)}',
                  icone: Icons.receipt_long,
                  couleur: AppColors.achat,
                ),
              ];

              return LayoutBuilder(builder: (context, c) {
                final colonnes = c.maxWidth >= 700 ? 4 : 2;
                const espace = 10.0;
                final largeur = (c.maxWidth - espace * (colonnes - 1)) / colonnes;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: espace,
                      runSpacing: 4,
                      children: [for (final w in cartes) SizedBox(width: largeur, child: w)],
                    ),
                    if (t.nbAlertesStock > 0) ...[
                      const SizedBox(height: 4),
                      Relief3D(
                        onTap: widget.onAlertesTap,
                        couleur: const Color(0xFFFFF3E0),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(children: [
                          const Icon(Icons.warning_amber_rounded, color: AppColors.alerte),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${t.nbAlertesStock} article(s) en rupture ou sous le seuil',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.texte),
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppColors.alerte),
                        ]),
                      ),
                    ],
                  ],
                );
              });
            },
          ),
        ],
      ),
    );
  }
}

/// Carte de statistique en relief. Hauteur fixe + FittedBox = jamais de débordement.
class _CarteStat extends StatelessWidget {
  const _CarteStat({
    required this.titre,
    required this.valeur,
    required this.sousTitre,
    required this.icone,
    required this.couleur,
  });
  final String titre;
  final String valeur;
  final String sousTitre;
  final IconData icone;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Relief3D(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        height: 92,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: couleur.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(icone, size: 18, color: couleur),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(titre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.texteSecondaire, height: 1.1)),
              ),
            ]),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(valeur, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: couleur)),
            ),
            Text(sousTitre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.texteSecondaire)),
          ],
        ),
      ),
    );
  }
}
