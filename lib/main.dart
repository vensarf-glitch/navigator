import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:web/web.dart' as web;

const _mapViewType = 'yandex-map-surface';
const _yandexMapsApiKey = String.fromEnvironment('YANDEX_MAPS_API_KEY');

@JS('navigatorMapInit')
external void _navigatorMapInit(
  JSString containerId,
  JSString apiKey,
  JSFunction onSelect,
  JSFunction onReady,
  JSFunction onError,
);

@JS('navigatorMapLocate')
external void _navigatorMapLocate(JSFunction onSuccess, JSFunction onError);

@JS('navigatorMapSetOrigin')
external void _navigatorMapSetOrigin(JSNumber latitude, JSNumber longitude);

@JS('navigatorMapSetDestination')
external void _navigatorMapSetDestination(
    JSNumber latitude, JSNumber longitude);

@JS('navigatorMapBuildRoute')
external void _navigatorMapBuildRoute(
  JSNumber fromLatitude,
  JSNumber fromLongitude,
  JSNumber toLatitude,
  JSNumber toLongitude,
  JSFunction onResult,
);

double _asDouble(JSAny? value) => (value as JSNumber).toDartDouble;
String _asString(JSAny? value) => (value as JSString).toDart;

void main() {
  runApp(const NavigatorApp());
}

class NavigatorApp extends StatelessWidget {
  const NavigatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Навигатор',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Manrope',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF176B5B),
          primary: const Color(0xFF176B5B),
          secondary: const Color(0xFFE7654B),
          surface: const Color(0xFFFFFEFA),
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F2EC),
      ),
      home: const NavigatorScreen(),
    );
  }
}

class NavigatorScreen extends StatefulWidget {
  const NavigatorScreen({super.key});

  @override
  State<NavigatorScreen> createState() => _NavigatorScreenState();
}

class _NavigatorScreenState extends State<NavigatorScreen> {
  static bool _viewFactoryRegistered = false;

  _MapPoint? _origin;
  _MapPoint? _destination;
  _RouteSummary? _route;
  bool _mapReady = false;
  bool _findingLocation = false;
  bool _buildingRoute = false;
  String? _mapError;

  @override
  void initState() {
    super.initState();
    if (!_viewFactoryRegistered) {
      ui_web.platformViewRegistry.registerViewFactory(_mapViewType, (viewId) {
        final mapContainer =
            web.document.createElement('div') as web.HTMLDivElement
              ..id = 'yandex-map-$viewId'
              ..style.width = '100%'
              ..style.height = '100%';

        scheduleMicrotask(() {
          if (_yandexMapsApiKey.isEmpty) return;
          _navigatorMapInit(
            mapContainer.id.toJS,
            _yandexMapsApiKey.toJS,
            ((JSAny? latitude, JSAny? longitude) =>
                _onMapTap(_asDouble(latitude), _asDouble(longitude))).toJS,
            _onMapReady.toJS,
            ((JSAny? message) => _onMapError(_asString(message))).toJS,
          );
        });
        return mapContainer;
      });
      _viewFactoryRegistered = true;
    }
  }

  void _onMapReady() {
    if (mounted) setState(() => _mapReady = true);
  }

  void _onMapError(String message) {
    if (mounted) setState(() => _mapError = message);
  }

  void _onMapTap(double latitude, double longitude) {
    final point = _MapPoint(latitude, longitude);
    setState(() {
      _destination = point;
      _route = null;
    });
    _navigatorMapSetDestination(point.latitude.toJS, point.longitude.toJS);
  }

  void _findLocation() {
    if (!_mapReady || _findingLocation) return;
    setState(() => _findingLocation = true);
    _navigatorMapLocate(
      ((JSAny? latitude, JSAny? longitude) =>
          _onLocationFound(_asDouble(latitude), _asDouble(longitude))).toJS,
      ((JSAny? message) => _onLocationError(_asString(message))).toJS,
    );
  }

  void _onLocationFound(double latitude, double longitude) {
    if (!mounted) return;
    final point = _MapPoint(latitude, longitude);
    setState(() {
      _origin = point;
      _findingLocation = false;
      _route = null;
    });
    _navigatorMapSetOrigin(point.latitude.toJS, point.longitude.toJS);
  }

  void _onLocationError(String message) {
    if (!mounted) return;
    setState(() => _findingLocation = false);
    _showMessage(message);
  }

