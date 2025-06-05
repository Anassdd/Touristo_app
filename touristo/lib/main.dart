import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'graph.dart'; // Your graph.dart model

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

  Graph? graph;
  List<GraphNode> museums = [];
  String currentTyping = '';
  bool isTypingTo = false;

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
        _toFocus.unfocus();
      } else {
        _fromController.text = museum.name!;
        _fromFocus.unfocus();
      }
      currentTyping = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background placeholder (can be replaced by map)
          Container(color: Colors.blueGrey[50]),

          // Scrollable Bottom Panel
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
                      final from = _fromController.text;
                      final to = _toController.text;
                      if (from.isEmpty || to.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Please select both locations"),
                          ),
                        );
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Ready to calculate route from $from to $to',
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
