// =============================================================================
//  ImprimantePage — réglages du ticket / de la facture imprimée
// =============================================================================
//  • Format du papier : ticket 58 mm, ticket 80 mm ou A4
//  • En-tête personnalisé, message de bas de ticket, nombre de copies,
//    affichage du NIF
//  • APERÇU en direct du ticket (avec les infos de Paramètres > Société)
//
//  L'impression réelle (imprimante Bluetooth / Wi-Fi via le service
//  d'impression Android) et le PDF sont ajoutés à l'étape 3 : ils utiliseront
//  directement ces réglages.
// =============================================================================

import 'package:flutter/material.dart';

import 'package:gestock_pos/core/database/database_helper.dart';
import 'package:gestock_pos/core/settings/app_settings.dart';
import 'package:gestock_pos/core/theme/app_colors.dart';
import 'package:gestock_pos/core/utils/formatters.dart';
import 'package:gestock_pos/core/widgets/communs.dart';
import 'package:gestock_pos/core/widgets/relief_3d.dart';

class ImprimantePage extends StatefulWidget {
  const ImprimantePage({super.key});

  @override
  State<ImprimantePage> createState() => _ImprimantePageState();
}

class _ImprimantePageState extends State<ImprimantePage> {
  final s = AppSettings.instance;
  late int _largeur = s.largeurTicketMm;
  late int _copies = s.copiesTicket;
  late bool _nif = s.afficherNifTicket;
  late final _entete = TextEditingController(text: s.enteteTicket);
  late final _pied = TextEditingController(text: s.piedTicket);
  Map<String, Object?> _societe = {};

  @override
  void initState() {
    super.initState();
    _chargerSociete();
  }

  @override
  void dispose() {
    _entete.dispose();
    _pied.dispose();
    super.dispose();
  }

  Future<void> _chargerSociete() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('societe', limit: 1);
    if (mounted && rows.isNotEmpty) setState(() => _societe = rows.first);
  }

  Future<void> _enregistrer() async {
    await s.definirPlusieurs({
      'ticket_largeur': '$_largeur',
      'ticket_copies': '$_copies',
      'ticket_nif': _nif ? '1' : '0',
      'ticket_entete': _entete.text.trim(),
      'ticket_pied': _pied.text.trim(),
    });
    if (mounted) afficherMessage(context, 'Réglages d\'impression enregistrés');
  }

  /// Texte du ticket d'exemple, centré sur le nombre de colonnes du papier.
  String _apercu() {
    final cols = _largeur == 58 ? 32 : (_largeur == 80 ? 48 : 64);
    String centre(String t) => t.length >= cols ? t : t.padLeft((cols + t.length) ~/ 2).padRight(cols);
    String ligne(String g, String d) {
      final espaces = cols - g.length - d.length;
      return espaces < 1 ? '$g $d' : '$g${' ' * espaces}$d';
    }

    final sep = '-' * cols;
    final nom = (_societe['raison_sociale'] as String?) ?? 'Ma Société';
    final b = StringBuffer()..writeln(centre(nom.toUpperCase()));
    for (final champ in ['adresse', 'telephone']) {
      final v = _societe[champ] as String?;
      if (v != null && v.isNotEmpty) b.writeln(centre(v));
    }
    if (_nif && (_societe['nif'] as String?)?.isNotEmpty == true) b.writeln(centre('NIF : ${_societe['nif']}'));
    for (final l in _entete.text.split('\n').where((l) => l.trim().isNotEmpty)) {
      b.writeln(centre(l.trim()));
    }
    b
      ..writeln(sep)
      ..writeln(ligne('VC-${s.pointVenteCode}-2026-00042', fmtDate(DateTime.now())))
      ..writeln(sep)
      ..writeln(ligne('Huile de table 1 L', ''))
      ..writeln(ligne('  2 x 654,00', '1 308,00'))
      ..writeln(ligne('Sucre blanc 1 kg', ''))
      ..writeln(ligne('  3 x 103,55', '310,65'))
      ..writeln(sep)
      ..writeln(ligne('Total HT', '1 485,00'))
      ..writeln(ligne('TVA', '133,65'))
      ..writeln(ligne('TOTAL TTC', '1 618,65 DA'))
      ..writeln(sep);
    if (_pied.text.trim().isNotEmpty) b.writeln(centre(_pied.text.trim()));
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Imprimante')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 120), children: [
        Card(
          margin: EdgeInsets.zero,
          color: const Color(0xFFE3F2FD),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Row(children: [
              Icon(Icons.info_outline, color: AppColors.vente),
              SizedBox(width: 10),
              Expanded(
                child: Text('Ces réglages seront utilisés pour l\'impression des tickets et des factures '
                    '(PDF et imprimante Bluetooth / Wi-Fi), ajoutée à l\'étape 3.'),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Format du papier', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 58, label: Text('58 mm')),
            ButtonSegment(value: 80, label: Text('80 mm')),
            ButtonSegment(value: 210, label: Text('A4')),
          ],
          selected: {_largeur},
          onSelectionChanged: (v) => setState(() => _largeur = v.first),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _entete,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Lignes d\'en-tête supplémentaires', helperText: 'Ex. « Vente en gros et détail »'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pied,
          decoration: const InputDecoration(labelText: 'Message de bas de ticket'),
          onChanged: (_) => setState(() {}),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _nif,
          title: const Text('Afficher le NIF de la société'),
          onChanged: (v) => setState(() => _nif = v),
        ),
        Row(children: [
          const Expanded(child: Text('Nombre de copies', style: TextStyle(fontWeight: FontWeight.w600))),
          IconButton(
              onPressed: _copies > 1 ? () => setState(() => _copies--) : null, icon: const Icon(Icons.remove_circle_outline)),
          Text('$_copies', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          IconButton(
              onPressed: _copies < 5 ? () => setState(() => _copies++) : null, icon: const Icon(Icons.add_circle_outline)),
        ]),
        const SizedBox(height: 12),
        const Text('Aperçu', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        // Aperçu "papier" : police à chasse fixe, défilement horizontal si besoin
        Relief3D(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(_apercu(), style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.3)),
          ),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Bouton3D(libelle: 'Enregistrer', icone: Icons.check, couleur: AppColors.ajouter, onPressed: _enregistrer),
        ),
      ),
    );
  }
}
