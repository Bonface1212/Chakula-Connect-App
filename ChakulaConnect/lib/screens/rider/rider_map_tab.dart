// lib/screens/rider/rider_map_tab.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as rider_location;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';

class RiderMapTab extends StatefulWidget {
  const RiderMapTab({super.key});

  @override
  State<RiderMapTab> createState() => _RiderMapTabState();
}

class _RiderMapTabState extends State<RiderMapTab> with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final riderLocation = rider_location.Location();
  rider_location.LocationData? _currentLocation;
  StreamSubscription<rider_location.LocationData>? _locationSubscription;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  List<Map<String, dynamic>> _availableClaims = [];

  LatLng? _previousLocation;
  BitmapDescriptor? _bikeIcon;

  Map<String, dynamic>? _activeClaim;
  bool _pickedUp = false;

  @override
  void initState() {
    super.initState();
    _loadBikeIcon();
    _fetchCurrentLocation();
    _listenToClaims();
  }

  Future<void> _loadBikeIcon() async {
    _bikeIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(40, 40)),
      'assets/icons/rider_bike.png',
    );
  }

  Future<void> _fetchCurrentLocation() async {
    bool serviceEnabled = await riderLocation.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await riderLocation.requestService();
      if (!serviceEnabled) return;
    }

    final permissionGranted = await riderLocation.requestPermission();
    if (permissionGranted != rider_location.PermissionStatus.granted) return;

    final location = await riderLocation.getLocation();
    if (location.latitude == null || location.longitude == null) return;

    setState(() => _currentLocation = location);
    _updateRiderMarkerDirect(LatLng(location.latitude!, location.longitude!));
    _previousLocation = LatLng(location.latitude!, location.longitude!);

    _locationSubscription = riderLocation.onLocationChanged.listen((newLocation) {
      if (newLocation.latitude != null && newLocation.longitude != null) {
        _previousLocation = LatLng(newLocation.latitude!, newLocation.longitude!);
        _updateRiderMarkerDirect(_previousLocation!);
      }
    });
  }

  Future<void> _listenToClaims() async {
    final riderId = FirebaseAuth.instance.currentUser?.uid;
    if (riderId == null) return;

    FirebaseFirestore.instance.collection('claims').snapshots().listen((snapshot) {
      List<Map<String, dynamic>> available = [];
      Map<String, dynamic>? active;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;

        if (data['status'] == 'assigned' && data['riderId'] == riderId) {
          active = data;
        } else if (data['status'] == 'claimed') {
          available.add(data);
        }
      }

      setState(() => _availableClaims = available);

      if (active != null && _activeClaim == null) {
        _activeClaim = active;
        _pickedUp = false;
        _renderRoute(active, isPickup: true);
      }
    });
  }

  Future<void> _acceptClaim(Map<String, dynamic> claim) async {
    final riderId = FirebaseAuth.instance.currentUser?.uid;
    if (riderId == null) return;

    await FirebaseFirestore.instance
        .collection('claims')
        .doc(claim['id'])
        .update({'riderId': riderId, 'status': 'assigned'});

    setState(() {
      _activeClaim = claim;
      _pickedUp = false;
    });

    // Render route to donor first
    _renderRoute(claim, isPickup: true);
  }

  Future<void> _pickupDelivery() async {
    if (_activeClaim == null) return;

    setState(() => _pickedUp = true);
    // Render route from current location to recipient
    _renderRoute(_activeClaim!, isPickup: false);
  }

  Future<void> _renderRoute(Map<String, dynamic> claim, {required bool isPickup}) async {
    if (_previousLocation == null) return;

    final riderLatLng = _previousLocation!;
    final donorData = claim['donorLocation'];
    final recipientData = claim['recipientLocation'];

    if (donorData == null || donorData['lat'] == null || donorData['lng'] == null) return;
    if (recipientData == null || recipientData['lat'] == null || recipientData['lng'] == null) return;

    final donorLatLng = LatLng(donorData['lat'], donorData['lng']);
    final recipientLatLng = LatLng(recipientData['lat'], recipientData['lng']);

    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    final polylinePoints = PolylinePoints(apiKey: apiKey);

    // Determine current destination
    final destinationLatLng = isPickup ? donorLatLng : recipientLatLng;

    final result = await polylinePoints.getRouteBetweenCoordinates(
      request: PolylineRequest(
        origin: PointLatLng(riderLatLng.latitude, riderLatLng.longitude),
        destination: PointLatLng(destinationLatLng.latitude, destinationLatLng.longitude),
        mode: TravelMode.driving,
      ),
    );

    if (result.points.isEmpty) return;

    final points = result.points.map((p) => LatLng(p.latitude, p.longitude)).toList();

    setState(() {
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: PolylineId(isPickup ? 'pickupRoute' : 'dropoffRoute'),
          color: isPickup ? Colors.blue : Colors.green,
          width: 6,
          points: points,
        ),
      );

      // Donor & recipient markers
      _markers
        ..removeWhere((m) => m.markerId.value != 'rider')
        ..addAll([
          Marker(
            markerId: const MarkerId('donor'),
            position: donorLatLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: const InfoWindow(title: 'Donor Location'),
          ),
          Marker(
            markerId: const MarkerId('recipient'),
            position: recipientLatLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: const InfoWindow(title: 'Recipient Location'),
          ),
        ]);
    });

    // Center map on rider
    if (_mapController != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(riderLatLng, 16),
      );
    }

    _animateRiderAlongPolyline(points);
  }

  Future<void> _animateRiderAlongPolyline(List<LatLng> polyline) async {
    if (polyline.isEmpty) return;
    const int segmentDuration = 400;

    for (int i = 0; i < polyline.length - 1; i++) {
      final start = polyline[i];
      final end = polyline[i + 1];

      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: segmentDuration),
      );

      final anim = LatLngTween(begin: start, end: end).animate(controller);
      anim.addListener(() => _updateRiderMarkerDirect(anim.value));

      await controller.forward();
      controller.dispose();
      _previousLocation = end;
    }
  }

  void _updateRiderMarkerDirect(LatLng position) {
    final riderMarker = Marker(
      markerId: const MarkerId('rider'),
      position: position,
      anchor: const Offset(0.5, 0.5),
      icon: _bikeIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      infoWindow: const InfoWindow(title: 'You (Rider)'),
    );

    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'rider');
      _markers.add(riderMarker);
    });
  }

  void _makeCall(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cannot launch dialer')));
    }
  }

  void _launchGoogleMapsNavigation() async {
    if (_activeClaim == null || _previousLocation == null) return;

    final destinationData = !_pickedUp
        ? _activeClaim!['donorLocation']
        : _activeClaim!['recipientLocation'];

    if (destinationData == null) return;

    final double? lat = destinationData['lat'];
    final double? lng = destinationData['lng'];
    if (lat == null || lng == null) return;

    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&origin=${_previousLocation!.latitude},${_previousLocation!.longitude}&destination=$lat,$lng&travelmode=driving');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps')),
      );
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _activeClaim != null
          ? FloatingActionButton.extended(
        onPressed: _launchGoogleMapsNavigation,
        icon: const Icon(Icons.navigation),
        label: const Text("Navigate"),
      )
          : null,
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) => _mapController = controller,
            initialCameraPosition: const CameraPosition(
              target: LatLng(-1.286389, 36.817223),
              zoom: 14,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            mapToolbarEnabled: false,
          ),

          // Available claims (status: claimed)
          if (_availableClaims.isNotEmpty && _activeClaim == null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(10),
                color: Colors.white.withOpacity(0.95),
                child: SizedBox(
                  height: 160,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _availableClaims.length,
                    itemBuilder: (context, index) {
                      final claim = _availableClaims[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Food: ${claim['foodName'] ?? 'Food'}',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.call),
                                    label: const Text('Donor'),
                                    onPressed: () =>
                                        _makeCall(claim['donorPhone'] ?? ''),
                                  ),
                                  const SizedBox(width: 6),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.call),
                                    label: const Text('Recipient'),
                                    onPressed: () =>
                                        _makeCall(claim['recipientPhone'] ?? ''),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ElevatedButton(
                                onPressed: () => _acceptClaim(claim),
                                child: const Text("Accept Delivery"),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

          // Pickup button
          if (_activeClaim != null && !_pickedUp)
            Positioned(
              bottom: 180,
              left: 10,
              right: 10,
              child: ElevatedButton(
                onPressed: _pickupDelivery,
                child: const Text("Picked Up Delivery"),
              ),
            ),
        ],
      ),
    );
  }
}

// Helper Tween
class LatLngTween extends Tween<LatLng> {
  LatLngTween({required LatLng begin, required LatLng end}) : super(begin: begin, end: end);

  @override
  LatLng lerp(double t) => LatLng(
    begin!.latitude + (end!.latitude - begin!.latitude) * t,
    begin!.longitude + (end!.longitude - begin!.longitude) * t,
  );
}
