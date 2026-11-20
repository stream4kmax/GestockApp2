// =============================================================================
//  SocietePage — informations de l'entreprise (en-tête des factures)
// =============================================================================
//  Raison sociale, activité, coordonnées et identifiants fiscaux algériens
//  (NIF, NIS, RC, Article d'imposition), RIB. La raison sociale signe aussi
//  les messages WhatsApp / SMS envoyés aux clients.
// =============================================================================

import 'package:flutter/material.dart';

import 'package:gestock_pos/core/database/database_helper.dart';
import 'package:gestock_pos/core/theme/app_colors.dart';
import 'package:gestock_pos/core/utils/ids.dart';
import 'package:gestock_pos/core/widgets/communs.dart';
import 'package:gestock_pos/core/widgets/relief_3d.dart';

class SocietePage extends StatefulWidget {
  const SocietePage({super.key});

  @override
  State<SocietePage> createState() => _SocietePageState();
}

class _SocietePageState extends State<SocietePage> {
  final _form = GlobalKey<FormState>();
  String? _id;
  bool _pret = false;
  bool _enregistrement = false;

  // colonne SQL → (libellé, icône, clavier)
  static const _champs = <String, (String, IconData, TextInputType)>{
    'raison_sociale': ('Raison sociale *', Icons.business, TextInputType.text),
    'activite': ('Activité', Icons.work, TextInputType.text),
    'adresse': ('Adresse', Icons.place, TextInputType.streetAddress),
    'telephone': ('Téléphone', Icons.phone, TextInputType.phone),
    'email': ('E-mail', Icons.email, TextInputType.emailAddress),
    'nif': ('NIF (identification fiscale)', Icons.badge, TextInputType.number),
    'nis': ('NIS (identification statistique)', Icons.badge_outlined, TextInputType.number),
    'rc': ('RC (registre du commerce)', Icons.description, TextInputType.text),
    'art': ('Article d\'imposition', Icons.receipt, TextInputType.number),
    'rib': ('RIB (coordonnées bancaires)', Icons.account_balance, TextInputType.text),
  };
  final Map<String, TextEditingController> _ctrl = {for (final k in _champs.keys) k: TextEditingController()};

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _charger() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('societe', limit: 1);
    if (rows.isNotEmpty) {
      _id = rows.first['id'] as String;
      for (final k in _champs.keys) {
        _ctrl[k]!.text = (rows.first[k] as String?) ?? '';
      }
    }
    if (mounted) setState(() => _pret = true);
  }

  Future<void> _enregistrer() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _enregistrement = true);
    final db = await DatabaseHelper.instance.database;
    final now = maintenantUtc();
    final valeurs = {
      for (final k in _champs.keys) k: _ctrl[k]!.text.trim().isEmpty ? null : _ctrl[k]!.text.trim(),
      'updated_at': now,
      'sync_status': 1,
    };
    if (_id == null) {
      _id = 'SOC-1';
      await db.insert('societe', {...valeurs, 'id': _id, 'created_at': now, 'devise': 'DA'});
    } else {
      await db.update('societe', valeurs, where: 'id = ?', whereArgs: [_id]);
    }
    if (!mounted) return;
    setState(() => _enregistrement = false);
    afficherMessage(context, 'Informations de la société enregistrées');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Société')),
      body: !_pret
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                children: [
                  const Text(
                    'Ces informations apparaîtront en en-tête des factures (étape 3 : PDF) '
                    'et en signature des messages WhatsApp / SMS.',
                    style: TextStyle(color: AppColors.texteSecondaire),
                  ),
                  const SizedBox(height: 16),
                  for (final e in _champs.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: _ctrl[e.key],
                        keyboardType: e.value.$3,
                        textCapitalization:
                            e.value.$3 == TextInputType.text ? TextCapitalization.sentences : TextCapitalization.none,
                        decoration: InputDecoration(labelText: e.value.$1, prefixIcon: Icon(e.value.$2)),
                        validator: e.key == 'raison_sociale'
                            ? (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null
                            : null,
                      ),
                    ),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Bouton3D(
            libelle: 'Enregistrer',
            icone: Icons.check,
            couleur: AppColors.ajouter,
            chargement: _enregistrement,
            onPressed: _pret ? _enregistrer : null,
          ),
        ),
      ),
    );
  }
}
