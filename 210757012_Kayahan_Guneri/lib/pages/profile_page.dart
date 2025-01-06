import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';

// Profil sayfası - kullanıcı bilgileri ve ayarları
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Kullanıcı bilgilerini ve tercihlerini tutan değişkenler
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = true;
  bool _notificationsEnabled = true;
  List<Map<String, dynamic>> _favoriteEvents = [];
  Map<String, bool> _notificationPreferences = {
    'newEvents': true,
    'reminders': true,
    'updates': true,
  };

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadNotificationPreferences();
  }

  // Kullanıcı bilgilerini Firebase'den yükler
  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        setState(() {
          _nameController.text = userData['name'] ?? '';
          _emailController.text = userData['email'] ?? '';
        });
      }

      // Favori etkinlikleri yükle
      final eventsQuery = await FirebaseFirestore.instance
          .collection('events')
          .where('favorites', arrayContains: user.uid)
          .get();

      setState(() {
        _favoriteEvents = eventsQuery.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Profil yükleme hatası: $e');
      setState(() => _isLoading = false);
    }
  }

  // Bildirim tercihlerini yerel depolamadan yükler
  Future<void> _loadNotificationPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _notificationPreferences = {
        'newEvents': prefs.getBool('notify_new_events') ?? true,
        'reminders': prefs.getBool('notify_reminders') ?? true,
        'updates': prefs.getBool('notify_updates') ?? true,
      };
    });
  }

  // Profil bilgilerini Firebase'de günceller
  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'name': _nameController.text.trim(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil güncellendi')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil güncellenirken hata oluştu')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Bildirim ayarlarını yerel depolamada günceller
  Future<void> _updateNotificationPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setBool(
        'notify_new_events', _notificationPreferences['newEvents']!);
    await prefs.setBool(
        'notify_reminders', _notificationPreferences['reminders']!);
    await prefs.setBool('notify_updates', _notificationPreferences['updates']!);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bildirim ayarları güncellendi')),
    );
  }

  // Kullanıcı oturumunu kapatır
  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Çıkış yapılırken hata oluştu')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final darkBlue = Color(0xFF1A237E);
    final mediumBlue = Color(0xFF3949AB);
    final lightBlue = Color(0xFF5C6BC0);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: darkBlue,
        title: const Text('Profil', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _signOut,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.grey[100]!, Colors.white],
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Profil Bilgileri',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: darkBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Ad Soyad',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide:
                                      BorderSide(color: mediumBlue, width: 2),
                                ),
                                labelStyle: TextStyle(color: mediumBlue),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'E-posta',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                              enabled: false,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _updateProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: mediumBlue,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Profili Güncelle'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bildirim Ayarları',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: darkBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SwitchListTile(
                              title: const Text('Bildirimleri Etkinleştir'),
                              value: _notificationsEnabled,
                              activeColor: mediumBlue,
                              onChanged: (value) {
                                setState(() => _notificationsEnabled = value);
                                _updateNotificationPreferences();
                              },
                            ),
                            if (_notificationsEnabled) ...[
                              CheckboxListTile(
                                title: const Text('Yeni Etkinlik Bildirimleri'),
                                value: _notificationPreferences['newEvents'],
                                activeColor: mediumBlue,
                                onChanged: (value) {
                                  setState(() =>
                                      _notificationPreferences['newEvents'] =
                                          value ?? true);
                                  _updateNotificationPreferences();
                                },
                              ),
                              CheckboxListTile(
                                title: const Text('Etkinlik Hatırlatıcıları'),
                                value: _notificationPreferences['reminders'],
                                activeColor: mediumBlue,
                                onChanged: (value) {
                                  setState(() =>
                                      _notificationPreferences['reminders'] =
                                          value ?? true);
                                  _updateNotificationPreferences();
                                },
                              ),
                              CheckboxListTile(
                                title: const Text('Etkinlik Güncellemeleri'),
                                value: _notificationPreferences['updates'],
                                activeColor: mediumBlue,
                                onChanged: (value) {
                                  setState(() =>
                                      _notificationPreferences['updates'] =
                                          value ?? true);
                                  _updateNotificationPreferences();
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Favori Etkinlikler',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: darkBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_favoriteEvents.isEmpty)
                              Center(
                                child: Text(
                                  'Henüz favori etkinliğiniz yok',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _favoriteEvents.length,
                                itemBuilder: (context, index) {
                                  final event = _favoriteEvents[index];
                                  return Card(
                                    elevation: 2,
                                    margin: const EdgeInsets.only(bottom: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ListTile(
                                      title: Text(
                                        event['name'] ?? 'İsimsiz Etkinlik',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(event['date'] ??
                                          'Tarih belirtilmemiş'),
                                      trailing: IconButton(
                                        icon: Icon(Icons.favorite,
                                            color: mediumBlue),
                                        onPressed: () async {
                                          await FirebaseFirestore.instance
                                              .collection('events')
                                              .doc(event['id'])
                                              .update({
                                            'favorites':
                                                FieldValue.arrayRemove([
                                              FirebaseAuth
                                                  .instance.currentUser?.uid
                                            ])
                                          });
                                          _loadUserData();
                                        },
                                      ),
                                    ),
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
    );
  }
}
