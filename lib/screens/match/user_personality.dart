import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/rasgos.dart';
import 'package:paw_match/screens/home/menu_screen.dart';
import 'package:paw_match/services/match_estado.dart';
import 'package:paw_match/services/personalidad_usuario_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/cuestionario_usuario.dart';

/// Tras iniciar sesión o registrarse: el cuestionario es obligatorio solo
/// cuando ese usuario todavía no tiene fila en `personalidadusuario`.
Future<void> abrirDestinoTrasAuth(BuildContext context) async {
  final id = Session.idUsuario;
  var mostrarCuestionario = false;
  // El administrador no responde el cuestionario: va directo al menú.
  if (!Session.isAdmin && id != null && id.isNotEmpty) {
    try {
      mostrarCuestionario = !await PersonalidadUsuarioService.existe(id);
    } catch (_) {
      mostrarCuestionario = true;
    }
  }
  if (!context.mounted) return;
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(
      builder: (_) => mostrarCuestionario
          ? const UserPersonalityScreen()
          : const MenuScreen(),
    ),
    (_) => false,
  );
}

class UserPersonalityScreen extends StatefulWidget {
  const UserPersonalityScreen({super.key});

  @override
  State<UserPersonalityScreen> createState() => _UserPersonalityScreenState();
}

class _UserPersonalityScreenState extends State<UserPersonalityScreen> {
  final Map<String, double> _valores = {
    for (final r in rasgosMascota) r.clave: 3,
  };

  bool _guardando = false;

  double _valorDe(String clave) => _valores[clave] ?? 3;

  Future<void> _guardar() async {
    final valores = {
      for (final r in rasgosMascota) r.clave: _valorDe(r.clave).round(),
    };
    setState(() => _guardando = true);
    try {
      await PersonalidadUsuarioService.guardar(valores);
      MatchEstado.instancia.publicar(valores);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => MenuScreen(indiceInicial: MenuScreen.indiceMatch),
        ),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.blanco,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const EncabezadoCuestionarioUsuario(),
                          const SizedBox(height: 18),
                          for (final r in rasgosMascota)
                            TarjetaRasgoUsuario(
                              rasgo: r,
                              valor: _valorDe(r.clave),
                              onChanged: _guardando
                                  ? null
                                  : (v) => setState(() => _valores[r.clave] = v),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _barraGuardar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barraGuardar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.blanco,
        border: Border(top: BorderSide(color: AppColors.bordeRosa)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: FilledButton(
            onPressed: _guardando ? null : _guardar,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: _guardando
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.blanco,
                    ),
                  )
                : const Text('Guardar y continuar'),
          ),
        ),
      ),
    );
  }
}
