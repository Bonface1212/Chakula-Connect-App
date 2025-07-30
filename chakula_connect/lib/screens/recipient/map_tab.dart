// ignore_for_file: use_build_context_synchronously, depend_on_referenced_packages

import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// ignore: unused_import
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

class MapTab extends StatefulWidget {
  final String claimId;
  const MapTab({super.key, required this.claimId});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  GoogleMapController? _mapController;
  LatLng? _recipientLocation;
  LatLng? _riderLocation;
  LatLng? _donorLocation;
  Set<Polyline> _polylines = {};
  double? _distanceInMeters;
  StreamSubscription<DocumentSnapshot>? _claimSub;

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
    _listenToClaim();
  }

  Future<void> _fetchCurrentLocation() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best));

    setState(() => _recipientLocation = LatLng(pos.latitude, pos.longitude));
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_recipientLocation!, 14));
  }

  void _listenToClaim() {
    final docRef = FirebaseFirestore.instance.collection('claims').doc(widget.claimId);

    _claimSub = docRef.snapshots().listen((doc) {
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;
      final riderLoc = data['riderLocation'];
      final donorLoc = data['donorLocation'];
      final status = data['status'];

      if (riderLoc != null && riderLoc['lat'] != null && riderLoc['lng'] != null) {
        setState(() => _riderLocation = LatLng(riderLoc['lat'], riderLoc['lng']));
        _drawRoute();
      }

      if (donorLoc != null && donorLoc['lat'] != null && donorLoc['lng'] != null) {
        setState(() => _donorLocation = LatLng(donorLoc['lat'], donorLoc['lng']));
      }

      if (status == 'arrived') {
  
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Rider has arrived"),
            content: const Text("Your delivery rider has arrived at the pickup point."),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
          ),
        );
      }
    });
  }

  Future<void> _drawRoute() async {
    if (_recipientLocation == null || _riderLocation == null) return;

    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Google Maps API key missing.")),
      );
      return;
    }

    final polylinePoints = PolylinePoints(apiKey: apiKey);
    final result = await polylinePoints.getRouteBetweenCoordinates(
      request: RouteRequest(
        origin: PointLatLng(
          _riderLocation!.latitude,
          _riderLocation!.longitude,
        ),
        destination: PointLatLng(
          _recipientLocation!.latitude,
          _recipientLocation!.longitude,
        ),
        travelMode: TravelMode.driving,
        apiKey: apiKey,
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
          _riderLocation!.latitude,
          _riderLocation!.longitude,
          _recipientLocation!.latitude,
          _recipientLocation!.longitude,
        );
      });
    } else {
      debugPrint("Failed to draw polyline: ${result.errorMessage}");
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 1000;
  }

  @override
  void dispose() {
    _claimSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_recipientLocation == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _recipientLocation!,
              zoom: 14,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            polylines: _polylines,
            markers: {
              if (_recipientLocation != null)
                Marker(
                  markerId: const MarkerId("recipient"),
                  position: _recipientLocation!,
                  infoWindow: const InfoWindow(title: "You (Recipient)"),
                ),
              if (_donorLocation != null)
                Marker(
                  markerId: const MarkerId("donor"),
                  position: _donorLocation!,
                  infoWindow: const InfoWindow(title: "Donor Location"),
                ),
              if (_riderLocation != null)
                Marker(
                  markerId: const MarkerId("rider"),
                  position: _riderLocation!,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                  infoWindow: const InfoWindow(title: "Rider"),
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
                color: Colors.white.withAlpha((0.9 * 255).toInt()),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.1 * 255).toInt()),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Text(
                _distanceInMeters != null
                    ? "Distance to Rider: ${(_distanceInMeters! / 1000).toStringAsFixed(2)} km"
                    : "Waiting for rider location...",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: non_constant_identifier_names, strict_top_level_inference
RouteRequest({required PointLatLng origin, required PointLatLng destination, required TravelMode travelMode, required String apiKey}) {
}
