// ignore_for_file: use_build_context_synchronously, depend_on_referenced_packages, deprecated_member_use, unused_import, unused_element

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as rider_location;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';

class RiderMapTab extends StatefulWidget {
  const RiderMapTab({super.key});

  @override
  State<RiderMapTab> createState() => _RiderMapTabState();
}

class _RiderMapTabState extends State<RiderMapTab> {
  late GoogleMapController _mapController;
  final riderLocation = rider_location.Location();
  rider_location.LocationData? _currentLocation;
  StreamSubscription<rider_location.LocationData>? _locationSubscription;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  Map<String, dynamic>? _activeClaim;

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
    _listenToClaim();
  }

  Future<void> _fetchCurrentLocation() async {
    final hasPermission = await riderLocation.requestPermission();
    if (hasPermission == rider_location.PermissionStatus.granted) {
      _currentLocation = await riderLocation.getLocation();
      _locationSubscription = riderLocation.onLocationChanged.listen((location) {
        setState(() => _currentLocation = location);
        _updateRiderMarker(location);
      });
    }
  }

  Future<void> _listenToClaim() async {
    final riderId = FirebaseAuth.instance.currentUser?.uid;
    if (riderId == null) return;

    FirebaseFirestore.instance
        .collection('claims')
        .where('riderId', isEqualTo: riderId)
        .where('status', isEqualTo: 'assigned')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final claim = doc.data();
        claim['id'] = doc.id;
        setState(() => _activeClaim = claim);
        _renderClaimRoute(claim);
      } else {
        setState(() => _activeClaim = null);
        _markers.removeWhere((m) => m.markerId.value != 'rider');
        _polylines.clear();
      }
    });
  }

  void _updateRiderMarker(rider_location.LocationData location) {
    final riderMarker = Marker(
      markerId: const MarkerId('rider'),
      position: LatLng(location.latitude!, location.longitude!),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      infoWindow: const InfoWindow(title: 'You (Rider)'),
    );

    setState(() {
      _markers.removeWhere((m) => m.markerId == riderMarker.markerId);
      _markers.add(riderMarker);
    });

    _mapController.animateCamera(
      CameraUpdate.newLatLng(LatLng(location.latitude!, location.longitude!)),
    );
  }

  Future<void> _renderClaimRoute(Map<String, dynamic> claim) async {
    final pickup = claim['pickupLocation'];
    final dropOff = claim['dropOffLocation'];
    if (pickup == null || dropOff == null) return;

    final pickupLatLng = LatLng(pickup['lat'], pickup['lng']);
    final dropOffLatLng = LatLng(dropOff['lat'], dropOff['lng']);

    setState(() {
      _markers
        ..removeWhere((m) => m.markerId.value == 'pickup' || m.markerId.value == 'dropoff')
        ..addAll([
          Marker(markerId: const MarkerId('pickup'), position: pickupLatLng),
          Marker(
            markerId: const MarkerId('dropoff'),
            position: dropOffLatLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          ),
        ]);
      _polylines.clear();
    });

    final result = await PolylinePoints(apiKey: dotenv.env['GOOGLE_MAPS_API_KEY']!)
        .getRouteBetweenCoordinates(
      request: PolylineRequest(
        origin: PointLatLng(pickupLatLng.latitude, pickupLatLng.longitude),
        destination: PointLatLng(dropOffLatLng.latitude, dropOffLatLng.longitude),
        mode: TravelMode.driving,
      ),
    );

    if (result.points.isNotEmpty) {
      final polyline = Polyline(
        polylineId: const PolylineId('route'),
        color: Colors.blue,
        width: 6,
        points: result.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
      );
      setState(() => _polylines.add(polyline));
    }
  }

  Future<void> _handleSearch() async {
    final response = await http.get(Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=Kenyatta+Hospital&components=country:ke&key=${dotenv.env['GOOGLE_MAPS_API_KEY']}',
    ));

    final data = json.decode(response.body);
    if (data['status'] == 'OK' && data['predictions'].isNotEmpty) {
      final prediction = data['predictions'][0];
      final placeId = prediction['place_id'];
      final detailsRes = await http.get(Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=${dotenv.env['GOOGLE_MAPS_API_KEY']}',
      ));

      final details = json.decode(detailsRes.body);
      final loc = details['result']['geometry']['location'];
      final name = details['result']['name'];
      final address = details['result']['formatted_address'];
      final searchedLatLng = LatLng(loc['lat'], loc['lng']);

      setState(() {
        _markers.add(
          Marker(
            markerId: const MarkerId("searchedLocation"),
            position: searchedLatLng,
            infoWindow: InfoWindow(title: name),
          ),
        );
      });

      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(searchedLatLng, 16),
      );

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('recentSearches').doc(uid).collection('places').add({
          'name': name,
          'address': address,
          'lat': loc['lat'],
          'lng': loc['lng'],
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      if (_activeClaim != null) {
        _promptUpdatePickupLocation(loc['lat'], loc['lng'], name, address);
      }
    }
  }

  void _promptUpdatePickupLocation(double lat, double lng, String name, String address) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Use This Location?"),
        content: Text("Do you want to update the pickup location to:\n$name\n$address"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final claimId = _activeClaim!['id'];
              await FirebaseFirestore.instance.collection('claims').doc(claimId).update({
                'pickupLocation': {'lat': lat, 'lng': lng},
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pickup location updated.')),
              );
              _listenToClaim();
            },
            child: const Text("Set as Pickup"),
          ),
        ],
      ),
    );
  }

  void _launchNavigation() async {
    if (_activeClaim == null) return;
    final pickup = _activeClaim!['pickupLocation'];
    final lat = pickup['lat'];
    final lng = pickup['lng'];
    final url = Uri.parse("google.navigation:q=$lat,$lng&mode=d");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch Google Maps')),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _handleSearch,
        child: const Icon(Icons.search),
      ),
      body: GoogleMap(
        onMapCreated: (controller) => _mapController = controller,
        initialCameraPosition: CameraPosition(
          target: _currentLocation != null
              ? LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!)
              : const LatLng(-1.286389, 36.817223),
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
