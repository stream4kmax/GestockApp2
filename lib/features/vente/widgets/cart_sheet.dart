// =============================================================================
//  CartSheet — détail du panier (feuille qui remonte du bas de l'écran)
// =============================================================================
//  • Boutons − / + pour la quantité
//  • Appui sur une ligne : modifier quantité, prix HT et remise %
//  • Glisser une ligne vers la gauche : la supprimer
//  • Remise globale sur tout le panier
//  • Récapitulatif Total HT / Remise / TVA / TTC
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gestock_pos/core/utils/formatters.dart';
import 'package:gestock_pos/data/models/ligne_panier.dart';
import 'package:gestock_pos/features/vente/cart_provider.dart';

class CartSheet extends StatelessWidget {
  const CartSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        // Consumer : ce bloc se redessine à chaque changement du panier.
        return Consumer<CartProvider>(
          builder: (context, cart, _) {
            final t = cart.totaux;
            return Column(
              children: [
                // Poignée + titre
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  title: Text('Panier (${cart.nbLignes} ligne${cart.nbLignes > 1 ? 's' : ''})',
                      style: Theme.of(context).textTheme.titleMedium),
                  trailing: TextButton.icon(
                    onPressed: cart.estVide ? null : () => _editerRemiseGlobale(context, cart),
                    icon: const Icon(Icons.percent, size: 18),
                    label: Text(cart.remiseGlobalePct > 0
                        ? 'Remise ${fmtQte(cart.remiseGlobalePct)} %'
                        : 'Remise globale'),
                  ),
                ),
                const Divider(height: 1),

                // Lignes
                Expanded(
                  child: cart.estVide
                      ? const Center(child: Text('Le panier est vide'))
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: cart.lignes.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                          itemBuilder: (context, i) => _LigneTile(ligne: cart.lignes[i]),
                        ),
                ),

                // Totaux
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    children: [
                      _LigneTotal('Total HT brut', t.htBrut),
                      if (t.remiseGlobale > 0) _LigneTotal('Remise globale', -t.remiseGlobale),
                      _LigneTotal('Total HT', t.ht),
                      _LigneTotal('TVA', t.tva),
                      const SizedBox(height: 4),
                      _LigneTotal('Total TTC', t.ttc, grand: true),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editerRemiseGlobale(BuildContext context, CartProvider cart) async {
    final ctrl = TextEditingController(text: fmtQte(cart.remiseGlobalePct));
    final pct = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remise globale'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Remise', suffixText: '%'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, parseNombre(ctrl.text) ?? 0),
            child: const Text('Appliquer'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (pct != null) cart.definirRemiseGlobale(pct);
  }
}

/// Une ligne du panier.
class _LigneTile extends StatelessWidget {
  const _LigneTile({required this.ligne});
  final LignePanier ligne;

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
    final id = ligne.article.id;
    final pas = ligne.article.unite == 'U' ? 1.0 : 0.5; // vrac : pas de 0,5

    return Dismissible(
      key: ValueKey(id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline),
      ),
      onDismissed: (_) => cart.supprimer(id),
      child: ListTile(
        onTap: () => _editerLigne(context, cart),
        title: Text(ligne.article.designation, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${fmtMonnaie(ligne.prixUnitaireHt)} HT'
          '${ligne.remisePct > 0 ? ' · −${fmtQte(ligne.remisePct)} %' : ''}'
          '\n${fmtMonnaie(ligne.montantTtc)} TTC',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () => _afficherErreur(context, cart.modifierQuantite(id, ligne.quantite - pas)),
            ),
            SizedBox(
              width: 36,
              child: Text(fmtQte(ligne.quantite),
                  textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => _afficherErreur(context, cart.modifierQuantite(id, ligne.quantite + pas)),
            ),
          ],
        ),
      ),
    );
  }

  void _afficherErreur(BuildContext context, String? erreur) {
    if (erreur == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(erreur), backgroundColor: Theme.of(context).colorScheme.error));
  }

  Future<void> _editerLigne(BuildContext context, CartProvider cart) async {
    final r = await showDialog<({double quantite, double prixHt, double remise})>(
      context: context,
      builder: (_) => _EditLigneDialog(ligne: ligne),
    );
    if (r == null || !context.mounted) return;
    cart.modifierPrix(ligne.article.id, r.prixHt);
    cart.modifierRemise(ligne.article.id, r.remise);
    _afficherErreur(context, cart.modifierQuantite(ligne.article.id, r.quantite));
  }
}

/// Boîte de dialogue : quantité, prix unitaire HT, remise %.
class _EditLigneDialog extends StatefulWidget {
  const _EditLigneDialog({required this.ligne});
  final LignePanier ligne;

  @override
  State<_EditLigneDialog> createState() => _EditLigneDialogState();
}

class _EditLigneDialogState extends State<_EditLigneDialog> {
  late final _qte = TextEditingController(text: fmtQte(widget.ligne.quantite));
  late final _prix = TextEditingController(text: widget.ligne.prixUnitaireHt.toStringAsFixed(2));
  late final _remise = TextEditingController(text: fmtQte(widget.ligne.remisePct));

  @override
  void dispose() {
    _qte.dispose();
    _prix.dispose();
    _remise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const clavier = TextInputType.numberWithOptions(decimal: true);
    return AlertDialog(
      title: Text(widget.ligne.article.designation),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _qte, keyboardType: clavier, autofocus: true,
              decoration: InputDecoration(labelText: 'Quantité', suffixText: widget.ligne.article.unite)),
          const SizedBox(height: 12),
          TextField(controller: _prix, keyboardType: clavier,
              decoration: const InputDecoration(labelText: 'Prix unitaire HT', suffixText: 'DA')),
          const SizedBox(height: 12),
          TextField(controller: _remise, keyboardType: clavier,
              decoration: const InputDecoration(labelText: 'Remise', suffixText: '%')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: () => Navigator.pop(context, (
            quantite: parseNombre(_qte.text) ?? widget.ligne.quantite,
            prixHt: parseNombre(_prix.text) ?? widget.ligne.prixUnitaireHt,
            remise: parseNombre(_remise.text) ?? 0,
          )),
          child: const Text('Valider'),
        ),
      ],
    );
  }
}

/// Une ligne "libellé ........ montant" du récapitulatif.
class _LigneTotal extends StatelessWidget {
  const _LigneTotal(this.libelle, this.montant, {this.grand = false});
  final String libelle;
  final double montant;
  final bool grand;

  @override
  Widget build(BuildContext context) {
    final style = grand
        ? Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(libelle, style: style),
          const Spacer(),
          Text(fmtMonnaie(montant), style: style),
        ],
      ),
    );
  }
}
