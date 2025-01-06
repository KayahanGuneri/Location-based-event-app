import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

// Etkinlik detay sayfası - seçilen etkinliğin tüm detaylarını gösterir
class EventDetailPage extends StatefulWidget {
  final Map<String, dynamic> event;

  const EventDetailPage({super.key, required this.event});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  final _commentController = TextEditingController();
  double _userRating = 0;
  bool _isFavorite = false;
  bool _isAttending = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Kullanıcının favori ve katılım durumunu yükler
  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Önce belgeyi oluşturalım
      final eventRef = FirebaseFirestore.instance
          .collection('events')
          .doc(widget.event['id']);

      // Belge var mı kontrol edelim ve yoksa oluşturalım
      final eventDoc = await eventRef.get();
      if (!eventDoc.exists) {
        await eventRef.set({
          'name': widget.event['name'],
          'date': widget.event['dates']?['start']?['localDate'],
          'favorites': [],
          'attendees': [],
          'comments': [],
          'ratings': {},
        });
      }

      // Belgeyi tekrar okuyalım
      final updatedDoc = await eventRef.get();
      final data = updatedDoc.data() as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _isFavorite =
              (data['favorites'] as List?)?.contains(user.uid) ?? false;
          _isAttending =
              (data['attendees'] as List?)?.contains(user.uid) ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Firestore bağlantı hatası: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Bağlantı hatası. Lütfen internet bağlantınızı kontrol edin.'),
          ),
        );
      }
    }
  }

  // Etkinliği favorilere ekler veya çıkarır
  Future<void> _toggleFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final eventRef =
        FirebaseFirestore.instance.collection('events').doc(widget.event['id']);

    setState(() => _isFavorite = !_isFavorite);

    if (_isFavorite) {
      await eventRef.update({
        'favorites': FieldValue.arrayUnion([user.uid])
      });
    } else {
      await eventRef.update({
        'favorites': FieldValue.arrayRemove([user.uid])
      });
    }
  }

  // Kullanıcının etkinliğe katılım durumunu değiştirir
  Future<void> _toggleAttendance() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final eventRef =
        FirebaseFirestore.instance.collection('events').doc(widget.event['id']);

    setState(() => _isAttending = !_isAttending);

    if (_isAttending) {
      await eventRef.update({
        'attendees': FieldValue.arrayUnion([user.uid])
      });
    } else {
      await eventRef.update({
        'attendees': FieldValue.arrayRemove([user.uid])
      });
    }
  }

  // Etkinliği cihazın takvimine ekler
  Future<void> _addToCalendar() async {
    final startDate =
        DateTime.parse(widget.event['dates']?['start']?['localDate']);
    final endDate = startDate.add(const Duration(hours: 2));

    final url = Uri.parse(
      'content://com.android.calendar/events',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Takvim uygulaması açılamadı')),
      );
    }
  }

  // Etkinliğe yeni yorum ekler
  Future<void> _addComment() async {
    if (_commentController.text.isEmpty) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yorum yapmak için giriş yapmalısınız')),
        );
        return;
      }

      // Kullanıcının ad soyad bilgisini users koleksiyonundan alalım
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kullanıcı bilgileri bulunamadı')),
        );
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final userFullName = userData['name']
          as String?; // 'nameController' yerine 'name' kullanıyoruz

      if (userFullName == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kullanıcı adı bilgisi bulunamadı')),
        );
        return;
      }

      setState(() => _isLoading = true);

      // Yeniden deneme mantığı
      int retryCount = 0;
      const maxRetries = 3;

      while (retryCount < maxRetries) {
        try {
          final eventRef = FirebaseFirestore.instance
              .collection('events')
              .doc(widget.event['id']);

          // Önce belgenin var olduğundan emin olalım
          final docSnapshot = await eventRef.get();
          if (!docSnapshot.exists) {
            await eventRef.set({
              'name': widget.event['name'],
              'date': widget.event['dates']?['start']?['localDate'],
              'favorites': [],
              'attendees': [],
              'comments': [],
              'ratings': {},
            });
          }

          // Yorumu ekleyelim
          await eventRef.update({
            'comments': FieldValue.arrayUnion([
              {
                'userId': user.uid,
                'userName': userFullName, // Kayıt sırasında alınan ad soyad
                'text': _commentController.text,
                'timestamp': DateTime.now().toIso8601String(),
              }
            ])
          });

          // Başarılı olduğunda döngüden çık
          break;
        } catch (e) {
          retryCount++;
          if (retryCount == maxRetries) {
            throw e; // Son denemede de başarısız olursa hatayı fırlat
          }
          // Bekle ve tekrar dene
          await Future.delayed(Duration(seconds: retryCount));
        }
      }

      // Başarılı mesajı gösterelim
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yorumunuz eklendi')),
        );
        _commentController.clear();
      }
    } catch (e) {
      print('Yorum ekleme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Bağlantı hatası. Lütfen internet bağlantınızı kontrol edin ve tekrar deneyin.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Kullanıcının etkinliğe puan vermesini sağlar
  Future<void> _rateEvent(double rating) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('events')
        .doc(widget.event['id'])
        .update({
      'ratings.${user.uid}': rating,
    });

    setState(() => _userRating = rating);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venue = widget.event['_embedded']?['venues']?.first;
    final imageUrl = widget.event['images']?.firstWhere(
      (img) => img['ratio'] == '16_9',
      orElse: () => widget.event['images']?.first,
    )?['url'];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.event['name'] ?? 'Etkinlik Detayı',
                style: const TextStyle(color: Colors.white),
              ),
              background: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: theme.colorScheme.primary,
                    ),
            ),
            actions: [
              if (!_isLoading)
                IconButton(
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: Colors.white,
                  ),
                  onPressed: _toggleFavorite,
                ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.event['name'] ?? 'İsimsiz Etkinlik',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tarih: ${DateFormat('dd.MM.yyyy').format(DateTime.parse(widget.event['dates']?['start']?['localDate']))}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (venue != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Mekan: ${venue['name']}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _toggleAttendance,
                                icon: Icon(_isAttending
                                    ? Icons.check_circle
                                    : Icons.add_circle),
                                label: Text(
                                    _isAttending ? 'Katılıyorum' : 'Katıl'),
                              ),
                              ElevatedButton.icon(
                                onPressed: _addToCalendar,
                                icon: const Icon(Icons.calendar_today),
                                label: const Text('Takvime Ekle'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Puanla',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Row(
                            children: List.generate(5, (index) {
                              return IconButton(
                                icon: Icon(
                                  index < _userRating
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: Colors.amber,
                                ),
                                onPressed: () => _rateEvent(index + 1),
                              );
                            }),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Yorum Yap',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _commentController,
                            decoration: InputDecoration(
                              hintText: 'Yorumunuzu yazın...',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.send),
                                onPressed: _addComment,
                              ),
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('events')
                                .doc(widget.event['id'])
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }

                              if (!snapshot.data!.exists) {
                                return const Text('Henüz yorum yapılmamış');
                              }

                              final data =
                                  snapshot.data!.data() as Map<String, dynamic>;
                              final comments = List<Map<String, dynamic>>.from(
                                  data['comments'] ?? []);

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Yorumlar (${comments.length})',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  if (comments.isEmpty)
                                    const Text('Henüz yorum yapılmamış')
                                  else
                                    ...comments.map((comment) => Card(
                                          margin:
                                              const EdgeInsets.only(bottom: 8),
                                          child: Padding(
                                            padding: const EdgeInsets.all(8),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  comment['userName'] ??
                                                      'Anonim',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(comment['text']),
                                              ],
                                            ),
                                          ),
                                        )),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
