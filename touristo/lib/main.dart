import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'graph.dart';
import 'algorithm.dart'; // import your algorithm file

void main() {
  runApp(const MyApp());
}

String token =
    'pk.eyJ1IjoiYW5hc3NhaWQiLCJhIjoiY21iaHRwZWFhMDFhYTJscjAxN2J1aGdqcSJ9.DuvzVIBDrYLB0-se6FhOxg';

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
  bool isLoading = false;
  double? routeDistance;
  double? routeDuration;
  List<TextEditingController> stopControllers = [];
  List<FocusNode> stopFocusNodes = [];
  List<dynamic> stopIds = [];
  List<LatLng?> stopLatLngs = [];
  List<GraphNode?> intermediateStops = [];
  final DraggableScrollableController _draggableController =
      DraggableScrollableController();
  double _sheetExtent = 0.35;
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
  dynamic _fromId;
  dynamic _toId;

  List<LatLng> routePoints = [];

  String selectedAlgorithm = 'Dijkstra (Heap)';

  @override
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
      _mapController.move(latLng, 15);
    });
  }

  // ========================================================== Reset Selection Button =======================================================
  void resetSelections() {
    setState(() {
      _fromController.clear();
      _toController.clear();
      _fromLatLng = null;
      _toLatLng = null;
      _fromId = null;
      _toId = null;
      routePoints.clear();
      routeDistance = null; //  Clear distance
      routeDuration = null; //  Clear duration
      currentTyping = '';
      _mapController.move(LatLng(48.8566, 2.3522), 13);
    });
  }

  // ========================================================== Selection et appeld'algorithme =======================================================
  // DEBUG VERSION
  void computeRoute() {
    if (graph == null || _fromId == null || _toId == null) {
      print('🚫 Missing data: graph or selected nodes are null');
      return;
    }

    print('📍 From ID: $_fromId');
    print('📍 To ID: $_toId');
    print('📦 Algorithm: $selectedAlgorithm');

    Map<String, Map<dynamic, dynamic>> result;
    if (selectedAlgorithm == 'Dijkstra (Heap)') {
      result = dijkstraAvecTas(graph!, _fromId);
    } else if (selectedAlgorithm == 'Dijkstra (No Heap)') {
      result = dijkstraSansTas(graph!, _fromId);
    } else if (selectedAlgorithm == 'Bellman-Ford') {
      result = bellmanFord(graph!, _fromId);
    } else {
      result = Aetoile(graph!, _fromId, _toId);
    }

    final path = chemin(_fromId, _toId, result['predecesseurs']!);
    print('🧭 Path IDs: $path');

    final distanceMap = result['distances']!;
    var totalDistance = distanceMap[_toId] / 1000 ?? 0.0;
    List<LatLng> points = [];

    for (int i = 0; i < path.length - 1; i++) {
      final nodeA = graph!.getNode(path[i])!;
      final nodeB = graph!.getNode(path[i + 1])!;
      totalDistance += Distance().as(
        LengthUnit.Kilometer,
        LatLng(nodeA.lat, nodeA.lon),
        LatLng(nodeB.lat, nodeB.lon),
      );
      points.add(LatLng(nodeA.lat, nodeA.lon));
    }

    // Add last point
    if (path.isNotEmpty) {
      final lastNode = graph!.getNode(path.last)!;
      points.add(LatLng(lastNode.lat, lastNode.lon));
    }

    final estimatedTime =
        totalDistance / 5 * 60; // assuming 5km/h walking speed

    setState(() {
      routePoints = path.map((id) {
        final node = graph!.getNode(id);
        return LatLng(node!.lat, node.lon);
      }).toList();
      routeDistance = totalDistance;
      routeDuration = estimatedTime;
    });

    print('📏 Distance: ${totalDistance.toStringAsFixed(2)} km');
    print('⏱️ Time: ${estimatedTime.toStringAsFixed(1)} min');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(
                48.8566,
                2.3522,
              ), // Paris coordinates pour initialiser la carte
              initialZoom: 13,
            ),
            children: [
              // visual background layer
              TileLayer(
                urlTemplate:
                    'https://api.mapbox.com/styles/v1/{id}/tiles/256/{z}/{x}/{y}@2x?access_token={accessToken}',
                additionalOptions: {
                  'accessToken': token,
                  'id': 'mapbox/streets-v11',
                },
              ),
              MarkerLayer(
                markers: [
                  if (_fromLatLng == null || _toLatLng == null)
                    ...museums.map((m) {
                      final isSelected = m.id == _fromId || m.id == _toId;
                      return Marker(
                        width: isSelected ? 50 : 30,
                        height: isSelected ? 50 : 30,
                        point: LatLng(m.lat, m.lon),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              if (_fromLatLng == null) {
                                _fromLatLng = LatLng(m.lat, m.lon);
                                _fromId = m.id;
                                _fromController.text = m.name!;
                              } else if (_toLatLng == null) {
                                _toLatLng = LatLng(m.lat, m.lon);
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
                ],
              ),

              if (routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      strokeWidth: 5,
                      color: const Color.fromARGB(255, 41, 39, 176),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            right: 20,
            bottom: _sheetExtent * MediaQuery.of(context).size.height + 20,
            child: Visibility(
              visible: showResetButton,
              child: FloatingActionButton(
                heroTag: "resetBtn",
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 4,
                mini: true,
                onPressed: resetSelections,
                child: const Icon(Icons.refresh),
              ),
            ),
          ),
          // Bottom Sheet
          DraggableScrollableSheet(
            controller: _draggableController,
            initialChildSize: 0.35,
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
                    'Choose Algorithm:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  DropdownButton<String>(
                    value: selectedAlgorithm,
                    isExpanded: true,
                    onChanged: (value) =>
                        setState(() => selectedAlgorithm = value!),
                    items: const [
                      DropdownMenuItem(
                        value: 'Dijkstra (Heap)',
                        child: Text('Dijkstra (Heap)'),
                      ),
                      DropdownMenuItem(
                        value: 'Dijkstra (No Heap)',
                        child: Text('Dijkstra (No Heap)'),
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
                      labelText: 'From',
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
                      labelText: 'To',
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
                    child: const Text("Calculate Route"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                  if (routeDistance != null && routeDuration != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📏 Distance: ${routeDistance!.toStringAsFixed(2)} km',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '⏱️ Estimated Time: ${routeDuration!.toStringAsFixed(0)} min',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: resetSelections,
                    child: const Text("Reset"),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: addStopField,
                    icon: const Icon(Icons.add),
                    label: const Text("Add Stop"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                      foregroundColor: const Color.fromARGB(255, 0, 0, 0),
                    ),
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
