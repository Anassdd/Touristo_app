import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'graph.dart';
import 'algorithm.dart'; // import your algorithm file

void main() {
  runApp(const MyApp());
}

String TOKEN =
    'pk.eyJ1IjoiYW5hc3NhaWQiLCJhIjoiY21iaHRwZWFhMDFhYTJscjAxN2J1aGdqcSJ9.DuvzVIBDrYLB0-se6FhOxg';

// main application widget
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MainApp(),
    );
  }
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});
  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  //VARIABLES
  bool returnToStart = true;
  bool useOptimalTSP = false;
  Set<dynamic> selectedMuseumIds = {};
  int _nextStopIndexToFill = 0;
  double? routeDistance;
  double? routeDuration;
  List<TextEditingController> stopControllers = [];
  List<FocusNode> stopFocusNodes = [];
  List<dynamic> stopIds = [];
  List<LatLng?> stopLatLngs = [];
  List<GraphNode?> intermediateStops = [];
  final DraggableScrollableController _draggableController =
      DraggableScrollableController();
  double _sheetExtent = 0.3;
  bool showResetButton = true;
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final FocusNode _fromFocus = FocusNode();
  final FocusNode _toFocus = FocusNode();
  final MapController _mapController = MapController();

  Graph? graph;
  List<GraphNode> museums = [];
  String currentTyping = '';
  bool isTypingTo = false;

  LatLng? _fromLatLng;
  LatLng? _toLatLng;
  LatLng? _customDepartureLatLng;
  dynamic _fromId;
  dynamic _toId;

  List<LatLng> routePoints = [];

  String selectedAlgorithm = 'Dijkstra (Tas)';

  // FUNCTIONS OR METHODES

  @override
  void initState() {
    super.initState();
    loadGraphData();
    _draggableController.addListener(() {
      setState(() {
        _sheetExtent = _draggableController.size;
        showResetButton = _sheetExtent < 0.5;
      });
    });
  }

  void addStopField() {
    setState(() {
      stopControllers.add(TextEditingController());
      stopFocusNodes.add(FocusNode());
      stopIds.add(null);
      stopLatLngs.add(null);
    });
  }

  List<LatLng> getAllSelectedPoints() {
    final points = <LatLng>[];

    if (_fromLatLng != null) points.add(_fromLatLng!);
    for (final stop in stopLatLngs) {
      if (stop != null) points.add(stop);
    }
    if (_toLatLng != null) points.add(_toLatLng!);

    return points;
  }

  // transforme le json à un graphe et creation de liste des musées
  Future<void> loadGraphData() async {
    final g = await loadGraphFromJson('assets/paris_walk_graph.json');
    final museumList = g.nodes.values
        .where((n) => n.type == 'museum' && n.name != null)
        .toList();

    setState(() {
      graph = g;
      museums = museumList;
    });
  }

  // ========================================================== Recherche et selection de Musée dans le TextEditor =======================================================

  // filtre et cherche le nom de musée lors d'ecriture du nom de musée
  List<GraphNode> get filteredMuseums {
    return museums
        .where(
          (m) => m.name!.toLowerCase().contains(currentTyping.toLowerCase()),
        )
        .toList();
  }

  // mis a jour de typing
  void onChanged(String value, bool isToField, [int? stopIndex]) {
    setState(() {
      isTypingTo = isToField;
      currentTyping = value;
    });
  }

  void onSuggestionTap(GraphNode museum, [int? stopIndex]) {
    setState(() {
      final latLng = LatLng(museum.lat, museum.lon);
      selectedMuseumIds.add(museum.id);
      if (stopIndex != null) {
        stopControllers[stopIndex].text = museum.name!;
        stopLatLngs[stopIndex] = latLng;
        stopIds[stopIndex] = museum.id;
        stopFocusNodes[stopIndex].unfocus();
      } else if (isTypingTo) {
        _toController.text = museum.name!;
        _toLatLng = latLng;
        _toId = museum.id;
        _toFocus.unfocus();
      } else {
        _fromController.text = museum.name!;
        _fromLatLng = latLng;
        _fromId = museum.id;
        _fromFocus.unfocus();
      }
      currentTyping = '';
      _fitMapToSelectedMuseums();
      _mapController.move(latLng, 15);
    });
  }

  // ========================================================== Reset Selection Button =======================================================
  void resetSelections() {
    setState(() {
      _nextStopIndexToFill = 0;
      _fromController.clear();
      _toController.clear();
      _customDepartureLatLng = null;
      _fromLatLng = null;
      _toLatLng = null;
      _fromId = null;
      _toId = null;

      //  Clear all stop-related data
      stopControllers.clear();
      stopFocusNodes.clear();
      stopLatLngs.clear();
      stopIds.clear();
      intermediateStops.clear();

      selectedMuseumIds.clear(); // optional: clears all visual selections
      routePoints.clear();
      routeDistance = null;
      routeDuration = null;
      currentTyping = '';

      _animateMapTo(
        LatLng(48.8566, 2.3522), // center of Paris
        13,
      );
    });
  }

  double _calculateZoomFromBounds(LatLngBounds bounds, Size screenSize) {
    const WORLD_DIM = 256.0; // Tile size
    const ZOOM_MAX = 18;

    final latFraction = (latRad(bounds.north) - latRad(bounds.south)) / math.pi;
    final lngDiff = bounds.east - bounds.west;
    final lngFraction = ((lngDiff < 0 ? (lngDiff + 360) : lngDiff) / 360).clamp(
      0,
      1,
    );

    final latZoom =
        (math.log(screenSize.height / WORLD_DIM / latFraction) / math.ln2);
    final lngZoom =
        (math.log(screenSize.width / WORLD_DIM / lngFraction) / math.ln2);

    return math.min(latZoom, lngZoom).clamp(0, ZOOM_MAX).toDouble();
  }

  double latRad(double lat) {
    final sin = math.sin(lat * math.pi / 180);
    final radX2 = math.log((1 + sin) / (1 - sin)) / 2;
    return radX2.clamp(-math.pi, math.pi);
  }

  void _animateMapTo(LatLng targetCenter, double targetZoom) async {
    // smoothly animate the map to the targetcenter lat and long, with zoom level
    const int steps = 30;

    const Duration stepDuration = Duration(milliseconds: 16); // ~60fps

    final currentCenter = _mapController.camera.center;
    final currentZoom = _mapController.camera.zoom;

    for (int i = 1; i <= steps; i++) {
      final t = i / steps;

      final lat = _lerp(currentCenter.latitude, targetCenter.latitude, t);
      final lon = _lerp(currentCenter.longitude, targetCenter.longitude, t);
      final zoom = _lerp(currentZoom, targetZoom, t);

      _mapController.move(LatLng(lat, lon), zoom);
      await Future.delayed(stepDuration);
    }
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;
  // ========================================================== Selection et appeld'algorithme =======================================================
  // DEBUG VERSION, wiht prints
  void computeRoute() {
    if (graph == null || _fromId == null || _toId == null) {
      print(' Missing data: graph or selected nodes are null');
      return;
    }

    final stops = stopIds.whereType<dynamic>().toList();

    List<LatLng> points = [];
    double totalDistance = 0.0;

    if (stops.isNotEmpty) {
      // ==== TSP Case ====
      final result = useOptimalTSP
          ? voyageurOptimal(
              graph!,
              _fromId,
              stops,
              destination: _toId,
              returnToStart: returnToStart,
            )
          : voyageurRapide(
              graph!,
              _fromId,
              stops,
              destination: _toId,
              returnToStart: returnToStart,
            );
      final path = result['chemin'] as List<dynamic>;

      for (int i = 0; i < path.length - 1; i++) {
        final segmentResult = Aetoile(graph!, path[i], path[i + 1]);
        final subPath = chemin(
          path[i],
          path[i + 1],
          segmentResult['predecesseurs']!,
        );

        if (subPath.length < 2) continue;

        for (int j = 0; j < subPath.length - 1; j++) {
          final nodeA = graph!.getNode(subPath[j])!;
          final nodeB = graph!.getNode(subPath[j + 1])!;
          final edge = graph!
              .neighbors(nodeA.id)
              .firstWhere(
                (e) => e.target == nodeB.id,
                orElse: () => throw Exception(
                  'Arc manquant entre ${nodeA.id} et ${nodeB.id}',
                ),
              );
          totalDistance += edge.length / 1000; // convertir m → km

          points.add(LatLng(nodeA.lat, nodeA.lon));
        }

        // Add last point of segment
        if (subPath.isNotEmpty) {
          final lastNode = graph!.getNode(subPath.last)!;
          points.add(LatLng(lastNode.lat, lastNode.lon));
        }
      }

      print('TSP Distance: ${totalDistance.toStringAsFixed(2)} km');
    } else {
      // ==== Normal shortest path ====
      print(' From ID: $_fromId');
      print(' To ID: $_toId');
      print(' Algorithm: $selectedAlgorithm');

      Map<String, Map<dynamic, dynamic>> result;
      if (selectedAlgorithm == 'Dijkstra (Tas)') {
        result = dijkstraAvecTas(graph!, _fromId);
      } else if (selectedAlgorithm == 'Dijkstra (Sans Tas)') {
        result = dijkstraSansTas(graph!, _fromId);
      } else if (selectedAlgorithm == 'Bellman-Ford') {
        result = bellmanFord(graph!, _fromId);
      } else {
        result = Aetoile(graph!, _fromId, _toId);
      }

      final path = chemin(_fromId, _toId, result['predecesseurs']!);
      print('chemin (path) IDs: $path');

      for (int i = 0; i < path.length - 1; i++) {
        final fromId = path[i];
        final toId = path[i + 1];

        final edge = graph!
            .neighbors(fromId)
            .firstWhere(
              (e) => e.target == toId,
              orElse: () =>
                  throw Exception('Arc manquant entre $fromId et $toId'),
            );

        totalDistance += edge.length / 1000; // convertir mètres → km

        final nodeA = graph!.getNode(fromId)!;
        points.add(LatLng(nodeA.lat, nodeA.lon));
      }
      if (path.isNotEmpty) {
        final lastNode = graph!.getNode(path.last)!;
        points.add(LatLng(lastNode.lat, lastNode.lon));
      }

      print(' Distance: ${totalDistance.toStringAsFixed(2)} km');
    }

    // ==== Affichage unifié ====
    final estimatedTime = totalDistance / 5 * 60;

    setState(() {
      routePoints = points;
      routeDistance = totalDistance;
      routeDuration = estimatedTime;

      final allPoints = getAllSelectedPoints();
      if (allPoints.length > 1) {
        final bounds = LatLngBounds.fromPoints(allPoints);
        final center = bounds.center;
        final zoomLevel = _calculateZoomFromBounds(
          bounds,
          MediaQuery.of(context).size,
        );

        _draggableController.animateTo(
          0.2,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );

        _animateMapTo(center, zoomLevel);
        _fitMapToSelectedMuseums();
      }
    });

    print('Final Distance: ${totalDistance.toStringAsFixed(2)} km');
    print('Estimated Time: ${estimatedTime.toStringAsFixed(1)} min');
  } //   if (graph == null || _fromId == null || _toId == null) {
  //     print(' Missing data: graph or selected nodes are null');
  //     return;
  //   }

  //   // DEBUG PRINTS
  //   print(' From ID: $_fromId');
  //   print(' To ID: $_toId');
  //   print(' Algorithm: $selectedAlgorithm');

  //   // appel de l'algorithme choisi
  //   Map<String, Map<dynamic, dynamic>> result;
  //   if (selectedAlgorithm == 'Dijkstra (Tas)') {
  //     result = dijkstraAvecTas(graph!, _fromId);
  //   } else if (selectedAlgorithm == 'Dijkstra (Sans Tas)') {
  //     result = dijkstraSansTas(graph!, _fromId);
  //   } else if (selectedAlgorithm == 'Bellman-Ford') {
  //     result = bellmanFord(graph!, _fromId);
  //   } else {
  //     result = Aetoile(graph!, _fromId, _toId);
  //   }
  //   // calcul du chemin
  //   final path = chemin(_fromId, _toId, result['predecesseurs']!);
  //   // DEBUG PRINTS
  //   print('chemin (path) IDs: $path');

  //   final distanceMap = result['distances']!;
  //   var totalDistance = distanceMap[_toId] / 1000 ?? 0.0;
  //   List<LatLng> points = [];

  //   for (int i = 0; i < path.length - 1; i++) {
  //     final nodeA = graph!.getNode(path[i])!;
  //     final nodeB = graph!.getNode(path[i + 1])!;
  //     totalDistance += Distance().as(
  //       LengthUnit.Kilometer,
  //       LatLng(nodeA.lat, nodeA.lon),
  //       LatLng(nodeB.lat, nodeB.lon),
  //     );
  //     points.add(LatLng(nodeA.lat, nodeA.lon));
  //   }

  //   // Add last point
  //   if (path.isNotEmpty) {
  //     final lastNode = graph!.getNode(path.last)!;
  //     points.add(LatLng(lastNode.lat, lastNode.lon));
  //   }

  //   final estimatedTime =
  //       totalDistance / 5 * 60; // assuming 5km/h walking speed

  //   setState(() {
  //     routePoints = path.map((id) {
  //       final node = graph!.getNode(id);
  //       return LatLng(node!.lat, node.lon);
  //     }).toList();
  //     routeDistance = totalDistance;
  //     routeDuration = estimatedTime;
  //     final allPoints = getAllSelectedPoints();
  //     if (allPoints.length > 1) {
  //       final bounds = LatLngBounds.fromPoints(allPoints);
  //       final center = bounds.center;
  //       final zoomLevel = _calculateZoomFromBounds(
  //         bounds,
  //         MediaQuery.of(context).size,
  //       );

  //       _draggableController.animateTo(
  //         0.2,
  //         duration: const Duration(milliseconds: 500),
  //         curve: Curves.easeOut,
  //       );

  //       _animateMapTo(center, zoomLevel);
  //       _fitMapToSelectedMuseums();
  //     }
  //   });

  //   print(' Distance: ${totalDistance.toStringAsFixed(2)} km');
  //   print(' Time: ${estimatedTime.toStringAsFixed(1)} min');
  // }

  void _fitMapToSelectedMuseums() {
    final points = <LatLng>[];

    if (_fromLatLng != null) points.add(_fromLatLng!);
    for (final stop in stopLatLngs) {
      if (stop != null) points.add(stop);
    }
    if (_toLatLng != null) points.add(_toLatLng!);

    if (points.length < 2) return;

    final bounds = LatLngBounds.fromPoints(points);
    final center = bounds.center;
    final zoom = _calculateZoomFromBounds(bounds, MediaQuery.of(context).size);

    _animateMapTo(center, zoom);
  }

  void _handleCustomDeparture(LatLng latLng) {
    if (graph == null) return;

    const customId = 'custom_departure';
    final nearestNode = graph!.findNearestNode(
      latLng.latitude,
      latLng.longitude,
    );
    if (nearestNode == null) return;

    final customNode = GraphNode(
      id: customId,
      lat: latLng.latitude,
      lon: latLng.longitude,
      name: 'Custom Location',
      type: 'custom',
    );

    final distance = Distance().as(
      LengthUnit.Meter,
      latLng,
      LatLng(nearestNode.lat, nearestNode.lon),
    );

    setState(() {
      _customDepartureLatLng = latLng;
      _fromLatLng = latLng;
      _fromId = customId;

      _fromController.text = 'Custom Location'; // THIS LINE FIXES THE UI

      graph!.addNode(customNode);
      graph!.addEdge(
        GraphEdge(source: customId, target: nearestNode.id, length: distance),
      );
      graph!.addEdge(
        GraphEdge(source: nearestNode.id, target: customId, length: distance),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(48.8566, 2.3522),
              initialZoom: 13,
              onTap: (tapPosition, latLng) {
                _handleCustomDeparture(latLng);
              },
            ),
            children: [
              // visual background layer
              TileLayer(
                urlTemplate:
                    'https://api.mapbox.com/styles/v1/{id}/tiles/256/{z}/{x}/{y}@2x?access_token={accessToken}',
                additionalOptions: {
                  'accessToken': TOKEN,
                  'id': 'mapbox/streets-v11',
                },
              ),
              MarkerLayer(
                markers: [
                  if (_customDepartureLatLng != null)
                    Marker(
                      point: _customDepartureLatLng!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.transparent,
                        size: 40,
                      ),
                    ),
                  if (_fromLatLng == null || _toLatLng == null)
                    ...museums.map((m) {
                      final isSelected =
                          m.id == _fromId ||
                          m.id == _toId ||
                          stopIds.contains(m.id);
                      return Marker(
                        width: isSelected ? 50 : 30,
                        height: isSelected ? 50 : 30,
                        point: LatLng(m.lat, m.lon),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              final tappedLatLng = LatLng(m.lat, m.lon);
                              selectedMuseumIds.add(m.id);
                              // Fill FROM if not yet selected
                              if (_fromLatLng == null) {
                                _fromLatLng = tappedLatLng;
                                _fromId = m.id;
                                _fromController.text = m.name!;
                              }
                              // Fill STOP if any stops are unfilled
                              else if (_nextStopIndexToFill <
                                  stopControllers.length) {
                                stopLatLngs[_nextStopIndexToFill] =
                                    tappedLatLng;
                                stopIds[_nextStopIndexToFill] = m.id;
                                stopControllers[_nextStopIndexToFill].text =
                                    m.name!;
                                _nextStopIndexToFill++;
                              }
                              // Fill TO if not yet selected
                              else if (_toLatLng == null) {
                                _toLatLng = tappedLatLng;
                                _toId = m.id;
                                _toController.text = m.name!;
                              }
                            });
                          },
                          child: Icon(
                            Icons.location_on,
                            color: isSelected
                                ? const Color.fromARGB(255, 15, 14, 89)
                                : const Color.fromARGB(255, 15, 14, 83),
                            size: isSelected ? 40 : 26,
                          ),
                        ),
                      );
                    }),
                  if (_fromLatLng != null)
                    Marker(
                      width: 45,
                      height: 45,
                      point: _fromLatLng!,
                      // ICON DE DEPART
                      child: const Icon(
                        Icons.my_location,
                        color: Color.fromARGB(255, 36, 36, 36),
                        size: 30,
                      ),
                    ),
                  if (_toLatLng != null)
                    Marker(
                      width: 45,
                      height: 45,
                      point: _toLatLng!,
                      // ICON D'ARRIVEE
                      child: const Icon(
                        Icons.location_pin,
                        color: Color.fromARGB(255, 36, 36, 36),
                        size: 40,
                      ),
                    ),
                  // Show STOP markers even after both FROM and TO are selected
                  ...stopLatLngs
                      .asMap()
                      .entries
                      .where((e) => e.value != null)
                      .map((entry) {
                        final index = entry.key;
                        final latLng = entry.value!;
                        return Marker(
                          width: 40,
                          height: 40,
                          point: latLng,
                          child: Container(
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,

                              color: Color.fromARGB(255, 26, 55, 117),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }),
                ],
              ),

              if (routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      strokeWidth: 5,
                      color: const Color.fromARGB(155, 27, 39, 98),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            top: 40,
            right: 20,
            child: Visibility(
              visible: _sheetExtent > 0.35, // Show only when sheet is up
              child: FloatingActionButton(
                mini: true,
                heroTag: 'collapse_sheet',
                backgroundColor: Colors.white,
                onPressed: () {
                  _draggableController.animateTo(
                    0.2,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                  );
                },
                child: const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: _sheetExtent * MediaQuery.of(context).size.height + 20,
            right: 20,
            child: Visibility(
              visible: showResetButton,
              child: Row(
                children: [
                  FloatingActionButton(
                    heroTag: 'addStopLeft',
                    backgroundColor: Colors.white,
                    mini: true,
                    onPressed: addStopField,
                    child: const Icon(
                      Icons.add_location_alt,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Calculate Button
                  FloatingActionButton(
                    heroTag: 'calculate',
                    backgroundColor: Colors.black,
                    mini: true,
                    onPressed: computeRoute,
                    child: const Icon(Icons.route, color: Colors.white),
                  ),
                  const SizedBox(width: 10),

                  // Reset Button
                  FloatingActionButton(
                    heroTag: 'reset',
                    backgroundColor: Colors.white,
                    mini: true,
                    onPressed: resetSelections,
                    child: const Icon(Icons.refresh, color: Colors.black),
                  ),
                ],
              ),
            ),
          ),
          if (routeDistance != null && routeDuration != null)
            Positioned(
              top: 70,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${routeDistance!.toStringAsFixed(2)} km',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${routeDuration!.toStringAsFixed(0)} min',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          // Bottom Sheet
          DraggableScrollableSheet(
            controller: _draggableController,
            initialChildSize: 0.3,
            minChildSize: 0.2,
            maxChildSize: 0.9,
            builder: (_, scrollController) => Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  const Text(
                    "Choisir l'Algorithme:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  DropdownButton<String>(
                    iconEnabledColor: Colors.black, // Icon color
                    dropdownColor: Colors.white,
                    value: selectedAlgorithm,
                    isExpanded: true,
                    onChanged: (value) =>
                        setState(() => selectedAlgorithm = value!),
                    items: const [
                      DropdownMenuItem(
                        value: 'Dijkstra (Tas)',
                        child: Text('Dijkstra (Tas)'),
                      ),
                      DropdownMenuItem(
                        value: 'Dijkstra (Sans Tas)',
                        child: Text('Dijkstra (Sans Tas)'),
                      ),
                      DropdownMenuItem(
                        value: 'Bellman-Ford',
                        child: Text('Bellman-Ford'),
                      ),
                      DropdownMenuItem(
                        value: 'A*',
                        child: Text('A* (A étoile)'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // === FROM FIELD ===
                  TextField(
                    controller: _fromController,
                    focusNode: _fromFocus,
                    onChanged: (v) => onChanged(v, false),
                    decoration: const InputDecoration(
                      labelText: 'Départ',
                      prefixIcon: Icon(Icons.my_location),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // === STOPS FIELD LIST ===
                  ...List.generate(stopControllers.length, (i) {
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: stopControllers[i],
                                focusNode: stopFocusNodes[i],
                                onChanged: (v) => onChanged(v, false, i),
                                decoration: InputDecoration(
                                  labelText: 'Stop ${i + 1}',
                                  prefixIcon: const Icon(
                                    Icons.stop_circle_outlined,
                                  ),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  stopControllers.removeAt(i);
                                  stopFocusNodes.removeAt(i);
                                  stopLatLngs.removeAt(i);
                                  stopIds.removeAt(i);
                                });
                              },
                              icon: const Icon(
                                Icons.delete_forever,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        if (currentTyping.isNotEmpty)
                          ...filteredMuseums.map(
                            (m) => ListTile(
                              title: Text(m.name!),
                              onTap: () => onSuggestionTap(m, i),
                            ),
                          ),
                        const SizedBox(height: 12),
                      ],
                    );
                  }),

                  const SizedBox(height: 12),

                  // === TO FIELD ===
                  TextField(
                    controller: _toController,
                    focusNode: _toFocus,
                    onChanged: (v) => onChanged(v, true),
                    decoration: const InputDecoration(
                      labelText: 'Arrivé',
                      prefixIcon: Icon(Icons.location_on),
                      border: OutlineInputBorder(),
                    ),
                  ),

                  if (currentTyping.isNotEmpty)
                    ...filteredMuseums.map(
                      (m) => ListTile(
                        title: Text(m.name!),
                        onTap: () => onSuggestionTap(m),
                      ),
                    ),

                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: computeRoute,
                    child: const Text("Gooo"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),

                  if (routeDistance != null && routeDuration != null)
                    const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: resetSelections,
                    child: const Text("Reset"),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: addStopField,
                    icon: const Icon(Icons.add),
                    label: const Text("Ajouter un arrêt"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                      foregroundColor: const Color.fromARGB(255, 0, 0, 0),
                    ),
                  ),
                  SwitchListTile(
                    title: const Text("Voyageur Optimal"),
                    subtitle: const Text("Pas rapide mais optimal"),
                    value: useOptimalTSP,
                    onChanged: (bool value) {
                      setState(() {
                        useOptimalTSP = value;
                      });
                    },
                    activeColor: Colors.indigo,
                  ),
                  SwitchListTile(
                    title: const Text('Retour au départ'),
                    value: returnToStart,
                    onChanged: (value) {
                      setState(() {
                        returnToStart = value;
                      });
                    },
                    activeColor: Colors.indigo,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
