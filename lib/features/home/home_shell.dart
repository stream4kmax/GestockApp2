// =============================================================================
//  HomeShell — page d'accueil avec la barre de navigation inférieure
// =============================================================================
//  • NavigationBar (Material 3) avec les 6 modules.
//  • IndexedStack : les 6 pages restent en mémoire ; quand on change d'onglet
//    puis qu'on revient, on retrouve l'écran exactement où on l'avait laissé
//    (position de défilement, etc.).
//  • Touche "Retour" Android : si on n'est pas sur l'onglet Vente, on y
//    revient d'abord au lieu de quitter l'application.
// =============================================================================

import 'package:flutter/material.dart';

import 'package:gestock_pos/features/home/module_menu_page.dart';
import 'package:gestock_pos/features/home/modules.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0; // onglet affiché (0 = Vente)

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // On autorise la fermeture de l'app uniquement depuis le 1er onglet.
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _index = 0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            for (final module in modulesApp) ModuleMenuPage(module: module),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          // 6 onglets sur un téléphone : on n'affiche que le libellé de
          // l'onglet actif, sinon les textes seraient tronqués.
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          destinations: [
            for (final m in modulesApp)
              NavigationDestination(
                icon: Icon(m.icone),
                selectedIcon: Icon(m.iconeActive, color: m.couleur),
                label: m.libelle,
                tooltip: m.libelle,
              ),
          ],
        ),
      ),
    );
  }
}
