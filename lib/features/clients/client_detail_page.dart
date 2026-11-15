// =============================================================================
//  ClientDetailPage — fiche client + messagerie
// =============================================================================
//  • Coordonnées, solde (rouge si le client doit de l'argent), plafond
//  • DEUX boutons en relief : WhatsApp et SMS
//    → modèles pré-remplis : Relance (si solde > 0), Promotion, Message libre
//  • Derniers documents : appui sur l'icône d'envoi = renvoyer le
//    récapitulatif de CETTE facture par WhatsApp ou SMS
// =============================================================================

import 'package:flutter/material.dart';

import 'package:gestock_pos/core/theme/app_colors.dart';
import 'package:gestock_pos/core/utils/formatters.dart';
import 'package:gestock_pos/core/widgets/message_sheet.dart';
import 'package:gestock_pos/core/widgets/relief_3d.dart';
import 'package:gestock_pos/data/models/client.dart';
import 'package:gestock_pos/data/repositories/client_repository.dart';
import 'package:gestock_pos/data/repositories/document_repository.dart';
import 'package:gestock_pos/data/repositories/reference_repository.dart';
import 'package:gestock_pos/features/clients/client_form_page.dart';
import 'package:gestock_pos/services/messaging_service.dart';

class ClientDetailPage extends StatefulWidget {
  const ClientDetailPage({super.key, required this.clientId});
  final String clientId;

  @override
  State<ClientDetailPage> createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends State<ClientDetailPage> {
  final _docRepo = DocumentRepository();
  Client? _client;
  List<DocumentResume> _documents = [];
  String _societe = '';
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final c = await ClientRepository().parId(widget.clientId);
    final docs = await _docRepo.derniersDuClient(widget.clientId);
    final societe = await ReferenceRepository().raisonSociale();
    if (!mounted) return;
    setState(() {
      _client = c;
      _documents = docs;
      _societe = societe;
      _chargement = false;
    });
  }

  /// Modèles proposés depuis la fiche (le premier est sélectionné d'office).
  List<ModeleMessage> _modeles(Client c) => [
        if (c.solde > 0)
          ModeleMessage('Relance paiement', 'RELANCE',
              MessagingService.messageRelance(nomClient: c.nom, solde: c.solde, societe: _societe)),
        ModeleMessage('Promotion', 'PROMO', MessagingService.messagePromotion(nomClient: c.nom, societe: _societe)),
        ModeleMessage('Message libre', 'MESSAGE', 'Bonjour ${c.nom},\n\n'),
      ];

  Future<void> _envoyerFacture(Client c, DocumentResume d) async {
    final lignes = await _docRepo.lignes(d.id);
    if (!mounted) return;
    final texte = MessagingService.messageFacture(
      nomClient: c.nom,
      typeDocument: d.type.libelle,
      numero: d.numero,
      date: d.date,
      lignes: [for (final l in lignes) LigneMessage(l.designation, l.quantite, l.montantTtc)],
      totalHt: d.totalHt,
      totalTva: d.totalTva,
      totalTtc: d.totalTtc,
      montantPaye: d.montantPaye,
      societe: _societe,
    );
    await MessageSheet.ouvrir(
      context,
      titre: 'Envoyer ${d.numero}',
      numero: c.numeroWhatsApp,
      tiersType: 'C',
      tiersId: c.id,
      documentId: d.id,
      modeles: [ModeleMessage('Facture', 'FACTURE', texte)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _client;
    if (_chargement || c == null) {
      return Scaffold(
          appBar: AppBar(), body: Center(child: _chargement ? const CircularProgressIndicator() : const Text('Introuvable')));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(c.nom, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Modifier',
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => ClientFormPage(client: c)));
              if (mounted) _charger();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            // --- Solde ---
            if (!c.estComptoir)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Relief3D(
                  couleur: c.solde > 0 ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Icon(Icons.account_balance_wallet,
                        color: c.solde > 0 ? AppColors.supprimer : AppColors.ajouter, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.solde > 0 ? 'Reste à payer' : 'Compte à jour',
                            style: const TextStyle(color: AppColors.texteSecondaire)),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(fmtMonnaie(c.solde),
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: c.solde > 0 ? AppColors.supprimer : AppColors.ajouter)),
                        ),
                        if (c.plafondCredit > 0)
                          Text('Plafond : ${fmtMonnaie(c.plafondCredit)}'
                              '${c.encoursDepasse ? '  ⚠ dépassé' : ''}',
                              style: TextStyle(
                                  fontSize: 12, color: c.encoursDepasse ? AppColors.supprimer : null)),
                      ]),
                    ),
                  ]),
                ),
              ),

            // --- Coordonnées ---
            Card(
              child: Column(children: [
                ListTile(leading: const Icon(Icons.phone), title: Text(c.telephone ?? '—'), subtitle: const Text('Téléphone')),
                if (c.whatsapp != null)
                  ListTile(leading: const Icon(Icons.chat), title: Text(c.whatsapp!), subtitle: const Text('WhatsApp')),
                if (c.email != null) ListTile(leading: const Icon(Icons.email), title: Text(c.email!)),
                if (c.adresse != null) ListTile(leading: const Icon(Icons.place), title: Text(c.adresse!)),
                ListTile(
                  leading: const Icon(Icons.sell),
                  title: Text('Tarif ${c.typeTarif.libelle}'),
                  subtitle: const Text('Appliqué automatiquement au POS'),
                ),
              ]),
            ),

            // --- Les DEUX boutons de messagerie ---
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(children: [
                Expanded(
                  child: Bouton3D(
                    libelle: 'WhatsApp',
                    icone: Icons.chat,
                    couleur: AppColors.whatsapp,
                    onPressed: () => MessageSheet.ouvrir(context,
                        titre: 'WhatsApp / SMS à ${c.nom}',
                        numero: c.numeroWhatsApp,
                        tiersType: 'C',
                        tiersId: c.id,
                        modeles: _modeles(c)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Bouton3D(
                    libelle: 'SMS',
                    icone: Icons.sms,
                    couleur: AppColors.sms,
                    onPressed: () => MessageSheet.ouvrir(context,
                        titre: 'WhatsApp / SMS à ${c.nom}',
                        numero: c.telephone ?? c.whatsapp,
                        tiersType: 'C',
                        tiersId: c.id,
                        modeles: _modeles(c)),
                  ),
                ),
              ]),
            ),

            // --- Derniers documents ---
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('Derniers documents', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            if (_documents.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Aucun document pour ce client.', style: TextStyle(color: AppColors.texteSecondaire)),
              ),
            for (final d in _documents)
              Card(
                child: ListTile(
                  title: Text(d.numero, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${d.type.libelle} · ${fmtDate(d.date)}'
                      '${d.resteAPayer > 0.009 ? '\nReste : ${fmtMonnaie(d.resteAPayer)}' : ''}'),
                  isThreeLine: d.resteAPayer > 0.009,
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(fmtMonnaie(d.totalTtc), style: const TextStyle(fontWeight: FontWeight.w800)),
                    IconButton(
                      tooltip: 'Envoyer le récapitulatif',
                      icon: const Icon(Icons.send, color: AppColors.whatsapp),
                      onPressed: () => _envoyerFacture(c, d),
                    ),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
