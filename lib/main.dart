import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:map3terms/src/map3terms_scrambler.dart';

void main() {
  runApp(Map3TermsApp());
}

class Map3TermsApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Map3Terms Map',
      theme: ThemeData.dark().copyWith(
        primaryColor: Color(0xff5471a8),
        scaffoldBackgroundColor: Color(0xff2d3138),
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      routerConfig: _router,
    );
  }
}

class Map3TermsHome extends StatefulWidget {
  final String? initialWords;
  Map3TermsHome({this.initialWords});

  @override
  _Map3TermsHomeState createState() => _Map3TermsHomeState();
}

class _Map3TermsHomeState extends State<Map3TermsHome> {
  final TextEditingController _inputController = TextEditingController();
  final MapController _mapController = MapController();

  LatLng _center = LatLng(51.50844113, -0.116708278); // Default: London

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.initialWords != null && widget.initialWords!.isNotEmpty) {
        await _initializeFromURL(widget.initialWords!);
      } else {
        await _updateWordsFromCenter();
      }
    });
  }

  Future<void> _initializeFromURL(String terms) async {
    terms = terms.replaceAll("-", " "); // Convert URL-friendly format
    try {
      final coords = await wordsToCoord(terms);
      setState(() {
        _center = LatLng(coords[0], coords[1]);
        _mapController.move(_center, 19.0);
        _inputController.text = terms.replaceAll(".", " "); // Show spaces instead of dots
      });
    } catch (e) {
      print("Error processing terms from URL: $e");
    }
  }

  /// **Handles input change: Detects if input is coordinates or terms**
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

  /// **Centers the map when terms are entered**
  Future<void> _updateMapFromWords() async {
    final terms = _inputController.text.trim().replaceAll(" ", ".");
    if (terms.isEmpty) return;

    try {
      final coords = await wordsToCoord(terms);
      setState(() {
        _center = LatLng(coords[0], coords[1]);
        _mapController.move(_center, _mapController.camera.zoom);
      });
    } catch (e) {
      _showError("Invalid terms format.");
    }
  }

  Future<void> _updateWordsFromCenter() async {
    try {
      final terms = await coordToWords([_center.latitude, _center.longitude]);
      setState(() {
        _inputController.text = terms.replaceAll(".", " ");
      });

      // 🌍 Update the browser URL dynamically
      final String urlWords = terms.replaceAll(".", "-");
      GoRouter.of(context).go("/?terms=$urlWords");
    } catch (e) {
      print("Error converting coordinates to terms: $e");
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
                    labelText: 'Enter 3 Terms or Coordinates',
                    labelStyle: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.w800
                    ),
                    filled: true,
                    fillColor: Color(0xff3d424e),
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
                            color: Color(0xfffcba65).withValues(alpha: 0.1),
                            borderStrokeWidth: 2,
                            borderColor: Color(0xfffcba65),
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
              child: Icon(Icons.my_location, color: Colors.white),
              backgroundColor: Color(0xff5471a8),
            ),
          ),
          Positioned(
            bottom: 80,
            right: 20,
            child: FloatingActionButton(
              onPressed: () {
                final String terms = _inputController.text.replaceAll(" ", "-"); // Convert to URL format
                final String shareableUrl = "https://randogoth.github.io/web3terms/#/?terms=$terms";
                Clipboard.setData(ClipboardData(text: shareableUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Copied to clipboard: $shareableUrl")),
                );
              },
              child: Icon(Icons.share, color: Colors.white),
              backgroundColor: Color(0xff5471a8),
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
      ..color = Color(0xff70a5d8).withValues(alpha: 0.5) // Adjust color & opacity
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

final GoRouter _router = GoRouter(
  debugLogDiagnostics: true, // Helps debug routing issues
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) {
        final String? terms = state.uri.queryParameters['terms']?.replaceAll("-", ".");
        return Map3TermsHome(initialWords: terms);
      },
    ),
  ],
);