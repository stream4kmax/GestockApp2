// =============================================================================
//  DocumentDetailPage — fiche d'un document (tous types)
// =============================================================================
//  • En-tête : type, numéro, date, tiers, statut, document d'origine
//  • Lignes et totaux (HT, TVA, TTC, payé, reste à payer)
//  • Actions selon le type :
//     - Envoyer par WhatsApp / SMS (client ou fournisseur)
//     - Encaisser / Payer le reste (documents non soldés)
//     - Bon de commande fournisseur → « Réceptionner » (crée le bon de réception
//       pré-rempli et marque la commande comme transformée)
// =============================================================================

import 'package:flutter/material.dart';

import 'package:gestock_pos/core/constants/type_document.dart';
import 'package:gestock_pos/core/theme/app_colors.dart';
import 'package:gestock_pos/core/utils/formatters.dart';
import 'package:gestock_pos/core/widgets/message_sheet.dart';
import 'package:gestock_pos/core/widgets/relief_3d.dart';
import 'package:gestock_pos/data/repositories/client_repository.dart';
import 'package:gestock_pos/data/repositories/document_repository.dart';
import 'package:gestock_pos/data/repositories/fournisseur_repository.dart';
import 'package:gestock_pos/data/repositories/reference_repository.dart';
import 'package:gestock_pos/features/documents/document_saisie_page.dart';
import 'package:gestock_pos/features/tresorerie/reglement_sheet.dart';
import 'package:gestock_pos/services/messaging_service.dart';

class DocumentDetailPage extends StatefulWidget {
  const DocumentDetailPage({super.key, required this.documentId});
  final String documentId;

  @override
  State<DocumentDetailPage> createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends State<DocumentDetailPage> {
  final _repo = DocumentRepository();
  DocumentResume? _doc;
  List<LigneDetail> _lignes = [];
  String? _numeroSource;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final d = await _repo.parId(widget.documentId);
    final lignes = d == null ? <LigneDetail>[] : await _repo.lignesDetail(d.id);
    final src = d?.documentSourceId == null ? null : await _repo.numeroDe(d!.documentSourceId!);
    if (!mounted) return;
    setState(() {
      _doc = d;
      _lignes = lignes;
      _numeroSource = src;
      _chargement = false;
    });
  }

  /// Numéro de téléphone et solde du tiers du document.
  Future<({String? numero, String? telephone, double solde})> _tiers(DocumentResume d) async {
    if (d.tiersId == null) return (numero: null, telephone: null, solde: 0.0);
    if (d.tiersType == 'C') {
      final c = await ClientRepository().parId(d.tiersId!);
      return (numero: c?.numeroWhatsApp, telephone: c?.telephone, solde: c?.solde ?? 0.0);
    }
    final f = await FournisseurRepository().parId(d.tiersId!);
    return (numero: f?.numeroWhatsApp, telephone: f?.telephone, solde: f?.solde ?? 0.0);
  }

  Future<void> _envoyer(DocumentResume d) async {
    final t = await _tiers(d);
    final societe = await ReferenceRepository().raisonSociale();
    final nom = d.tiersNom ?? 'cher client';
    final texte = d.type == TypeDocument.commandeFournisseur
        ? MessagingService.messageCommandeFournisseur(
            nomFournisseur: nom,
            societe: societe,
            lignes: [for (final l in _lignes) (designation: l.designation, quantite: l.quantite, unite: '')],
          )
        : MessagingService.messageFacture(
            nomClient: nom,
            typeDocument: d.type.libelle,
            numero: d.numero,
            date: d.date,
            lignes: [for (final l in _lignes) LigneMessage(l.designation, l.quantite, l.montantTtc)],
            totalHt: d.totalHt,
            totalTva: d.totalTva,
            totalTtc: d.totalTtc,
            montantPaye: d.montantPaye,
            societe: societe,
          );
    if (!mounted) return;
    await MessageSheet.ouvrir(
      context,
      titre: 'Envoyer ${d.numero}',
      numero: t.numero ?? t.telephone,
      tiersType: d.tiersType,
      tiersId: d.tiersId,
      documentId: d.id,
      modeles: [ModeleMessage(d.type.libelle, 'FACTURE', texte)],
    );
  }

  Future<void> _regler(DocumentResume d) async {
    final t = await _tiers(d);
    if (!mounted) return;
    final ok = await ReglementSheet.ouvrir(
      context,
      tiersType: d.tiersType!,
      tiersId: d.tiersId!,
      tiersNom: d.tiersNom ?? '',
      solde: t.solde,
      montantSuggere: d.resteAPayer,
    );
    if (ok) _charger();
  }

