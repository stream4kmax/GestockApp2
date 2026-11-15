// ClientFormPage — ajouter / modifier / supprimer un client.

import 'package:flutter/material.dart';

import 'package:gestock_pos/core/constants/type_tarif.dart';
import 'package:gestock_pos/core/theme/app_colors.dart';
import 'package:gestock_pos/core/utils/formatters.dart';
import 'package:gestock_pos/core/widgets/communs.dart';
import 'package:gestock_pos/core/widgets/relief_3d.dart';
import 'package:gestock_pos/data/models/client.dart';
import 'package:gestock_pos/data/repositories/client_repository.dart';

class ClientFormPage extends StatefulWidget {
  const ClientFormPage({super.key, this.client});
  final Client? client;

  @override
  State<ClientFormPage> createState() => _ClientFormPageState();
}

class _ClientFormPageState extends State<ClientFormPage> {
  final _form = GlobalKey<FormState>();
  final _repo = ClientRepository();
  late final c = widget.client;

  late final _nom = TextEditingController(text: c?.nom);
  late final _code = TextEditingController(text: c?.code);
  late final _tel = TextEditingController(text: c?.telephone);
  late final _whatsapp = TextEditingController(text: c?.whatsapp);
  late final _email = TextEditingController(text: c?.email);
  late final _adresse = TextEditingController(text: c?.adresse);
  late final _nif = TextEditingController(text: c?.nif);
  late final _rc = TextEditingController(text: c?.rc);
  late final _plafond =
      TextEditingController(text: (c?.plafondCredit ?? 0) == 0 ? '' : c!.plafondCredit.toStringAsFixed(0));
  late TypeTarif _tarif = c?.typeTarif ?? TypeTarif.detail;
  bool _enregistrement = false;

  @override
  void dispose() {
    for (final x in [_nom, _code, _tel, _whatsapp, _email, _adresse, _nif, _rc, _plafond]) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _enregistrement = true);
    final nouveau = Client(
      id: c?.id ?? '',
      code: _code.text.trim(),
      nom: _nom.text.trim(),
      telephone: _tel.text,
      whatsapp: _whatsapp.text,
      email: _email.text,
      adresse: _adresse.text,
      nif: _nif.text,
      rc: _rc.text,
      plafondCredit: parseNombre(_plafond.text) ?? 0,
      typeTarif: _tarif,
    );
    try {
      if (c == null) {
        await _repo.creer(nouveau);
      } else {
        await _repo.modifier(nouveau);
      }
      if (!mounted) return;
      afficherMessage(context, c == null ? 'Client ajouté' : 'Client modifié');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) afficherMessage(context, 'Erreur : $e', erreur: true);
    } finally {
      if (mounted) setState(() => _enregistrement = false);
    }
  }

  Future<void> _supprimer() async {
    if (!await confirmerSuppression(context, '« ${c!.nom} »')) return;
    try {
      await _repo.supprimer(c!.id);
      if (!mounted) return;
      afficherMessage(context, 'Client supprimé');
      Navigator.of(context)
        ..pop(true) // formulaire
        ..pop(true); // fiche client derrière
    } catch (e) {
      if (mounted) afficherMessage(context, '$e', erreur: true);
    }
  }

  Widget _champ(TextEditingController ctrl, String label, IconData icone,
          {TextInputType? clavier, bool obligatoire = false, String? aide}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: ctrl,
          keyboardType: clavier,
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(icone), helperText: aide),
          validator: obligatoire ? (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null : null,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final peutSupprimer = c != null && !c!.estComptoir;
    return Scaffold(
      appBar: AppBar(title: Text(c == null ? 'Nouveau client' : 'Modifier le client')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            _champ(_nom, 'Nom *', Icons.person, obligatoire: true),
            _champ(_code, 'Code client', Icons.tag),
            _champ(_tel, 'Téléphone (SMS)', Icons.phone, clavier: TextInputType.phone),
            _champ(_whatsapp, 'WhatsApp (si différent)', Icons.chat,
                clavier: TextInputType.phone, aide: 'Laisser vide = même numéro que le téléphone'),
            _champ(_email, 'E-mail', Icons.email, clavier: TextInputType.emailAddress),
            _champ(_adresse, 'Adresse', Icons.place),
            _champ(_nif, 'NIF', Icons.badge),
            _champ(_rc, 'Registre du commerce', Icons.description),
            _champ(_plafond, 'Plafond de crédit (DA)', Icons.credit_score,
                clavier: TextInputType.number, aide: 'Vide = pas de limite'),
            const Text('Tarif appliqué par défaut au POS', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SegmentedButton<TypeTarif>(
              segments: [for (final t in TypeTarif.values) ButtonSegment(value: t, label: Text(t.libelle))],
              selected: {_tarif},
              onSelectionChanged: (s) => setState(() => _tarif = s.first),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(children: [
            if (peutSupprimer) ...[
              Expanded(
                child: Bouton3D(
                    libelle: 'Supprimer', icone: Icons.delete, couleur: AppColors.supprimer, onPressed: _supprimer),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: Bouton3D(
                libelle: 'Enregistrer',
                icone: Icons.check,
                couleur: AppColors.ajouter,
                chargement: _enregistrement,
                onPressed: _enregistrer,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
