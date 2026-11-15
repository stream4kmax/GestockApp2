// =============================================================================
//  FournisseurListPage — liste des fournisseurs
// =============================================================================
//  Les fournisseurs qui ont des articles à réapprovisionner apparaissent en
//  premier, avec un badge orange. Bouton vert « + » pour en ajouter un.
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:gestock_pos/core/theme/app_colors.dart';
import 'package:gestock_pos/core/widgets/communs.dart';
import 'package:gestock_pos/data/models/fournisseur.dart';
import 'package:gestock_pos/data/repositories/fournisseur_repository.dart';
import 'package:gestock_pos/features/fournisseurs/fournisseur_detail_page.dart';
import 'package:gestock_pos/features/fournisseurs/fournisseur_form_page.dart';

class FournisseurListPage extends StatefulWidget {
  const FournisseurListPage({super.key});

  @override
  State<FournisseurListPage> createState() => _FournisseurListPageState();
}

class _FournisseurListPageState extends State<FournisseurListPage> {
  final _repo = FournisseurRepository();
  final _recherche = TextEditingController();
  Timer? _debounce;
  List<FournisseurResume> _liste = [];
  bool _chargement = true;

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
    final res = await _repo.tous(recherche: _recherche.text);
    if (!mounted) return;
    setState(() {
      _liste = res;
      _chargement = false;
    });
  }

  void _onRecherche(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _charger);
    setState(() {});
  }

  Future<void> _ouvrir(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fournisseurs')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _ouvrir(const FournisseurFormPage()),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: Column(
        children: [
          ChampRecherche(controller: _recherche, onChanged: _onRecherche, hint: 'Nom ou téléphone…'),
          Expanded(
            child: _chargement
                ? const Center(child: CircularProgressIndicator())
                : _liste.isEmpty
                    ? const EtatVide(icone: Icons.local_shipping_outlined, message: 'Aucun fournisseur.\nAppuyez sur « Ajouter ».')
                    : RefreshIndicator(
                        onRefresh: _charger,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 96),
                          itemCount: _liste.length,
                          itemBuilder: (_, i) {
                            final r = _liste[i];
                            final f = r.fournisseur;
                            return Card(
                              child: ListTile(
                                onTap: () => _ouvrir(FournisseurDetailPage(fournisseurId: f.id)),
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.achat.withValues(alpha: 0.15),
                                  child: Text(f.nom[0].toUpperCase(),
                                      style: const TextStyle(color: AppColors.achat, fontWeight: FontWeight.w800)),
                                ),
                                title: Text(f.nom,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text(
                                  '${f.telephone ?? 'Pas de téléphone'} · ${r.nbArticles} article(s)',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: r.nbAReapprovisionner > 0
                                    ? Badge(
                                        backgroundColor: AppColors.alerte,
                                        label: Text('${r.nbAReapprovisionner}'),
                                        child: const Icon(Icons.warning_amber_rounded, color: AppColors.alerte),
                                      )
                                    : const Icon(Icons.chevron_right),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
