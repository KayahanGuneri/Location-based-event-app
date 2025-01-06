import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'map_page.dart';
import 'event_detail_page.dart';
import 'profile_page.dart';

// Ana sayfa - etkinliklerin listelendiği ve filtrelendiği sayfa
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // API ve durum yönetimi için gerekli değişkenler
  final String _apiKey = 'QOda5s5NP43WgkAUJtSdpPBC4E0J6smy';
  List<dynamic> _events = [];
  String _selectedCategory = 'all';
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // Kullanıcının mevcut konumunu alır ve konum izinlerini kontrol eder
  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        await _fetchEvents();
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() => _currentPosition = position);
      await _fetchEvents();
    } catch (e) {
      await _fetchEvents();
    }
  }

  // Ticketmaster API'sinden etkinlikleri çeker
  Future<void> _fetchEvents() async {
    setState(() => _isLoading = true);
    try {
      String url = 'https://app.ticketmaster.com/discovery/v2/events.json?'
          'apikey=$_apiKey'
          '&locale=*';

      if (_currentPosition != null) {
        url +=
            '&latlong=${_currentPosition!.latitude},${_currentPosition!.longitude}';
      }

      if (_selectedCategory != 'all') {
        url += '&classificationName=$_selectedCategory';
      }

      if (_searchController.text.isNotEmpty) {
        url += '&keyword=${_searchController.text}';
      }

      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      setState(() {
        _events = data['_embedded']?['events'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Etkinlikler yüklenirken hata oluştu')),
        );
      }
    }
  }

  // Ana sayfa arayüzünü oluşturur
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        title: const Text('Etkinlikler', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: () {
              print('Events for map: ${_events.length}');
              if (_events.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Henüz etkinlik yüklenmedi')),
                );
                return;
              }

              for (var event in _events) {
                print('Event: ${event['name']}');
                print('Venue: ${event['_embedded']?['venues']?.first}');
                final venue = event['_embedded']?['venues']?.first;
                if (venue != null) {
                  print(
                      'Location: ${venue['location']?['latitude']}, ${venue['location']?['longitude']}');
                }
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MapPage(events: _events),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchEvents,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Etkinlik ara...',
                hintStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.secondary.withOpacity(0.3),
              ),
              onSubmitted: (_) => _fetchEvents(),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                _filterChip('Tümü', 'all'),
                _filterChip('Müzik', 'Music'),
                _filterChip('Spor', 'Sports'),
                _filterChip('Sanat', 'Arts & Theatre'),
                _filterChip('Aile', 'Family'),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _events.isEmpty
                    ? const Center(child: Text('Etkinlik bulunamadı'))
                    : ListView.builder(
                        itemCount: _events.length,
                        padding: const EdgeInsets.all(8),
                        itemBuilder: (context, index) {
                          final event = _events[index];
                          final imageUrl = event['images']?.firstWhere(
                            (img) => img['ratio'] == '16_9',
                            orElse: () => event['images']?.first,
                          )?['url'];

                          return Card(
                            elevation: 4,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        EventDetailPage(event: event),
                                  ),
                                );
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (imageUrl != null)
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(4)),
                                      child: Image.network(
                                        imageUrl,
                                        width: double.infinity,
                                        height: 200,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Container(
                                            height: 200,
                                            color: Colors.grey[300],
                                            child: const Center(
                                              child: Icon(Icons.error_outline,
                                                  size: 50),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          event['name'] ?? 'İsimsiz Etkinlik',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          event['dates']?['start']
                                                  ?['localDate'] ??
                                              'Tarih belirtilmemiş',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                        ),
                                        if (event['classifications'] != null &&
                                            event['classifications'].isNotEmpty)
                                          Text(
                                            event['classifications'][0]
                                                    ['segment']?['name'] ??
                                                'Kategori belirtilmemiş',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: Colors.grey[600],
                                                ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // Kategori filtre çiplerini oluşturur
  Widget _filterChip(String label, String category) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label),
        selected: _selectedCategory == category,
        onSelected: (selected) {
          setState(() => _selectedCategory = selected ? category : 'all');
          _fetchEvents();
        },
      ),
    );
  }
}
