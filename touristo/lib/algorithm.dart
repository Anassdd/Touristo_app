import 'dart:math';

import 'package:touristo/graph.dart';

// DIJKSTRA SANS TAS

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
        double nouvDist = distances[current]! + edge.length;
        // mis a jour de chemin si il est plus court
        if (nouvDist < distances[edge.target]!) {
          distances[edge.target] = nouvDist;
          pred[edge.target] = current;
        }
      }
    }
  }
  return {'distances': distances, 'predecesseurs': pred};
}

// DIJKTRA AVEC TAS
Map<String, Map<dynamic, dynamic>> dijkstraAvecTas(
  Graph graph,
  dynamic depart,
) {
  final distances =
      <
        dynamic,
        double
      >{}; // le variables ou on store les distances (type : id, dist)
  final pred =
      <dynamic, dynamic>{}; // dictionnaire des predecesseurs (type : id , id)
  final visitee = <dynamic>{};
  // initialiser toutes les distances à l'infini
  for (var nodeId in graph.nodes.keys) {
    distances[nodeId] = double.infinity;
  }
  distances[depart] = 0.0;

  // tas des noeuds a visiter avec leurs distances (type id : distance)
  final tas = <MapEntry<dynamic, double>>[
    MapEntry(depart, 0.0), //init de tas
  ];

  // tand que la tas n'est pas vide
  while (tas.isNotEmpty) {
    // trier la liste pour devenir un tas minimumm
    tas.sort((a, b) => a.value.compareTo(b.value));
    final teteTas = tas.removeAt(0); //prendre le min
    final curr = teteTas.key;

    if (visitee.contains(curr)) continue;
    visitee.add(curr);

    // on parcours tout les arcs voisins
    for (final edge in graph.neighbors(curr)) {
      if (!visitee.contains(edge.target)) {
        final nouvDist = distances[curr]! + edge.length;
        // mis a jour de chemin si il est plus court et ajout dans le tas
        if (nouvDist < distances[edge.target]!) {
          distances[edge.target] = nouvDist;
          pred[edge.target] = curr;
          tas.add(MapEntry(edge.target, nouvDist));
        }
      }
    }
  }
  return {'distances': distances, 'predecesseurs': pred};
}

// BELMAN FORD
Map<String, Map<dynamic, dynamic>> bellmanFord(Graph graph, dynamic source) {
  final distances = <dynamic, double>{};
  final pred = <dynamic, dynamic>{};
  // init
  for (var nodeId in graph.nodes.keys) {
    distances[nodeId] = double.infinity;
    pred[nodeId] = null;
  }
  distances[source] = 0.0;
  // recuperer de toutes les arêtes
  final tousEdge = graph.adjacencyList.values.expand((e) => e).toList();

  // on loop V - 1 fois
  for (int i = 0; i < graph.nodes.length - 1; i++) {
    // on parcours tous les arcs
    for (var edge in tousEdge) {
      if (distances[edge.source] != double.infinity) {
        final nouvDist = distances[edge.source]! + edge.length;
        // comparaison et mis a jour des distances
        if (nouvDist < distances[edge.target]!) {
          distances[edge.target] = nouvDist;
          pred[edge.target] = edge.source;
        }
      }
    }
  }

  return {'distances': distances, 'predecesseurs': pred};
}

// A* avec heuristique distance eucludienne

double heuristique(GraphNode a, GraphNode b) {
  // distance eucludienne
  final dx = a.lat - b.lat;
  final dy = a.lon - b.lon;
  return sqrt(dx * dx + dy * dy);
}

Map<String, Map<dynamic, dynamic>> Aetoile(
  Graph graph,
  dynamic depart,
  dynamic arrive,
) {
  final distances = <dynamic, double>{};
  final pred = <dynamic, dynamic>{};
  final noeudsExplo = <dynamic>{}; // l'nsemble des noeuds a explorer

  // initialisation

  for (var id in graph.nodes.keys) {
    distances[id] = double.infinity;
  }
  distances[depart] = 0.0;
  noeudsExplo.add(depart);

  // on explore tout les noeuds si on a pas trouver la destination
  while (noeudsExplo.isNotEmpty) {
    // trouver le noeud avec f(n) = g(n) + h(n) le plus petit
    dynamic curr = noeudsExplo.first;
    double minF =
        distances[curr]! +
        heuristique(graph.getNode(curr)!, graph.getNode(arrive)!);

    for (var node in noeudsExplo) {
      double f =
          distances[node]! +
          heuristique(graph.getNode(node)!, graph.getNode(arrive)!);
      if (f < minF) {
        minF = f;
        curr = node;
      }
    }

    // on est arrivé
    if (curr == arrive) break;

    noeudsExplo.remove(curr);

    for (var edge in graph.neighbors(curr)) {
      double nouvDist = distances[curr]! + edge.length;

      if (nouvDist < distances[edge.target]!) {
        distances[edge.target] = nouvDist;
        pred[edge.target] = curr;
        noeudsExplo.add(edge.target);
      }
    }
  }

  return {'distances': distances, 'predecesseurs': pred};
}

