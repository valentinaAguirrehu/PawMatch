package com.example.paw_match

import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "paw_match/whatsapp")
            .setMethodCallHandler { call, result ->
                if (call.method != "compartirPdf") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val bytes = call.argument<ByteArray>("bytes")
                val nombre = call.argument<String>("nombre") ?: "acta.pdf"
                val mensaje = call.argument<String>("mensaje") ?: ""
                if (bytes == null) {
                    result.error("sin_pdf", "No hay PDF para compartir", null)
                    return@setMethodCallHandler
                }
                try {
                    result.success(compartirPdfPorWhatsApp(bytes, nombre, mensaje))
                } catch (e: Exception) {
                    result.error("whatsapp", e.message, null)
                }
            }
    }

    /// Abre WhatsApp con el PDF ya adjunto. Si no está instalado, muestra el menú para enviarlo.
    private fun compartirPdfPorWhatsApp(bytes: ByteArray, nombre: String, mensaje: String): Boolean {
        val seguro = nombre.replace(Regex("[^a-zA-Z0-9._-]"), "_")
        val carpeta = File(cacheDir, "actas")
        if (!carpeta.exists()) carpeta.mkdirs()
        val archivo = File(carpeta, seguro)
        archivo.writeBytes(bytes)

        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", archivo)
        val enviar = Intent(Intent.ACTION_SEND).apply {
            type = "application/pdf"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_TEXT, mensaje)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        var paqueteWhatsapp: String? = null
        for (paquete in listOf("com.whatsapp", "com.whatsapp.w4b")) {
            enviar.setPackage(paquete)
            if (enviar.resolveActivity(packageManager) != null) {
                paqueteWhatsapp = paquete
                break
            }
        }

        if (paqueteWhatsapp == null) {
            enviar.setPackage(null)
            startActivity(Intent.createChooser(enviar, "Compartir acta"))
            return false
        }

        enviar.setPackage(paqueteWhatsapp)
        startActivity(enviar)
        return true
    }
}
