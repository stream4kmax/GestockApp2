// =============================================================================
//  FournisseurDetailPage — fiche fournisseur + réapprovisionnement
// =============================================================================
//  • Coordonnées et boutons : Appeler, WhatsApp, SMS
//  • Liste des articles achetés chez ce fournisseur (urgences en premier),
//    avec cases à cocher pour préparer une commande
//  • Quantité suggérée = de quoi revenir à 2 × le seuil d'alerte
//  • « Commander » : message de commande pré-rempli envoyé par WhatsApp ou SMS
// =============================================================================

import 'package:flutter/material.dart';

import 'package:gestock_pos/core/theme/app_colors.dart';
import 'package:gestock_pos/core/utils/formatters.dart';
import 'package:gestock_pos/core/widgets/communs.dart';
import 'package:gestock_pos/core/widgets/message_sheet.dart';
import 'package:gestock_pos/core/widgets/relief_3d.dart';
import 'package:gestock_pos/data/models/article.dart';
import 'package:gestock_pos/data/models/fournisseur.dart';
import 'package:gestock_pos/data/repositories/article_repository.dart';
import 'package:gestock_pos/data/repositories/fournisseur_repository.dart';
import 'package:gestock_pos/data/repositories/reference_repository.dart';
import 'package:gestock_pos/features/article/article_form_page.dart';
import 'package:gestock_pos/features/fournisseurs/fournisseur_form_page.dart';
import 'package:gestock_pos/features/tresorerie/ajuster_solde_dialog.dart';
import 'package:gestock_pos/services/messaging_service.dart';

class FournisseurDetailPage extends StatefulWidget {
  const FournisseurDetailPage({super.key, required this.fournisseurId});
  final String fournisseurId;

  @override
  State<FournisseurDetailPage> createState() => _FournisseurDetailPageState();
}

class _FournisseurDetailPageState extends State<FournisseurDetailPage> {
  Fournisseur? _f;
  List<Article> _articles = [];
  final Set<String> _selection = {}; // articles cochés pour la commande
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final f = await FournisseurRepository().parId(widget.fournisseurId);
    final articles = await ArticleRepository().parFournisseur(widget.fournisseurId);
    if (!mounted) return;
    setState(() {
      _f = f;
      _articles = articles;
      // Par défaut, on coche tout ce qui est à réapprovisionner
      _selection
        ..clear()
        ..addAll(articles.where((a) => a.aReapprovisionner).map((a) => a.id));
      _chargement = false;
    });
  }

  /// Quantité proposée : remonter à 2 × le seuil (au moins 1).
  double _qteSuggeree(Article a) {
    final double cible = a.stockMin > 0 ? a.stockMin * 2 : 10.0;
    final double q = cible - (a.stock < 0 ? 0.0 : a.stock);
    return q < 1 ? 1.0 : q.ceilToDouble();
  }

  Future<void> _commander() async {
    final f = _f!;
    final choisis = _articles.where((a) => _selection.contains(a.id)).toList();
    if (choisis.isEmpty) {
      afficherMessage(context, 'Cochez au moins un article.', erreur: true);
      return;
    }
    final societe = await ReferenceRepository().raisonSociale();
    if (!mounted) return;
    final texte = MessagingService.messageCommandeFournisseur(
      nomFournisseur: f.nom,
      societe: societe,
      lignes: [
        for (final a in choisis) (designation: a.designation, quantite: _qteSuggeree(a), unite: a.unite),
      ],
    );
    await MessageSheet.ouvrir(
      context,
      titre: 'Commande à ${f.nom}',
      numero: f.numeroWhatsApp,
      tiersType: 'F',
      tiersId: f.id,
      modeles: [ModeleMessage('Commande', 'COMMANDE', texte)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = _f;
    if (_chargement || f == null) {
      return Scaffold(
          appBar: AppBar(), body: Center(child: _chargement ? const CircularProgressIndicator() : const Text('Introuvable')));
    }
    final aReappro = _articles.where((a) => a.aReapprovisionner).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(f.nom, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Modifier',
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => FournisseurFormPage(fournisseur: f)));
              if (mounted) _charger();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nouvel article de ce fournisseur',
        onPressed: () async {
          await Navigator.push(
              context, MaterialPageRoute(builder: (_) => ArticleFormPage(fournisseurIdParDefaut: f.id)));
          if (mounted) _charger();
        },
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            // --- Coordonnées ---
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // v2c : ce que vous devez au fournisseur + ajustement
                    Row(children: [
                      Expanded(
                        child: Text('Vous devez : ${fmtMonnaie(f.solde)}',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: f.solde > 0 ? AppColors.supprimer : AppColors.ajouter)),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final ok = await ajusterSoldeDialog(context,
                              tiersType: 'F', tiersId: f.id, tiersNom: f.nom, soldeActuel: f.solde);
                          if (ok) _charger();
                        },
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Ajuster'),
                      ),
                    ]),
                    if (f.telephone != null) _Info(Icons.phone, f.telephone!),
                    if (f.email != null) _Info(Icons.email, f.email!),
                    if (f.adresse != null) _Info(Icons.place, f.adresse!),
                    if (f.nif != null) _Info(Icons.badge, 'NIF : ${f.nif}'),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: Bouton3D(
                          libelle: 'Appeler',
                          icone: Icons.call,
                          couleur: AppColors.vente,
                          hauteur: 44,
                          onPressed: f.telephone == null
                              ? null
                              : () => MessagingService.instance.appeler(f.telephone!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Bouton3D(
                          libelle: 'Message',
                          icone: Icons.chat,
                          couleur: AppColors.whatsapp,
                          hauteur: 44,
                          onPressed: () => MessageSheet.ouvrir(
                            context,
                            titre: 'Message à ${f.nom}',
                            numero: f.numeroWhatsApp,
                            tiersType: 'F',
                            tiersId: f.id,
                            modeles: [ModeleMessage('Libre', 'MESSAGE', 'Bonjour ${f.nom},\n\n')],
                          ),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),

            // --- Articles fournis ---
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(children: [
                Expanded(
                  child: Text('Articles fournis (${_articles.length})',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                if (aReappro > 0)
                  Text('$aReappro à commander',
                      style: const TextStyle(color: AppColors.alerte, fontWeight: FontWeight.w700)),
              ]),
            ),
            if (_articles.isEmpty)
              const EtatVide(
                  icone: Icons.inventory_2_outlined,
                  message: 'Aucun article lié.\nChoisissez ce fournisseur dans la fiche d\'un article.'),
            for (final a in _articles)
              Card(
                child: CheckboxListTile(
                  value: _selection.contains(a.id),
                  onChanged: (v) => setState(() => v == true ? _selection.add(a.id) : _selection.remove(a.id)),
                  title: Text(a.designation, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StockChip(disponible: a.stock, seuil: a.stockMin, unite: a.unite),
                      Text('Achat ${fmtMonnaie(a.prixAchatHt)} HT', style: const TextStyle(fontSize: 12)),
                      if (a.aReapprovisionner)
                        Text('→ commander ${fmtQte(_qteSuggeree(a))} ${a.unite}',
                            style: const TextStyle(fontSize: 12, color: AppColors.alerte, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: _articles.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Bouton3D(
                  libelle: 'Commander (${_selection.length})',
                  icone: Icons.send,
                  couleur: AppColors.achat,
                  onPressed: _selection.isEmpty ? null : _commander,
                ),
              ),
            ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.icone, this.texte);
  final IconData icone;
  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Icon(icone, size: 18, color: AppColors.texteSecondaire),
          const SizedBox(width: 8),
          Expanded(child: Text(texte)),
        ]),
      );
}
