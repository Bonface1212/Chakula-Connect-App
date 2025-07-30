// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:chakula_connect/screens/recipient/map_tab.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class DonorMapTab extends StatefulWidget {
  final String claimId;
  const DonorMapTab({super.key, required this.claimId});

  @override
  State<DonorMapTab> createState() => _DonorMapTabState();
}

class _DonorMapTabState extends State<DonorMapTab> {
  GoogleMapController? mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  LatLng? _riderLatLng;
  LatLng? _destinationLatLng;
  StreamSubscription<DocumentSnapshot>? _riderSubscription;
  final PolylinePoints _polylinePoints = PolylinePoints(apiKey: 'AIzaSyCI_I9I8n03XY-17h-outvh0PVUvieMQdc');

  // ignore: unused_field
  final String _googleMapsApiKey = 'AIzaSyCI_I9I8n03XY-17h-outvh0PVUvieMQdc'; // ✅ Replace with your actual key

  @override
  void initState() {
    super.initState();
    _listenToRiderLocation();
  }

  @override
  void dispose() {
    _riderSubscription?.cancel();
    super.dispose();
  }

  void _listenToRiderLocation() {
    _riderSubscription = FirebaseFirestore.instance
        .collection('claims')
        .doc(widget.claimId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        var data = snapshot.data() as Map<String, dynamic>;
        if (data['riderLocation'] != null) {
          GeoPoint riderGeo = data['riderLocation'];
          _riderLatLng = LatLng(riderGeo.latitude, riderGeo.longitude);
          _updateRiderMarker(_riderLatLng!);
        }

        if (data['destination'] != null) {
          GeoPoint destGeo = data['destination'];
          _destinationLatLng = LatLng(destGeo.latitude, destGeo.longitude);
          _updateDestinationMarker(_destinationLatLng!);
        }

        if (_riderLatLng != null && _destinationLatLng != null) {
          _drawPolyline();
        }

        if (data['status'] == 'arrived') {
          _showArrivalNotification();
        }
      }
    });
  }

  void _updateRiderMarker(LatLng position) {
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'rider');
      _markers.add(Marker(
        markerId: const MarkerId('rider'),
        position: position,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'Rider Location'),
      ));
    });
    mapController?.animateCamera(CameraUpdate.newLatLng(position));
  }

  void _updateDestinationMarker(LatLng position) {
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'destination');
      _markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: position,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Destination'),
      ));
    });
  }

Future<void> _drawPolyline() async {
  final request = RouteRequest(
    origin: PointLatLng(_riderLatLng!.latitude, _riderLatLng!.longitude),
    destination: PointLatLng(_destinationLatLng!.latitude, _destinationLatLng!.longitude),
    travelMode: TravelMode.driving, apiKey: '',
  );

  final result = await _polylinePoints.getRouteBetweenCoordinates(request: request);

  if (result.points.isNotEmpty) {
    final polylineCoordinates = result.points
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();

    setState(() {
      _polylines.clear();
      _polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        color: Colors.blue,
        width: 5,
        points: polylineCoordinates,
      ));
    });
  }
}



  void _showArrivalNotification() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Rider has arrived"),
        content: const Text("Your rider has reached the pickup point."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Track Rider"),
      ),
      body: GoogleMap(
        onMapCreated: (GoogleMapController controller) {
          mapController = controller;
        },
        initialCameraPosition: CameraPosition(
          target: _riderLatLng ?? const LatLng(-1.2921, 36.8219), // Default: Nairobi
          zoom: 14,
        ),
        markers: _markers,
        polylines: _polylines,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
    );
  }
}

class RouteMode {
  // ignore: prefer_typing_uninitialized_variables, strict_top_level_inference
  static var driving;
}
