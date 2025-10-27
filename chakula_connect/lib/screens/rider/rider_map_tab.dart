// ignore_for_file: use_build_context_synchronously, deprecated_member_use, unused_import

import 'dart:async';
import 'dart:math';
import 'package:chakula_connect/screens/recipient/map_tab.dart';
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

class _RiderMapTabState extends State<RiderMapTab>
    with TickerProviderStateMixin {
  late GoogleMapController _mapController;
  final riderLocation = rider_location.Location();
  rider_location.LocationData? _currentLocation;
  StreamSubscription<rider_location.LocationData>? _locationSubscription;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  List<Map<String, dynamic>> _requestedClaims = [];

  LatLng? _previousLocation;
  double _riderRotation = 0.0;
  BitmapDescriptor? _bikeIcon;

  // Animation
  AnimationController? _moveController;
  Animation<LatLng>? _animation;
  LatLng? _animatedStart;
  LatLng? _animatedEnd;

  @override
  void initState() {
    super.initState();
    _loadBikeIcon();
    _fetchCurrentLocation();
    _listenToClaims();
  }

  Future<void> _loadBikeIcon() async {
    _bikeIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/icons/rider_bike.png',
    );
  }

  Future<void> _fetchCurrentLocation() async {
    final hasPermission = await riderLocation.requestPermission();
    if (hasPermission == rider_location.PermissionStatus.granted) {
      _currentLocation = await riderLocation.getLocation();
      _updateRiderMarker(_currentLocation!);

      _locationSubscription = riderLocation.onLocationChanged.listen((
        location,
      ) {
        _animateRider(LatLng(location.latitude!, location.longitude!));
      });
    }
  }

  // Convert LocationData to LatLng and update the rider marker using the existing direct updater.
  void _updateRiderMarker(rider_location.LocationData location) {
    if (location.latitude == null || location.longitude == null) return;
    final pos = LatLng(location.latitude!, location.longitude!);
    _previousLocation = pos;
    _updateRiderMarkerDirect(pos);
  }

  Future<void> _listenToClaims() async {
    final riderId = FirebaseAuth.instance.currentUser?.uid;
    if (riderId == null) return;

    FirebaseFirestore.instance.collection('claims').snapshots().listen((
      snapshot,
    ) {
      List<Map<String, dynamic>> requested = [];
      Map<String, dynamic>? active;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;

        if (data['status'] == 'assigned' && data['riderId'] == riderId) {
          active = data;
        } else if (data['status'] == 'requested') {
          requested.add(data);
        }
      }

      setState(() {
        _requestedClaims = requested;
      });

      if (active != null) _renderClaimRoute(active);
    });
  }

  void _animateRider(LatLng newLatLng) {
    if (_previousLocation == null) {
      _previousLocation = newLatLng;
      _updateRiderMarkerDirect(newLatLng);
      return;
    }

    _animatedStart = _previousLocation;
    _animatedEnd = newLatLng;
    _riderRotation = _calculateRotation(_animatedStart!, _animatedEnd!);

    _moveController?.dispose();
    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _animation =
        Tween<LatLng>(
          begin: _animatedStart,
          end: _animatedEnd,
        ).animate(_moveController!)..addListener(() {
          if (_animation != null) _updateRiderMarkerDirect(_animation!.value);
        });

    _moveController!.forward();
    _previousLocation = newLatLng;
  }

  void _updateRiderMarkerDirect(LatLng position) {
    final riderMarker = Marker(
      markerId: const MarkerId('rider'),
      position: position,
      rotation: _riderRotation,
      anchor: const Offset(0.5, 0.5),
      icon:
          _bikeIcon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      infoWindow: const InfoWindow(title: 'You (Rider)'),
    );

    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'rider');
      _markers.add(riderMarker);
    });

    _mapController.animateCamera(CameraUpdate.newLatLng(position));
  }

  double _calculateRotation(LatLng start, LatLng end) {
    final double deltaLat = end.latitude - start.latitude;
    final double deltaLng = end.longitude - start.longitude;
    final double angle = (atan2(deltaLng, deltaLat) * 180 / pi);
    return angle;
  }

  Future<void> _renderClaimRoute(Map<String, dynamic> claim) async {
      final pickup = claim['pickupLocation'];
      final dropOff = claim['dropOffLocation'];
      if (pickup == null || dropOff == null) return;

    final pickupLatLng = LatLng(pickup['lat'], pickup['lng']);
    final dropOffLatLng = LatLng(dropOff['lat'], dropOff['lng']);

    setState(() {
      _markers
        ..removeWhere(
          (m) => m.markerId.value == 'pickup' || m.markerId.value == 'dropoff',
        )
        ..addAll([
          Marker(markerId: const MarkerId('pickup'), position: pickupLatLng),
          Marker(
            markerId: const MarkerId('dropoff'),
            position: dropOffLatLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
          ),
        ]);
      _polylines.clear();
    });

    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      debugPrint('Google Maps API key missing.');
      return;
    }

    final polylinePoints = PolylinePoints(apiKey: apiKey);

    final PolylineResult result = await polylinePoints
        .getRouteBetweenCoordinates(
          request: RouteRequest(
            origin: PointLatLng(pickupLatLng.latitude, pickupLatLng.longitude),
            destination: PointLatLng(dropOffLatLng.latitude, dropOffLatLng.longitude),
            travelMode: TravelMode.driving, apiKey: '',
          ),
        );

    // The PolylinePoints package returns a string status (e.g. 'OK'), so compare against that.
    if (result.status != 'OK' || result.points.isEmpty) {
      debugPrint('Polyline error: ${result.errorMessage}');
      return;
    }

    final points = result.points
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    final polyline = Polyline(
      polylineId: const PolylineId('route'),
      color: Colors.blue,
      width: 6,
      points: points,
    );

    setState(() {
      _polylines.add(polyline);
    });
  }

  Future<void> _acceptClaim(Map<String, dynamic> claim) async {
    final riderId = FirebaseAuth.instance.currentUser?.uid;
    if (riderId == null) return;
    await FirebaseFirestore.instance
        .collection('claims')
        .doc(claim['id'])
        .update({'riderId': riderId, 'status': 'assigned'});
  }

  void _makeCall(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cannot launch dialer')));
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _moveController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initialCamera = CameraPosition(
      target: _currentLocation != null
          ? LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!)
          : const LatLng(-1.286389, 36.817223),
      zoom: 14,
    );

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) => _mapController = controller,
            initialCameraPosition: initialCamera,
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            mapToolbarEnabled: false,
          ),
          if (_requestedClaims.isNotEmpty)
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
                    itemCount: _requestedClaims.length,
                    itemBuilder: (context, index) {
                      final claim = _requestedClaims[index];
                      final donor = claim['donorName'] ?? 'Donor';
                      final recipient = claim['recipientName'] ?? 'Recipient';
                      final pickup = claim['pickupLocation'];

                      return GestureDetector(
                        onTap: () {
                          _mapController.animateCamera(
                            CameraUpdate.newLatLng(
                              LatLng(pickup['lat'], pickup['lng']),
                            ),
                          );
                        },
                        child: Card(
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
                                Text(
                                  'Donor: $donor',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text('Recipient: $recipient'),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.call),
                                      label: const Text('Donor'),
                                      onPressed: () =>
                                          _makeCall(claim['donorPhone']),
                                    ),
                                    const SizedBox(width: 6),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.call),
                                      label: const Text('Recipient'),
                                      onPressed: () =>
                                          _makeCall(claim['recipientPhone']),
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
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
// Removed local PolylineStatus mixin; use the package's status string (e.g. 'OK') instead.

