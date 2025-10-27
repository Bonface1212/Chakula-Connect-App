// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:async';
import 'package:chakula_connect/screens/recipient/map_tab.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
// ignore: unused_import
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DonorMapTab extends StatefulWidget {
  final String? claimId;
  const DonorMapTab({super.key, this.claimId});

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

  // ignore: unused_field
  final PolylinePoints _polylinePoints = PolylinePoints(
    apiKey: 'YOUR_GOOGLE_MAPS_API_KEY',
  );

  String _deliveryStatus = "Waiting for status...";
  String? _riderPhone;
  String? _recipientPhone;
  BitmapDescriptor? _riderIcon;
  BitmapDescriptor? _homeIcon;

  String? _donationName;
  String? _recipientName;
  String? _imageUrl;
  String? _updatedAtText;
  
  get statusText => null;

  @override
  void initState() {
    super.initState();
    _loadCustomMarkers();
    if (widget.claimId != null) {
      _listenToRiderLocation();
    }
  }

  @override
  void dispose() {
    _riderSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCustomMarkers() async {
  
    _riderIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/icons/rider_bike.png',
    );

    _homeIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/icons/home_marker.png',
    );
    setState(() {});
  }

  void _listenToRiderLocation() {
    _riderSubscription = FirebaseFirestore.instance
        .collection('claims')
        .doc(widget.claimId)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) return;
      final data = snapshot.data() as Map<String, dynamic>;

      _riderPhone = data['riderPhone'];
      _recipientPhone = data['recipientPhone'];
      _donationName = data['donationName'];
      _recipientName = data['recipientName'];
      _imageUrl = data['imageUrl'];

      Timestamp? updatedAt = data['updatedAt'];
      if (updatedAt != null) {
        final date = updatedAt.toDate();
        _updatedAtText = DateFormat('MMM d, yyyy h:mm a').format(date);
      }

      final String status = data['status'] ?? 'pending';
      String statusText = _getStatusText(status);

      if (data['riderLocation'] != null) {
        final GeoPoint riderGeo = data['riderLocation'];
        _riderLatLng = LatLng(riderGeo.latitude, riderGeo.longitude);
        _updateMarker('rider', _riderLatLng!, _riderIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue), 'Rider Location');
      }

      if (data['destination'] != null) {
        final GeoPoint destGeo = data['destination'];
        _destinationLatLng = LatLng(destGeo.latitude, destGeo.longitude);
        _updateMarker('destination', _destinationLatLng!, _homeIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed), 'Recipient Destination');
      }

      if (_riderLatLng != null && _destinationLatLng != null) {
        await _drawPolyline(statusText);
      } else {
        setState(() {
          _deliveryStatus = statusText;
        });
      }
    });
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'assigned':
        return "Assigned";
      case 'enroute':
        return "En route";
      case 'arrived':
        return "Arrived";
      case 'delivered':
        return "Delivered";
      default:
        return "Pending";
    }
  }

Future<void> _drawPolyline(dynamic result) async {
  // ignore: unused_local_variable
  final request = RouteRequest(
    origin: PointLatLng(_riderLatLng!.latitude, _riderLatLng!.longitude),
    destination: PointLatLng(_destinationLatLng!.latitude, _destinationLatLng!.longitude),
    travelMode: TravelMode.driving, apiKey: '',
  );
    

    if (result.points.isNotEmpty) {
      final polylineCoordinates = result.points
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();

      setState(() {
        _polylines.clear();
        _polylines.add(Polyline(
          polylineId: const PolylineId('route'),
          color: Colors.orange,
          width: 6,
          points: polylineCoordinates,
        ));
      });
    }

    if (result.status == 'OK' && result.routes.isNotEmpty) {
      final durationInSec = result.routes.first.durationValue;
      final etaMinutes = (durationInSec / 60).ceil();

      setState(() {
        _deliveryStatus = "ETA: $etaMinutes min • $statusText";
      });
    } else {
      setState(() {
        _deliveryStatus = statusText;
      });
    }
  }

  void _updateMarker(String id, LatLng position, BitmapDescriptor icon, String title) {
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == id);
      _markers.add(Marker(
        markerId: MarkerId(id),
        position: position,
        icon: icon,
        infoWindow: InfoWindow(title: title),
      ));
    });

    if (id == 'rider') {
      mapController?.animateCamera(CameraUpdate.newLatLng(position));
    }
  }

  void _makeCall(String? number) async {
    if (number != null && await canLaunchUrl(Uri.parse('tel:$number'))) {
      await launchUrl(Uri.parse('tel:$number'));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cannot launch dialer")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.claimId == null) {
      return const Center(
        child: Text('No delivery is currently being tracked.', style: TextStyle(fontSize: 16)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Track Delivery"),
        backgroundColor: Colors.orange[700],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) => mapController = controller,
            initialCameraPosition: CameraPosition(
              target: _riderLatLng ?? const LatLng(-1.2921, 36.8219),
              zoom: 14,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(_imageUrl!, height: 150, fit: BoxFit.cover),
                  ),
                const SizedBox(height: 6),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Donation: ${_donationName ?? 'N/A'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('Recipient: ${_recipientName ?? 'N/A'}'),
                        if (_updatedAtText != null)
                          Text('Last updated: $_updatedAtText', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.delivery_dining, color: Colors.orange[700]),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_deliveryStatus, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
                            IconButton(
                              icon: const Icon(Icons.call, color: Colors.green),
                              onPressed: () => _makeCall(_riderPhone),
                              tooltip: 'Call Rider',
                            ),
                            IconButton(
                              icon: const Icon(Icons.person_pin_circle, color: Colors.deepPurple),
                              onPressed: () => _makeCall(_recipientPhone),
                              tooltip: 'Call Recipient',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _riderLatLng != null
          ? FloatingActionButton(
              backgroundColor: Colors.orange[700],
              onPressed: () => mapController?.animateCamera(
                CameraUpdate.newLatLng(_riderLatLng!),
              ),
              child: const Icon(Icons.my_location),
            )
          : null,
    );
  }
}

extension on PolylineResult {
}