// FournisseurFormPage — ajouter / modifier / supprimer un fournisseur.

import 'package:flutter/material.dart';

import 'package:gestock_pos/core/theme/app_colors.dart';
import 'package:gestock_pos/core/widgets/communs.dart';
import 'package:gestock_pos/core/widgets/relief_3d.dart';
import 'package:gestock_pos/data/models/fournisseur.dart';
import 'package:gestock_pos/core/utils/formatters.dart';
import 'package:gestock_pos/data/repositories/fournisseur_repository.dart';
import 'package:gestock_pos/data/repositories/solde_repository.dart';

class FournisseurFormPage extends StatefulWidget {
  const FournisseurFormPage({super.key, this.fournisseur});
  final Fournisseur? fournisseur;

  @override
  State<FournisseurFormPage> createState() => _FournisseurFormPageState();
}

class _FournisseurFormPageState extends State<FournisseurFormPage> {
  final _form = GlobalKey<FormState>();
  final _repo = FournisseurRepository();
  late final f = widget.fournisseur;

  late final _nom = TextEditingController(text: f?.nom);
  late final _code = TextEditingController(text: f?.code);
  late final _tel = TextEditingController(text: f?.telephone);
  late final _whatsapp = TextEditingController(text: f?.whatsapp);
  late final _email = TextEditingController(text: f?.email);
  late final _adresse = TextEditingController(text: f?.adresse);
  late final _nif = TextEditingController(text: f?.nif);
  late final _rc = TextEditingController(text: f?.rc);
  final _detteAnterieure = TextEditingController(); // v2c
  bool _enregistrement = false;

  @override
  void dispose() {
    for (final c in [_nom, _code, _tel, _whatsapp, _email, _adresse, _nif, _rc, _detteAnterieure]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _enregistrement = true);
    final nouveau = Fournisseur(
      id: f?.id ?? '',
      code: _code.text.trim(),
      nom: _nom.text.trim(),
      telephone: _tel.text,
      whatsapp: _whatsapp.text,
      email: _email.text,
      adresse: _adresse.text,
      nif: _nif.text,
      rc: _rc.text,
    );
    try {
      if (f == null) {
        final id = await _repo.creer(nouveau);
        // v2c : reprise de ce que vous deviez AVANT l'application
        final dette = parseNombre(_detteAnterieure.text) ?? 0;
        if (dette > 0) {
          await SoldeRepository().creerSoldeInitial(
              tiersType: 'F', tiersId: id, tiersNom: nouveau.nom, montant: dette);
        }
      } else {
        await _repo.modifier(nouveau);
      }
      if (!mounted) return;
      afficherMessage(context, f == null ? 'Fournisseur ajouté' : 'Fournisseur modifié');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) afficherMessage(context, 'Erreur : $e', erreur: true);
    } finally {
      if (mounted) setState(() => _enregistrement = false);
    }
  }

  Future<void> _supprimer() async {
    if (!await confirmerSuppression(context, '« ${f!.nom} »')) return;
    await _repo.supprimer(f!.id);
    if (!mounted) return;
    afficherMessage(context, 'Fournisseur supprimé');
    // Ferme le formulaire ET la fiche détail située derrière
    Navigator.of(context)
      ..pop(true)
      ..pop(true);
  }

  Widget _champ(TextEditingController c, String label, IconData icone,
          {TextInputType? clavier, bool obligatoire = false, String? aide}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c,
          keyboardType: clavier,
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(icone), helperText: aide),
          validator: obligatoire ? (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null : null,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(f == null ? 'Nouveau fournisseur' : 'Modifier le fournisseur')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            _champ(_nom, 'Nom / Raison sociale *', Icons.business, obligatoire: true),
            _champ(_code, 'Code', Icons.tag),
            _champ(_tel, 'Téléphone', Icons.phone, clavier: TextInputType.phone),
            _champ(_whatsapp, 'WhatsApp (si différent)', Icons.chat,
                clavier: TextInputType.phone, aide: 'Laisser vide = même numéro que le téléphone'),
            _champ(_email, 'E-mail', Icons.email, clavier: TextInputType.emailAddress),
            _champ(_adresse, 'Adresse', Icons.place),
            _champ(_nif, 'NIF', Icons.badge),
            _champ(_rc, 'Registre du commerce', Icons.description),
            if (f == null)
              _champ(_detteAnterieure, 'Dette antérieure (DA)', Icons.history_edu,
                  clavier: const TextInputType.numberWithOptions(decimal: true),
                  aide: 'Ce que vous devez déjà à ce fournisseur avant d\'utiliser l\'application'),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(children: [
            if (f != null) ...[
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
