// =============================================================================
//  GeStock POS — Point d'entrée de l'application (v2)
// =============================================================================
//  Changements v2 :
//   • Thème CLAIR uniquement (le mode sombre est supprimé).
//   • Taille du texte limitée (×0,9 à ×1,15) : si l'utilisateur a choisi une
//     très grande police dans Android, la mise en page ne déborde plus
//     ("Bottom overflowed by … pixels").
//   • La base passe en version 2 : la migration s'exécute toute seule au
//     premier lancement après la mise à jour (aucune donnée perdue).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:gestock_pos/core/database/database_helper.dart';
import 'package:gestock_pos/core/settings/app_settings.dart';
import 'package:gestock_pos/core/theme/app_colors.dart';
import 'package:gestock_pos/core/theme/app_theme.dart';
import 'package:gestock_pos/features/home/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');

  // Barre d'état claire avec icônes foncées (assortie au thème clair)
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.surface,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  // Ouvre la base ; en v2, onUpgrade ajoute les nouvelles colonnes si besoin.
  await DatabaseHelper.instance.database;

  // Étape 2b : charge les réglages (point de vente, options, ticket…)
  await AppSettings.instance.charger();

  runApp(const GestockApp());
}

class GestockApp extends StatelessWidget {
  const GestockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeStock POS',
      debugShowCheckedModeBanner: false,

      // Thème clair UNIQUEMENT
      theme: AppTheme.clair,
      themeMode: ThemeMode.light,

      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR'), Locale('ar', 'DZ')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // Limite l'agrandissement du texte système pour éviter les débordements
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.15)),
          child: child!,
        );
      },

      home: const HomeShell(),
    );
  }
}