  Future<void> _receptionner(DocumentResume d) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentSaisiePage(
          type: TypeDocument.receptionFournisseur,
          fournisseurInitialId: d.tiersId,
          lignesInitiales: _lignes,
          documentSourceId: d.id,
        ),
      ),
    );
    if (ok == true) _charger();
  }

  @override
  Widget build(BuildContext context) {
    final d = _doc;
    if (_chargement || d == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: _chargement ? const CircularProgressIndicator() : const Text('Document introuvable')),
      );
    }
    final estBonStock = d.type == TypeDocument.bonEntree || d.type == TypeDocument.bonSortie;
    final peutRegler = d.type.effetCompte > 0 && d.tiersId != null && !d.estSolde;
    final peutReceptionner = d.type == TypeDocument.commandeFournisseur && d.statut == 'VALIDE';

    return Scaffold(
      appBar: AppBar(title: Text(d.numero, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // --- En-tête ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.type.libelle,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.vente)),
                const SizedBox(height: 6),
                _Info(Icons.calendar_today, fmtDate(d.date)),
                if (d.tiersNom != null && d.tiersNom!.isNotEmpty)
                  _Info(
                      d.tiersType == 'C'
                          ? Icons.person
                          : d.tiersType == 'F'
                              ? Icons.local_shipping
                              : Icons.edit_note,
                      d.tiersNom!),
                if (d.notes != null && d.notes!.isNotEmpty && !estBonStock) _Info(Icons.notes, d.notes!),
                if (_numeroSource != null) _Info(Icons.link, 'Issu de $_numeroSource'),
                if (d.statut == 'TRANSFORME')
                  const _Info(Icons.check_circle, 'Transformé (réceptionné / facturé)', couleur: AppColors.ajouter),
              ]),
            ),
          ),

          // --- Lignes ---
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Articles', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          Card(
            child: Column(children: [
              for (final l in _lignes)
                ListTile(
                  dense: true,
                  title: Text(l.designation, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${fmtQte(l.quantite)} × ${fmtMonnaie(l.prixUnitaireHt)} HT'
                      '${l.remisePct > 0 ? ' · −${fmtQte(l.remisePct)} %' : ''} · TVA ${fmtQte(l.tauxTva)} %'),
                  trailing: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 110),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(fmtMonnaie(l.montantTtc), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
            ]),
          ),

          // --- Totaux ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                _Total('Total HT', d.totalHt),
                _Total('TVA', d.totalTva),
                _Total('Total TTC', d.totalTtc, grand: true),
                if (d.type.avecPaiement) ...[
                  const Divider(height: 18),
                  _Total('Payé', d.montantPaye, couleur: AppColors.ajouter),
                  _Total('Reste à payer', d.resteAPayer > 0 ? d.resteAPayer : 0,
                      couleur: d.estSolde ? AppColors.ajouter : AppColors.supprimer),
                ],
              ]),
            ),
          ),

          // --- Actions ---
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (peutReceptionner)
                Bouton3D(
                  libelle: 'Réceptionner (créer le bon de réception)',
                  icone: Icons.move_to_inbox,
                  couleur: AppColors.ajouter,
                  onPressed: () => _receptionner(d),
                ),
              if (peutRegler)
                Bouton3D(
                  libelle: d.tiersType == 'C' ? 'Encaisser le reste' : 'Payer le reste',
                  icone: Icons.payments,
                  couleur: AppColors.ajouter,
                  onPressed: () => _regler(d),
                ),
              if (d.tiersId != null)
                Bouton3D(
                  libelle: 'Envoyer par WhatsApp / SMS',
                  icone: Icons.send,
                  couleur: AppColors.whatsapp,
                  onPressed: () => _envoyer(d),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.icone, this.texte, {this.couleur});
  final IconData icone;
  final String texte;
  final Color? couleur;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          Icon(icone, size: 18, color: couleur ?? AppColors.texteSecondaire),
          const SizedBox(width: 8),
          Expanded(child: Text(texte, style: TextStyle(color: couleur))),
        ]),
      );
}

class _Total extends StatelessWidget {
  const _Total(this.libelle, this.montant, {this.grand = false, this.couleur});
  final String libelle;
  final double montant;
  final bool grand;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: grand ? 20 : 15,
      fontWeight: grand ? FontWeight.w800 : FontWeight.w500,
      color: couleur,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Text(libelle, style: style),
        const SizedBox(width: 12),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(fit: BoxFit.scaleDown, child: Text(fmtMonnaie(montant), style: style)),
          ),
        ),
      ]),
    );
  }
}
