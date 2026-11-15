// =============================================================================
//  Page d'un module : grille de cases 3D (v2)
// =============================================================================
//  Correction du « Bottom overflowed by 22 pixels » :
//   La v1 utilisait childAspectRatio : sur un petit écran ou avec une grande
//   police, la case devenait trop basse pour l'icône + 2 lignes de texte.
//   La v2 utilise une HAUTEUR FIXE (mainAxisExtent) et une largeur maximale
//   (maxCrossAxisExtent) : le nombre de colonnes s'adapte tout seul à l'écran
//   et le contenu a toujours la place nécessaire.
// =============================================================================

import 'package:flutter/material.dart';

import 'package:gestock_pos/core/theme/app_colors.dart';
import 'package:gestock_pos/core/widgets/relief_3d.dart';
import 'package:gestock_pos/data/repositories/article_repository.dart';
import 'package:gestock_pos/features/article/article_list_page.dart';
import 'package:gestock_pos/features/home/dashboard_header.dart';
import 'package:gestock_pos/features/home/modules.dart';
import 'package:gestock_pos/features/home/placeholder_page.dart';

class ModuleMenuPage extends StatefulWidget {
  const ModuleMenuPage({super.key, required this.module});
  final ModuleApp module;

  @override
  State<ModuleMenuPage> createState() => _ModuleMenuPageState();
}

class _ModuleMenuPageState extends State<ModuleMenuPage> {
  int _rafraichir = 0; // change la clé du tableau de bord → rechargement

  Future<void> _ouvrir(WidgetBuilder builder) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: builder));
    if (mounted) setState(() => _rafraichir++);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.module;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Icon(m.iconeActive, color: m.couleur),
          const SizedBox(width: 10),
          Flexible(child: Text(m.libelle, overflow: TextOverflow.ellipsis)),
        ]),
      ),
      body: CustomScrollView(
        slivers: [
          if (m.avecTableauDeBord)
            SliverToBoxAdapter(
              child: DashboardHeader(
                key: ValueKey(_rafraichir),
                onAlertesTap: () => _ouvrir((_) => const ArticleListPage(
                      titre: 'Articles en rupture',
                      filtreInitial: FiltreStock.alerte,
                    )),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 190, // ≈ 2 colonnes sur téléphone, 4-5 sur tablette
                mainAxisExtent: 124,     // hauteur fixe : plus jamais de débordement
                mainAxisSpacing: 8,
                crossAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                childCount: m.sousModules.length,
                (context, i) {
                  final sm = m.sousModules[i];
                  return _Case3D(
                    sousModule: sm,
                    couleur: m.couleur,
                    onTap: () => _ouvrir(sm.builder ?? (_) => PlaceholderPage(titre: sm.libelle)),
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

/// Case du menu en relief, qui s'enfonce à l'appui.
class _Case3D extends StatelessWidget {
  const _Case3D({required this.sousModule, required this.couleur, required this.onTap});
  final SousModule sousModule;
  final Color couleur;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dispo = sousModule.builder != null;
    return Relief3D(
      onTap: onTap,
      semanticLabel: sousModule.libelle,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icône dans une pastille colorée en léger relief
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dispo
                    ? [AppColors.eclaircir(couleur, 0.08), couleur]
                    : [const Color(0xFFCFD6E0), const Color(0xFFB0BAC7)],
              ),
              boxShadow: [
                BoxShadow(
                  color: (dispo ? couleur : Colors.grey).withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(sousModule.icone, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 8),
          // Flexible + maxLines : le texte prend la place restante, sans déborder
          Flexible(
            child: Text(
              sousModule.libelle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.15,
                fontWeight: FontWeight.w700,
                color: dispo ? AppColors.texte : AppColors.texteSecondaire,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
