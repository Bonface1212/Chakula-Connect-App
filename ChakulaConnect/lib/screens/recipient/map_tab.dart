// lib/screens/recipient/map_tab.dart
// ignore_for_file: use_build_context_synchronously, depend_on_referenced_packages

import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MapTab extends StatefulWidget {
  final String? claimId;
  const MapTab({super.key, this.claimId});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  GoogleMapController? _mapController;
  LatLng? _recipientLocation;
  LatLng? _riderLocation;
  LatLng? _donorLocation;

  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  double? _distanceInMeters;
  String? _etaText;
  StreamSubscription<DocumentSnapshot>? _claimSub;

  BitmapDescriptor? _riderIcon;
  BitmapDescriptor? _donorIcon;
  BitmapDescriptor? _recipientIcon;

  // Rider animation
  LatLng? _animatedRiderPosition;
  Timer? _animationTimer;
  int _animationIndex = 0;
  List<LatLng> _animationPoints = [];

  @override
  void initState() {
    super.initState();
    _loadCustomMarkers();
    _fetchCurrentLocation();

    if (widget.claimId != null && widget.claimId!.isNotEmpty) {
      _listenToClaim();
    } else {
      _showNearbyRiders();
    }
  }

  Future<void> _loadCustomMarkers() async {
    _riderIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(32, 32)),
      'assets/icons/rider_bike.png',
    );

    _donorIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(32, 32)),
      'assets/icons/home_marker.png',
    );

    _recipientIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(32, 32)),
      'assets/images/avatar_placeholder.png',
    );
  }

  Future<void> _fetchCurrentLocation() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return;

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
    );

    setState(() => _recipientLocation = LatLng(pos.latitude, pos.longitude));
    _moveCamera(_recipientLocation!);
  }

  void _moveCamera(LatLng target) {
    if (_mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(target, 14));
    }
  }

  void _listenToClaim() {
    final docRef = FirebaseFirestore.instance.collection('claims').doc(widget.claimId);

    _claimSub = docRef.snapshots().listen((doc) async {
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;
      final riderLoc = data['riderLocation'];
      final donorLoc = data['donorLocation'];
      final status = data['status'] ?? 'claimed';

      if (donorLoc != null && donorLoc['lat'] != null && donorLoc['lng'] != null) {
        _donorLocation = LatLng(donorLoc['lat'], donorLoc['lng']);
      }

      if ((status == 'accepted' || status == 'enroutePickup') &&
          riderLoc != null &&
          riderLoc['lat'] != null &&
          riderLoc['lng'] != null) {
        _riderLocation = LatLng(riderLoc['lat'], riderLoc['lng']);
        await _drawRoute(status: status);
        _moveCamera(_riderLocation!);
      } else {
        _riderLocation = null;
        _polylines.clear();
      }

      setState(() {
        _markers = {
          Marker(
            markerId: const MarkerId("recipient"),
            position: _recipientLocation!,
            icon: _recipientIcon ?? BitmapDescriptor.defaultMarker,
            infoWindow: const InfoWindow(title: "You (Recipient)"),
          ),
          if (_donorLocation != null)
            Marker(
              markerId: const MarkerId("donor"),
              position: _donorLocation!,
              icon: _donorIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              infoWindow: const InfoWindow(title: "Donor Location"),
            ),
          if (_riderLocation != null)
            Marker(
              markerId: const MarkerId("rider"),
              position: _animatedRiderPosition ?? _riderLocation!,
              icon: _riderIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
              infoWindow: const InfoWindow(title: "Rider"),
            ),
        };
      });
    });
  }

  Future<void> _drawRoute({required String status}) async {
    if (_riderLocation == null) return;

    LatLng destination;
    if (status == 'accepted') {
      if (_donorLocation == null) return;
      destination = _donorLocation!;
    } else if (status == 'enroutePickup') {
      if (_recipientLocation == null) return;
      destination = _recipientLocation!;
    } else {
      return;
    }

    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) return;

    final polylinePoints = PolylinePoints(apiKey: dotenv.env['GOOGLE_MAPS_API_KEY']!);

    final result = await polylinePoints.getRouteBetweenCoordinates(
      request: PolylineRequest(
        origin: PointLatLng(_riderLocation!.latitude, _riderLocation!.longitude),
        destination: PointLatLng(destination.latitude, destination.longitude),
        mode: TravelMode.driving,
      ),
    );


    if (result.points.isEmpty) return;

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
        destination.latitude,
        destination.longitude,
      );
      _etaText = _calculateETA(_distanceInMeters!);

      _animationPoints = points;
      _animationIndex = 0;
      _animatedRiderPosition = _animationPoints.first;
      _startRiderAnimation();
    });
  }

  void _startRiderAnimation() {
    _animationTimer?.cancel();
    if (_animationPoints.isEmpty) return;

    _animationTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_animationIndex < _animationPoints.length) {
        setState(() {
          _animatedRiderPosition = _animationPoints[_animationIndex];
          _markers = _markers.map((marker) {
            if (marker.markerId.value == "rider") {
              return marker.copyWith(positionParam: _animatedRiderPosition);
            }
            return marker;
          }).toSet();
        });
        _animationIndex++;
      } else {
        timer.cancel();
      }
    });
  }

  // When there is no claim, show nearby online riders
  Future<void> _showNearbyRiders() async {
    if (_recipientLocation == null) return;

    final ridersQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'Rider')
        .where('isOnline', isEqualTo: true)
        .get();

    final nearbyRiders = ridersQuery.docs.map((r) {
      final loc = r['location'] as String?; // store as lat,lng string in your riders' collection
      if (loc == null) return null;
      final parts = loc.split(',');
      if (parts.length != 2) return null;
      return LatLng(double.tryParse(parts[0])!, double.tryParse(parts[1])!);
    }).whereType<LatLng>().toList();

    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId("recipient"),
          position: _recipientLocation!,
          icon: _recipientIcon ?? BitmapDescriptor.defaultMarker,
          infoWindow: const InfoWindow(title: "You (Recipient)"),
        ),
        ...nearbyRiders.map((riderLoc) => Marker(
          markerId: MarkerId("rider_${riderLoc.latitude}_${riderLoc.longitude}"),
          position: riderLoc,
          icon: _riderIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: "Online Rider"),
        )),
      };
    });
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 1000; // meters
  }

  String _calculateETA(double distanceMeters) {
    const avgSpeedKmh = 40; // average delivery speed
    final etaMinutes = distanceMeters / 1000 / avgSpeedKmh * 60;
    return "${etaMinutes.toStringAsFixed(0)} min";
  }

  @override
  void dispose() {
    _claimSub?.cancel();
    _animationTimer?.cancel();
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
            markers: _markers,
            onMapCreated: (controller) => _mapController = controller,
          ),
          if (_distanceInMeters != null)
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
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
                  ],
                ),
                child: Text(
                  "Distance: ${(_distanceInMeters! / 1000).toStringAsFixed(2)} km • ETA: $_etaText",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
