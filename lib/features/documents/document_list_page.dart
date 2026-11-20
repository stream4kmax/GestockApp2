// =============================================================================
//  DocumentListPage — historique d'un ou plusieurs types de documents
// =============================================================================
//  Exemple : Achat > Bon de réception → liste des BR + bouton « + Nouveau ».
//  Filtres : recherche (numéro, tiers), période, « non soldés ».
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:gestock_pos/core/constants/type_document.dart';
import 'package:gestock_pos/core/theme/app_colors.dart';
import 'package:gestock_pos/core/utils/formatters.dart';
import 'package:gestock_pos/core/widgets/communs.dart';
import 'package:gestock_pos/core/widgets/periode_selecteur.dart';
import 'package:gestock_pos/data/repositories/dashboard_repository.dart';
import 'package:gestock_pos/data/repositories/document_repository.dart';
import 'package:gestock_pos/features/documents/document_detail_page.dart';
import 'package:gestock_pos/features/documents/document_saisie_page.dart';
import 'package:gestock_pos/features/vente/pos_page.dart';

class DocumentListPage extends StatefulWidget {
  const DocumentListPage({
    super.key,
    required this.titre,
    required this.types,
    this.typeNouveau,
    this.couleur = AppColors.vente,
  });

  final String titre;
  final List<TypeDocument> types;
  final TypeDocument? typeNouveau; // null = pas de bouton « Nouveau »
  final Color couleur;

  @override
  State<DocumentListPage> createState() => _DocumentListPageState();
}

class _DocumentListPageState extends State<DocumentListPage> {
  final _repo = DocumentRepository();
  final _recherche = TextEditingController();
  Timer? _debounce;
  Periode? _periode = Periode.mois;
  bool _nonSoldes = false;
  List<DocumentResume> _docs = [];
  bool _chargement = true;

  bool get _avecPaiement => widget.types.any((t) => t.avecPaiement);

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
    final (debut, fin) = bornesPeriode(_periode);
    final res = await _repo.lister(
      types: widget.types,
      recherche: _recherche.text,
      nonSoldes: _nonSoldes,
      debut: debut,
      fin: fin,
    );
    if (!mounted) return;
    setState(() {
      _docs = res;
      _chargement = false;
    });
  }

  Future<void> _nouveau() async {
    final t = widget.typeNouveau!;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => t.estVente ? PosPage(type: t) : DocumentSaisiePage(type: t)),
    );
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    final total = _docs.fold<double>(0, (s, d) => s + d.totalTtc);
    return Scaffold(
      appBar: AppBar(title: Text(widget.titre)),
      floatingActionButton: widget.typeNouveau == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _nouveau,
              icon: const Icon(Icons.add),
              label: const Text('Nouveau'),
            ),
      body: Column(children: [
        ChampRecherche(
          controller: _recherche,
          hint: 'N° de document ou nom…',
          onChanged: (_) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 300), _charger);
            setState(() {});
          },
        ),
        PeriodeSelecteur(
          valeur: _periode,
          onChanged: (p) {
            setState(() => _periode = p);
            _charger();
          },
        ),
        if (_avecPaiement)
          SwitchListTile(
            dense: true,
            value: _nonSoldes,
            title: const Text('Seulement les documents non soldés'),
            onChanged: (v) {
              setState(() => _nonSoldes = v);
              _charger();
            },
          ),
        // Récapitulatif de la liste
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(children: [
            Text('${_docs.length} document(s)', style: const TextStyle(color: AppColors.texteSecondaire)),
            const Spacer(),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Total ${fmtMonnaie(total)}',
                    style: TextStyle(fontWeight: FontWeight.w800, color: widget.couleur)),
              ),
            ),
          ]),
        ),
        Expanded(
          child: _chargement
              ? const Center(child: CircularProgressIndicator())
              : _docs.isEmpty
                  ? EtatVide(
                      icone: Icons.description_outlined,
                      message: widget.typeNouveau == null
                          ? 'Aucun document sur cette période'
                          : 'Aucun document sur cette période.\nAppuyez sur « Nouveau ».')
                  : RefreshIndicator(
                      onRefresh: _charger,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 96),
                        itemCount: _docs.length,
                        itemBuilder: (_, i) => _CarteDocument(
                          doc: _docs[i],
                          afficherType: widget.types.length > 1,
                          onTap: () async {
                            await Navigator.push(
                                context, MaterialPageRoute(builder: (_) => DocumentDetailPage(documentId: _docs[i].id)));
                            _charger();
                          },
                        ),
                      ),
                    ),
        ),
      ]),
    );
  }
}

class _CarteDocument extends StatelessWidget {
  const _CarteDocument({required this.doc, required this.afficherType, required this.onTap});
  final DocumentResume doc;
  final bool afficherType;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = doc;
    final couleur = d.type.effetStock > 0
        ? AppColors.ajouter
        : d.type.effetStock < 0
            ? (d.type.estVente ? AppColors.vente : AppColors.supprimer)
            : AppColors.texteSecondaire;
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: couleur.withValues(alpha: 0.12),
          child: Text(d.type.prefixe, style: TextStyle(color: couleur, fontWeight: FontWeight.w800, fontSize: 13)),
        ),
        title: Text(d.numero, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          [
            if (afficherType) d.type.libelle,
            if (d.tiersNom != null && d.tiersNom!.isNotEmpty) d.tiersNom!,
            fmtDate(d.date),
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 120),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(fmtMonnaie(d.totalTtc), style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            if (d.statut == 'TRANSFORME')
              const Text('Transformé', style: TextStyle(fontSize: 11, color: AppColors.ajouter, fontWeight: FontWeight.w700))
            else if (d.type.avecPaiement && !d.estSolde)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Reste ${fmtMonnaie(d.resteAPayer)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.supprimer, fontWeight: FontWeight.w700)),
              ),
          ]),
        ),
      ),
    );
  }
}
