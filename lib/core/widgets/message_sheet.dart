// =============================================================================
//  MessageSheet — feuille d'envoi WhatsApp / SMS (réutilisée partout)
// =============================================================================
//  Utilisée depuis : la fiche client, la confirmation de vente, la fiche
//  fournisseur (commande de réapprovisionnement).
//  • Numéro pré-rempli (modifiable ; obligatoire pour le client comptoir)
//  • Modèles de message (Facture, Relance, Promotion…) sous forme de puces
//  • Texte pré-rempli ET modifiable avant l'envoi
//  • DEUX gros boutons en relief : WhatsApp (vert) et SMS (bleu)
// =============================================================================

import 'package:flutter/material.dart';

import 'package:gestock_pos/core/theme/app_colors.dart';
import 'package:gestock_pos/core/widgets/relief_3d.dart';
import 'package:gestock_pos/services/messaging_service.dart';

/// Un modèle proposé (libellé de la puce + texte).
class ModeleMessage {
  const ModeleMessage(this.libelle, this.objet, this.texte);
  final String libelle;
  final String objet; // FACTURE, RELANCE, PROMO, COMMANDE…
  final String texte;
}

/// Ouvre la feuille. Exemple :
///   await MessageSheet.ouvrir(context, titre: 'Envoyer à Ali',
///       numero: client.numeroWhatsApp, modeles: [...]);
class MessageSheet extends StatefulWidget {
  const MessageSheet({
    super.key,
    required this.titre,
    required this.modeles,
    this.numero,
    this.tiersType,
    this.tiersId,
    this.documentId,
  });

  final String titre;
  final String? numero;
  final List<ModeleMessage> modeles;
  final String? tiersType;
  final String? tiersId;
  final String? documentId;

  static Future<void> ouvrir(
    BuildContext context, {
    required String titre,
    required List<ModeleMessage> modeles,
    String? numero,
    String? tiersType,
    String? tiersId,
    String? documentId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true, // la feuille remonte au-dessus du clavier
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => MessageSheet(
        titre: titre,
        numero: numero,
        modeles: modeles,
        tiersType: tiersType,
        tiersId: tiersId,
        documentId: documentId,
      ),
    );
  }

  @override
  State<MessageSheet> createState() => _MessageSheetState();
}

class _MessageSheetState extends State<MessageSheet> {
  late final _numero = TextEditingController(text: widget.numero ?? '');
  late final _texte = TextEditingController(text: widget.modeles.first.texte);
  int _modele = 0;
  bool _envoi = false;

  @override
  void dispose() {
    _numero.dispose();
    _texte.dispose();
    super.dispose();
  }

  Future<void> _envoyer(CanalMessage canal) async {
    if (!MessagingService.numeroValide(_numero.text)) {
      _snack('Numéro de téléphone invalide.');
      return;
    }
    setState(() => _envoi = true);
    final service = MessagingService.instance;
    final objet = widget.modeles[_modele].objet;
    final ok = canal == CanalMessage.whatsapp
        ? await service.envoyerWhatsApp(
            numero: _numero.text, message: _texte.text, objet: objet,
            tiersType: widget.tiersType, tiersId: widget.tiersId, documentId: widget.documentId)
        : await service.envoyerSms(
            numero: _numero.text, message: _texte.text, objet: objet,
            tiersType: widget.tiersType, tiersId: widget.tiersId, documentId: widget.documentId);
    if (!mounted) return;
    setState(() => _envoi = false);
    if (ok) {
      Navigator.pop(context);
    } else {
      _snack(canal == CanalMessage.whatsapp
          ? 'Impossible d\'ouvrir WhatsApp (application installée ?).'
          : 'Impossible d\'ouvrir l\'application SMS.');
    }
  }

  void _snack(String t) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(t), backgroundColor: AppColors.supprimer));

  @override
  Widget build(BuildContext context) {
    // viewInsets.bottom = hauteur du clavier : on remonte le contenu d'autant
    final clavier = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + clavier),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.titre, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _numero,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Numéro (ex. 0550 12 34 56)',
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            if (widget.modeles.length > 1) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (var i = 0; i < widget.modeles.length; i++)
                    ChoiceChip(
                      label: Text(widget.modeles[i].libelle),
                      selected: _modele == i,
                      onSelected: (_) => setState(() {
                        _modele = i;
                        _texte.text = widget.modeles[i].texte;
                      }),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _texte,
              minLines: 5,
              maxLines: 10,
              decoration: const InputDecoration(labelText: 'Message (modifiable)', alignLabelWithHint: true),
            ),
            const SizedBox(height: 16),
            // Les deux boutons côte à côte, chacun prend la moitié de la largeur
            Row(
              children: [
                Expanded(
                  child: Bouton3D(
                    libelle: 'WhatsApp',
                    icone: Icons.chat,
                    couleur: AppColors.whatsapp,
                    chargement: _envoi,
                    onPressed: () => _envoyer(CanalMessage.whatsapp),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Bouton3D(
                    libelle: 'SMS',
                    icone: Icons.sms,
                    couleur: AppColors.sms,
                    chargement: _envoi,
                    onPressed: () => _envoyer(CanalMessage.sms),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
