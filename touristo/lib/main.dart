import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'graph.dart';
import 'algorithm.dart'; // import your algorithm file

void main() {
  runApp(const MyApp());
}

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
  void initState() {
    super.initState();
    loadGraphData();
  }

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

  List<GraphNode> get filteredMuseums {
    return museums
        .where(
          (m) => m.name!.toLowerCase().contains(currentTyping.toLowerCase()),
        )
        .toList();
  }

  void onChanged(String value, bool isToField) {
    setState(() {
      isTypingTo = isToField;
      currentTyping = value;
    });
  }

  void onSuggestionTap(GraphNode museum) {
    setState(() {
      final latLng = LatLng(museum.lat, museum.lon);
      if (isTypingTo) {
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

  void resetSelections() {
    setState(() {
      _fromController.clear();
      _toController.clear();
      _fromLatLng = null;
      _toLatLng = null;
      _fromId = null;
      _toId = null;
      routePoints.clear();
      currentTyping = '';
      _mapController.move(LatLng(48.8566, 2.3522), 13);
    });
  }

  void computeRoute() {
    if (graph == null || _fromId == null || _toId == null) return;

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

    setState(() {
      routePoints = path.map((id) {
        final node = graph!.getNode(id);
        return LatLng(node!.lat, node.lon);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(center: LatLng(48.8566, 2.3522), zoom: 13),
            children: [
              TileLayer(
                urlTemplate:
                    'https://api.mapbox.com/styles/v1/{id}/tiles/256/{z}/{x}/{y}@2x?access_token={accessToken}',
                additionalOptions: {
                  'accessToken':
                      'pk.eyJ1IjoiYW5hc3NhaWQiLCJhIjoiY21iaHRwZWFhMDFhYTJscjAxN2J1aGdqcSJ9.DuvzVIBDrYLB0-se6FhOxg',
                  'id': 'mapbox/streets-v11',
                },
              ),
              MarkerLayer(
                markers: [
                  if (_fromLatLng == null || _toLatLng == null)
                    ...museums.map(
                      (m) => Marker(
                        width: 30,
                        height: 30,
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
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.blue,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  if (_fromLatLng != null)
                    Marker(
                      width: 45,
                      height: 45,
                      point: _fromLatLng!,
                      child: const Icon(
                        Icons.flag,
                        color: Colors.green,
                        size: 40,
                      ),
                    ),
                  if (_toLatLng != null)
                    Marker(
                      width: 45,
                      height: 45,
                      point: _toLatLng!,
                      child: const Icon(
                        Icons.flag,
                        color: Colors.red,
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
                      color: Colors.purple,
                    ),
                  ],
                ),
            ],
          ),

          // Bottom Sheet
          DraggableScrollableSheet(
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
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: resetSelections,
                    child: const Text("Reset"),
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
