// =============================================================================
//  ClientListPage — liste des clients
// =============================================================================
//  Réutilisée pour : Vente > Clients, Trésorerie > Relance client (débiteurs),
//  Trésorerie > En cours dépassé (solde > plafond).
//  Bouton WhatsApp direct sur chaque ligne + bouton vert « + » pour ajouter.
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:gestock_pos/core/theme/app_colors.dart';
import 'package:gestock_pos/core/utils/formatters.dart';
import 'package:gestock_pos/core/widgets/communs.dart';
import 'package:gestock_pos/data/models/client.dart';
import 'package:gestock_pos/data/repositories/client_repository.dart';
import 'package:gestock_pos/features/clients/client_detail_page.dart';
import 'package:gestock_pos/features/clients/client_form_page.dart';

class ClientListPage extends StatefulWidget {
  const ClientListPage({super.key, this.titre = 'Clients', this.filtreInitial = FiltreClient.tous});
  final String titre;
  final FiltreClient filtreInitial;

  @override
  State<ClientListPage> createState() => _ClientListPageState();
}

class _ClientListPageState extends State<ClientListPage> {
  final _repo = ClientRepository();
  final _recherche = TextEditingController();
  Timer? _debounce;
  late FiltreClient _filtre = widget.filtreInitial;
  List<Client> _clients = [];
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
    final res = await _repo.tous(recherche: _recherche.text, filtre: _filtre);
    if (!mounted) return;
    setState(() {
      _clients = res;
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
      appBar: AppBar(title: Text(widget.titre)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _ouvrir(const ClientFormPage()),
        icon: const Icon(Icons.person_add),
        label: const Text('Ajouter'),
      ),
      body: Column(
        children: [
          ChampRecherche(controller: _recherche, onChanged: _onRecherche, hint: 'Nom, téléphone ou code…'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(children: [
              for (final (f, l) in [
                (FiltreClient.tous, 'Tous'),
                (FiltreClient.debiteurs, 'Débiteurs'),
                (FiltreClient.encoursDepasse, 'En cours dépassé'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(l),
                    selected: _filtre == f,
                    elevation: 2,
                    pressElevation: 0,
                    onSelected: (_) {
                      setState(() => _filtre = f);
                      _charger();
                    },
                  ),
                ),
            ]),
          ),
          Expanded(
            child: _chargement
                ? const Center(child: CircularProgressIndicator())
                : _clients.isEmpty
                    ? const EtatVide(icone: Icons.people_outline, message: 'Aucun client')
                    : RefreshIndicator(
                        onRefresh: _charger,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 96),
                          itemCount: _clients.length,
                          itemBuilder: (_, i) {
                            final c = _clients[i];
                            return Card(
                              child: ListTile(
                                onTap: () => _ouvrir(ClientDetailPage(clientId: c.id)),
                                leading: CircleAvatar(
                                  backgroundColor: (c.encoursDepasse ? AppColors.supprimer : AppColors.vente)
                                      .withValues(alpha: 0.12),
                                  child: Icon(c.estComptoir ? Icons.storefront : Icons.person,
                                      color: c.encoursDepasse ? AppColors.supprimer : AppColors.vente),
                                ),
                                title: Text(c.nom,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text(
                                  c.estComptoir
                                      ? 'Ventes anonymes'
                                      : '${c.telephone ?? 'Pas de téléphone'} · ${c.typeTarif.libelle}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: c.estComptoir
                                    ? null
                                    : SizedBox(
                                        width: 110,
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            const Text('Solde', style: TextStyle(fontSize: 11)),
                                            FittedBox(
                                              child: Text(
                                                fmtMonnaie(c.solde),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  color: c.solde > 0 ? AppColors.supprimer : AppColors.ajouter,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
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
