// ignore_for_file: use_build_context_synchronously, unused_import, unused_field

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:permission_handler/permission_handler.dart' as perm;

class MapTab extends ConsumerStatefulWidget {
  const MapTab({super.key});

  @override
  ConsumerState<MapTab> createState() => _MapTabState();
}

class _MapTabState extends ConsumerState<MapTab> {
  final Completer<GoogleMapController> _mapController = Completer();
  final loc.Location _location = loc.Location();
  loc.LocationData? _currentLocation;
  bool _locationPermissionGranted = false;
  bool _useFallback = false;
  bool _hasError = false;
  LatLng? _manualLocation;
  String? _selectedCategory;
  Set<Marker> _markers = {};
  StreamSubscription<QuerySnapshot>? _donationSubscription;
  Set<Polyline> _polylines = {};

  static const LatLng _fallbackLocation = LatLng(-1.2921, 36.8219); // Nairobi

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _donationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      final serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled && !await _location.requestService()) {
        _handleLocationError();
        return;
      }

      final permission = await _location.hasPermission();
      if (permission == loc.PermissionStatus.denied &&
          await _location.requestPermission() != loc.PermissionStatus.granted) {
        _handleLocationError();
        return;
      }

      _locationPermissionGranted = true;
      final locationData = await _location.getLocation();

      setState(() {
        _currentLocation = locationData;
        _useFallback = false;
        _hasError = false;
      });

      _listenToDonations();
    } catch (e) {
      _handleLocationError();
    }
  }

  void _handleLocationError() {
    setState(() {
      _useFallback = true;
      _hasError = true;
      _currentLocation = loc.LocationData.fromMap({
        'latitude': _fallbackLocation.latitude,
        'longitude': _fallbackLocation.longitude,
      });
    });
    _listenToDonations();
  }

  void _listenToDonations() {
    _donationSubscription?.cancel();

    _donationSubscription = FirebaseFirestore.instance
        .collection('donations')
        .where('isClaimed', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      Set<Marker> newMarkers = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final category = data['category'] as String?;
        final geo = data['location'];
        if (geo == null) continue;

        final lat = geo['latitude'];
        final lng = geo['longitude'];
        if (lat == null || lng == null) continue;

        if (_selectedCategory == null || _selectedCategory == category) {
          newMarkers.add(
            Marker(
              markerId: MarkerId(doc.id),
              position: LatLng(lat, lng),
              infoWindow: InfoWindow(
                title: data['title'] ?? 'Donation',
                snippet: category ?? 'No Category',
              ),
              onTap: () => _drawRouteTo(lat, lng),
            ),
          );
        }
      }
      setState(() => _markers = newMarkers);
    });
  }

  Future<void> _drawRouteTo(double lat, double lng) async {
    final userLatLng =
        _manualLocation ??
        LatLng(
          _currentLocation?.latitude ?? _fallbackLocation.latitude,
          _currentLocation?.longitude ?? _fallbackLocation.longitude,
        );

    final donationLatLng = LatLng(lat, lng);

    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          color: Colors.green,
          width: 5,
          points: [userLatLng, donationLatLng],
        ),
      };
    });

    final controller = await _mapController.future;
    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            userLatLng.latitude < donationLatLng.latitude
                ? userLatLng.latitude
                : donationLatLng.latitude,
            userLatLng.longitude < donationLatLng.longitude
                ? userLatLng.longitude
                : donationLatLng.longitude,
          ),
          northeast: LatLng(
            userLatLng.latitude > donationLatLng.latitude
                ? userLatLng.latitude
                : donationLatLng.latitude,
            userLatLng.longitude > donationLatLng.longitude
                ? userLatLng.longitude
                : donationLatLng.longitude,
          ),
        ),
        100,
      ),
    );
  }

  Future<void> _promptManualLocationInput() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enter your location"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "e.g. Nairobi, Kenya"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text("Submit"),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final locations = await geocoding.locationFromAddress(result);
        if (locations.isNotEmpty) {
          final found = locations.first;
          setState(() {
            _manualLocation = LatLng(found.latitude, found.longitude);
            _useFallback = true;
            _hasError = false;
          });
          _listenToDonations();
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Location not found")));
      }
    }
  }

  Widget _buildErrorUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("Unable to load map."),
          const SizedBox(height: 10),
          const Text("Please enable location and check permission"),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _promptManualLocationInput,
            child: const Text("Enter Location Manually"),
          ),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: _initLocation, child: const Text("Retry")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const isDarkMode = false;

    final isReady = _currentLocation != null || _manualLocation != null;

    if (!isReady) {
      return _hasError
          ? _buildErrorUI()
          : const Center(child: CircularProgressIndicator());
    }

    final initialPosition =
        _manualLocation ??
        LatLng(
          _currentLocation?.latitude ?? _fallbackLocation.latitude,
          _currentLocation?.longitude ?? _fallbackLocation.longitude,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Donation Map'),
        backgroundColor: isDarkMode ? Colors.black : Colors.green,
      ),
      body: Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                FilterChip(
                  label: const Text("All"),
                  selected: _selectedCategory == null,
                  onSelected: (_) => setState(() => _selectedCategory = null),
                ),
                const SizedBox(width: 8),
                ...["Fruits", "Vegetables", "Grains", "Other"].map((cat) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(cat),
                      selected: _selectedCategory == cat,
                      onSelected: (_) =>
                          setState(() => _selectedCategory = cat),
                    ),
                  );
                }),
              ],
            ),
          ),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: initialPosition,
                zoom: 14,
              ),
              myLocationEnabled: !_useFallback,
              myLocationButtonEnabled: true,
              markers: _markers,
              polylines: _polylines,
              onMapCreated: (controller) {
                if (!_mapController.isCompleted) {
                  _mapController.complete(controller);
                }
              },
            ),
          ),
          if (_markers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text("No donations nearby in this category."),
            ),
        ],
      ),
    );
  }
}
