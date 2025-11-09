// lib/http_override.dart

import 'dart:io';

// ADVERTENCIA: ¡NO USAR EN PRODUCCIÓN!
// Esto le dice a la app que confíe en CUALQUIER certificado SSL.
// Solo debe usarse para desarrollo con servidores que usan certificados auto-firmados.
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}
