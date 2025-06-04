import 'package:flutter/material.dart';
import 'package:touristo/graph.dart'; // Assuming your graph.dart is in lib/
import 'package:touristo/algorithm.dart'; // Assuming your algorithm.dart is in lib/
import 'package:touristo/graph_display_widget.dart'; // Import the new graph display widget
// If your files are in a different location, adjust the import paths accordingly.

void main() {
  runApp(const AlgorithmTestApp());
}

class AlgorithmTestApp extends StatelessWidget {
  const AlgorithmTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Algorithm Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AlgorithmTestPage(),
    );
  }
}

class AlgorithmTestPage extends StatefulWidget {
  const AlgorithmTestPage({super.key});

  @override
  State<AlgorithmTestPage> createState() => _AlgorithmTestPageState();
}

class _AlgorithmTestPageState extends State<AlgorithmTestPage> {
  Graph? _graph;
  List<dynamic> _path = [];
  double _totalDistance = 0.0;
  bool _isLoading = true;
  String _message = 'Initializing graph...';

  // --- Define your start and end nodes for the simple graph ---
  final dynamic _startNodeId = "Node_0";
  final dynamic _endNodeId =
      "Node_9"; // Changed to a node within the new 10-node graph

  @override
  void initState() {
    super.initState();
    _createSimpleGraphAndRunAlgorithms();
  }

