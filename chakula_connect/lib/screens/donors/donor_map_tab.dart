// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api, unused_local_variable

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  _MapTabState createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  late GoogleMapController _mapController;
  LatLng? _donorLocation;
  final LatLng _recipientLocation = const LatLng(-1.2921, 36.8219); // Nairobi CBD
  Set<Polyline> _polylines = {};
  double? _distanceInMeters;

  @override
  void initState() {
    super.initState();
    _fetchDonorLocation();
  }

  Future<void> _fetchDonorLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) return;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    setState(() {
      _donorLocation = LatLng(position.latitude, position.longitude);
    });

    _mapController.animateCamera(CameraUpdate.newLatLngZoom(_donorLocation!, 14));
    _drawRoute();
  }

  Future<void> _drawRoute() async {
    if (_donorLocation == null) return;

    
    final polylinePoints = PolylinePoints(apiKey: '');

    final result = await polylinePoints.getRouteBetweenCoordinates(
      request: RouteRequest(
        origin: PointLatLng(_recipientLocation.latitude, _recipientLocation.longitude),
        destination: PointLatLng(_donorLocation!.latitude, _donorLocation!.longitude),
        travelMode: TravelMode.driving,
        apiKey: dotenv.env['GOOGLE_MAPS_API_KEY']!,
      ),
    );

    if (result.status == 'OK' && result.points.isNotEmpty) {
      final points = result.points.map((e) => LatLng(e.latitude, e.longitude)).toList();

      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId("route"),
            points: points,
            color: Colors.green,
            width: 5,
          ),
        };
        _distanceInMeters = _calculateDistance(
          _donorLocation!.latitude,
          _donorLocation!.longitude,
          _recipientLocation.latitude,
          _recipientLocation.longitude,
        );
      });
    } else {
      debugPrint("Failed to draw polyline: ${result.errorMessage}");
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295;
    final double a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 1000;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _donorLocation == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _donorLocation!,
                    zoom: 14,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  polylines: _polylines,
                  markers: {
                    Marker(
                      markerId: const MarkerId("donor"),
                      position: _donorLocation!,
                      infoWindow: const InfoWindow(title: "You (Donor)"),
                    ),
                    Marker(
                      markerId: const MarkerId("recipient"),
                      position: _recipientLocation,
                      infoWindow: const InfoWindow(title: "Recipient Location"),
                    ),
                  },
                  onMapCreated: (controller) => _mapController = controller,
                ),
                Positioned(
                  top: 40,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Text(
                      _distanceInMeters != null
                          ? "Distance to Recipient: ${(_distanceInMeters! / 1000).toStringAsFixed(2)} km"
                          : "Calculating distance...",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

 RouteRequest({required PointLatLng origin, required PointLatLng destination, required TravelMode travelMode, required String apiKey}) {}

