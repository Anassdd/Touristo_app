import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // Import flutter_map
import 'package:latlong2/latlong.dart'; // Import LatLng
import 'package:touristo/graph.dart'; // Assuming your graph.dart is in lib/
import 'package:touristo/algorithm.dart'; // Assuming your algorithm.dart is in lib/

void main() {
  runApp(const MapAlgorithmTestApp());
}

class MapAlgorithmTestApp extends StatelessWidget {
  const MapAlgorithmTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Touristo Map',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
        ),
      ),
      home: const MapAlgorithmTestPage(),
    );
  }
}

class MapAlgorithmTestPage extends StatefulWidget {
  const MapAlgorithmTestPage({super.key});

  @override
  State<MapAlgorithmTestPage> createState() => _MapAlgorithmTestPageState();
}

class _MapAlgorithmTestPageState extends State<MapAlgorithmTestPage> {
  Graph? _graph;
  List<Polyline> _shortestPathPolylines = [];
  double _totalDistance = 0.0;
  bool _isLoading = true;
  String _message = 'Loading Paris graph data...';
  List<Marker> _museumMarkers = [];
  List<Polyline> _graphEdges = [];

  final MapController _mapController = MapController();
  final TextEditingController _startNodeController = TextEditingController();
  final TextEditingController _endNodeController = TextEditingController();

  // Initial map center (e.g., center of Paris)
  static const LatLng _initialCenter = LatLng(48.8566, 2.3522);
  static const double _initialZoom = 13.0;

  @override
  void initState() {
    super.initState();
    _loadGraphAndInitializeMap();
  }

  @override
  void dispose() {
    _startNodeController.dispose();
    _endNodeController.dispose();
    super.dispose();
  }

  Future<void> _loadGraphAndInitializeMap() async {
    setState(() {
      _isLoading = true;
      _message = 'Loading Paris graph data...';
      _museumMarkers = [];
      _graphEdges = [];
      _shortestPathPolylines = [];
      _totalDistance = 0.0;
    });

    try {
      _graph = await loadGraphFromJson('assets/paris_walk_graph.json');

      if (_graph == null) {
        setState(() {
          _message = 'Failed to load graph data.';
          _isLoading = false;
        });
        print("Error: _graph is null after loadGraphFromJson.");
        return;
      }

      _populateMapData();

      setState(() {
        _message = 'Graph loaded. Ready to find paths!';
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('FATAL Error during _loadGraphAndInitializeMap: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _message = 'An error occurred: $e';
        _isLoading = false;
      });
    }
  }

  void _populateMapData() {
    final List<Marker> markers = [];
    final List<Polyline> edges = [];

    // Create markers for all nodes, especially museums
    for (var node in _graph!.nodes.values) {
      final latLng = LatLng(node.lat, node.lon);
      markers.add(
        Marker(
          point: latLng,
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Tapped Node: ${node.name ?? node.id} (ID: ${node.id})',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Icon(
              node.type == 'museum' ? Icons.museum : Icons.circle,
              color: node.type == 'museum' ? Colors.purple : Colors.blueGrey,
              size: node.type == 'museum' ? 30 : 15,
            ),
          ),
          // CORRECTED: Use 'anchor' with Anchor.center for newer flutter_map versions
          // anchor: Anchor.center,
        ),
      );
    }

    // Create polylines for all graph edges
    for (var sourceId in _graph!.adjacencyList.keys) {
      final sourceNode = _graph!.getNode(sourceId);
      if (sourceNode == null) continue;
      final sourceLatLng = LatLng(sourceNode.lat, sourceNode.lon);

      for (var edge in _graph!.neighbors(sourceId)) {
        final targetNode = _graph!.getNode(edge.target);
        if (targetNode == null) continue;
        final targetLatLng = LatLng(targetNode.lat, targetNode.lon);

        edges.add(
          Polyline(
            points: [sourceLatLng, targetLatLng],
            strokeWidth: 1.0,
            color: Colors.grey.withOpacity(0.6),
          ),
        );
      }
    }

