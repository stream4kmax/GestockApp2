// =============================================================================
//  PaiementDialog — encaissement (ou remboursement pour un avoir / retour)
// =============================================================================
//  • Choix du mode : Espèces, Chèque, Virement, Carte, À crédit
//  • Montant reçu + boutons rapides (billets) + calcul du rendu monnaie
//  • Paiement partiel autorisé pour un client identifié (le reste va au solde)
//  • Client comptoir : paiement intégral obligatoire
// =============================================================================

import 'package:flutter/material.dart';

import 'package:gestock_pos/core/constants/mode_paiement.dart';
import 'package:gestock_pos/core/utils/formatters.dart';
import 'package:gestock_pos/data/models/paiement.dart';

class PaiementDialog extends StatefulWidget {
  const PaiementDialog({
    super.key,
    required this.total,
    required this.creditAutorise,
    this.titre = 'Encaissement',
  });

  final double total;
  final bool creditAutorise;
  final String titre;

  @override
  State<PaiementDialog> createState() => _PaiementDialogState();
}

class _PaiementDialogState extends State<PaiementDialog> {
  ModePaiement _mode = ModePaiement.especes;
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.total.toStringAsFixed(2));

  double get _recu => parseNombre(_ctrl.text) ?? 0;
  Paiement get _paiement => Paiement(mode: _mode, montantRecu: _mode == ModePaiement.credit ? 0 : _recu);

  /// Message bloquant (bouton Valider désactivé) ou null si tout est correct.
  String? get _erreur {
    if (!widget.creditAutorise) {
      if (_mode == ModePaiement.credit) return 'Crédit impossible pour le client comptoir.';
      if (_recu + 0.001 < widget.total) return 'Montant insuffisant.';
    }
    if (_recu < 0) return 'Montant invalide.';
    return null;
  }

  /// Boutons rapides : montant exact + billets courants arrondis au-dessus.
  List<double> get _montantsRapides {
    final valeurs = <double>{widget.total};
    for (final billet in [200, 500, 1000, 2000]) {
      valeurs.add((widget.total / billet).ceil() * billet.toDouble());
    }
    return valeurs.where((v) => v >= widget.total).toList()..sort();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = _paiement;
    final resteDu = round2(widget.total - p.encaisse(widget.total));

    return AlertDialog(
      title: Text(widget.titre),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Total TTC', style: theme.textTheme.labelLarge),
            Text(fmtMonnaie(widget.total),
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Modes de paiement
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final m in ModePaiement.values)
                  ChoiceChip(
                    avatar: Icon(m.icone, size: 18),
                    label: Text(m.libelle),
                    selected: _mode == m,
                    onSelected: (_) => setState(() => _mode = m),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            if (_mode != ModePaiement.credit) ...[
              TextField(
                controller: _ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Montant reçu', suffixText: 'DA'),
                onChanged: (_) => setState(() {}),
              ),
              if (_mode == ModePaiement.especes) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final v in _montantsRapides)
                      ActionChip(
                        label: Text(v == widget.total ? 'Exact' : fmtQte(v)),
                        onPressed: () => setState(() => _ctrl.text = v.toStringAsFixed(2)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Rendu monnaie : ${fmtMonnaie(p.rendu(widget.total))}',
                    style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
              ],
            ],

            // Information sur le reste dû (client identifié)
            if (widget.creditAutorise && resteDu > 0) ...[
              const SizedBox(height: 8),
              Text('Reste dû ajouté au solde du client : ${fmtMonnaie(resteDu)}',
                  style: TextStyle(color: Colors.orange.shade800)),
            ],

            if (_erreur != null) ...[
              const SizedBox(height: 8),
              Text(_erreur!, style: TextStyle(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton.icon(
          icon: const Icon(Icons.check),
          label: const Text('Valider'),
          onPressed: _erreur == null ? () => Navigator.pop(context, p) : null,
        ),
      ],
    );
  }
}
