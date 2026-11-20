// =============================================================================
//  CrudSimplePage — écran générique « liste + ajouter / modifier / supprimer »
// =============================================================================
//  Un seul écran pour toutes les petites tables de référence :
//  Taxes, Commerciaux, Points de vente, Familles d'articles.
//  Chaque table est décrite par une ConfigCrud (voir configs_crud.dart) :
//  nom de la table, champs du formulaire, libellés de la liste, règles.
// =============================================================================

import 'package:flutter/material.dart';

import 'package:gestock_pos/core/database/database_helper.dart';
import 'package:gestock_pos/core/theme/app_colors.dart';
import 'package:gestock_pos/core/utils/formatters.dart';
import 'package:gestock_pos/core/utils/ids.dart';
import 'package:gestock_pos/core/widgets/communs.dart';
import 'package:gestock_pos/core/widgets/relief_3d.dart';

enum TypeChamp { texte, nombre, telephone, booleen }

class ChampCrud {
  const ChampCrud(this.cle, this.libelle,
      {this.type = TypeChamp.texte, this.obligatoire = false, this.suffixe, this.aide, this.unique = false});
  final String cle;       // nom de la colonne SQL
  final String libelle;
  final TypeChamp type;
  final bool obligatoire;
  final String? suffixe;  // ex. '%'
  final String? aide;
  final bool unique;      // valeur unique dans la table (ex. code)
}

typedef Ligne = Map<String, Object?>;

class ConfigCrud {
  const ConfigCrud({
    required this.table,
    required this.titre,
    required this.singulier,
    required this.icone,
    required this.couleur,
    required this.champs,
    required this.titreLigne,
    this.sousTitreLigne,
    this.orderBy = 'rowid',
    this.selectSql,
    this.avantSuppression,
    this.apresEnregistrement,
    this.apresSuppression,
    this.aide,
  });

  final String table;
  final String titre;
  final String singulier;       // ex. « la taxe »
  final IconData icone;
  final Color couleur;
  final List<ChampCrud> champs;
  final String Function(Ligne) titreLigne;
  final String Function(Ligne)? sousTitreLigne;
  final String orderBy;
  final String? selectSql;      // requête personnalisée (ex. avec un compteur)
  /// Renvoie un message pour INTERDIRE la suppression, ou null pour l'autoriser.
  final Future<String?> Function(Ligne)? avantSuppression;
  final Future<void> Function(String id, Ligne valeurs)? apresEnregistrement;
  final Future<void> Function(String id)? apresSuppression;
  final String? aide;           // texte d'explication en haut de la liste
}

class CrudSimplePage extends StatefulWidget {
  const CrudSimplePage({super.key, required this.config});
  final ConfigCrud config;

  @override
  State<CrudSimplePage> createState() => _CrudSimplePageState();
}

class _CrudSimplePageState extends State<CrudSimplePage> {
  List<Ligne> _lignes = [];
  bool _chargement = true;