    setState(() {
      _museumMarkers = markers;
      _graphEdges = edges;
    });
  }

  Future<void> _findPath() async {
    setState(() {
      _isLoading = true;
      _message = 'Calculating shortest path...';
      _shortestPathPolylines = []; // Clear previous path
      _totalDistance = 0.0;
    });

    final String startInput = _startNodeController.text.trim();
    final String endInput = _endNodeController.text.trim();

    // Find actual node IDs based on input (can be ID or name)
    dynamic startNodeId;
    dynamic endNodeId;

    // Helper to find node by ID or name
    GraphNode? findNode(String input) {
      // Try by ID first
      for (var node in _graph!.nodes.values) {
        if (node.id.toString() == input) return node;
      }
      // Then try by name (case-insensitive, partial match)
      for (var node in _graph!.nodes.values) {
        if (node.name != null &&
            node.name!.toLowerCase().contains(input.toLowerCase())) {
          return node;
        }
      }
      return null;
    }

    final GraphNode? startGraphNode = findNode(startInput);
    final GraphNode? endGraphNode = findNode(endInput);

    if (startGraphNode == null) {
      setState(() {
        _message =
            'Error: Start node "$startInput" not found. Please check input.';
        _isLoading = false;
      });
      return;
    }
    if (endGraphNode == null) {
      setState(() {
        _message = 'Error: End node "$endInput" not found. Please check input.';
        _isLoading = false;
      });
      return;
    }

    startNodeId = startGraphNode.id;
    endNodeId = endGraphNode.id;

    try {
      final dijkstraResult = dijkstraSansTas(_graph!, startNodeId);
      final predecessors =
          dijkstraResult['predecesseurs'] as Map<dynamic, dynamic>?;
      final distances = dijkstraResult['distances'] as Map<dynamic, double>?;

      if (predecessors == null || distances == null) {
        setState(() {
          _message = 'Dijkstra algorithm did not return expected results.';
          _isLoading = false;
        });
        return;
      }

      if (distances[endNodeId] == null || distances[endNodeId]!.isInfinite) {
        setState(() {
          _message =
              'No path found from "${startGraphNode.name ?? startNodeId}" to "${endGraphNode.name ?? endNodeId}".';
          _shortestPathPolylines = [];
          _totalDistance = double.infinity;
          _isLoading = false;
        });
        return;
      }

      final calculatedPathIds = chemin(startNodeId, endNodeId, predecessors);
      final List<LatLng> pathPoints = [];
      for (var id in calculatedPathIds) {
        final node = _graph!.getNode(id);
        if (node != null) {
          pathPoints.add(LatLng(node.lat, node.lon));
        }
      }

      setState(() {
        _shortestPathPolylines = [
          Polyline(
            points: pathPoints,
            strokeWidth: 6.0,
            color: Colors.deepOrange,
            isDotted: false,
          ),
        ];
        _totalDistance = distances[endNodeId] ?? double.infinity;
        _message = 'Path found!';
        _isLoading = false;
      });

      // Optionally, zoom to fit the path
      if (pathPoints.isNotEmpty) {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(pathPoints),
            padding: const EdgeInsets.all(50),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Error finding path: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _message = 'An error occurred while finding path: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Touristo: Paris Pathfinding'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // --- Map Layer ---
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: _initialCenter,
              zoom: _initialZoom,
              minZoom: 10.0,
              maxZoom: 18.0,
              // absorbPanEvents: false, // Removed: not a valid parameter for MapOptions
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.touristo',
              ),
              PolylineLayer(
                polylines: [
                  ..._graphEdges, // All graph edges (faint)
                  ..._shortestPathPolylines, // The calculated shortest path (highlighted)
                ],
              ),
              MarkerLayer(markers: _museumMarkers),
            ],
          ),

          // --- Loading/Message Overlay ---
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 20),
                    Text(
                      _message,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          // --- Bottom "Uber Style" Panel ---
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Find Your Route',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _startNodeController,
                    decoration: InputDecoration(
                      labelText:
                          'Start Museum ID or Name (e.g., museum_0 or Armée)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(
                        Icons.location_on,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _endNodeController,
                    decoration: InputDecoration(
                      labelText:
                          'End Museum ID or Name (e.g., museum_1 or Louvre)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.flag, color: Colors.red),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _findPath,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 5,
                    ),
                    child: _isLoading && _message.contains('Calculating')
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Calculate Route',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(height: 15),
                  if (_totalDistance > 0 && _totalDistance.isFinite)
                    Text(
                      'Shortest Distance: ${_totalDistance.toStringAsFixed(2)} meters',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    )
                  else if (_totalDistance.isInfinite && !_isLoading)
                    Text(
                      _message, // Display the "No path found" message
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    )
                  else if (!_isLoading && !_message.contains('Ready'))
                    Text(
                      _message, // Display other error messages
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
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
