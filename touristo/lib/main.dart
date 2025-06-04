import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const TouristoApp());
}

class TouristoApp extends StatelessWidget {
  const TouristoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Touristo',
      debugShowCheckedModeBanner: false,
      home: const DestinationPickerPage(),
    );
  }
}

class DestinationPickerPage extends StatefulWidget {
  const DestinationPickerPage({super.key});

  @override
  State<DestinationPickerPage> createState() => _DestinationPickerPageState();
}

class _DestinationPickerPageState extends State<DestinationPickerPage> {
  final MapController _mapController = MapController();
  final TextEditingController _destinationController = TextEditingController();
  LatLng _currentCenter = LatLng(48.8566, 2.3522); // Default: Paris center

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🗺️ Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: _currentCenter,
              zoom: 13,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  setState(() {
                    _currentCenter = position.center!;
                  });
                }
              },
            ),
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
            ],
          ),

          // 📍 Center pin
          const Center(
            child: Icon(
              Icons.location_searching,
              size: 40,
              color: Colors.black,
            ),
          ),

          // 📌 Bottom panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Set your destination',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _destinationController,
                    readOnly: true,
                    onTap: () {
                      // Simulate selecting the museum under the pin
                      _destinationController.text = "Musée de l'Orangerie";
                    },
                    decoration: InputDecoration(
                      hintText: 'Select a museum',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Destination confirmed at ${_currentCenter.latitude.toStringAsFixed(5)}, ${_currentCenter.longitude.toStringAsFixed(5)}',
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Confirm destination'),
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
