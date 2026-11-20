// =============================================================================
//  CalculatricePage — calculatrice du commerçant (3 onglets)
// =============================================================================
//  1. Calcul     : calculatrice classique avec touches 3D (+ − × ÷ % parenthèses)
//  2. Marge      : prix d'achat + marge % → prix de vente HT / TTC
//                  (ou prix de vente → marge réelle)
//  3. HT ↔ TTC   : conversion selon le taux de TVA (0, 9, 19 %)
// =============================================================================

import 'package:flutter/material.dart';

import 'package:gestock_pos/core/theme/app_colors.dart';
import 'package:gestock_pos/core/utils/formatters.dart';
import 'package:gestock_pos/core/widgets/relief_3d.dart';

class CalculatricePage extends StatelessWidget {
  const CalculatricePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Calculatrice'),
          bottom: const TabBar(tabs: [Tab(text: 'Calcul'), Tab(text: 'Marge'), Tab(text: 'HT ↔ TTC')]),
        ),
        body: const TabBarView(children: [_Calcul(), _Marge(), _HtTtc()]),
      ),
    );
  }
}

// =============================================================================
//  1. Calculatrice classique
// =============================================================================
class _Calcul extends StatefulWidget {
  const _Calcul();

  @override
  State<_Calcul> createState() => _CalculState();
}

class _CalculState extends State<_Calcul> {
  String _expr = '';
  String _resultat = '0';

  static const _touches = [
    ['C', '(', ')', '÷'],
    ['7', '8', '9', '×'],
    ['4', '5', '6', '−'],
    ['1', '2', '3', '+'],
    ['%', '0', ',', '='],
  ];

  void _appui(String t) {
    setState(() {
      switch (t) {
        case 'C':
          _expr = '';
          _resultat = '0';
        case '=':
          final r = Evaluateur.evaluer(_expr);
          _resultat = r == null ? 'Erreur' : fmtQte(r);
          if (r != null) _expr = _brut(r);
        default:
          _expr += t;
          final r = Evaluateur.evaluer(_expr);
          if (r != null) _resultat = fmtQte(r); // aperçu en direct
      }
    });
  }

  void _effacer() => setState(() {
        if (_expr.isNotEmpty) _expr = _expr.substring(0, _expr.length - 1);
      });

  static String _brut(double v) =>
      (v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(6).replaceFirst(RegExp(r'0+$'), ''))
          .replaceAll('.', ',');

  Color _couleur(String t) => switch (t) {
        'C' => AppColors.supprimer,
        '=' => AppColors.ajouter,
        '÷' || '×' || '−' || '+' || '%' || '(' || ')' => AppColors.vente,
        _ => AppColors.surface,
      };

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Écran
      Container(
        width: double.infinity,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F0E8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.bordure),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Row(children: [
            IconButton(onPressed: _effacer, icon: const Icon(Icons.backspace_outlined), tooltip: 'Effacer'),
            Expanded(
              child: Text(_expr.isEmpty ? ' ' : _expr,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 20, color: AppColors.texteSecondaire)),
            ),
          ]),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(_resultat, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
      // Clavier : LayoutBuilder répartit la hauteur disponible entre les 5 rangées
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: LayoutBuilder(builder: (context, c) {
            final hauteur = (c.maxHeight / _touches.length).clamp(0.0, 90.0); // jamais plus haut que l'espace disponible
            return Column(children: [
              for (final rangee in _touches)
                SizedBox(
                  height: hauteur,
                  child: Row(children: [
                    for (final t in rangee)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Relief3D(
                            onTap: () => _appui(t),
                            couleur: _couleur(t),
                            rayon: 14,
                            profondeur: 4,
                            padding: EdgeInsets.zero,
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(t,
                                    style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: _couleur(t) == AppColors.surface ? AppColors.texte : Colors.white)),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ]),
                ),
            ]);
          }),
        ),
      ),
    ]);
  }
}

/// Évaluateur d'expressions (descente récursive) :
///   expression := terme (('+'|'−') terme)*
///   terme      := facteur (('×'|'÷') facteur)*
///   facteur    := nombre['%'] | '(' expression ')' | '−' facteur
class Evaluateur {
  Evaluateur._(this._s);
  final String _s;
  int _i = 0;

  static double? evaluer(String expr) {
    if (expr.trim().isEmpty) return 0;
    try {
      final e = Evaluateur._(expr.replaceAll(',', '.').replaceAll(' ', ''));
      final v = e._expression();
      if (e._i != e._s.length || v.isNaN || v.isInfinite) return null;
      return v;
    } catch (_) {
      return null;
    }
  }

  String? get _c => _i < _s.length ? _s[_i] : null;

  double _expression() {
    var v = _terme();
    while (_c == '+' || _c == '−' || _c == '-') {
      final op = _s[_i++];
      final d = _terme();
      v = op == '+' ? v + d : v - d;
    }
    return v;
  }

  double _terme() {
    var v = _facteur();
    while (_c == '×' || _c == '÷' || _c == '*' || _c == '/') {
      final op = _s[_i++];
      final d = _facteur();
      v = (op == '×' || op == '*') ? v * d : v / d;
    }
    return v;
  }

