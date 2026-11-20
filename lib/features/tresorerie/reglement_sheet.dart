// =============================================================================
//  ReglementSheet — saisir un règlement client ou fournisseur
// =============================================================================
//  Utilisée par : Règlement client, Règlement fournisseur, État de paiement,
//  fiche d'un document. Le montant est affecté automatiquement aux documents
//  non soldés les plus anciens (voir TresorerieRepository).
// =============================================================================

import 'package:flutter/material.dart';

import 'package:gestock_pos/core/constants/mode_paiement.dart';
import 'package:gestock_pos/core/theme/app_colors.dart';
import 'package:gestock_pos/core/utils/formatters.dart';
import 'package:gestock_pos/core/widgets/communs.dart';
import 'package:gestock_pos/core/widgets/relief_3d.dart';
import 'package:gestock_pos/data/repositories/tresorerie_repository.dart';

class ReglementSheet extends StatefulWidget {
  const ReglementSheet({
    super.key,
    required this.tiersType,
    required this.tiersId,
    required this.tiersNom,
    required this.solde,
    this.montantSuggere,
  });

  final String tiersType; // 'C' ou 'F'
  final String tiersId;
  final String tiersNom;
  final double solde;
  final double? montantSuggere;

  /// Ouvre la feuille ; renvoie true si un règlement a été enregistré.
  static Future<bool> ouvrir(
    BuildContext context, {
    required String tiersType,
    required String tiersId,
    required String tiersNom,
    required double solde,
    double? montantSuggere,
  }) async {
    final r = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => ReglementSheet(
        tiersType: tiersType,
        tiersId: tiersId,
        tiersNom: tiersNom,
        solde: solde,
        montantSuggere: montantSuggere,
      ),
    );
    return r ?? false;
  }

  @override
  State<ReglementSheet> createState() => _ReglementSheetState();
}

class _ReglementSheetState extends State<ReglementSheet> {
  late final _montant = TextEditingController(
      text: ((widget.montantSuggere ?? widget.solde) > 0 ? (widget.montantSuggere ?? widget.solde) : 0)
          .toStringAsFixed(2));
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  ModePaiement _mode = ModePaiement.especes;
  bool _enregistrement = false;

  bool get _client => widget.tiersType == 'C';

  @override
  void dispose() {
    _montant.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    final m = parseNombre(_montant.text) ?? 0;
    if (m <= 0) {
      afficherMessage(context, 'Saisissez un montant.', erreur: true);
      return;
    }
    setState(() => _enregistrement = true);
    try {
      final nb = await TresorerieRepository().enregistrerReglement(
        tiersType: widget.tiersType,
        tiersId: widget.tiersId,
        tiersNom: widget.tiersNom,
        montant: m,
        mode: _mode,
        reference: _reference.text.trim().isEmpty ? null : _reference.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (!mounted) return;
      afficherMessage(context, 'Règlement de ${fmtMonnaie(m)} enregistré ($nb document(s) mis à jour)');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) afficherMessage(context, '$e'.replaceFirst('Exception: ', ''), erreur: true);
    } finally {
      if (mounted) setState(() => _enregistrement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clavier = MediaQuery.viewInsetsOf(context).bottom;
    final m = parseNombre(_montant.text) ?? 0;
    final nouveauSolde = round2(widget.solde - m);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + clavier),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(_client ? 'Règlement reçu de' : 'Règlement versé à',
              style: const TextStyle(color: AppColors.texteSecondaire)),
          Text(widget.tiersNom, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${_client ? 'Le client doit' : 'Vous devez'} : ${fmtMonnaie(widget.solde)}',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: widget.solde > 0 ? AppColors.supprimer : AppColors.ajouter)),
          const SizedBox(height: 14),
          TextField(
            controller: _montant,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Montant', suffixText: 'DA', prefixIcon: Icon(Icons.payments)),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 6),
          Text('Solde après règlement : ${fmtMonnaie(nouveauSolde)}',
              style: const TextStyle(fontSize: 12, color: AppColors.texteSecondaire)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final mode in ModePaiement.values.where((x) => x != ModePaiement.credit))
              ChoiceChip(
                avatar: Icon(mode.icone, size: 18),
                label: Text(mode.libelle),
                selected: _mode == mode,
                onSelected: (_) => setState(() => _mode = mode),
              ),
          ]),
          if (_mode == ModePaiement.cheque || _mode == ModePaiement.virement) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _reference,
              decoration: InputDecoration(
                  labelText: _mode == ModePaiement.cheque ? 'N° de chèque / banque' : 'Référence du virement',
                  prefixIcon: const Icon(Icons.numbers)),
            ),
          ],
          const SizedBox(height: 12),
          TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes', prefixIcon: Icon(Icons.notes))),
          const SizedBox(height: 16),
          Bouton3D(
            libelle: 'Enregistrer le règlement',
            icone: Icons.check_circle,
            couleur: AppColors.ajouter,
            chargement: _enregistrement,
            onPressed: _enregistrer,
          ),
        ]),
      ),
    );
  }
}
