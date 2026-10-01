import 'package:flutter/material.dart';

// Permite que una pantalla se entere cuando vuelve a quedar visible
// (por ejemplo, al volver de registrar/editar/eliminar algo), para
// refrescar sus datos sin depender de que cada pantalla anterior le
// avise "manualmente" con un valor de retorno.
final RouteObserver<PageRoute<dynamic>> routeObserver = RouteObserver<PageRoute<dynamic>>();
