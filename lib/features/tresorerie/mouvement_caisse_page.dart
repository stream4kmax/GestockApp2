// =============================================================================
//  MouvementCaissePage — entrées et sorties d'espèces
// =============================================================================
//  • Solde de caisse actuel + entrées / sorties de la période
//  • Liste des mouvements (ventes en espèces, règlements, apports, dépenses…)
//  • Bouton « + » : ajouter un apport (+), une dépense (−) ou un retrait (−)
//  • Glisser vers la gauche : supprimer un mouvement MANUEL
//    (les mouvements liés à une vente / un règlement ne se suppriment pas ici)
// =============================================================================

import 'package:flutter/material.dart';

import 'package:gestock_pos/core/theme/app_colors.dart';
import 'package:gestock_pos/core/utils/formatters.dart';
import 'package:gestock_pos/core/widgets/communs.dart';
import 'package:gestock_pos/core/widgets/periode_selecteur.dart';
import 'package:gestock_pos/core/widgets/relief_3d.dart';
import 'package:gestock_pos/data/repositories/dashboard_repository.dart';
import 'package:gestock_pos/data/repositories/tresorerie_repository.dart';

class MouvementCaissePage extends StatefulWidget {
  const MouvementCaissePage({super.key});

  @override
  State<MouvementCaissePage> createState() => _MouvementCaissePageState();
}