  void _buildRoute() {
    final origin = _origin;
    final destination = _destination;
    if (!_mapReady || origin == null || destination == null || _buildingRoute)
      return;

    setState(() {
      _buildingRoute = true;
      _route = null;
    });
    _navigatorMapBuildRoute(
      origin.latitude.toJS,
      origin.longitude.toJS,
      destination.latitude.toJS,
      destination.longitude.toJS,
      ((JSAny? duration, JSAny? distance, JSAny? error) => _onRouteBuilt(
            _asString(duration),
            _asString(distance),
            _asString(error),
          )).toJS,
    );
  }

  void _onRouteBuilt(String duration, String distance, String error) {
    if (!mounted) return;
    setState(() {
      _buildingRoute = false;
      _route = error.isEmpty ? _RouteSummary(duration, distance) : null;
    });
    if (error.isNotEmpty) _showMessage('Не удалось построить маршрут: $error');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const HtmlElementView(viewType: _mapViewType),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: PointerInterceptor(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 76, 0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFEFA),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x260F211D),
                        blurRadius: 18,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.navigation, color: Color(0xFF176B5B)),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Маршрут',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          Text(
                            'ЯНДЕКС КАРТЫ',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: const Color(0xFF74766F),
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: 90,
            child: SafeArea(
              bottom: false,
              child: PointerInterceptor(
                child: FloatingActionButton.small(
                  heroTag: 'my_location',
                  tooltip: 'Моё местоположение',
                  onPressed:
                      _mapReady && !_findingLocation ? _findLocation : null,
                  backgroundColor: const Color(0xFFFFFEFA),
                  foregroundColor: const Color(0xFF176B5B),
                  child: _findingLocation
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                ),
              ),
            ),
          ),
          if (_yandexMapsApiKey.isEmpty || _mapError != null)
            Positioned(
              left: 16,
              right: 16,
              top: 90,
              child: PointerInterceptor(
                child: _MapNotice(
                  message: _mapError ??
                      'Добавьте API-ключ Яндекс Карт для загрузки карты.',
                ),
              ),
            ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: PointerInterceptor(
                    child: _RoutePanel(
                      hasOrigin: _origin != null,
                      hasDestination: _destination != null,
                      isBuildingRoute: _buildingRoute,
                      isMapReady: _mapReady,
                      route: _route,
                      onBuildRoute: _buildRoute,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutePanel extends StatelessWidget {
  const _RoutePanel({
    required this.hasOrigin,
    required this.hasDestination,
    required this.isBuildingRoute,
    required this.isMapReady,
    required this.route,
    required this.onBuildRoute,
  });

  final bool hasOrigin;
  final bool hasDestination;
  final bool isBuildingRoute;
  final bool isMapReady;
  final _RouteSummary? route;
  final VoidCallback onBuildRoute;

  @override
  Widget build(BuildContext context) {
    final ready = isMapReady && hasOrigin && hasDestination && !isBuildingRoute;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEFA),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x260F211D),
            blurRadius: 24,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trip_origin, size: 18, color: Color(0xFF176B5B)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasOrigin
                      ? 'Моё местоположение'
                      : 'Определите точку отправления',
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasOrigin)
                const Icon(Icons.check_circle,
                    size: 18, color: Color(0xFF176B5B)),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: SizedBox(
              height: 18,
              child: VerticalDivider(
                  width: 1, thickness: 1, color: Color(0xFFD9D8D0)),
            ),
          ),
          Row(
            children: [
              const Icon(Icons.location_on, size: 20, color: Color(0xFFE7654B)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasDestination
                      ? 'Точка на карте'
                      : 'Нажмите на карту, чтобы выбрать финиш',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: hasDestination ? null : const Color(0xFF74766F),
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasDestination)
                const Icon(Icons.check_circle,
                    size: 18, color: Color(0xFF176B5B)),
            ],
          ),
          if (route != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 13),
              child: Divider(height: 1, color: Color(0xFFE7E5DD)),
            ),
            Row(
              children: [
                const Icon(Icons.schedule, size: 18, color: Color(0xFF176B5B)),
                const SizedBox(width: 7),
                Text(
                  route!.duration,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(width: 18),
                const Icon(Icons.route, size: 18, color: Color(0xFF74766F)),
                const SizedBox(width: 7),
                Text(route!.distance),
              ],
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: ready ? onBuildRoute : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE7654B),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE8E5DC),
                disabledForegroundColor: const Color(0xFF93938C),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              icon: isBuildingRoute
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.alt_route),
              label: Text(
                  isBuildingRoute ? 'Строим маршрут' : 'Построить маршрут'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapNotice extends StatelessWidget {
  const _MapNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFFEFA),
      borderRadius: BorderRadius.circular(8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}

class _MapPoint {
  const _MapPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

class _RouteSummary {
  const _RouteSummary(this.duration, this.distance);

  final String duration;
  final String distance;
}