  ConfigCrud get c => widget.config;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final db = await DatabaseHelper.instance.database;
    final rows = c.selectSql != null
        ? await db.rawQuery(c.selectSql!)
        : await db.query(c.table, where: 'deleted = 0', orderBy: c.orderBy);
    if (!mounted) return;
    setState(() {
      _lignes = rows;
      _chargement = false;
    });
  }

  Future<void> _formulaire([Ligne? ligne]) async {
    final valeurs = await showModalBottomSheet<Ligne>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _FormulaireCrud(config: c, ligne: ligne),
    );
    if (valeurs == null) return;

    final db = await DatabaseHelper.instance.database;
    final now = maintenantUtc();
    final id = (ligne?['id'] as String?) ?? nouvelId();

    // Contrôle des champs uniques
    for (final ch in c.champs.where((x) => x.unique)) {
      final r = await db.query(c.table,
          where: '${ch.cle} = ? AND id <> ? AND deleted = 0', whereArgs: [valeurs[ch.cle], id], limit: 1);
      if (r.isNotEmpty) {
        if (mounted) afficherMessage(context, '« ${valeurs[ch.cle]} » existe déjà (${ch.libelle}).', erreur: true);
        return;
      }
    }

    try {
      if (ligne == null) {
        await db.insert(c.table, {...valeurs, 'id': id, 'created_at': now, 'updated_at': now, 'sync_status': 1});
      } else {
        await db.update(c.table, {...valeurs, 'updated_at': now, 'sync_status': 1}, where: 'id = ?', whereArgs: [id]);
      }
      await c.apresEnregistrement?.call(id, valeurs);
    } catch (e) {
      // Ex. code déjà utilisé par un élément supprimé (contrainte UNIQUE)
      if (mounted) afficherMessage(context, 'Enregistrement impossible : valeur déjà utilisée.', erreur: true);
      return;
    }
    if (!mounted) return;
    afficherMessage(context, ligne == null ? 'Ajouté' : 'Modifié');
    _charger();
  }

  Future<void> _supprimer(Ligne ligne) async {
    final interdit = await c.avantSuppression?.call(ligne);
    if (!mounted) return;
    if (interdit != null) {
      afficherMessage(context, interdit, erreur: true);
      return;
    }
    if (!await confirmerSuppression(context, '${c.singulier} « ${c.titreLigne(ligne)} »')) return;
    final db = await DatabaseHelper.instance.database;
    final id = ligne['id'] as String;
    await db.update(c.table, {'deleted': 1, 'updated_at': maintenantUtc(), 'sync_status': 1},
        where: 'id = ?', whereArgs: [id]);
    await c.apresSuppression?.call(id);
    if (!mounted) return;
    afficherMessage(context, 'Supprimé');
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(c.titre)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _formulaire(),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _charger,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 96, top: 8),
                children: [
                  if (c.aide != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Text(c.aide!, style: const TextStyle(color: AppColors.texteSecondaire)),
                    ),
                  if (_lignes.isEmpty) EtatVide(icone: c.icone, message: 'Aucun élément.\nAppuyez sur « Ajouter ».'),
                  for (final l in _lignes)
                    Card(
                      child: ListTile(
                        onTap: () => _formulaire(l),
                        leading: CircleAvatar(
                          backgroundColor: c.couleur.withValues(alpha: 0.12),
                          child: Icon(c.icone, color: c.couleur),
                        ),
                        title: Text(c.titreLigne(l), style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: c.sousTitreLigne == null ? null : Text(c.sousTitreLigne!(l)),
                        trailing: IconButton(
                          tooltip: 'Supprimer',
                          icon: const Icon(Icons.delete_outline, color: AppColors.supprimer),
                          onPressed: () => _supprimer(l),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

/// Formulaire généré à partir de la liste des champs.
class _FormulaireCrud extends StatefulWidget {
  const _FormulaireCrud({required this.config, this.ligne});
  final ConfigCrud config;
  final Ligne? ligne;

  @override
  State<_FormulaireCrud> createState() => _FormulaireCrudState();
}

class _FormulaireCrudState extends State<_FormulaireCrud> {
  final _form = GlobalKey<FormState>();
  final Map<String, TextEditingController> _ctrl = {};
  final Map<String, bool> _bool = {};

  @override
  void initState() {
    super.initState();
    for (final ch in widget.config.champs) {
      final v = widget.ligne?[ch.cle];
      if (ch.type == TypeChamp.booleen) {
        _bool[ch.cle] = (v as int? ?? 0) == 1;
      } else if (ch.type == TypeChamp.nombre) {
        final n = (v as num?)?.toDouble();
        _ctrl[ch.cle] = TextEditingController(
            text: n == null ? '' : (n == n.roundToDouble() ? n.toInt().toString() : n.toString()));
      } else {
        _ctrl[ch.cle] = TextEditingController(text: v as String? ?? '');
      }
    }
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _valider() {
    if (!_form.currentState!.validate()) return;
    final valeurs = <String, Object?>{};
    for (final ch in widget.config.champs) {
      switch (ch.type) {
        case TypeChamp.booleen:
          valeurs[ch.cle] = _bool[ch.cle]! ? 1 : 0;
        case TypeChamp.nombre:
          valeurs[ch.cle] = parseNombre(_ctrl[ch.cle]!.text) ?? 0;
        case TypeChamp.texte:
        case TypeChamp.telephone:
          final t = _ctrl[ch.cle]!.text.trim();
          valeurs[ch.cle] = t.isEmpty ? null : t;
      }
    }
    Navigator.pop(context, valeurs);
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    final clavier = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + clavier),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(widget.ligne == null ? 'Ajouter ${cfg.singulier}' : 'Modifier ${cfg.singulier}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            for (final ch in cfg.champs)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ch.type == TypeChamp.booleen
                    ? SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(ch.libelle),
                        subtitle: ch.aide == null ? null : Text(ch.aide!),
                        value: _bool[ch.cle]!,
                        onChanged: (v) => setState(() => _bool[ch.cle] = v),
                      )
                    : TextFormField(
                        controller: _ctrl[ch.cle],
                        keyboardType: switch (ch.type) {
                          TypeChamp.nombre => const TextInputType.numberWithOptions(decimal: true),
                          TypeChamp.telephone => TextInputType.phone,
                          _ => TextInputType.text,
                        },
                        decoration: InputDecoration(
                          labelText: '${ch.libelle}${ch.obligatoire ? ' *' : ''}',
                          suffixText: ch.suffixe,
                          helperText: ch.aide,
                        ),
                        validator: (v) {
                          if (ch.type == TypeChamp.nombre) return validerNombre(v, obligatoire: ch.obligatoire);
                          if (ch.obligatoire && (v == null || v.trim().isEmpty)) return 'Obligatoire';
                          return null;
                        },
                      ),
              ),
            Bouton3D(libelle: 'Enregistrer', icone: Icons.check, couleur: AppColors.ajouter, onPressed: _valider),
          ]),
        ),
      ),
    );
  }
}
