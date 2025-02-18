import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:map3terms/src/map3terms_scrambler.dart';

void main() {
  runApp(WhatFreeWordsApp());
}

class WhatFreeWordsApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WhatFreeWords Map',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.black,
        textTheme: TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
        ),
      ),
      home: WhatFreeWordsHome(),
    );
  }
}

class WhatFreeWordsHome extends StatefulWidget {
  @override
  _WhatFreeWordsHomeState createState() => _WhatFreeWordsHomeState();
}

class _WhatFreeWordsHomeState extends State<WhatFreeWordsHome> {
  final TextEditingController _inputController = TextEditingController();
  final MapController _mapController = MapController();

  LatLng _center = LatLng(51.50844113, -0.116708278); // Default: London

  @override
  void initState() {
    super.initState();
    _updateWordsFromCenter();
  }

  /// **Handles input change: Detects if input is coordinates or words**
  Future<void> _handleInput() async {
    final String input = _inputController.text.trim();

    if (_isCoordinate(input)) {
      await _updateMapFromCoordinates(input);
    } else {
      await _updateMapFromWords();
    }
  }

  /// **Checks if input is a valid coordinate format (-90 to 90, -180 to 180)**
  bool _isCoordinate(String input) {
    final RegExp coordRegex = RegExp(
      r"^(-?[0-9]{1,2}(?:\.[0-9]+)?),\s*(-?[0-9]{1,3}(?:\.[0-9]+)?)$",
    );
    return coordRegex.hasMatch(input);
  }

  /// **Centers the map from coordinates entered in the text field**
  Future<void> _updateMapFromCoordinates(String input) async {
    try {
      final parts = input.split(',');
      final double lat = double.parse(parts[0].trim());
      final double lon = double.parse(parts[1].trim());

      if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
        throw FormatException("Coordinates out of range.");
      }

      setState(() {
        _center = LatLng(lat, lon);
        _mapController.move(_center, _mapController.camera.zoom);
      });

      await _updateWordsFromCenter();
    } catch (e) {
      _showError("Invalid coordinate format. Use: lat, lon");
    }
  }

  /// **Centers the map when words are entered**
  Future<void> _updateMapFromWords() async {
    final words = _inputController.text.trim().replaceAll(" ", ".");
    if (words.isEmpty) return;

    try {
      final coords = await wordsToCoord(words);
      setState(() {
        _center = LatLng(coords[0], coords[1]);
        _mapController.move(_center, _mapController.camera.zoom);
      });
    } catch (e) {
      _showError("Invalid words format.");
    }
  }

  /// **Updates the words when the map moves**
  Future<void> _updateWordsFromCenter() async {
    try {
      final words = await coordToWords([_center.latitude, _center.longitude]);
      setState(() {
        _inputController.text = words.replaceAll(".", " ");
      });
    } catch (e) {
      print("Error converting coordinates to words: $e");
    }
  }

  /// **Centers map on user location**
  Future<void> _centerOnUserLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showError("Location permission denied.");
        return;
      }
    }

    final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    setState(() {
      _center = LatLng(position.latitude, position.longitude);
      _mapController.move(_center, _mapController.camera.zoom);
    });

    _updateWordsFromCenter();
  }

  /// **Shows error messages in a snackbar**
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: TextField(
                  controller: _inputController,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Enter Words or Coordinates',
                    labelStyle: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.w800
                    ),
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.search, color: Colors.white),
                      onPressed: _handleInput,
                    ),
                  ),
                  onSubmitted: (_) => _handleInput(),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _center,
                      initialZoom: 16.0,
                      onPositionChanged: (position, hasGesture) {
                        if (hasGesture) {
                          setState(() {
                            _center = position.center!;
                          });
                          _updateWordsFromCenter();
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}",
                        subdomains: ['a', 'b', 'c'],
                      ),
                      PolygonLayer(
                        polygons: [
                          Polygon(
                            points: _boundingBox(_center),
                            color: Colors.white.withOpacity(0.1),
                            borderStrokeWidth: 2,
                            borderColor: Colors.white,
                          ),
                        ],
                      ),
                    ],
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: CrossOverlayPainter(),
                      ),
                    ),
                  ),
                ]
              ),
            ),
            ]
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: _centerOnUserLocation,
              child: Icon(Icons.my_location, color: Colors.black),
              backgroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// **Computes the bounding box based on word grid size (~6m)**
  List<LatLng> _boundingBox(LatLng center) {
    const double wordGridSize = 0.00006; // ~6m per word

    return [
      LatLng(center.latitude + wordGridSize, center.longitude - wordGridSize),
      LatLng(center.latitude + wordGridSize, center.longitude + wordGridSize),
      LatLng(center.latitude - wordGridSize, center.longitude + wordGridSize),
      LatLng(center.latitude - wordGridSize, center.longitude - wordGridSize),
    ];
  }
}

class CrossOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5) // Adjust color & opacity
      ..strokeWidth = 1;

    // Draw horizontal line across the entire screen
    canvas.drawLine(
      Offset(0, size.height / 2) , // Left edge
      Offset(size.width, size.height / 2), // Right edge
      paint,
    );

    // Draw vertical line across the entire screen
    canvas.drawLine(
      Offset(size.width / 2, 0), // Top edge
      Offset(size.width / 2, size.height), // Bottom edge
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