  Future<void> _createSimpleGraphAndRunAlgorithms() async {
    setState(() {
      _isLoading = true;
      _message = 'Creating graph with 10 nodes...';
    });

    try {
      // Create a graph with 10 nodes directly in code
      final smallGraph = Graph();

      // Add 10 nodes
      for (int i = 0; i < 10; i++) {
        smallGraph.addNode(
          GraphNode(
            id: "Node_$i",
            lat: i * 0.5, // Distribute nodes for visualization
            lon: (i % 3) * 0.7,
            name: "Node $i",
          ),
        );
      }

      // Add edges to create a path and some branching
      smallGraph.addEdge(
        GraphEdge(source: "Node_0", target: "Node_1", length: 1.0),
      );
      smallGraph.addEdge(
        GraphEdge(source: "Node_0", target: "Node_2", length: 3.0),
      );
      smallGraph.addEdge(
        GraphEdge(source: "Node_1", target: "Node_3", length: 2.0),
      );
      smallGraph.addEdge(
        GraphEdge(source: "Node_2", target: "Node_4", length: 1.5),
      );
      smallGraph.addEdge(
        GraphEdge(source: "Node_3", target: "Node_5", length: 2.5),
      );
      smallGraph.addEdge(
        GraphEdge(source: "Node_4", target: "Node_6", length: 1.0),
      );
      smallGraph.addEdge(
        GraphEdge(source: "Node_5", target: "Node_7", length: 3.0),
      );
      smallGraph.addEdge(
        GraphEdge(source: "Node_6", target: "Node_8", length: 1.0),
      );
      smallGraph.addEdge(
        GraphEdge(source: "Node_7", target: "Node_9", length: 2.0),
      );
      smallGraph.addEdge(
        GraphEdge(source: "Node_8", target: "Node_9", length: 0.5),
      ); // Shorter path to end

      // Add some cross-connections for more complexity
      smallGraph.addEdge(
        GraphEdge(source: "Node_0", target: "Node_4", length: 5.0),
      );
      smallGraph.addEdge(
        GraphEdge(source: "Node_1", target: "Node_6", length: 4.0),
      );
      smallGraph.addEdge(
        GraphEdge(source: "Node_2", target: "Node_7", length: 6.0),
      );

      _graph = smallGraph;

      setState(() {
        _message = 'Graph created. Running Dijkstra...';
      });

      // Verify that start and end nodes exist in the graph
      if (_graph!.nodes[_startNodeId] == null) {
        setState(() {
          _message = 'Start node "$_startNodeId" not found in the graph.';
          _isLoading = false;
        });
        print('Error: Start node "$_startNodeId" not found.');
        return;
      }
      if (_graph!.nodes[_endNodeId] == null) {
        setState(() {
          _message = 'End node "$_endNodeId" not found in the graph.';
          _isLoading = false;
        });
        print('Error: End node "$_endNodeId" not found.');
        return;
      }

      final dijkstraResult = dijkstraSansTas(_graph!, _startNodeId);
      final predecessors =
          dijkstraResult['predecesseurs'] as Map<dynamic, dynamic>?;
      final distances = dijkstraResult['distances'] as Map<dynamic, double>?;

      if (predecessors == null || distances == null) {
        setState(() {
          _message =
              'Dijkstra algorithm did not return expected results (predecessors or distances are null).';
          _isLoading = false;
        });
        print(
          "Error: Dijkstra result invalid (null predecessors or distances).",
        );
        return;
      }

      // Check if a path exists to the end node
      if (distances[_endNodeId] == null || distances[_endNodeId]!.isInfinite) {
        setState(() {
          _message =
              'No path found from "$_startNodeId" to "$_endNodeId" or destination is unreachable.';
          _path = [];
          _totalDistance = double.infinity;
          _isLoading = false;
        });
        print(
          'Info: No path found or destination unreachable for "$_endNodeId". Distance: ${distances[_endNodeId]}',
        );
        return; // Path not found, but not necessarily an error in the algorithm itself.
      }

      final calculatedPath = chemin(_startNodeId, _endNodeId, predecessors);

      setState(() {
        _path = calculatedPath;
        _totalDistance = distances[_endNodeId] ?? double.infinity;
        _message = 'Algorithm execution complete.';
        _isLoading = false;
      });

      // Print to console for verification
      print('--- Algorithm Test Results (10-Node Graph) ---');
      print(
        'Start Node: $_startNodeId (${_graph?.getNode(_startNodeId)?.name ?? 'N/A'})',
      );
      print(
        'End Node: $_endNodeId (${_graph?.getNode(_endNodeId)?.name ?? 'N/A'})',
      );
      if (_path.isNotEmpty) {
        print(
          'Path: ${_path.map((id) => _graph?.getNode(id)?.name ?? id).join(" -> ")}',
        );
        print('Total Distance: ${_totalDistance.toStringAsFixed(2)}');
      } else if (_totalDistance.isInfinite) {
        print('No path found or end node is unreachable.');
      } else {
        print(
          'Path is empty but destination might be the start node or reachable with 0 distance.',
        );
      }
      print('--------------------------------------------');
    } catch (e, stackTrace) {
      // Added stackTrace for more debug info
      print('FATAL Error during _createSimpleGraphAndRunAlgorithms: $e');
      print('Stack trace: $stackTrace'); // Print stack trace
      setState(() {
        _message =
            'An error occurred during graph creation or algorithm execution: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dijkstra Algorithm Test (10 Nodes)')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    Text(_message, textAlign: TextAlign.center),
                  ],
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Testing Pathfinding Algorithm on 10-Node Graph',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    _buildInfoCard(
                      title: 'Start Node',
                      value:
                          '$_startNodeId (${_graph?.getNode(_startNodeId)?.name ?? 'N/A'})',
                    ),
                    _buildInfoCard(
                      title: 'End Node',
                      value:
                          '$_endNodeId (${_graph?.getNode(_endNodeId)?.name ?? 'N/A'})',
                    ),
                    const SizedBox(height: 20),
                    // Display the graph visualization here
                    if (_graph != null && !_isLoading)
                      SizedBox(
                        // Wrap GraphDisplayWidget in SizedBox to give it constraints
                        height: 400, // Fixed height for the graph view
                        child: GraphDisplayWidget(
                          graph: _graph!,
                          path: _path,
                          startNodeId: _startNodeId,
                          endNodeId: _endNodeId,
                        ),
                      ),
                    const SizedBox(height: 20), // Spacing after the graph
                    if (!_isLoading &&
                        _message.contains('Algorithm execution complete')) ...[
                      // Check if not loading and message indicates success
                      if (_path.isNotEmpty) ...[
                        _buildInfoCard(
                          title: 'Shortest Distance',
                          value: _totalDistance.isInfinite
                              ? 'Unreachable'
                              : '${_totalDistance.toStringAsFixed(2)} units',
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Path Details:',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8.0),
                            color: Colors.grey.shade50,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _path.map((nodeId) {
                              final node = _graph?.getNode(nodeId);
                              final nodeName = node?.name ?? 'Unknown Node';
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4.0,
                                ),
                                child: Text(
                                  'ID: $nodeId, Name: $nodeName',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ] else if (_totalDistance.isInfinite) ...[
                        // Path not found, but algorithm completed
                        Card(
                          elevation: 2,
                          color: Colors.yellow.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'No path found from "$_startNodeId" to "$_endNodeId". The destination might be unreachable.',
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ] else if (_path.isEmpty &&
                          _startNodeId == _endNodeId) ...[
                        _buildInfoCard(
                          title: 'Shortest Distance',
                          value: '0.00 units (Start and End are the same)',
                        ),
                        const SizedBox(height: 10),
                        const Text('Path: Start and End node are the same.'),
                      ],
                    ] else if (!_isLoading) // If not loading and message is not "complete", it's an error or other status
                      Card(
                        elevation: 2,
                        color:
                            _message.contains("Error") ||
                                _message.contains("not found") ||
                                _message.contains("occurred")
                            ? Colors.red.shade50
                            : Colors.blue.shade50, // For other status messages
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            _message, // Display error or status message
                            style: TextStyle(
                              color:
                                  _message.contains("Error") ||
                                      _message.contains("not found") ||
                                      _message.contains("occurred")
                                  ? Colors.red.shade800
                                  : Colors.blue.shade800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    Center(
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : _createSimpleGraphAndRunAlgorithms, // Disable button while loading
                        child: const Text('Re-run Test'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInfoCard({required String title, required String value}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(value, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
