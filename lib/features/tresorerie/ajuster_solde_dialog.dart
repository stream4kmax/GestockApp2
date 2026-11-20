// Boîte « Ajuster le solde » (fiche client et fiche fournisseur).
// On saisit le NOUVEAU solde ; l'application calcule l'écart et enregistre
// un crédit antérieur (hausse) ou un ajustement (baisse).

import 'package:flutter/material.dart';

import 'package:gestock_pos/core/theme/app_colors.dart';
import 'package:gestock_pos/core/utils/formatters.dart';
import 'package:gestock_pos/core/widgets/communs.dart';
import 'package:gestock_pos/data/repositories/solde_repository.dart';

/// Renvoie true si le solde a été modifié.
Future<bool> ajusterSoldeDialog(
  BuildContext context, {
  required String tiersType,
  required String tiersId,
  required String tiersNom,
  required double soldeActuel,
}) async {
  final nouveau = TextEditingController(text: soldeActuel.toStringAsFixed(2));
  final motif = TextEditingController();
  final client = tiersType == 'C';

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final n = parseNombre(nouveau.text);
        final ecart = n == null ? 0.0 : round2(n - soldeActuel);
        return AlertDialog(
          title: const Text('Ajuster le solde'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(tiersNom, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text('${client ? 'Le client doit' : 'Vous devez'} actuellement : ${fmtMonnaie(soldeActuel)}'),
              const SizedBox(height: 14),
              TextField(
                controller: nouveau,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Nouveau solde', suffixText: 'DA'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              if (ecart != 0)
                Text(
                  ecart > 0
                      ? '+ ${fmtMonnaie(ecart)} : un document « ${client ? 'Crédit antérieur' : 'Dette antérieure'} » sera créé'
                      : '− ${fmtMonnaie(-ecart)} : ajustement sans mouvement de caisse',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: ecart > 0 ? AppColors.alerte : AppColors.ajouter),
                ),
              const SizedBox(height: 12),
              TextField(controller: motif, decoration: const InputDecoration(labelText: 'Motif (facultatif)')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.ajouter),
              onPressed: n == null || n < 0 ? null : () => Navigator.pop(ctx, true),
              child: const Text('Valider'),
            ),
          ],
        );
      },
    ),
  );

  final valeur = parseNombre(nouveau.text);
  final texteMotif = motif.text;
  // (Contrôleurs non libérés ici : la boîte peut encore être en animation de
  //  fermeture ; le ramasse-miettes s'en charge.)
  if (ok != true || valeur == null) return false;

  try {
    final message = await SoldeRepository().ajusterSolde(
      tiersType: tiersType,
      tiersId: tiersId,
      tiersNom: tiersNom,
      soldeActuel: soldeActuel,
      nouveauSolde: valeur,
      motif: texteMotif,
    );
    if (context.mounted) afficherMessage(context, message);
    return true;
  } catch (e) {
    if (context.mounted) afficherMessage(context, '$e'.replaceFirst('Exception: ', ''), erreur: true);
    return false;
  }
}
