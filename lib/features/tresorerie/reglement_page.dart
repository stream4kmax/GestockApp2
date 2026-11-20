// =============================================================================
//  ReglementPage — Règlement client / Règlement fournisseur
// =============================================================================
//  Onglet « À régler » : clients qui doivent de l'argent (ou fournisseurs à
//  payer), du plus gros solde au plus petit → appui = saisir le règlement.
//  Onglet « Historique » : derniers règlements enregistrés.
//  Bouton « + » : règlement pour n'importe quel tiers (acompte, avance…).
// =============================================================================

import 'package:flutter/material.dart';

import 'package:gestock_pos/core/theme/app_colors.dart';
import 'package:gestock_pos/core/utils/formatters.dart';
import 'package:gestock_pos/core/widgets/communs.dart';
import 'package:gestock_pos/core/widgets/message_sheet.dart';
import 'package:gestock_pos/data/repositories/client_repository.dart';
import 'package:gestock_pos/data/repositories/fournisseur_repository.dart';
import 'package:gestock_pos/data/repositories/reference_repository.dart';
import 'package:gestock_pos/data/repositories/tresorerie_repository.dart';
import 'package:gestock_pos/features/tresorerie/reglement_sheet.dart';
import 'package:gestock_pos/services/messaging_service.dart';

/// Tiers simplifié (client ou fournisseur).
class _Tiers {
  const _Tiers(this.id, this.nom, this.solde, this.numero);
  final String id;
  final String nom;
  final double solde;
  final String? numero;
}

class ReglementPage extends StatefulWidget {
  const ReglementPage({super.key, required this.tiersType});
  final String tiersType; // 'C' ou 'F'

  @override
  State<ReglementPage> createState() => _ReglementPageState();
}

class _ReglementPageState extends State<ReglementPage> {
  List<_Tiers> _tous = [];
  List<Reglement> _historique = [];
  bool _chargement = true;

  bool get _client => widget.tiersType == 'C';
  Color get _couleur => _client ? AppColors.vente : AppColors.achat;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final tiers = <_Tiers>[];
    if (_client) {
      for (final c in await ClientRepository().tous()) {
        if (!c.estComptoir) tiers.add(_Tiers(c.id, c.nom, c.solde, c.numeroWhatsApp));
      }
    } else {
      for (final r in await FournisseurRepository().tous()) {
        final f = r.fournisseur;
        tiers.add(_Tiers(f.id, f.nom, f.solde, f.numeroWhatsApp));
      }
    }
    tiers.sort((a, b) => b.solde.compareTo(a.solde));
    final hist = await TresorerieRepository().reglementsRecents(widget.tiersType);
    if (!mounted) return;
    setState(() {
      _tous = tiers;
      _historique = hist;
      _chargement = false;
    });
  }

  Future<void> _regler(_Tiers t) async {
    final ok = await ReglementSheet.ouvrir(context,
        tiersType: widget.tiersType, tiersId: t.id, tiersNom: t.nom, solde: t.solde);
    if (ok) _charger();
  }

  Future<void> _relancer(_Tiers t) async {
    final societe = await ReferenceRepository().raisonSociale();
    if (!mounted) return;
    await MessageSheet.ouvrir(
      context,
      titre: 'Relance — ${t.nom}',
      numero: t.numero,
      tiersType: 'C',
      tiersId: t.id,
      modeles: [
        ModeleMessage('Relance', 'RELANCE', MessagingService.messageRelance(nomClient: t.nom, solde: t.solde, societe: societe)),
      ],
    );
  }

  /// Choisir n'importe quel tiers (même sans solde) pour un acompte.
  Future<void> _choisirTiers() async {
    final t = await showModalBottomSheet<_Tiers>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => ListView(shrinkWrap: true, children: [
        for (final t in _tous)
          ListTile(
            title: Text(t.nom),
            subtitle: Text('Solde : ${fmtMonnaie(t.solde)}'),
            onTap: () => Navigator.pop(ctx, t),
          ),
      ]),
    );
    if (t != null) _regler(t);
  }

  @override
  Widget build(BuildContext context) {
    final aRegler = _tous.where((t) => t.solde > 0.009).toList();
    final total = aRegler.fold<double>(0, (s, t) => s + t.solde);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_client ? 'Règlement client' : 'Règlement fournisseur'),
          bottom: TabBar(
            labelColor: _couleur,
            indicatorColor: _couleur,
            tabs: const [Tab(text: 'À régler'), Tab(text: 'Historique')],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _tous.isEmpty ? null : _choisirTiers,
          icon: const Icon(Icons.add),
          label: const Text('Règlement'),
        ),
        body: _chargement
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(children: [
                // ---------------- À régler ----------------
                RefreshIndicator(
                  onRefresh: _charger,
                  child: ListView(padding: const EdgeInsets.only(bottom: 96), children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Row(children: [
                        Expanded(
                          child: Text(_client ? 'Total dû par les clients' : 'Total dû aux fournisseurs',
                              style: const TextStyle(color: AppColors.texteSecondaire)),
                        ),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(fmtMonnaie(total),
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.supprimer)),
                          ),
                        ),
                      ]),
                    ),
                    if (aRegler.isEmpty)
                      const SizedBox(height: 260, child: EtatVide(icone: Icons.verified, message: 'Rien à régler 👍')),
                    for (final t in aRegler)
                      Card(
                        child: ListTile(
                          onTap: () => _regler(t),
                          leading: CircleAvatar(
                            backgroundColor: _couleur.withValues(alpha: 0.12),
                            child: Icon(_client ? Icons.person : Icons.local_shipping, color: _couleur),
                          ),
                          title: Text(t.nom, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(fmtMonnaie(t.solde),
                              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.supprimer)),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (_client)
                              IconButton(
                                tooltip: 'Relancer (WhatsApp / SMS)',
                                icon: const Icon(Icons.notifications_active, color: AppColors.alerte),
                                onPressed: () => _relancer(t),
                              ),
                            const Icon(Icons.payments, color: AppColors.ajouter),
                          ]),
                        ),
                      ),
                  ]),
                ),
                // ---------------- Historique ----------------
                RefreshIndicator(
                  onRefresh: _charger,
                  child: _historique.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 300, child: EtatVide(icone: Icons.history, message: 'Aucun règlement')),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 96),
                          itemCount: _historique.length,
                          itemBuilder: (_, i) {
                            final r = _historique[i];
                            final recu = r.sens > 0;
                            return Card(
                              child: ListTile(
                                leading: Icon(recu ? Icons.call_received : Icons.call_made,
                                    color: recu ? AppColors.ajouter : AppColors.supprimer),
                                title: Text(r.tiersNom, maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text([
                                  r.modeLibelle,
                                  if (r.reference != null) r.reference!,
                                  if (r.documentNumero != null) r.documentNumero!,
                                  fmtDate(r.date),
                                ].join(' · ')),
                                trailing: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 110),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(fmtMonnaie(r.montant),
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800, color: recu ? AppColors.ajouter : AppColors.supprimer)),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ]),
      ),
    );
  }
}
