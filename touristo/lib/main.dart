import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'graph.dart';

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
      if (isTypingTo) {
        _toController.text = museum.name!;
        _toLatLng = LatLng(museum.lat, museum.lon);
        _toFocus.unfocus();
      } else {
        _fromController.text = museum.name!;
        _fromLatLng = LatLng(museum.lat, museum.lon);
        _fromFocus.unfocus();
      }
      currentTyping = '';
      _mapController.move(LatLng(museum.lat, museum.lon), 15);
    });
  }

  void resetSelections() {
    setState(() {
      _fromController.clear();
      _toController.clear();
      _fromLatLng = null;
      _toLatLng = null;
      currentTyping = '';
      _mapController.move(LatLng(48.8566, 2.3522), 13);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🌍 Map
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
                                _fromController.text = m.name!;
                                _fromLatLng = LatLng(m.lat, m.lon);
                              } else if (_toLatLng == null) {
                                _toController.text = m.name!;
                                _toLatLng = LatLng(m.lat, m.lon);
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
            ],
          ),

          // 🧾 Bottom Sheet
          DraggableScrollableSheet(
            initialChildSize: 0.3,
            minChildSize: 0.2,
            maxChildSize: 0.85,
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
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const Text(
                    'Set your destination',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                  const SizedBox(height: 12),

                  if (currentTyping.isNotEmpty)
                    ...filteredMuseums.map(
                      (m) => ListTile(
                        title: Text(m.name!),
                        onTap: () => onSuggestionTap(m),
                      ),
                    ),

                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () {
                      if (_fromLatLng == null || _toLatLng == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Please select both locations"),
                          ),
                        );
                        return;
                      }

                      final sw = LatLng(
                        _fromLatLng!.latitude < _toLatLng!.latitude
                            ? _fromLatLng!.latitude
                            : _toLatLng!.latitude,
                        _fromLatLng!.longitude < _toLatLng!.longitude
                            ? _fromLatLng!.longitude
                            : _toLatLng!.longitude,
                      );
                      final ne = LatLng(
                        _fromLatLng!.latitude > _toLatLng!.latitude
                            ? _fromLatLng!.latitude
                            : _toLatLng!.latitude,
                        _fromLatLng!.longitude > _toLatLng!.longitude
                            ? _fromLatLng!.longitude
                            : _toLatLng!.longitude,
                      );
                      final bounds = LatLngBounds(sw, ne);
                      _mapController.fitBounds(
                        bounds,
                        options: const FitBoundsOptions(
                          padding: EdgeInsets.all(40),
                        ),
                      );

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Showing route from ${_fromController.text} to ${_toController.text}',
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text("Confirm destination"),
                  ),

                  const SizedBox(height: 10),

                  OutlinedButton(
                    onPressed: resetSelections,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(48),
                    ),
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
