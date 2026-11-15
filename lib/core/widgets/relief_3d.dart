// =============================================================================
//  Relief3D & Bouton3D — effet de relief "touche de clavier"
// =============================================================================
//  Principe du rendu 3D :
//   ┌───────────────┐   ← face (couleur + léger dégradé = reflet de lumière)
//   │               │
//   └───────────────┘
//    ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀   ← socle : ombre DURE (sans flou), couleur assombrie
//      ░░░░░░░░░░░░     ← ombre portée douce (flou) sur le fond
//
//  À l'appui (onTapDown) : la face descend de `profondeur` pixels et les ombres
//  se réduisent → la case semble s'enfoncer. Au relâchement, elle remonte.
//  Une petite vibration (HapticFeedback) renforce la sensation tactile.
//
//  La place du socle est réservée en dessous (Padding) : la mise en page ne
//  "saute" pas pendant l'animation et rien ne déborde.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:gestock_pos/core/theme/app_colors.dart';

class Relief3D extends StatefulWidget {
  const Relief3D({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.couleur = AppColors.surface,
    this.rayon = 18,
    this.profondeur = 5,
    this.padding = const EdgeInsets.all(12),
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color couleur;
  final double rayon;
  final double profondeur;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;

  @override
  State<Relief3D> createState() => _Relief3DState();
}

class _Relief3DState extends State<Relief3D> {
  bool _enfonce = false;

  bool get _cliquable => widget.onTap != null || widget.onLongPress != null;

  void _changer(bool valeur) {
    if (!_cliquable || _enfonce == valeur) return;
    setState(() => _enfonce = valeur);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profondeur;
    final decalage = _enfonce ? p - 1 : 0.0; // la face descend
    final hauteurSocle = _enfonce ? 1.0 : p;  // le socle se "comprime"
    final estBlanc = widget.couleur == AppColors.surface;
    final socle = estBlanc ? const Color(0xFFD5DCE6) : AppColors.assombrir(widget.couleur);

    return Semantics(
      button: _cliquable,
      label: widget.semanticLabel,
      child: Padding(
        padding: EdgeInsets.only(bottom: p), // place réservée au socle
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _changer(true),
          onTapUp: (_) => _changer(false),
          onTapCancel: () => _changer(false),
          onTap: widget.onTap == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  widget.onTap!();
                },
          onLongPress: widget.onLongPress,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(0, decalage, 0),
            padding: widget.padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.rayon),
              // Dégradé vertical : plus clair en haut = lumière venant du dessus
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: estBlanc
                    ? const [Colors.white, Color(0xFFF7F9FC)]
                    : [AppColors.eclaircir(widget.couleur, 0.06), widget.couleur],
              ),
              border: Border.all(
                color: estBlanc ? AppColors.bordure : AppColors.eclaircir(widget.couleur, 0.12),
              ),
              boxShadow: [
                // 1. Socle dur (épaisseur de la "touche")
                BoxShadow(color: socle, offset: Offset(0, hauteurSocle), blurRadius: 0),
                // 2. Ombre portée douce
                BoxShadow(
                  color: Colors.black.withValues(alpha: _enfonce ? 0.06 : 0.14),
                  offset: Offset(0, hauteurSocle + 2),
                  blurRadius: _enfonce ? 2 : 10,
                ),
              ],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Bouton coloré en relief : icône + libellé qui se réduit si la place manque.
class Bouton3D extends StatelessWidget {
  const Bouton3D({
    super.key,
    required this.libelle,
    required this.onPressed,
    this.icone,
    this.couleur = AppColors.vente,
    this.chargement = false,
    this.hauteur = 52,
  });

  final String libelle;
  final IconData? icone;
  final Color couleur;
  final VoidCallback? onPressed;
  final bool chargement;
  final double hauteur;

  @override
  Widget build(BuildContext context) {
    final actif = onPressed != null && !chargement;
    final fond = actif ? couleur : const Color(0xFFB8C0CC);
    return Relief3D(
      onTap: actif ? onPressed : null,
      couleur: fond,
      rayon: 14,
      profondeur: 4,
      semanticLabel: libelle,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: SizedBox(
        height: hauteur,
        child: Center(
          // FittedBox : sur un petit écran, le texte rétrécit au lieu de déborder
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (chargement)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                else if (icone != null)
                  Icon(icone, color: Colors.white, size: 22),
                if (icone != null || chargement) const SizedBox(width: 8),
                Text(
                  libelle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