// CHEMIN

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

// VOYAGEUR DE COMMERCE

// Retourne toutes les permutations possibles d'une liste
List<List<T>> permutations<T>(List<T> liste) {
  if (liste.length <= 1) return [liste];
  final resultats = <List<T>>[];
  for (int i = 0; i < liste.length; i++) {
    final element = liste[i];
    final reste = List<T>.from(liste)..removeAt(i);
    for (var perm in permutations(reste)) {
      resultats.add([element, ...perm]);
    }
  }
  return resultats;
}

// Voyageur de commerce avec A* à chaque étape, retourne le chemin optimal (mais très lent)
// Principe: On prends tout les permutations possibles des musées pour parcourir notre etapes et apres on calcul la distance et on garde le chemin avec la distance minimale
Map<String, dynamic> voyageurOptimal(
  Graph graphe,
  dynamic depart,
  List<dynamic> etapes,
) {
  // NOTE etapes sont les musée qu'on veut visiter (stops)
  double meilleureDistance = double.infinity;
  List<dynamic> meilleurChemin = [];

  // on recupere toutes les combinaisons possibles des musées à visiter
  final toutesLesPossibilites = permutations(etapes);

  // On teste chaque ordre possible
  for (var ordre in toutesLesPossibilites) {
    var chemin = [depart, ...ordre, depart];
    // on revient au point de depart à la fin (poitn initial)
    double distance = 0.0;

    // on calcule la distance totale de ce chemin
    for (int i = 0; i < chemin.length - 1; i++) {
      var resultat = Aetoile(graphe, chemin[i], chemin[i + 1]);
      //on recupere la distance entre deux musée et s'il y a pas un chemin la distance est infini et alors on arrete -> pas de chemin
      var dist = resultat['distances']?[chemin[i + 1]] ?? double.infinity;
      if (dist == double.infinity) {
        distance = double.infinity;
        break;
      }
      distance += dist;
    }

    // on garde le meilleur chemin (le plus court)
    if (distance < meilleureDistance) {
      meilleureDistance = distance;
      meilleurChemin = chemin;
    }
  }

  return {'chemin': meilleurChemin, 'distance': meilleureDistance};
}

// Version plus rapide pour visiter tous les musées en allant à chaque fois vers le plus proche
Map<String, dynamic> voyageurRapide(
  Graph graphe,
  dynamic depart,
  List<dynamic> etapes,
) {
  //les musées dejavisités
  final visites = <dynamic>{depart};

  final chemin = [depart];
  double distanceTotale = 0.0;
  // notre position
  dynamic actuel = depart;

  // musees non visiter
  final aVisiter = List<dynamic>.from(etapes);

  while (aVisiter.isNotEmpty) {
    dynamic plusProche;
    double distMin = double.infinity;

    // on cherche le musee le plus proche de notre position actuelle
    for (final musee in aVisiter) {
      final nodeActuel = graphe.getNode(actuel)!;
      final nodeMusee = graphe.getNode(musee)!;

      final d = sqrt(
        pow(nodeActuel.lat - nodeMusee.lat, 2) +
            pow(nodeActuel.lon - nodeMusee.lon, 2),
      );

      if (d < distMin) {
        distMin = d;
        plusProche = musee;
      }
    }

    // mis à jour de chemin et les variables
    distanceTotale += distMin;
    chemin.add(plusProche);
    visites.add(plusProche);
    actuel = plusProche;
    aVisiter.remove(plusProche);
  }

  // En fin on revient au musée de départ
  final nodeFin = graphe.getNode(actuel)!;
  final nodeDebut = graphe.getNode(depart)!;

  final retour = sqrt(
    pow(nodeFin.lat - nodeDebut.lat, 2) + pow(nodeFin.lon - nodeDebut.lon, 2),
  );

  distanceTotale += retour;
  chemin.add(depart); // on revient au point de départ

  return {'chemin': chemin, 'distance': distanceTotale};
}
