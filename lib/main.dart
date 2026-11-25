import 'package:flutter/foundation.dart';
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
      builder: (context, child) => VistaEstableWeb(
        child: child ?? const SizedBox.shrink(),
      ),
      home: const SesionShell(),
    );
  }
}

/// En el celular, Chrome a veces informa la barra del navegador como si
/// fuera el teclado. Eso sube toda la pantalla y deja el menú encima.
/// Solo se respeta ese espacio cuando la persona está escribiendo.
class VistaEstableWeb extends StatelessWidget {
  final Widget child;

  const VistaEstableWeb({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;
    return ListenableBuilder(
      listenable: FocusManager.instance,
      builder: (context, _) {
        final media = MediaQuery.of(context);
        if (_estaEscribiendo() || media.viewInsets.bottom == 0) return child;
        return MediaQuery(
          data: media.copyWith(viewInsets: EdgeInsets.zero),
          child: child,
        );
      },
    );
  }

  bool _estaEscribiendo() {
    final contexto = FocusManager.instance.primaryFocus?.context;
    if (contexto == null) return false;
    return contexto.widget is EditableText ||
        contexto.findAncestorStateOfType<EditableTextState>() != null;
  }
}
