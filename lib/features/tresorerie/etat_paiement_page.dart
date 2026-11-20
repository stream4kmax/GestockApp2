// =============================================================================
//  EtatPaiementPage — état de paiement des documents clients
// =============================================================================
//  Toutes les ventes (comptoir, BL, factures) avec : payé, reste à payer et une
//  barre de progression. Filtre « Non soldés » activé par défaut.
//  Appui = fiche du document ; bouton 💵 = encaisser directement.
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:gestock_pos/core/constants/type_document.dart';
import 'package:gestock_pos/core/theme/app_colors.dart';
import 'package:gestock_pos/core/utils/formatters.dart';
import 'package:gestock_pos/core/widgets/communs.dart';
import 'package:gestock_pos/core/widgets/relief_3d.dart';
import 'package:gestock_pos/data/repositories/client_repository.dart';
import 'package:gestock_pos/data/repositories/document_repository.dart';
import 'package:gestock_pos/features/documents/document_detail_page.dart';
import 'package:gestock_pos/features/tresorerie/reglement_sheet.dart';

class EtatPaiementPage extends StatefulWidget {
  const EtatPaiementPage({super.key});

  @override
  State<EtatPaiementPage> createState() => _EtatPaiementPageState();
}

class _EtatPaiementPageState extends State<EtatPaiementPage> {
  final _repo = DocumentRepository();
  final _recherche = TextEditingController();
  Timer? _debounce;
  bool _nonSoldes = true;
  List<DocumentResume> _docs = [];
  bool _chargement = true;

  static const _types = [
    TypeDocument.soldeInitialClient, // v2c : crédits antérieurs
    TypeDocument.venteComptoir,
    TypeDocument.bonLivraison,
    TypeDocument.factureVente,
  ];

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
    final res = await _repo.lister(types: _types, recherche: _recherche.text, nonSoldes: _nonSoldes);
    if (!mounted) return;
    setState(() {
      // Les ventes du client comptoir sont toujours payées comptant : on les masque
      _docs = res.where((d) => d.tiersType == 'C').toList();
      _chargement = false;
    });
  }

  Future<void> _encaisser(DocumentResume d) async {
    final c = await ClientRepository().parId(d.tiersId!);
    if (!mounted || c == null) return;
    final ok = await ReglementSheet.ouvrir(context,
        tiersType: 'C', tiersId: c.id, tiersNom: c.nom, solde: c.solde, montantSuggere: d.resteAPayer);
    if (ok) _charger();
  }

  @override
  Widget build(BuildContext context) {
    final totalDu = _docs.fold<double>(0, (s, d) => s + (d.resteAPayer > 0 ? d.resteAPayer : 0));
    return Scaffold(
      appBar: AppBar(title: const Text('État de paiement client')),
      body: Column(children: [
        ChampRecherche(
          controller: _recherche,
          hint: 'Client ou n° de document…',
          onChanged: (_) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 300), _charger);
            setState(() {});
          },
        ),
        SwitchListTile(
          dense: true,
          value: _nonSoldes,
          title: const Text('Seulement les documents non soldés'),
          onChanged: (v) {
            setState(() => _nonSoldes = v);
            _charger();
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Relief3D(
            couleur: const Color(0xFFFFEBEE),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              const Icon(Icons.account_balance_wallet, color: AppColors.supprimer),
              const SizedBox(width: 10),
              const Expanded(child: Text('Reste à encaisser', style: TextStyle(fontWeight: FontWeight.w700))),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(fmtMonnaie(totalDu),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.supprimer)),
                ),
              ),
            ]),
          ),
        ),
        Expanded(
          child: _chargement
              ? const Center(child: CircularProgressIndicator())
              : _docs.isEmpty
                  ? const EtatVide(icone: Icons.verified, message: 'Aucun document')
                  : RefreshIndicator(
                      onRefresh: _charger,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: _docs.length,
                        itemBuilder: (_, i) {
                          final d = _docs[i];
                          final ratio = d.totalTtc <= 0 ? 1.0 : (d.montantPaye / d.totalTtc).clamp(0.0, 1.0);
                          return Card(
                            child: InkWell(
                              onTap: () async {
                                await Navigator.push(
                                    context, MaterialPageRoute(builder: (_) => DocumentDetailPage(documentId: d.id)));
                                _charger();
                              },
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                                child: Row(children: [
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(d.tiersNom ?? '—',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w800)),
                                      Text('${d.numero} · ${fmtDate(d.date)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12, color: AppColors.texteSecondaire)),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: ratio,
                                          minHeight: 7,
                                          color: d.estSolde ? AppColors.ajouter : AppColors.alerte,
                                          backgroundColor: AppColors.supprimer.withValues(alpha: 0.15),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'Total ${fmtMonnaie(d.totalTtc)} · Payé ${fmtMonnaie(d.montantPaye)}'
                                          '${d.estSolde ? ' · Soldé ✓' : ' · Reste ${fmtMonnaie(d.resteAPayer)}'}',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: d.estSolde ? AppColors.ajouter : AppColors.supprimer),
                                        ),
                                      ),
                                    ]),
                                  ),
                                  if (!d.estSolde)
                                    IconButton(
                                      tooltip: 'Encaisser',
                                      icon: const Icon(Icons.payments, color: AppColors.ajouter, size: 30),
                                      onPressed: () => _encaisser(d),
                                    ),
                                ]),
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
