import 'package:flutter/material.dart';
import 'package:touristo/graph.dart'; // Votre classe Graph
import 'package:touristo/algorithm.dart'; // Vos algorithmes (Dijkstra, Bellman-Ford, A*)
import 'package:touristo/graph_display_widget.dart'; // Votre widget de visualisation du graphe (maintenant interactif)

// Enum pour représenter les différents algorithmes que l'on peut choisir
enum AlgorithmType { dijkstraSansTas, dijkstraAvecTas, bellmanFord, aStar }

void main() {
  runApp(const AlgorithmTestApp());
}

class AlgorithmTestApp extends StatelessWidget {
  const AlgorithmTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test Algorithmes Graphe',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
        ),
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
  List<dynamic> _path = []; // Le chemin calculé (liste des IDs de nœuds)
  double _totalDistance = 0.0;
  bool _isLoading = true;
  String _message = 'Initialisation du graphe...';
  Duration _executionTime = Duration.zero;

  // Nœuds de départ et d'arrivée sélectionnés par l'utilisateur
  dynamic _selectedStartNodeId;
  dynamic _selectedEndNodeId;

  // Algorithme sélectionné par défaut
  AlgorithmType _selectedAlgorithm = AlgorithmType.dijkstraAvecTas;

  // Définir la taille du graphe
  static const int _numberOfNodes = 10; // Changé à 10 nœuds

  @override
  void initState() {
    super.initState();
    _createGraphAndInitialize(); // Crée le graphe au démarrage
  }

  // Fonction pour créer un graphe simple en dur (plus grand)
  Future<void> _createGraphAndInitialize() async {
    setState(() {
      _isLoading = true;
      _message = 'Création d\'un graphe de $_numberOfNodes nœuds...';
      _path = [];
      _totalDistance = 0.0;
      _executionTime = Duration.zero;
      _selectedStartNodeId = null; // Réinitialiser les sélections
      _selectedEndNodeId = null;
    });

    try {
      final smallGraph = Graph(); // Renommé pour correspondre à 10 nœuds

      // Ajout de 10 nœuds
      for (int i = 0; i < _numberOfNodes; i++) {
        smallGraph.addNode(
          GraphNode(
            id: "Node_$i",
            lat: i * 0.5, // Distribution pour visualisation
            lon: (i % 3) * 0.7,
            name: "Nœud $i",
          ),
        );
      }

      // Ajout d'arêtes pour créer un chemin et des ramifications (adapté pour 10 nœuds)
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
      ); // Chemin plus court vers la fin

      // Ajout de quelques connexions transversales pour la complexité
      smallGraph.addEdge(
        GraphEdge(source: "Node_0", target: "Node_4", length: 5.0),
      );
      smallGraph.addEdge(
        GraphEdge(source: "Node_1", target: "Node_6", length: 4.0),
      );
      smallGraph.addEdge(
        GraphEdge(source: "Node_2", target: "Node_7", length: 6.0),
      );
      smallGraph.addEdge(
        GraphEdge(source: "Node_3", target: "Node_9", length: 8.0),
      ); // Un autre long chemin direct

      _graph = smallGraph; // Assigner le graphe de 10 nœuds

      setState(() {
        _message =
            'Graphe de $_numberOfNodes nœuds créé. Sélectionnez les nœuds de départ et d\'arrivée.';
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('ERREUR FATALE lors de la création du graphe: $e');
      print('Trace de la pile: $stackTrace');
      setState(() {
        _message = 'Une erreur est survenue lors de la création du graphe: $e';
        _isLoading = false;
      });
    }
  }

  // Fonction appelée quand un nœud est tapé dans GraphDisplayWidget
  void _onNodeTapped(dynamic nodeId) {
    setState(() {
      _path = []; // Effacer le chemin précédent lors d'une nouvelle sélection
      _totalDistance = 0.0;
      _executionTime = Duration.zero;

      if (_selectedStartNodeId == null) {
        // Si aucun nœud de départ n'est sélectionné, ce nœud devient le départ
        _selectedStartNodeId = nodeId;
        _message =
            'Nœud de départ sélectionné: ${_graph?.getNode(nodeId)?.name ?? nodeId}. Sélectionnez le nœud d\'arrivée.';
      } else if (_selectedEndNodeId == null && nodeId != _selectedStartNodeId) {
        // Si un départ est sélectionné et que le nœud tapé est différent, il devient l'arrivée
        _selectedEndNodeId = nodeId;
        _message =
            'Nœud d\'arrivée sélectionné: ${_graph?.getNode(nodeId)?.name ?? nodeId}. Cliquez sur "Calculer le Chemin".';
      } else if (nodeId == _selectedStartNodeId) {
        // Si le nœud de départ est tapé à nouveau, le désélectionner
        _selectedStartNodeId = null;
        _selectedEndNodeId = null; // Réinitialiser l'arrivée aussi
        _message =
            'Nœud de départ désélectionné. Sélectionnez le nœud de départ.';
      } else if (nodeId == _selectedEndNodeId) {
        // Si le nœud d'arrivée est tapé à nouveau, le désélectionner
        _selectedEndNodeId = null;
        _message =
            'Nœud d\'arrivée désélectionné. Sélectionnez un nœud d\'arrivée.';
      } else {
        // Si les deux sont sélectionnés et qu'un autre nœud est tapé, faire de ce nœud le nouveau départ
        _selectedStartNodeId = nodeId;
        _selectedEndNodeId = null;
        _message =
            'Nouveau nœud de départ sélectionné: ${_graph?.getNode(nodeId)?.name ?? nodeId}. Sélectionnez le nœud d\'arrivée.';
      }
    });
  }

  // Fonction pour calculer le chemin avec les nœuds sélectionnés
  Future<void> _calculatePathWithSelectedNodes() async {
    if (_selectedStartNodeId == null || _selectedEndNodeId == null) {
      setState(() {
        _message =
            'Veuillez sélectionner un nœud de départ et un nœud d\'arrivée.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message =
          'Calcul du chemin entre '
          '${_graph?.getNode(_selectedStartNodeId)?.name ?? _selectedStartNodeId} '
          'et '
          '${_graph?.getNode(_selectedEndNodeId)?.name ?? _selectedEndNodeId} '
          'avec ${_selectedAlgorithm.toString().split('.').last}...';
      _path = [];
      _totalDistance = 0.0;
      _executionTime = Duration.zero;
    });

    try {
      // Chronométrer l'exécution de l'algorithme
      final Stopwatch stopwatch = Stopwatch()..start();
      Map<String, Map<dynamic, dynamic>> algorithmResult;

      switch (_selectedAlgorithm) {
        case AlgorithmType.dijkstraSansTas:
          algorithmResult = dijkstraSansTas(_graph!, _selectedStartNodeId!);
          break;
        case AlgorithmType.dijkstraAvecTas:
          algorithmResult = dijkstraAvecTas(_graph!, _selectedStartNodeId!);
          break;
        case AlgorithmType.bellmanFord:
          algorithmResult = bellmanFord(_graph!, _selectedStartNodeId!);
          break;
        case AlgorithmType.aStar:
          // A* nécessite aussi le nœud d'arrivée
          algorithmResult = Aetoile(
            _graph!,
            _selectedStartNodeId!,
            _selectedEndNodeId!,
          );
          break;
      }
      stopwatch.stop();
      _executionTime = stopwatch.elapsed;

      final predecessors =
          algorithmResult['predecesseurs'] as Map<dynamic, dynamic>?;
      final distances = algorithmResult['distances'] as Map<dynamic, double>?;

      if (predecessors == null || distances == null) {
        setState(() {
          _message =
              'Les algorithmes n\'ont pas retourné les résultats attendus.';
          _isLoading = false;
        });
        print("Erreur: Résultats de l'algorithme invalides.");
        return;
      }

      if (distances[_selectedEndNodeId] == null ||
          distances[_selectedEndNodeId]!.isInfinite) {
        setState(() {
          _message =
              'Aucun chemin trouvé de "${_graph?.getNode(_selectedStartNodeId)?.name ?? _selectedStartNodeId}" à "${_graph?.getNode(_selectedEndNodeId)?.name ?? _selectedEndNodeId}".';
          _path = [];
          _totalDistance = double.infinity;
          _isLoading = false;
        });
        print('Info: Aucun chemin trouvé ou destination inaccessible.');
        return;
      }

      final calculatedPath = chemin(
        _selectedStartNodeId!,
        _selectedEndNodeId!,
        predecessors,
      );

      setState(() {
        _path = calculatedPath;
        _totalDistance = distances[_selectedEndNodeId] ?? double.infinity;
        _message = 'Algorithme terminé. Chemin trouvé !';
        _isLoading = false;
      });

      print(
        '--- Résultats du Test Algorithme (${_selectedAlgorithm.toString().split('.').last}) ---',
      );
      print(
        'Temps d\'exécution: ${_executionTime.inMicroseconds} microsecondes',
      );
      print(
        'Nœud de Départ: $_selectedStartNodeId (${_graph?.getNode(_selectedStartNodeId)?.name ?? 'N/A'})',
      );
      print(
        'Nœud d\'Arrivée: $_selectedEndNodeId (${_graph?.getNode(_selectedEndNodeId)?.name ?? 'N/A'})',
      );
      if (_path.isNotEmpty) {
        print(
          'Chemin: ${_path.map((id) => _graph?.getNode(id)?.name ?? id).join(" -> ")}',
        );
        print('Distance Totale: ${_totalDistance.toStringAsFixed(2)}');
      } else if (_totalDistance.isInfinite) {
        print('Aucun chemin trouvé ou nœud d\'arrivée inaccessible.');
      } else {
        print('Le chemin est vide (le départ est peut-être l\'arrivée).');
      }
      print('----------------------------------------------------');
    } catch (e, stackTrace) {
      print('ERREUR FATALE lors de l\'exécution de l\'algorithme: $e');
      print('Trace de la pile: $stackTrace');
      setState(() {
        _message = 'Une erreur est survenue: $e';
        _isLoading = false;
      });
    }
  }

  // Fonction pour réinitialiser les sélections et les résultats
  void _clearSelections() {
    setState(() {
      _selectedStartNodeId = null;
      _selectedEndNodeId = null;
      _path = [];
      _totalDistance = 0.0;
      _executionTime = Duration.zero;
      _message = 'Sélectionnez un nœud de départ.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Algorithmes de Chemin (Interactif)'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Graphe de $_numberOfNodes Nœuds Interactif',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              // Sélecteur d'algorithme
              DropdownButtonFormField<AlgorithmType>(
                value: _selectedAlgorithm,
                decoration: InputDecoration(
                  labelText: 'Choisir l\'algorithme',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.settings),
                ),
                onChanged: (AlgorithmType? newValue) {
                  setState(() {
                    _selectedAlgorithm = newValue!;
                    _clearSelections(); // Réinitialise les sélections quand l'algo change
                    _message = 'Algorithme changé. Sélectionnez les nœuds.';
                  });
                },
                items: AlgorithmType.values
                    .map<DropdownMenuItem<AlgorithmType>>((AlgorithmType algo) {
                      String name = '';
                      switch (algo) {
                        case AlgorithmType.dijkstraSansTas:
                          name = 'Dijkstra (Sans Tas)';
                          break;
                        case AlgorithmType.dijkstraAvecTas:
                          name = 'Dijkstra (Avec Tas)';
                          break;
                        case AlgorithmType.bellmanFord:
                          name = 'Bellman-Ford';
                          break;
                        case AlgorithmType.aStar:
                          name = 'A* (A-étoile)';
                          break;
                      }
                      return DropdownMenuItem<AlgorithmType>(
                        value: algo,
                        child: Text(name),
                      );
                    })
                    .toList(),
              ),
              const SizedBox(height: 20),
              // Infos sur les nœuds sélectionnés
              _buildInfoCard(
                title: 'Nœud de Départ Sélectionné',
                value: _selectedStartNodeId != null
                    ? '${_graph?.getNode(_selectedStartNodeId)?.name ?? _selectedStartNodeId}'
                    : 'Aucun',
              ),
              _buildInfoCard(
                title: 'Nœud d\'Arrivée Sélectionné',
                value: _selectedEndNodeId != null
                    ? '${_graph?.getNode(_selectedEndNodeId)?.name ?? _selectedEndNodeId}'
                    : 'Aucun',
              ),
              // Affichage du temps d'exécution
              if (_executionTime != Duration.zero && !_isLoading)
                _buildInfoCard(
                  title: 'Temps d\'exécution',
                  value: '${_executionTime.inMicroseconds} µs',
                ),
              const SizedBox(height: 20),

              // Boutons d'action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : _calculatePathWithSelectedNodes,
                      icon: _isLoading && _message.contains('Calcul')
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.route),
                      label: Text('Calculer le Chemin'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _clearSelections,
                      icon: const Icon(Icons.clear),
                      label: Text('Effacer Sélections'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Affichage du graphe
              if (_graph != null && !_isLoading)
                SizedBox(
                  height: 400, // Hauteur fixe pour la visualisation du graphe
                  child: GraphDisplayWidget(
                    graph: _graph!,
                    path: _path,
                    startNodeId:
                        _selectedStartNodeId, // Passer les nœuds sélectionnés
                    endNodeId:
                        _selectedEndNodeId, // Passer les nœuds sélectionnés
                    onNodeTapped: _onNodeTapped, // Passer la fonction de rappel
                  ),
                )
              else if (_isLoading)
                Container(
                  height: 400,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(),
                ),
              const SizedBox(height: 20),

              // Affichage des résultats textuels
              if (!_isLoading) ...[
                if (_message.contains('Chemin trouvé') ||
                    _message.contains('Algorithme terminé')) ...[
                  if (_path.isNotEmpty) ...[
                    _buildInfoCard(
                      title: 'Distance la plus courte',
                      value: _totalDistance.isInfinite
                          ? 'Inaccessible'
                          : '${_totalDistance.toStringAsFixed(2)} unités',
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Détails du Chemin:',
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
                          final nodeName = node?.name ?? 'Nœud inconnu';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Text(
                              'ID: $nodeId, Nom: $nodeName',
                              style: const TextStyle(fontSize: 14),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ] else if (_totalDistance.isInfinite) ...[
                    Card(
                      elevation: 2,
                      color: Colors.yellow.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          _message,
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ] else if (_path.isEmpty &&
                      _selectedStartNodeId == _selectedEndNodeId) ...[
                    _buildInfoCard(
                      title: 'Distance la plus courte',
                      value: '0.00 unités (Départ et Arrivée sont identiques)',
                    ),
                    const SizedBox(height: 10),
                    const Text('Chemin: Départ et Arrivée sont le même nœud.'),
                  ],
                ] else ...[
                  // Message d'état ou d'erreur
                  Card(
                    elevation: 2,
                    color: _message.contains("Erreur")
                        ? Colors.red.shade50
                        : Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _message,
                        style: TextStyle(
                          color: _message.contains("Erreur")
                              ? Colors.red.shade800
                              : Colors.blue.shade800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
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
