import 'package:touristo/graph.dart';

Map<String, Map<dynamic, dynamic>> dijkstraSansTas(
  Graph graph,
  dynamic depart,
) {
  final distances =
      <
        dynamic,
        double
      >{}; // la distance entre le noeud de depart et chaque noeud, (id , distance)

  final pred = <dynamic, dynamic>{}; // les predecesseur pour avoir le chemin
  final visite = <dynamic>{}; // id des noeuds visités

  // initialisation des distance à Infini
  for (var nodeId in graph.nodes.keys) {
    distances[nodeId] = double.infinity;
  }
  // init de distance de noeud de depart a 0
  distances[depart] = 0.0;

  while (visite.length < graph.nodes.length) {
    dynamic current;
    double? minDistance;

    // parcours des noeuds
    for (var id in graph.nodes.keys) {
      // check si le noeud a été visité
      if (!visite.contains(id)) {
        if (minDistance == null || distances[id]! < minDistance) {
          minDistance = distances[id]!;
          current = id; //contient l'id de noeud de plus petit distance
        }
      }
    }
    visite.add(current);
    // loop sur tous les arcs ou arretes
    for (var edge in graph.neighbors(current)) {
      // si on n'a pas encore vue cet arc
      if (!visite.contains(edge.target)) {
        double newDist = distances[current]! + edge.length;
        // mis a jour de chemin si il est plus court
        if (newDist < distances[edge.target]!) {
          distances[edge.target] = newDist;
          pred[edge.target] = current;
        }
      }
    }
  }
  return {'distances': distances, 'predecesseurs': pred};
}

List<dynamic> chemin(
  dynamic depart,
  dynamic destination,
  Map<dynamic, dynamic> pred,
) {
  final chemin = <dynamic>[]; // liste des id
  dynamic curr = destination;

  if (pred[curr] == null && curr != depart) return [];

  while (curr != null) {
    chemin.insert(0, curr);
    curr = pred[curr];
  }

  return chemin;
}
