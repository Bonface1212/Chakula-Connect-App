// lib/screens/recipient/map_tab.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:chakula_connect/main.dart'; // Import themeNotifier

class MapTab extends StatefulWidget {
  const MapTab({Key? key}) : super(key: key);

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  final Completer<GoogleMapController> _controller = Completer();
  late GoogleMapController _mapController;

  Position? _currentPosition;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final List<LatLng> _polylineCoordinates = [];
  late PolylinePoints polylinePoints;

  final String googleAPIKey = dotenv.env['GOOGLE_MAPS_API_KEY']!;

  final List<Map<String, dynamic>> mockDonations = [
    {
      'name': 'Excess Bread',
      'position': const LatLng(-1.286389, 36.817223),
      'description': 'Fresh bread from bakery',
    },
    {
      'name': 'Vegetables',
      'position': const LatLng(-1.28333, 36.81667),
      'description': 'Surplus kale and spinach',
    },
    {
      'name': 'Cooked Rice',
      'position': const LatLng(-1.29, 36.82),
      'description': 'Leftover rice from restaurant',
    },
  ];

  @override
  void initState() {
    super.initState();
    polylinePoints = PolylinePoints();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) {
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;

        _markers.removeWhere(
          (marker) => marker.markerId == const MarkerId('currentLocation'),
        );

        _markers.add(
          Marker(
            markerId: const MarkerId('currentLocation'),
            position: LatLng(position.latitude, position.longitude),
            infoWindow: const InfoWindow(title: 'You Are Here'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
          ),
        );
      });

      _loadMockDonations();

      if (_controller.isCompleted) {
        final controller = await _controller.future;
        controller.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude),
            14,
          ),
        );
      }
    } catch (e) {
      debugPrint('Location error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get location: $e')),
      );
    }
  }

  void _loadMockDonations() {
    for (var donation in mockDonations) {
      final LatLng pos = donation['position'];
      final String name = donation['name'];
      final String description = donation['description'];

      _markers.add(
        Marker(
          markerId: MarkerId(name),
          position: pos,
          infoWindow: InfoWindow(
            title: name,
            snippet: description,
            onTap: () => _drawRouteTo(pos),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }
    setState(() {});
  }

  Future<void> _drawRouteTo(LatLng destination) async {
    if (_currentPosition == null) return;

    try {
      _polylines.clear();
      _polylineCoordinates.clear();

      final result = await polylinePoints.getRouteBetweenCoordinates(
        request: PolylineRequest(
          origin: PointLatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          destination: PointLatLng(destination.latitude, destination.longitude),
          mode: TravelMode.driving,
        ),
        googleApiKey: googleAPIKey,
      );

      if (result.points.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No route found.')),
        );
        return;
      }

      for (var point in result.points) {
        _polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      }

      _polylines.add(
        Polyline(
          polylineId: PolylineId(
            'route_${DateTime.now().millisecondsSinceEpoch}',
          ),
          color: Colors.green,
          width: 5,
          points: _polylineCoordinates,
        ),
      );

      setState(() {});
      _mapController.animateCamera(CameraUpdate.newLatLng(destination));
    } catch (e) {
      debugPrint('Route drawing error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to draw route: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = themeNotifier.value == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Donation Map'),
        centerTitle: true,
        backgroundColor: isDarkMode ? Colors.black : Colors.green,
      ),
      body: _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                ),
                zoom: 14,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              markers: _markers,
              polylines: _polylines,
              onMapCreated: (controller) {
                _mapController = controller;
                _controller.complete(controller);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getCurrentLocation,
        backgroundColor: Colors.green,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
