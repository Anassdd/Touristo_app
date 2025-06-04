import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart'
    as gv; // Alias graphview's Graph class
import 'package:touristo/graph.dart'; // Import your Graph and GraphNode classes

/// A Flutter widget to display a graph visually using the graphview library.
/// It allows for interactive tapping on nodes.
class GraphDisplayWidget extends StatelessWidget {
  final Graph graph; // This refers to your custom Graph class
  final List<dynamic> path;
  final dynamic startNodeId;
  final dynamic endNodeId;

  const GraphDisplayWidget({
    super.key,
    required this.graph,
    required this.path,
    this.startNodeId,
    this.endNodeId,
  });

  @override
  Widget build(BuildContext context) {
    // Convert your custom Graph object to GraphView's Graph object
    final gv.Graph graphViewGraph =
        gv.Graph(); // Use gv.Graph for graphview's Graph
    final Map<dynamic, gv.Node> nodeMap =
        {}; // Map your node IDs to GraphView Nodes

    // Add nodes to GraphView's graph
    for (var node in graph.nodes.values) {
      final graphViewNode = gv.Node.Id(
        node.id,
      ); // Use gv.Node for graphview's Node
      nodeMap[node.id] = graphViewNode;
      graphViewGraph.addNode(graphViewNode);
    }

    // Add edges to GraphView's graph
    for (var sourceId in graph.adjacencyList.keys) {
      final sourceNode = nodeMap[sourceId];
      if (sourceNode == null) continue;

      for (var edge in graph.neighbors(sourceId)) {
        final targetNode = nodeMap[edge.target];
        if (targetNode == null) continue;

        // Check if this edge is part of the shortest path for highlighting
        bool isPathEdge = false;
        if (path.length >= 2) {
          for (int i = 0; i < path.length - 1; i++) {
            if ((path[i] == sourceId && path[i + 1] == edge.target) ||
                (path[i] == edge.target && path[i + 1] == sourceId)) {
              isPathEdge = true;
              break;
            }
          }
        }

        // Add edge with data (e.g., length, path status)
        graphViewGraph.addEdge(
          sourceNode,
          targetNode,
          paint: Paint()
            ..color = isPathEdge
                ? Colors.deepOrange.shade600
                : Colors.blueGrey.shade200
            ..strokeWidth = isPathEdge ? 5.0 : 2.0
            ..style = PaintingStyle.stroke,
          // You can attach custom data to edges if needed, though not directly used for drawing here
          // This example uses `paint` directly for simplicity.
          // For text on edges, you might need to use a custom builder or overlay.
        );
      }
    }

    // Removed the explicit layout algorithm definition.
    // GraphView will now use its default layout.

    return Scaffold(
      // Use Scaffold to show SnackBars
      body: Center(
        child: InteractiveViewer(
          constrained: false, // Allows content to be larger than viewport
          boundaryMargin: const EdgeInsets.all(80), // Margin around the graph
          minScale: 0.1,
          maxScale: 2.5,
          child: gv.GraphView(
            // Use gv.GraphView
            graph: graphViewGraph,
            algorithm: gv.FruchtermanReingoldAlgorithm(),
            builder: (gv.Node node) {
              // Use gv.Node in builder
              // This builder function creates the widget for each node
              final nodeId = node.key!.value;
              final graphNode = graph.getNode(nodeId);

              Color nodeColor = Colors.blue.shade600;
              if (nodeId == startNodeId) {
                nodeColor = Colors.green.shade700; // Start node
              } else if (nodeId == endNodeId) {
                nodeColor = Colors.red.shade700; // End node
              } else if (path.contains(nodeId)) {
                nodeColor = Colors.orange.shade500; // Path node
              }

              return InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Tapped Node: $nodeId (Name: ${graphNode?.name ?? 'N/A'})',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: nodeColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(2, 2),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.blueGrey.shade800,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      nodeId.toString().replaceAll(
                        'Node_',
                        '',
                      ), // Simplify ID for display
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
            // For edge rendering, graphview uses `Paint` objects directly.
            // If you need custom widgets on edges (e.g., for length labels),
            // you might need to use a custom edge builder or overlay, which is more complex.
            // For now, we'll rely on the paint properties for path highlighting.
          ),
        ),
      ),
    );
  }
}
