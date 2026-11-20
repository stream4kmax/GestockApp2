// =============================================================================
//  EtatCaissePage — situation de la trésorerie
// =============================================================================
//  • Solde de caisse (espèces) depuis le début
//  • Pour la période : entrées, sorties, solde net
//  • Encaissements clients par mode de paiement (espèces, chèque, carte…)
//  • Répartition des sorties (règlements fournisseurs, dépenses, retraits)
//  • Ce que les clients doivent / ce que vous devez aux fournisseurs
// =============================================================================

import 'package:flutter/material.dart';

import 'package:gestock_pos/core/constants/mode_paiement.dart';
import 'package:gestock_pos/core/database/database_helper.dart';
import 'package:gestock_pos/core/theme/app_colors.dart';
import 'package:gestock_pos/core/utils/formatters.dart';
import 'package:gestock_pos/core/widgets/periode_selecteur.dart';
import 'package:gestock_pos/core/widgets/relief_3d.dart';
import 'package:gestock_pos/data/repositories/dashboard_repository.dart';
import 'package:gestock_pos/data/repositories/tresorerie_repository.dart';

class EtatCaissePage extends StatefulWidget {
  const EtatCaissePage({super.key});

  @override
  State<EtatCaissePage> createState() => _EtatCaissePageState();
}

class _EtatCaissePageState extends State<EtatCaissePage> {
  final _repo = TresorerieRepository();
  Periode? _periode = Periode.jour;
  double _solde = 0;
  TotauxCaisse _totaux = const TotauxCaisse(0, 0);
  Map<String, double> _parMode = {};
  Map<String, double> _sortiesParType = {};
  double _creancesClients = 0;
  double _dettesFournisseurs = 0;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final (debut, fin) = bornesPeriode(_periode);
    final solde = await _repo.soldeCaisse();
    final totaux = await _repo.totauxCaisse(debut, fin);
    final parMode = await _repo.encaissementsParMode(debut, fin);
    final mvts = await _repo.mouvementsCaisse(debut, fin);
    final sorties = <String, double>{};
    for (final m in mvts.where((m) => m.sens < 0)) {
      final cle = switch (m.sourceType) {
        'REGLEMENT' => 'Règlements / remboursements',
        'DEPENSE' => 'Dépenses',
        'RETRAIT' => 'Retraits',
        _ => 'Autres',
      };
      sorties[cle] = (sorties[cle] ?? 0) + m.montant;
    }
    final db = await DatabaseHelper.instance.database;
    final c = await db.rawQuery('SELECT COALESCE(SUM(solde), 0) AS s FROM clients WHERE deleted = 0 AND solde > 0');
    final f = await db.rawQuery('SELECT COALESCE(SUM(solde), 0) AS s FROM fournisseurs WHERE deleted = 0 AND solde > 0');
    if (!mounted) return;
    setState(() {
      _solde = solde;
      _totaux = totaux;
      _parMode = parMode;
      _sortiesParType = sorties;
      _creancesClients = (c.first['s'] as num).toDouble();
      _dettesFournisseurs = (f.first['s'] as num).toDouble();
      _chargement = false;
    });
  }

  String _libelleMode(String code) =>
      ModePaiement.values.where((m) => m.code == code).map((m) => m.libelle).firstOrNull ?? code;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('État de caisse')),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _charger,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                children: [
                  Relief3D(
                    couleur: AppColors.tresorerie,
                    padding: const EdgeInsets.all(18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Espèces en caisse', style: TextStyle(color: Colors.white70)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(fmtMonnaie(_solde),
                            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                    ]),
                  ),
                  PeriodeSelecteur(
                    valeur: _periode,
                    onChanged: (p) {
                      setState(() => _periode = p);
                      _charger();
                    },
                  ),
                  _Bloc('Caisse sur la période', [
                    _Ligne('Entrées', _totaux.entrees, AppColors.ajouter),
                    _Ligne('Sorties', _totaux.sorties, AppColors.supprimer),
                    _Ligne('Solde net', _totaux.net, _totaux.net >= 0 ? AppColors.vente : AppColors.supprimer, gras: true),
                  ]),
                  _Bloc('Encaissements clients par mode', [
                    if (_parMode.isEmpty) const Text('Aucun encaissement', style: TextStyle(color: AppColors.texteSecondaire)),
                    for (final e in _parMode.entries) _Ligne(_libelleMode(e.key), e.value, AppColors.vente),
                  ]),
                  _Bloc('Sorties de caisse', [
                    if (_sortiesParType.isEmpty) const Text('Aucune sortie', style: TextStyle(color: AppColors.texteSecondaire)),
                    for (final e in _sortiesParType.entries) _Ligne(e.key, e.value, AppColors.supprimer),
                  ]),
                  _Bloc('Créances et dettes (à ce jour)', [
                    _Ligne('Les clients vous doivent', _creancesClients, AppColors.alerte),
                    _Ligne('Vous devez aux fournisseurs', _dettesFournisseurs, AppColors.supprimer),
                  ]),
                ],
              ),
            ),
    );
  }
}

class _Bloc extends StatelessWidget {
  const _Bloc(this.titre, this.enfants);
  final String titre;
  final List<Widget> enfants;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(top: 10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(titre, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.tresorerie)),
            const SizedBox(height: 8),
            ...enfants,
          ]),
        ),
      );
}

class _Ligne extends StatelessWidget {
  const _Ligne(this.libelle, this.montant, this.couleur, {this.gras = false});
  final String libelle;
  final double montant;
  final Color couleur;
  final bool gras;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(libelle, style: TextStyle(fontWeight: gras ? FontWeight.w800 : FontWeight.w500))),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(fmtMonnaie(montant),
                  style: TextStyle(fontWeight: FontWeight.w800, color: couleur, fontSize: gras ? 17 : 15)),
            ),
          ),
        ]),
      );
}
