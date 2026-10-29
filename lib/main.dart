import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:paw_match/core/app_theme.dart';
import 'package:paw_match/core/navegacion.dart';
import 'package:paw_match/screens/sesion_shell.dart';
import 'package:paw_match/services/camara_escritorio.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configurarCamaraEscritorio();
  await initializeDateFormatting('es_ES', null);
  runApp(const PawMatchApp());
}

class PawMatchApp extends StatelessWidget {
  const PawMatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paw Match',
      navigatorKey: navegadorRaiz,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('es', 'ES'),
      supportedLocales: const [
        Locale('es', 'ES'),
        Locale('es', ''),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SesionShell(),
    );
  }
}
