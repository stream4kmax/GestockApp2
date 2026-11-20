// =============================================================================
//  OptionsPage — réglages généraux de l'application
// =============================================================================
//  • Point de vente de CET appareil (numérotation des documents)
//  • Autoriser la vente / la sortie sans stock (stock négatif)
//  • Indicatif téléphonique pour WhatsApp / SMS
//  • Informations : nombre d'articles, clients, documents… et version
// =============================================================================

import 'package:flutter/material.dart';

import 'package:gestock_pos/core/database/database_helper.dart';
import 'package:gestock_pos/core/settings/app_settings.dart';
import 'package:gestock_pos/core/theme/app_colors.dart';
import 'package:gestock_pos/core/widgets/communs.dart';
import 'package:gestock_pos/features/parametres/configs_crud.dart';

class OptionsPage extends StatefulWidget {
  const OptionsPage({super.key});

  @override
  State<OptionsPage> createState() => _OptionsPageState();
}

class _OptionsPageState extends State<OptionsPage> {
  final s = AppSettings.instance;
  List<Map<String, Object?>> _pointsVente = [];
  Map<String, int> _compteurs = {};
  late final _indicatif = TextEditingController(text: s.indicatifPays);

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _indicatif.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    final db = await DatabaseHelper.instance.database;
    final pv = await db.query('points_vente', where: 'deleted = 0', orderBy: 'code');
    final compteurs = {
      'Articles': await compter('articles'),
      'Clients': await compter('clients'),
      'Fournisseurs': await compter('fournisseurs'),
      'Documents': await compter('documents'),
      'Mouvements de stock': await compter('mouvements_stock'),
    };
    if (!mounted) return;
    setState(() {
      _pointsVente = pv;
      _compteurs = compteurs;
    });
  }

  Future<void> _definir(String cle, String valeur, String message) async {
    await s.definir(cle, valeur);
    if (!mounted) return;
    setState(() {});
    afficherMessage(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final pvValide = _pointsVente.any((p) => p['id'] == s.pointVenteId);
    return Scaffold(
      appBar: AppBar(title: const Text('Options')),
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        const _Titre('Point de vente'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              DropdownButtonFormField<String>(
                value: pvValide ? s.pointVenteId : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Point de vente de cet appareil', prefixIcon: Icon(Icons.storefront)),
                items: [
                  for (final p in _pointsVente)
                    DropdownMenuItem(
                      value: p['id'] as String,
                      child: Text('${p['code']} — ${p['libelle']}', overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) _definir('point_vente_id', v, 'Point de vente changé');
                },
              ),
              const SizedBox(height: 6),
              Text('Les nouveaux documents seront numérotés ${s.pointVenteCode}-… '
                  '(ajoutez des points de vente dans Paramètres > Point de vente).',
                  style: const TextStyle(fontSize: 12, color: AppColors.texteSecondaire)),
            ]),
          ),
        ),

        const _Titre('Stock'),
        Card(
          child: SwitchListTile(
            value: s.stockNegatifAutorise,
            title: const Text('Autoriser le stock négatif'),
            subtitle: const Text('Permet de vendre ou de sortir un article même si le stock est insuffisant'),
            onChanged: (v) => _definir('stock_negatif_autorise', v ? '1' : '0', v ? 'Stock négatif autorisé' : 'Contrôle du stock activé'),
          ),
        ),

        const _Titre('Messagerie'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _indicatif,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Indicatif pays',
                    prefixText: '+',
                    helperText: '213 = Algérie (0550… devient +213 550…)',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.ajouter),
                onPressed: () {
                  final v = _indicatif.text.replaceAll(RegExp(r'[^0-9]'), '');
                  if (v.isEmpty) return;
                  _definir('indicatif_pays', v, 'Indicatif enregistré');
                },
                child: const Text('OK'),
              ),
            ]),
          ),
        ),

        const _Titre('Informations'),
        Card(
          child: Column(children: [
            for (final e in _compteurs.entries)
              ListTile(dense: true, title: Text(e.key), trailing: Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w800))),
            const Divider(),
            const ListTile(
              dense: true,
              leading: Icon(Icons.info_outline),
              title: Text('GeStock POS — version 1.0.0'),
              subtitle: Text('Base de données locale v2 · fonctionne hors ligne'),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Titre extends StatelessWidget {
  const _Titre(this.texte);
  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(texte, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.outils)),
      );
}
