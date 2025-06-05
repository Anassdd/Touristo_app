import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Noeud du graphe
class GraphNode {
  final dynamic id; // int ou string (dynamic)
  final double lat; // axe x ou latitude
  final double lon; // axe y ou longitude
  final String? type; // optionel, musée, 'intersection' ..
  final String?
  name; // optionel, car les noeuds d'ontersection des rues n'ont pas de nom

  GraphNode({
    required this.id,
    required this.lat,
    required this.lon,
    this.type,
    this.name,
  });

  // obtenir les noeuds de file .json
  factory GraphNode.fromJson(Map<String, dynamic> json) {
    return GraphNode(
      id: json['id'],
      lat: json['lat'],
      lon: json['lon'],
      type: json['type'],
      name: json['name'],
    );
  }
}

/// Les arcs du graphes ou edge (en anglais)
class GraphEdge {
  final dynamic source; //id de noeud de depart
  final dynamic target; //id de noeud d'arrivé
  final double length; // longueurs entre les deux noeuds

  GraphEdge({required this.source, required this.target, required this.length});

  // obtenir les arcs de file .json
  factory GraphEdge.fromJson(Map<String, dynamic> json) {
    return GraphEdge(
      source: json['source'],
      target: json['target'],
      length: (json['length'] as num).toDouble(),
    );
  }
}

/// Structure de Graph par liste d'adjacence
class Graph {
  // cette structure ressemble très à la structure de graphe fait en Python où on utilise des dictionnaires pour representer les graphes
  final Map<dynamic, GraphNode> nodes = {};
  final Map<dynamic, List<GraphEdge>> adjacencyList = {};

  void addNode(GraphNode node) {
    nodes[node.id] = node;
    adjacencyList[node.id] = [];
  }

  void addEdge(GraphEdge edge) {
    adjacencyList.putIfAbsent(edge.source, () => []);
    adjacencyList[edge.source]!.add(edge);
  }

  // les noeuds voisins
  List<GraphEdge> neighbors(dynamic nodeId) {
    return adjacencyList[nodeId] ?? [];
  }

  GraphNode? getNode(dynamic id) => nodes[id];
}

/// initialisation du graphe par le code Json
///
/*
Future<Graph> loadGraphFromJson(String assetPath) async {
  final jsonString = await rootBundle.loadString(assetPath);
  final Map<String, dynamic> jsonData = jsonDecode(jsonString);

  final graph = Graph();

  for (var nodeJson in jsonData['nodes']) {
    final node = GraphNode.fromJson(nodeJson);
    graph.addNode(node);
  }

  for (var edgeJson in jsonData['edges']) {
    final edge = GraphEdge.fromJson(edgeJson);
    graph.addEdge(edge);
  }

  return graph;
}
*/
/// initialisation du graphe par le code Json en mode NON ORIENTÉ
Future<Graph> loadGraphFromJson(String assetPath) async {
  final jsonString = await rootBundle.loadString(assetPath);
  final Map<String, dynamic> jsonData = jsonDecode(jsonString);

  final graph = Graph();

  // Ajouter tous les noeuds
  for (var nodeJson in jsonData['nodes']) {
    final node = GraphNode.fromJson(nodeJson);
    graph.addNode(node);
  }

  // Ajouter chaque arête dans les deux sens (non orienté)
  for (var edgeJson in jsonData['edges']) {
    final edge = GraphEdge.fromJson(edgeJson);

    // Arête directe
    graph.addEdge(edge);

    // Arête inverse (source <-> target)
    final reversedEdge = GraphEdge(
      source: edge.target,
      target: edge.source,
      length: edge.length,
    );
    graph.addEdge(reversedEdge);
  }

  return graph;
}
