// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DonorMapTab extends StatefulWidget {
  const DonorMapTab({super.key});

  @override
  State<DonorMapTab> createState() => _DonorMapTabState();
}

class _DonorMapTabState extends State<DonorMapTab> {
  GoogleMapController? mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  LatLng? _riderLatLng;
  LatLng? _destinationLatLng;

  StreamSubscription<QuerySnapshot>? _claimsSubscription;
  StreamSubscription<QuerySnapshot>? _onlineUsersSubscription;

  late PolylinePoints _polylinePoints;

  String _deliveryStatus = "No active delivery";
  String? _riderPhone;
  String? _recipientPhone;
  BitmapDescriptor? _riderIcon;
  BitmapDescriptor? _homeIcon;
  BitmapDescriptor? _onlineRiderIcon;
  BitmapDescriptor? _onlineRecipientIcon;

  String? _donationName;
  String? _recipientName;
  String? _imageUrl;
  String? _updatedAtText;

  bool _hasActiveDelivery = false;
  String? _activeClaimId;

  @override
  void initState() {
    super.initState();
    _initPolylinePoints();
    _loadCustomMarkers().then((_) {
      _listenToClaims();
      _listenToOnlineUsers();
    });
  }

  void _initPolylinePoints() {
    if (!dotenv.isInitialized) return;
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) return;
    _polylinePoints = PolylinePoints(apiKey: apiKey);
  }

  @override
  void dispose() {
    _claimsSubscription?.cancel();
    _onlineUsersSubscription?.cancel();
    mapController?.dispose();
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
    _onlineRiderIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/icons/rider_bike_online.png',
    );
    _onlineRecipientIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/icons/home_marker_online.png',
    );
    setState(() {});
  }

  void _listenToClaims() {
    _claimsSubscription = FirebaseFirestore.instance
        .collection('claims')
        .where('status', whereIn: ['assigned', 'enroute', 'arrived'])
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final claim = snapshot.docs.first;
        _activeClaimId = claim.id;
        _hasActiveDelivery = true;
        _updateActiveDelivery(claim);
      } else {
        _hasActiveDelivery = false;
        _activeClaimId = null;
        _clearDeliveryData();
      }
    });
  }

  void _listenToOnlineUsers() {
    _onlineUsersSubscription = FirebaseFirestore.instance
        .collection('users')
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        // Remove old online markers
        _markers.removeWhere((m) =>
        !_hasActiveDelivery ||
            (m.markerId.value != 'rider' && m.markerId.value != 'destination'));

        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final type = data['role']; // 'rider' or 'recipient'
          final loc = data['location'];
          if (loc != null) {
            final latLng = LatLng(loc.latitude, loc.longitude);
            _markers.add(Marker(
              markerId: MarkerId(doc.id),
              position: latLng,
              icon: type == 'rider'
                  ? (_onlineRiderIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue))
                  : (_onlineRecipientIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)),
              infoWindow: InfoWindow(title: data['name'] ?? type),
            ));
          }
        }
      });
    });
  }

  void _updateActiveDelivery(QueryDocumentSnapshot claim) {
    final data = claim.data() as Map<String, dynamic>;
    _riderPhone = data['riderPhone'];
    _recipientPhone = data['recipientPhone'];
    _donationName = data['donationName'];
    _recipientName = data['recipientName'];
    _imageUrl = data['imageUrl'];

    Timestamp? updatedAt = data['updatedAt'];
    if (updatedAt != null) {
      _updatedAtText =
          DateFormat('MMM d, yyyy h:mm a').format(updatedAt.toDate());
    }

    _deliveryStatus = _getStatusText(data['status'] ?? 'pending');

    if (data['riderLocation'] != null) {
      final GeoPoint riderGeo = data['riderLocation'];
      _riderLatLng = LatLng(riderGeo.latitude, riderGeo.longitude);
      _updateMarker(
        'rider',
        _riderLatLng!,
        _riderIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        'Rider Location',
      );
    }

    if (data['destination'] != null) {
      final GeoPoint destGeo = data['destination'];
      _destinationLatLng = LatLng(destGeo.latitude, destGeo.longitude);
      _updateMarker(
        'destination',
        _destinationLatLng!,
        _homeIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        'Recipient Destination',
      );
    }

    if (_riderLatLng != null && _destinationLatLng != null) {
      _drawPolyline(_deliveryStatus);
    }

    setState(() {});
  }

  void _clearDeliveryData() {
    _riderLatLng = null;
    _destinationLatLng = null;
    _donationName = null;
    _recipientName = null;
    _imageUrl = null;
    _updatedAtText = null;
    _deliveryStatus = "No active delivery";
    _polylines.clear();
    setState(() {});
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'assigned':
        return "Assigned to Rider";
      case 'enroute':
        return "Rider En Route";
      case 'arrived':
        return "Rider Arrived";
      case 'delivered':
        return "Delivered";
      default:
        return "Pending";
    }
  }

  Future<void> _drawPolyline(String statusText) async {
    if (_riderLatLng == null || _destinationLatLng == null) return;

    final result = await _polylinePoints.getRouteBetweenCoordinates(
      request: PolylineRequest(
        origin: PointLatLng(_riderLatLng!.latitude, _riderLatLng!.longitude),
        destination: PointLatLng(_destinationLatLng!.latitude, _destinationLatLng!.longitude),
        mode: TravelMode.driving,
      ),
    );

    if (result.points.isNotEmpty) {
      final polylineCoordinates =
      result.points.map((p) => LatLng(p.latitude, p.longitude)).toList();

      setState(() {
        _polylines.clear();
        _polylines.add(Polyline(
          polylineId: const PolylineId('route'),
          color: Colors.orange,
          width: 6,
          points: polylineCoordinates,
        ));
        _deliveryStatus = "En Route • $statusText";
      });
    } else {
      setState(() => _deliveryStatus = statusText);
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
    if (id == 'rider') mapController?.animateCamera(CameraUpdate.newLatLng(position));
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Donor Map"),
        backgroundColor: Colors.orange[700],
      ),
      body: GoogleMap(
        onMapCreated: (controller) => mapController = controller,
        initialCameraPosition: CameraPosition(
          target: _riderLatLng ?? const LatLng(-1.2921, 36.8219),
          zoom: 13.5,
        ),
        markers: _markers,
        polylines: _polylines,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
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