class _MouvementCaissePageState extends State<MouvementCaissePage> {
  final _repo = TresorerieRepository();
  Periode? _periode = Periode.jour;
  List<MouvementCaisse> _mvts = [];
  double _solde = 0;
  TotauxCaisse _totaux = const TotauxCaisse(0, 0);
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final (debut, fin) = bornesPeriode(_periode);
    final mvts = await _repo.mouvementsCaisse(debut, fin);
    final solde = await _repo.soldeCaisse();
    final totaux = await _repo.totauxCaisse(debut, fin);
    if (!mounted) return;
    setState(() {
      _mvts = mvts;
      _solde = solde;
      _totaux = totaux;
      _chargement = false;
    });
  }

  Future<void> _ajouter() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _NouveauMouvementSheet(),
    );
    if (ok == true) _charger();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mouvement caisse')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ajouter,
        icon: const Icon(Icons.add),
        label: const Text('Mouvement'),
      ),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            // Solde actuel
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Relief3D(
                couleur: AppColors.tresorerie,
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  const Icon(Icons.savings, color: Colors.white, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Solde de caisse actuel', style: TextStyle(color: Colors.white70)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(fmtMonnaie(_solde),
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
            PeriodeSelecteur(
              valeur: _periode,
              onChanged: (p) {
                setState(() => _periode = p);
                _charger();
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                Expanded(child: _MiniTotal('Entrées', _totaux.entrees, AppColors.ajouter, Icons.south_west)),
                const SizedBox(width: 8),
                Expanded(child: _MiniTotal('Sorties', _totaux.sorties, AppColors.supprimer, Icons.north_east)),
                const SizedBox(width: 8),
                Expanded(
                    child: _MiniTotal('Net', _totaux.net, _totaux.net >= 0 ? AppColors.vente : AppColors.supprimer, Icons.balance)),
              ]),
            ),
            if (_chargement)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
            else if (_mvts.isEmpty)
              const SizedBox(height: 220, child: EtatVide(icone: Icons.compare_arrows, message: 'Aucun mouvement sur cette période'))
            else
              for (final m in _mvts)
                Card(
                  child: Dismissible(
                    key: ValueKey(m.id),
                    direction: m.sourceType == 'REGLEMENT' ? DismissDirection.none : DismissDirection.endToStart,
                    background: Container(
                      color: AppColors.supprimer,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (_) => confirmerSuppression(context, 'ce mouvement'),
                    onDismissed: (_) async {
                      // Retirer tout de suite de la liste (exigé par Dismissible), puis en base
                      setState(() => _mvts.remove(m));
                      await _repo.supprimerMouvementCaisse(m.id);
                      _charger();
                    },
                    child: ListTile(
                      leading: Icon(m.sens > 0 ? Icons.add_circle : Icons.remove_circle,
                          color: m.sens > 0 ? AppColors.ajouter : AppColors.supprimer, size: 32),
                      title: Text(m.libelle, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${_libelleSource(m.sourceType)} · ${fmtDate(m.date)}'),
                      trailing: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 110),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('${m.sens > 0 ? '+' : '−'}${fmtMonnaie(m.montant)}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, color: m.sens > 0 ? AppColors.ajouter : AppColors.supprimer)),
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  static String _libelleSource(String? s) => switch (s) {
        'REGLEMENT' => 'Règlement',
        'APPORT' => 'Apport',
        'DEPENSE' => 'Dépense',
        'RETRAIT' => 'Retrait',
        _ => 'Autre',
      };
}

class _MiniTotal extends StatelessWidget {
  const _MiniTotal(this.libelle, this.montant, this.couleur, this.icone);
  final String libelle;
  final double montant;
  final Color couleur;
  final IconData icone;

  @override
  Widget build(BuildContext context) => Relief3D(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(children: [
          Icon(icone, color: couleur, size: 20),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(fmtMonnaie(montant), style: TextStyle(fontWeight: FontWeight.w800, color: couleur)),
          ),
          Text(libelle, style: const TextStyle(fontSize: 11, color: AppColors.texteSecondaire)),
        ]),
      );
}

/// Feuille d'ajout : Apport (+) / Dépense (−) / Retrait (−).
class _NouveauMouvementSheet extends StatefulWidget {
  const _NouveauMouvementSheet();

  @override
  State<_NouveauMouvementSheet> createState() => _NouveauMouvementSheetState();
}

class _NouveauMouvementSheetState extends State<_NouveauMouvementSheet> {
  final _montant = TextEditingController();
  final _libelle = TextEditingController();
  String _type = 'DEPENSE';
  bool _enregistrement = false;

  static const _types = {
    'APPORT': ('Apport (+)', Icons.add_circle, AppColors.ajouter),
    'DEPENSE': ('Dépense (−)', Icons.shopping_bag, AppColors.supprimer),
    'RETRAIT': ('Retrait (−)', Icons.outbox, AppColors.alerte),
  };
  static const _suggestions = {
    'APPORT': ['Fond de caisse', 'Apport du gérant'],
    'DEPENSE': ['Transport', 'Électricité', 'Loyer', 'Fournitures', 'Repas', 'Salaire'],
    'RETRAIT': ['Versement en banque', 'Retrait du gérant'],
  };

  @override
  void dispose() {
    _montant.dispose();
    _libelle.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    final m = parseNombre(_montant.text) ?? 0;
    if (m <= 0 || _libelle.text.trim().isEmpty) {
      afficherMessage(context, 'Saisissez un montant et un libellé.', erreur: true);
      return;
    }
    setState(() => _enregistrement = true);
    await TresorerieRepository().ajouterMouvementCaisse(
      sens: _type == 'APPORT' ? 1 : -1,
      montant: m,
      libelle: _libelle.text.trim(),
      sourceType: _type,
    );
    if (!mounted) return;
    afficherMessage(context, 'Mouvement enregistré');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final clavier = MediaQuery.viewInsetsOf(context).bottom;
    final (_, _, couleur) = _types[_type]!;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + clavier),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Nouveau mouvement de caisse', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final e in _types.entries)
              ChoiceChip(
                avatar: Icon(e.value.$2, size: 18, color: e.value.$3),
                label: Text(e.value.$1),
                selected: _type == e.key,
                onSelected: (_) => setState(() => _type = e.key),
              ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _montant,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Montant', suffixText: 'DA', prefixIcon: Icon(Icons.payments)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _libelle,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Libellé', prefixIcon: Icon(Icons.edit_note)),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final s in _suggestions[_type]!) ActionChip(label: Text(s), onPressed: () => _libelle.text = s),
          ]),
          const SizedBox(height: 16),
          Bouton3D(
            libelle: 'Enregistrer',
            icone: Icons.check,
            couleur: couleur,
            chargement: _enregistrement,
            onPressed: _enregistrer,
          ),
        ]),
      ),
    );
  }
}