  double _facteur() {
    if (_c == '−' || _c == '-') {
      _i++;
      return -_facteur();
    }
    if (_c == '(') {
      _i++;
      final v = _expression();
      if (_c != ')') throw const FormatException('parenthèse');
      _i++;
      return _pourcent(v);
    }
    final debut = _i;
    while (_c != null && RegExp(r'[0-9.]').hasMatch(_c!)) {
      _i++;
    }
    if (debut == _i) throw const FormatException('nombre');
    return _pourcent(double.parse(_s.substring(debut, _i)));
  }

  double _pourcent(double v) {
    if (_c == '%') {
      _i++;
      return v / 100;
    }
    return v;
  }
}

// =============================================================================
//  2. Calcul de marge
// =============================================================================
class _Marge extends StatefulWidget {
  const _Marge();

  @override
  State<_Marge> createState() => _MargeState();
}

class _MargeState extends State<_Marge> {
  final _achat = TextEditingController();
  final _marge = TextEditingController(text: '20');
  final _vente = TextEditingController();
  double _tva = 19;

  @override
  void dispose() {
    _achat.dispose();
    _marge.dispose();
    _vente.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final achat = parseNombre(_achat.text) ?? 0;
    final margePct = parseNombre(_marge.text) ?? 0;
    final venteSaisie = parseNombre(_vente.text);

    // Prix de vente conseillé = achat × (1 + marge %)
    final venteHt = round2(achat * (1 + margePct / 100));
    final venteTtc = round2(venteHt * (1 + _tva / 100));
    // Marge réelle si un prix de vente est saisi
    final margeReelle = (venteSaisie != null && achat > 0) ? (venteSaisie - achat) / achat * 100 : null;

    return ListView(padding: const EdgeInsets.all(16), children: [
      TextField(
        controller: _achat,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Prix d\'achat HT', suffixText: 'DA'),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _marge,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Marge souhaitée', suffixText: '%'),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 12),
      _ChoixTva(valeur: _tva, onChanged: (v) => setState(() => _tva = v)),
      const SizedBox(height: 16),
      _Resultat('Prix de vente HT conseillé', fmtMonnaie(venteHt), AppColors.vente),
      _Resultat('Prix de vente TTC', fmtMonnaie(venteTtc), AppColors.ajouter),
      _Resultat('Bénéfice par unité', fmtMonnaie(round2(venteHt - achat)), AppColors.tresorerie),
      const Divider(height: 32),
      const Text('Ou vérifier un prix de vente :', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      TextField(
        controller: _vente,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Prix de vente HT pratiqué', suffixText: 'DA'),
        onChanged: (_) => setState(() {}),
      ),
      if (margeReelle != null)
        _Resultat('Marge réelle', '${fmtQte(round2(margeReelle))} %',
            margeReelle >= 0 ? AppColors.ajouter : AppColors.supprimer),
    ]);
  }
}

// =============================================================================
//  3. Conversion HT ↔ TTC
// =============================================================================
class _HtTtc extends StatefulWidget {
  const _HtTtc();

  @override
  State<_HtTtc> createState() => _HtTtcState();
}

class _HtTtcState extends State<_HtTtc> {
  final _montant = TextEditingController();
  bool _depuisHt = true;
  double _tva = 19;

  @override
  void dispose() {
    _montant.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = parseNombre(_montant.text) ?? 0;
    final ht = _depuisHt ? m : round2(m / (1 + _tva / 100));
    final ttc = _depuisHt ? round2(m * (1 + _tva / 100)) : m;
    return ListView(padding: const EdgeInsets.all(16), children: [
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: true, label: Text('HT → TTC')),
          ButtonSegment(value: false, label: Text('TTC → HT')),
        ],
        selected: {_depuisHt},
        onSelectionChanged: (s) => setState(() => _depuisHt = s.first),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _montant,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: _depuisHt ? 'Montant HT' : 'Montant TTC', suffixText: 'DA'),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 12),
      _ChoixTva(valeur: _tva, onChanged: (v) => setState(() => _tva = v)),
      const SizedBox(height: 16),
      _Resultat('Montant HT', fmtMonnaie(ht), AppColors.vente),
      _Resultat('TVA (${fmtQte(_tva)} %)', fmtMonnaie(round2(ttc - ht)), AppColors.alerte),
      _Resultat('Montant TTC', fmtMonnaie(ttc), AppColors.ajouter),
    ]);
  }
}

class _ChoixTva extends StatelessWidget {
  const _ChoixTva({required this.valeur, required this.onChanged});
  final double valeur;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<double>(
        segments: const [
          ButtonSegment(value: 0, label: Text('0 %')),
          ButtonSegment(value: 9, label: Text('9 %')),
          ButtonSegment(value: 19, label: Text('19 %')),
        ],
        selected: {valeur},
        onSelectionChanged: (s) => onChanged(s.first),
      );
}

class _Resultat extends StatelessWidget {
  const _Resultat(this.libelle, this.valeur, this.couleur);
  final String libelle;
  final String valeur;
  final Color couleur;

  @override
  Widget build(BuildContext context) => Relief3D(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Expanded(child: Text(libelle, style: const TextStyle(fontWeight: FontWeight.w600))),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(valeur, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: couleur)),
            ),
          ),
        ]),
      );
}
