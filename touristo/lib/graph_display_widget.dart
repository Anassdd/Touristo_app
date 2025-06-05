import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart'
    as gv; // Alias graphview pour éviter les conflits de nom
import 'package:touristo/graph.dart'; // Votre classe Graph

/// Widget d'affichage de graphe interactif.
/// Utilise la bibliothèque `graphview` pour le rendu et permet le pan, le zoom
/// et la sélection de nœuds par clic.
class GraphDisplayWidget extends StatefulWidget {
  final Graph graph; // Le graphe personnalisé à afficher
  final List<dynamic> path; // Le chemin à mettre en évidence
  final dynamic startNodeId; // L'ID du nœud de départ sélectionné
  final dynamic endNodeId; // L'ID du nœud d'arrivée sélectionné
  final Function(dynamic nodeId)?
  onNodeTapped; // Fonction de rappel pour le tap sur un nœud

  const GraphDisplayWidget({
    super.key,
    required this.graph,
    required this.path,
    this.startNodeId,
    this.endNodeId,
    this.onNodeTapped,
  });

  @override
  State<GraphDisplayWidget> createState() => _GraphDisplayWidgetState();
}

class _GraphDisplayWidgetState extends State<GraphDisplayWidget> {
  gv.Graph graphViewGraph = gv.Graph(); // Le graphe au format graphview
  Map<dynamic, gv.Node> nodeMap =
      {}; // Association de vos IDs de nœuds aux nœuds graphview

  @override
  void initState() {
    super.initState();
    _buildGraphViewGraph();
  }

  @override
  void didUpdateWidget(covariant GraphDisplayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reconstruire le graphe graphview si les données du graphe ont changé
    if (oldWidget.graph != widget.graph ||
        oldWidget.startNodeId != widget.startNodeId ||
        oldWidget.endNodeId != widget.endNodeId ||
        oldWidget.path != widget.path) {
      _buildGraphViewGraph();
    }
  }

  /// Convertit votre objet Graph personnalisé en un objet gv.Graph (graphview).
  void _buildGraphViewGraph() {
    graphViewGraph = gv.Graph();
    nodeMap.clear();

    // Ajouter les nœuds
    for (var node in widget.graph.nodes.values) {
      final gv.Node graphViewNode = gv.Node.Id(node.id);
      nodeMap[node.id] = graphViewNode;
      graphViewGraph.addNode(graphViewNode);
    }

    // Ajouter les arêtes
    for (var sourceId in widget.graph.adjacencyList.keys) {
      final gv.Node? sourceNode = nodeMap[sourceId];
      if (sourceNode == null) continue;

      for (var edge in widget.graph.neighbors(sourceId)) {
        final gv.Node? targetNode = nodeMap[edge.target];
        if (targetNode == null) continue;

        // Déterminer si cette arête fait partie du chemin pour la mise en évidence
        bool isPathEdge = false;
        if (widget.path.length >= 2) {
          for (int i = 0; i < widget.path.length - 1; i++) {
            // Vérifie les deux directions de l'arête si le chemin est non dirigé
            if ((widget.path[i] == sourceId &&
                    widget.path[i + 1] == edge.target) ||
                (widget.path[i] == edge.target &&
                    widget.path[i + 1] == sourceId)) {
              isPathEdge = true;
              break;
            }
          }
        }

        // Ajouter l'arête avec les propriétés de peinture pour le style
        graphViewGraph.addEdge(
          sourceNode,
          targetNode,
          paint: Paint()
            ..color = isPathEdge
                ? Colors.deepOrange.shade600
                : Colors.blueGrey.shade200
            ..strokeWidth = isPathEdge ? 5.0 : 2.0
            ..style = PaintingStyle.stroke,
        );
      }
    }
    setState(() {}); // Mettre à jour l'UI après la construction du graphe
  }

  @override
  Widget build(BuildContext context) {
    // Définir l'algorithme de disposition (layout) pour le graphe.
    // FruchtermanReingoldLayout est un algorithme de force-directed qui donne une bonne distribution visuelle.
    final gv.Algorithm algorithm = gv.FruchtermanReingoldAlgorithm();

    return Center(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blueGrey.shade200, width: 1),
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 8,
              spreadRadius: 3,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        // InteractiveViewer permet de panner et zoomer le graphe
        child: InteractiveViewer(
          constrained: false, // Le contenu peut être plus grand que la fenêtre
          boundaryMargin: const EdgeInsets.all(80), // Marge autour du graphe
          minScale: 0.1, // Zoom minimum
          maxScale: 2.5, // Zoom maximum
          child: gv.GraphView(
            graph: graphViewGraph,
            algorithm: algorithm,
            builder: (gv.Node node) {
              // Cette fonction construit le widget visuel pour chaque nœud
              final nodeId = node.key!.value; // L'ID de votre nœud
              widget.graph.getNode(nodeId); // Votre objet GraphNode

              // Déterminer la couleur du nœud en fonction de son statut
              Color nodeColor = Colors.blue.shade600;
              if (nodeId == widget.startNodeId) {
                nodeColor = Colors.green.shade700; // Nœud de départ
              } else if (nodeId == widget.endNodeId) {
                nodeColor = Colors.red.shade700; // Nœud d'arrivée
              } else if (widget.path.contains(nodeId)) {
                nodeColor =
                    Colors.orange.shade500; // Nœud faisant partie du chemin
              }

              return InkWell(
                onTap: () {
                  // Appeler la fonction de rappel quand un nœud est tapé
                  widget.onNodeTapped?.call(nodeId);
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
                      ), // Affiche l'ID simplifié
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
          ),
        ),
      ),
    );
  }
}
