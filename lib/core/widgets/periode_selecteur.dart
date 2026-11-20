// Sélecteur de période réutilisable : Jour / Mois / Année / Tout.
// `null` = « Tout » (aucune limite de date).

import 'package:flutter/material.dart';

import 'package:gestock_pos/data/repositories/dashboard_repository.dart';

/// Bornes [début, fin[ d'une période ; null = tout l'historique.
(DateTime, DateTime) bornesPeriode(Periode? p) =>
    p == null ? (DateTime(2000), DateTime(2100)) : p.bornes(DateTime.now());

class PeriodeSelecteur extends StatelessWidget {
  const PeriodeSelecteur({super.key, required this.valeur, required this.onChanged, this.avecTout = true});

  final Periode? valeur;
  final ValueChanged<Periode?> onChanged;
  final bool avecTout;

  @override
  Widget build(BuildContext context) {
    final options = <(Periode?, String)>[
      (Periode.jour, 'Jour'),
      (Periode.mois, 'Mois'),
      (Periode.annee, 'Année'),
      if (avecTout) (null, 'Tout'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          for (final (p, libelle) in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(libelle),
                selected: valeur == p,
                elevation: 2,
                pressElevation: 0,
                onSelected: (_) => onChanged(p),
              ),
            ),
        ],
      ),
    );
  }
}
