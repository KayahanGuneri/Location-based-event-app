import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;

// Harita sayfası - etkinliklerin konumlarını gösterir
class MapPage extends StatefulWidget {
  final List<dynamic> events;
  const MapPage({super.key, required this.events});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Position? _currentPosition;
  bool _isLoading = true;
  CameraPosition _initialPosition = const CameraPosition(
    target: LatLng(41.0082, 28.9784),
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMap();
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  // Haritayı başlatır ve yapılandırır
  Future<void> _initializeMap() async {
    try {
      await _getCurrentLocation();
      if (_currentPosition != null) {
        _initialPosition = CameraPosition(
          target:
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          zoom: 12,
        );
      }
      _createMarkers();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Map initialization error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() => _currentPosition = position);
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  // Etkinlik konumlarını haritada işaretler
  void _createMarkers() {
    final markers = <Marker>{};
    for (var event in widget.events) {
      final venue = event['_embedded']?['venues']?.first;
      if (venue == null) continue;

      final lat = double.tryParse(venue['location']?['latitude'] ?? '');
      final lng = double.tryParse(venue['location']?['longitude'] ?? '');
      if (lat == null || lng == null) continue;

      markers.add(
        Marker(
          markerId: MarkerId(event['id'] ?? DateTime.now().toString()),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: event['name'] ?? 'İsimsiz Etkinlik',
            snippet:
                '${event['dates']?['start']?['localDate'] ?? 'Tarih belirtilmemiş'}\nDetaylar için tıklayın',
            onTap: () => _showEventDetails(event, venue),
          ),
        ),
      );
    }
    setState(() => _markers = markers);
  }

  // Etkinlik detaylarını gösterir
  Future<void> _showEventDetails(dynamic event, dynamic venue) async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event['name'] ?? 'İsimsiz Etkinlik',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Tarih: ${event['dates']?['start']?['localDate'] ?? 'Belirtilmemiş'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              'Mekan: ${venue['name'] ?? 'Belirtilmemiş'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _getDirections(venue),
              icon: const Icon(Icons.directions),
              label: const Text('Yol Tarifi Al'),
            ),
          ],
        ),
      ),
    );
  }

  // Google Maps'te yol tarifi alır
  Future<void> _getDirections(dynamic venue) async {
    final lat = venue['location']?['latitude'];
    final lng = venue['location']?['longitude'];
    if (lat == null || lng == null) return;

    final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Etkinlik Haritası')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: _initialPosition,
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
              mapType: MapType.normal,
              compassEnabled: true,
              tiltGesturesEnabled: false,
              onMapCreated: (GoogleMapController controller) {
                setState(() => _mapController = controller);
              },
            ),
    );
  }
}
