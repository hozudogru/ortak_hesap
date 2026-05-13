import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

Future<void> saveFcmToken() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission();
  final token = await messaging.getToken();

  if (token != null) {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'email': user.email?.trim().toLowerCase(),
      'fcmToken': token,
    }, SetOptions(merge: true));
  }
}

class Expense {
  final String id;
  final String title;
  final double amount;
  final String currency;
  final DateTime? createdAt;
  final String paidBy;
  final List<String> participants;
  final String splitType;
  final String category;
  final Map<String, double> shares;
  

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.currency,
    required this.paidBy,
    this.createdAt,
    required this.participants,
    required this.splitType,
    required this.category,
    required this.shares,
    
  });
}
class Payment {
  final String id;
  final String fromEmail;
  final String toEmail;
  final double amount;

  Payment({
    required this.id,
    required this.fromEmail,
    required this.toEmail,
    required this.amount,
  });
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
  builder: (context, child) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(1.0),
      ),
      child: child!,
    );
  },

  title: 'Ortak Hesap',

  theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C63FF)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Color(0xFF6C63FF),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: const Color(0xFF6C63FF),
          foregroundColor: Colors.white,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Color(0xFF4A43C4),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: const Color(0xFF6C63FF),
          foregroundColor: Colors.white,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E2E),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const HomePage();
        }
        return const LoginPage();
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
    void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkUnreadNotificationsPopup();
    });
  }
  bool _notificationPopupShown = false;
  String _makeGroupCode() {
    final ms = DateTime.now().millisecondsSinceEpoch.toString();
    return ms.substring(ms.length - 6);
  }
  Future<void> checkUnreadNotificationsPopup() async {
  if (_notificationPopupShown) return;

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final cleanEmail = user.email?.trim().toLowerCase();

  final snapshot = await FirebaseFirestore.instance
      .collection('notificationRequests')
      .where('toEmail', isEqualTo: cleanEmail)
      .where('isRead', isEqualTo: false)
      .get();

  if (snapshot.docs.isEmpty) return;

  _notificationPopupShown = true;

  if (!mounted) return;

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("Yeni Bildirimler"),
        content: Text(
          "${snapshot.docs.length} yeni bildirimin var.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Sonra Bak"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationsPage(),
                ),
              );
            },
            child: const Text("Bildirimleri Aç"),
          ),
        ],
      );
    },
  );
}
  Future<String> _getCurrentUserName(User user) async {
    final email = user.email?.trim().toLowerCase() ?? '';
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();
    return (data?['name'] ?? data?['nickname'] ?? email.split('@').first).toString();
  }

  Future<void> addGroupToFirebase(String groupName, String currency) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final cleanOwnerEmail = user.email?.trim().toLowerCase() ?? '';
    final ownerName = await _getCurrentUserName(user);
    final groupCode = _makeGroupCode();
    final groupRef = FirebaseFirestore.instance.collection('groups').doc(groupName.trim());

    await groupRef.set({
      'name': groupName.trim(),
      'currency': currency,
      'ownerId': user.uid,
      'ownerEmail': cleanOwnerEmail,
      'memberIds': [user.uid],
      'groupCode': groupCode,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await groupRef.collection('members').doc(user.uid).set({
      'uid': user.uid,
      'email': cleanOwnerEmail,
      'name': ownerName,
      'nickname': ownerName,
      'role': 'owner',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> joinGroupByCode(String code) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final cleanCode = code.trim();
    if (cleanCode.isEmpty) return;

    final userEmail = user.email?.trim().toLowerCase() ?? '';
    final displayName = await _getCurrentUserName(user);

    final groupQuery = await FirebaseFirestore.instance
        .collection('groups')
        .where('groupCode', isEqualTo: cleanCode)
        .limit(1)
        .get();

    if (groupQuery.docs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Grup kodu bulunamadı')),
      );
      return;
    }

    final groupDoc = groupQuery.docs.first;
    final groupRef = groupDoc.reference;
    final groupData = groupDoc.data();
    final memberIds = List<String>.from(groupData['memberIds'] ?? []);

    if (memberIds.contains(user.uid)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zaten bu gruptasın')),
      );
      return;
    }

    await groupRef.update({
      'memberIds': FieldValue.arrayUnion([user.uid]),
    });

    await groupRef.collection('members').doc(user.uid).set({
      'uid': user.uid,
      'email': userEmail,
      'name': displayName,
      'nickname': displayName,
      'role': 'member',
      'joinedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gruba katıldın')),
    );
  }

  Future<void> deleteGroupFromFirebase(String groupName) async {
    await FirebaseFirestore.instance.collection('groups').doc(groupName).delete();
  }

  void showAddGroupDialog() {
    String newGroup = '';
    String selectedCurrency = 'TRY';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
            title: const Text("Yeni Grup"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  onChanged: (value) => newGroup = value,
                  decoration: const InputDecoration(
                    labelText: "Grup adı",
                    border: OutlineInputBorder(),
                  ),
                ),

                SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  value: selectedCurrency,
                  decoration: const InputDecoration(
                    labelText: "Para Birimi",
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'TRY',
                      child: Text('TRY - Türk Lirası'),
                    ),
                    DropdownMenuItem(
                      value: 'USD',
                      child: Text('USD - Amerikan Doları'),
                    ),
                    DropdownMenuItem(
                      value: 'EUR',
                      child: Text('EUR - Euro'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      selectedCurrency = value;
                    }
                  },
                ),
              ],
            ),

            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("İptal"),
              ),

              ElevatedButton(
                onPressed: () async {
                  if (newGroup.trim().isNotEmpty) {
                    await addGroupToFirebase(
                      newGroup.trim(),
                      selectedCurrency,
                    );

                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text("Oluştur"),
              ),
            ],
          );
      },
    );
  }

  void showJoinGroupDialog() {
    String code = '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Gruba Katıl'),
          content: TextField(
            keyboardType: TextInputType.number,
            onChanged: (value) => code = value,
            decoration: const InputDecoration(hintText: 'Grup kodunu gir'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (code.trim().isNotEmpty) {
                  await joinGroupByCode(code.trim());
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Katıl'),
            ),
          ],
        );
      },
    );
  }

  void openGroupDetail(String groupName, String groupCurrency) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupDetailPage(groupName: groupName,  groupCurrency: groupCurrency),
      ),
    );
  }

  Widget _buildUserHeader(User currentUser) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get(),
      builder: (context, snapshot) {
        final email = currentUser.email?.trim().toLowerCase() ?? '';
        String name = email.split('@').first;

        if (snapshot.hasData && snapshot.data!.data() != null) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          name = (data['name'] ?? data['nickname'] ?? name).toString();
        }

        final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.teal.shade100,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.teal,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hoş geldin',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      email,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Gruba katıl',
                icon: const Icon(Icons.group_add, color: Colors.teal),
                onPressed: showJoinGroupDialog,
              ),
              IconButton(
                tooltip: "QR ile katıl",
                icon: const Icon(Icons.qr_code_scanner, color: Colors.teal),
                onPressed: () async {
                  final code = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GroupQrScannerPage(),
                    ),
                  );

    if (code != null && code.isNotEmpty) {
      await joinGroupByCode(code);
    }
  },
),
            ],
          ),
        );
      },
    );
  }


  Widget _dashboardCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 8,
        ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.22),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ortak Hesap'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: showJoinGroupDialog,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: currentUser == null
          ? const Center(child: Text('Kullanıcı bulunamadı'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('groups')
                  .where('memberIds', arrayContains: currentUser.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                return Column(
                  children: [
                    _buildUserHeader(currentUser),

                    Container(
                     
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF6C63FF),
                            Color(0xFF5A55CA),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(28),
                          bottomRight: Radius.circular(28),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Gruplarım',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 10),

                            Text(
                              'Ortak harcamalarını kolayca takip et',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 14,
                              ),
                            ),

                            const SizedBox(height: 18),

                            Row(
                              children: [
                                Expanded(
                                  child: _dashboardCard(
                                    title: 'Aktif Grup',
                                    value: docs.length.toString(),
                                    icon: Icons.group,
                                  ),
                                ),

                                const SizedBox(width: 12),

                                Expanded(
                                  child: _dashboardCard(
                                    title: 'Durum',
                                    value: 'Güncel',
                                    icon: Icons.check_circle,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

   
                    Expanded(
                      child: docs.isEmpty
                          ? const Center(
                              child: Text(
                                'Henüz grup yok.\nYeni grup eklemek için + butonuna bas veya grup kodu ile katıl.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 16),
                              ),
                            )
                          : ListView.builder(
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final data = docs[index].data() as Map<String, dynamic>;
                                final groupName = (data['name'] ?? docs[index].id).toString();
                                final groupCode = (data['groupCode'] ?? '').toString();
                                final groupCurrency = (data['currency'] ?? 'TRY').toString();

                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  elevation: 3,
                                  shadowColor: Colors.black26,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    leading: CircleAvatar(
                                      backgroundColor: [
                                        Colors.deepPurple,
                                        Colors.orange,
                                        Colors.teal,
                                        Colors.pink,
                                        Colors.indigo,
                                      ][index % 5].withOpacity(0.2),
                                      child: Icon(
                                        Icons.group,
                                        color: [
                                          Colors.deepPurple,
                                          Colors.orange,
                                          Colors.teal,
                                          Colors.pink,
                                          Colors.indigo,
                                        ][index % 5],
                                      ),
                                    ),
                                    title: Text(
                                      groupName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Text(
                                      groupCode.isEmpty
                                          ? 'Grup detaylarını görüntüle'
                                          : 'Grup kodu: $groupCode',
                                    ),
                                    trailing: PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert),
                                      onSelected: (value) {
                                        if (groupCode.isEmpty) return;

                                        if (value == 'copy') {
                                          Clipboard.setData(ClipboardData(text: groupCode));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Kod kopyalandı: $groupCode')),
                                          );
                                        }

                                        if (value == 'share') {
                                          Share.share('Gruba katıl!\nKod: $groupCode');
                                        }

                                        if (value == 'whatsapp') {
                                          Share.share('Ortak hesap grubuma katıl 👇\nKod: $groupCode');
                                        }

                                        if (value == 'qr') {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => GroupQrPage(
                                                groupName: groupName,
                                                groupCode: groupCode,
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(
                                          value: 'copy',
                                          child: Row(
                                            children: [
                                              Icon(Icons.copy, size: 18),
                                              SizedBox(width: 8),
                                              Text('Kopyala'),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'share',
                                          child: Row(
                                            children: [
                                              Icon(Icons.share, size: 18),
                                              SizedBox(width: 8),
                                              Text('Paylaş'),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'whatsapp',
                                          child: Row(
                                            children: [
                                              Icon(Icons.chat, size: 18),
                                              SizedBox(width: 8),
                                              Text('WhatsApp ile gönder'),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'qr',
                                          child: Row(
                                            children: [
                                              Icon(Icons.qr_code, size: 18),
                                              SizedBox(width: 8),
                                              Text('QR Göster'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    onTap: () => openGroupDetail(groupName, groupCurrency),
                                    onLongPress: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) {
                                          return AlertDialog(
                                            title: const Text('Grubu Sil'),
                                            content: Text('$groupName silinsin mi?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: const Text('İptal'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () async {
                                                  await deleteGroupFromFirebase(groupName);
                                                  if (context.mounted) Navigator.pop(context);
                                                },
                                                child: const Text('Sil'),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: showAddGroupDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class GroupDetailPage extends StatefulWidget {
  final String groupName;
  final String groupCurrency;

  const GroupDetailPage({
    super.key,
    required this.groupName,
    required this.groupCurrency,
  });

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  IconData categoryIcon(String category) {
  switch (category) {
    case 'food':
      return Icons.restaurant;

    case 'transport':
      return Icons.local_taxi;

    case 'hotel':
      return Icons.hotel;

    case 'market':
      return Icons.shopping_cart;

    default:
      return Icons.receipt_long;
  }
}
  String nameForPdf(
  String email,
  Map<String, String> emailToName,
) {
  return emailToName[email] ?? email.split("@").first;
}
  List<Map<String, dynamic>> pdfExpenses = [];
 Future<void> generateGroupPdf({
  required BuildContext context,
  required String groupName,
  required List<Map<String, dynamic>> expenses,
}) async {
  final pdf = pw.Document();

  final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
  final ttf = pw.Font.ttf(fontData);

  double readAmount(Map<String, dynamic> item) {
    final value = item['tutar'] ??
        item['amount'] ??
        item['price'] ??
        item['total'] ??
        0;

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
    }

    return 0.0;
  }

  String readText(
    Map<String, dynamic> item,
    List<String> keys, {
    String defaultValue = '-',
  }) {
    for (final key in keys) {
      final value = item[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return defaultValue;
  }

  List<String> readParticipants(Map<String, dynamic> item) {
    final value = item['participants'] ??
        item['katilanlar'] ??
        item['selectedParticipants'] ??
        item['members'];

    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }

    return [];
  }

  String readDate(Map<String, dynamic> item) {
    final value = item['date'] ??
        item['createdAt'] ??
        item['tarih'] ??
        item['timestamp'];

    if (value == null) return '-';

    try {
      if (value is Timestamp) {
        return value.toDate().toString().substring(0, 19);
      }
    } catch (_) {}

    return value.toString();
  }
String displayName(String value) {
  if (value.contains('@')) {
    return value.split('@').first;
  }
  return value;
}
  final double totalExpense = expenses.fold(
    0.0,
    (sum, item) => sum + readAmount(item),
  );

  final Set<String> allParticipants = {};

  for (final expense in expenses) {
    allParticipants.addAll(readParticipants(expense));
  }

  final int participantCount =
      allParticipants.isEmpty ? 1 : allParticipants.length;

  final double perPersonAmount = totalExpense / participantCount;
  final double pageWidth = PdfPageFormat.a4.width - 44;
final Map<String, double> balances = {};

for (final expense in expenses) {
  final amount = readAmount(expense);
  final paidBy = readText(
    expense,
    [
      'paidBy',
      'odeyen',
      'ödeyen',
      'payer',
      'paidByEmail',
    ],
    defaultValue: '',
  );

  final participants = readParticipants(expense);

  if (amount <= 0 || paidBy.isEmpty || participants.isEmpty) {
    continue;
  }

  final double share = amount / participants.length;

  balances[paidBy] = (balances[paidBy] ?? 0) + amount;

  for (final participant in participants) {
    balances[participant] = (balances[participant] ?? 0) - share;
  }
}

final List<Map<String, dynamic>> debtors = [];
final List<Map<String, dynamic>> creditors = [];

balances.forEach((person, balance) {
  if (balance < -0.01) {
    debtors.add({
      'person': person,
      'amount': -balance,
    });
  } else if (balance > 0.01) {
    creditors.add({
      'person': person,
      'amount': balance,
    });
  }
});

final List<Map<String, dynamic>> paymentPlan = [];

int debtorIndex = 0;
int creditorIndex = 0;

while (debtorIndex < debtors.length && creditorIndex < creditors.length) {
  final debtor = debtors[debtorIndex];
  final creditor = creditors[creditorIndex];

  final double debtAmount = debtor['amount'] as double;
  final double creditAmount = creditor['amount'] as double;

  final double paymentAmount =
      debtAmount < creditAmount ? debtAmount : creditAmount;

  paymentPlan.add({
    'from': debtor['person'],
    'to': creditor['person'],
    'amount': paymentAmount,
  });

  debtor['amount'] = debtAmount - paymentAmount;
  creditor['amount'] = creditAmount - paymentAmount;

  if ((debtor['amount'] as double) <= 0.01) {
    debtorIndex++;
  }

  if ((creditor['amount'] as double) <= 0.01) {
    creditorIndex++;
  }
}
print('PAYMENT PLAN: $paymentPlan');
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(22),
      theme: pw.ThemeData.withFont(
        base: ttf,
        bold: ttf,
      ),
      build: (context) {
        return [
          pw.Container(
            
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColors.indigo50,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  groupName,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Ortak Hesap PDF Raporu',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Rapor Tarihi: ${DateTime.now().toString().substring(0, 16)}',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 10),

          pw.Row(
            children: [
              _pdfSummaryBox(
                title: 'Toplam Harcama',
                value: '${totalExpense.toStringAsFixed(2)} TRY',
              ),
              pw.SizedBox(width: 10),
              _pdfSummaryBox(
                title: 'Katılımcı Sayısı',
                value: participantCount.toString(),
              ),
              pw.SizedBox(width: 10),
              _pdfSummaryBox(
                title: 'Kişi Başı',
                value: '${perPersonAmount.toStringAsFixed(2)} TRY',
              ),
            ],
          ),

          pw.SizedBox(height: 24),

          pw.Text(
            'Harcamalar',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),

          pw.SizedBox(height: 10),

          if (expenses.isEmpty)
            pw.Text(
              'Henüz harcama bulunmamaktadır.',
              style: const pw.TextStyle(fontSize: 11),
            ),

          ...expenses.map((expense) {
            final title = readText(
              expense,
              [
                'harcamaAdi',
                'harcamaAdı',
                'title',
                'name',
                'ad',
                'description',
              ],
              defaultValue: 'Harcama',
            );

            final amount = readAmount(expense);

            final paidBy = readText(
              expense,
              [
                'paidBy',
                'odeyen',
                'ödeyen',
                'payer',
                'paidByEmail',
              ],
            );

            final splitType = readText(
              expense,
              [
                'splitType',
                'bolusumTipi',
                'bölüşümTipi',
                'divisionType',
              ],
              defaultValue: 'Eşit Böl',
            );
              final splitTypeText = splitType == 'custom'
                  ? 'Özel Bölüşüm'
                  : splitType == 'equal'
                      ? 'Eşit Böl'
                      : splitType;
            final participantsList = readParticipants(expense);

            final participants = participantsList.isNotEmpty
                ? participantsList.map((e) => displayName(e)).join(', ')
                : '-';

            final date = readDate(expense);

            return pw.Container(
              
              margin: const pw.EdgeInsets.only(bottom: 7),
              padding: const pw.EdgeInsets.all(9),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          title,
                          style: pw.TextStyle(
                            fontSize: 15,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Text(
                        '${amount.toStringAsFixed(2)} TRY',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 14),


                    ],
                  ),
                  pw.SizedBox(height: 8),
                  _pdfInfoRow('Ödeyen', displayName(paidBy)),
                  _pdfInfoRow('Bölüşüm Tipi', splitTypeText),
                  _pdfInfoRow('Katılanlar', participants),
                  _pdfInfoRow('Tarih', date),
                ],
              ),
            );
          }),

          pw.SizedBox(height: 18),

          pw.Text(
            'Katılımcılar',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),

          pw.SizedBox(height: 8),

          if (allParticipants.isEmpty)
            pw.Text(
              'Katılımcı bilgisi bulunmamaktadır.',
              style: const pw.TextStyle(fontSize: 11),
            )
          else
            pw.Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allParticipants.map((name) {
                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text(
                    displayName(name),
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                );
              }).toList(),
            ),
pw.SizedBox(height: 12),

pw.Text(
  'Ödeme Planı',
  style: pw.TextStyle(
    fontSize: 18,
    fontWeight: pw.FontWeight.bold,
  ),
),


pw.SizedBox(height: 8),

if (paymentPlan.isEmpty)
  pw.Container(
    
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: PdfColors.grey100,
      border: pw.Border.all(color: PdfColors.grey300),
      borderRadius: pw.BorderRadius.circular(7),
    ),
    child: pw.Text(
      'Ödeme planı oluşturulacak borç/alacak bilgisi bulunmamaktadır.',
      style: const pw.TextStyle(fontSize: 10),
    ),
  )
else
  pw.Column(
    children: paymentPlan.map((payment) {
      final from = displayName(payment['from'].toString());
      final to = displayName(payment['to'].toString());
      final amount = payment['amount'] as double;

      return pw.Container(
        
        margin: const pw.EdgeInsets.only(bottom: 4),
        padding: const pw.EdgeInsets.all(9),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(7),
        ),
        child: pw.Text(
          '$from, $to kişisine ${amount.toStringAsFixed(2)} TRY ödeyecek.',
          style: const pw.TextStyle(fontSize: 10),
        ),
      );
    }).toList(),
  ),
          pw.SizedBox(height: 22),

          pw.Text(
            'Özet',
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
            ),
          ),

          pw.SizedBox(
  width: pageWidth,
  child: pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey300),
    columnWidths: {
      0: const pw.FlexColumnWidth(2),
      1: const pw.FlexColumnWidth(2),
    },
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(
          color: PdfColors.grey200,
        ),
        children: [
          _pdfTableCell('Bilgi', isHeader: true),
          _pdfTableCell('Değer', isHeader: true),
        ],
      ),
      pw.TableRow(
        children: [
          _pdfTableCell('Toplam Harcama'),
          _pdfTableCell('${totalExpense.toStringAsFixed(2)} TRY'),
        ],
      ),
      pw.TableRow(
        children: [
          _pdfTableCell('Katılımcı Sayısı'),
          _pdfTableCell(participantCount.toString()),
        ],
      ),
      pw.TableRow(
        children: [
          _pdfTableCell('Kişi Başı Ortalama'),
          _pdfTableCell('${perPersonAmount.toStringAsFixed(2)} TRY'),
        ],
      ),
    ],
  ),
),
        ];
      },
    ),
  );

  await Printing.layoutPdf(
  onLayout: (PdfPageFormat format) async => pdf.save(),
);

if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(
    content: Text('PDF raporu oluşturuldu.'),
  ),
);
}
pw.Widget _pdfSummaryBox({
  required String title,
  required String value,
}) {
  return pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: const pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );
}

pw.Widget _pdfInfoRow(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 85,
          child: pw.Text(
            '$label:',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _pdfTableCell(
  String text, {
  bool isHeader = false,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
  }

  Future<void> markDebtAsPaid({
    required String fromEmail,
    required String toEmail,
    required double amount,
  }) async {
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupName)
        .collection('payments')
        .add({
      'fromEmail': fromEmail.trim().toLowerCase(),
      'toEmail': toEmail.trim().toLowerCase(),
      'amount': amount,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ödeme kaydedildi')),
    );
  }

  Future<void> sendDebtReminder({
    required String toEmail,
    required String amount,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final cleanToEmail = toEmail.trim().toLowerCase();
    final cleanFromEmail = user.email?.trim().toLowerCase() ?? '';

    await FirebaseFirestore.instance.collection('notificationRequests').add({
      'toEmail': cleanToEmail,
      'fromEmail': cleanFromEmail,
      'title': 'Borç Hatırlatma',
      'body': '$cleanFromEmail senden $amount ödeme yapmanı hatırlatıyor.',
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
      'isRead': false,
    });
  }

  Future<void> saveExpenseToFirebase(Expense expense) async {
    final user = FirebaseAuth.instance.currentUser;
    final payerEmail = user?.email?.trim().toLowerCase() ?? '';

    await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupName)
        .collection('expenses')
        .add({
      'title': expense.title,
      'amount': expense.amount,
      'currency': expense.currency,
      'paidBy': payerEmail,
      'paidByUid': user?.uid,
      'paidByEmail': payerEmail,
      'participants': expense.participants.map((e) => e.trim().toLowerCase()).toList(),
      'splitType': expense.splitType,
      'category': expense.category,
      'shares': expense.shares,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateExpenseFromFirebase(Expense expense) async {
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupName)
        .collection('expenses')
        .doc(expense.id)
        .update({
      'title': expense.title,
      'amount': expense.amount,
      'participants': expense.participants.map((e) => e.trim().toLowerCase()).toList(),
      'splitType': expense.splitType,
      'shares': expense.shares,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteExpenseFromFirebase(String expenseId) async {
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupName)
        .collection('expenses')
        .doc(expenseId)
        .delete();
  }

  Future<void> deleteMemberFromFirebase(String memberDocId) async {
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupName)
        .collection('members')
        .doc(memberDocId)
        .delete();
  }

  void showAddExpenseDialog(List<String> memberEmails) async {
  final groupDoc = await FirebaseFirestore.instance
      .collection('groups')
      .doc(widget.groupName)
      .get();

  final groupCurrency =
      (groupDoc.data()?['currency'] ?? 'TRY').toString();

  if (memberEmails.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Önce üye eklemelisin')),
    );
    return;
  }

  String title = '';
  String amount = '';
  String splitType = "equal";
  String selectedCategory = "general";

  final titleController = TextEditingController();
  final amountController = TextEditingController();

  final Map<String, TextEditingController> shareControllers = {};
  final currentUser = FirebaseAuth.instance.currentUser;
  final selectedPaidBy = currentUser?.email?.trim().toLowerCase() ?? '';
  final List<String> selectedParticipants = List.from(memberEmails);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(24),
      ),
    ),
    builder: (bottomSheetContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Harcama Ekle',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 18),

                  TextField(
                    controller: titleController,
                    onChanged: (value) => title = value,
                    decoration: InputDecoration(
                      labelText: 'Harcama adı',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    onChanged: (value) => amount = value,
                    decoration: InputDecoration(
                      labelText: 'Tutar ($groupCurrency)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: splitType,
                    decoration: InputDecoration(
                      labelText: "Bölüşüm Tipi",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: "equal",
                        child: Text("Eşit Böl"),
                      ),
                      DropdownMenuItem(
                        value: "custom",
                        child: Text("Kişiye Göre Tutar"),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          splitType = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: InputDecoration(
                      labelText: "Kategori",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: "general",
                        child: Text("Genel"),
                      ),
                      DropdownMenuItem(
                        value: "food",
                        child: Text("Yemek"),
                      ),
                      DropdownMenuItem(
                        value: "transport",
                        child: Text("Ulaşım"),
                      ),
                      DropdownMenuItem(
                        value: "hotel",
                        child: Text("Konaklama"),
                      ),
                      DropdownMenuItem(
                        value: "market",
                        child: Text("Market"),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          selectedCategory = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Kimler katıldı?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  ...memberEmails.map((email) {
                    final name = email.split("@").first;

                    return CheckboxListTile(
                      dense: true,
                      visualDensity: const VisualDensity(vertical: -3),
                      contentPadding: EdgeInsets.zero,
                      value: selectedParticipants.contains(email),
                      title: Text(name),
                     
                      onChanged: (checked) {
                        setDialogState(() {
                          if (checked == true) {
                            if (!selectedParticipants.contains(email)) {
                              selectedParticipants.add(email);
                            }

                            shareControllers.putIfAbsent(
                              email,
                              () => TextEditingController(text: ""),
                            );
                          } else {
                            selectedParticipants.remove(email);
                          }
                        });
                      },
                    );
                  }).toList(),

                  if (splitType == "custom") ...[
                    const SizedBox(height: 12),
                    const Text(
                      "Kişi Payları",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    ...selectedParticipants.map((email) {
                      shareControllers.putIfAbsent(
                        email,
                        () => TextEditingController(text: ""),
                      );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextField(
                          controller: shareControllers[email],
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "${email.split("@").first} payı",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ],

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(bottomSheetContext),
                          child: const Text('İptal'),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () async {
                            final parsedAmount = double.tryParse(
                              amount.replaceAll(',', '.'),
                            );

                            if (title.trim().isEmpty ||
                                parsedAmount == null ||
                                selectedParticipants.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Harcama adı, tutar ve katılımcılar zorunlu.',
                                  ),
                                ),
                              );
                              return;
                            }

                            final Map<String, double> customShares = {};

                            if (splitType == "custom") {
                              double totalShares = 0;

                              for (final email in selectedParticipants) {
                                final text =
                                    shareControllers[email]?.text ?? "0";

                                final value = double.tryParse(
                                      text.replaceAll(",", "."),
                                    ) ??
                                    0;

                                if (value <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "${email.split("@").first} için tutar gir",
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                customShares[email] = value;
                                totalShares += value;
                              }

                              if ((totalShares - parsedAmount).abs() > 0.01) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "Kişi payları toplamı harcama tutarına eşit olmalı. Toplam: ${totalShares.toStringAsFixed(2)}",
                                    ),
                                  ),
                                );
                                return;
                              }
                            }

                            await saveExpenseToFirebase(
                              Expense(
                                id: '',
                                title: title.trim(),
                                amount: parsedAmount,
                                currency: groupCurrency,
                                paidBy: selectedPaidBy,
                                participants: selectedParticipants,
                                splitType: splitType,
                                category: selectedCategory,
                                shares: splitType == "custom"
                                    ? customShares
                                    : {},
                              ),
                            );

                            if (context.mounted) {
                              Navigator.pop(bottomSheetContext);
                            }
                          },
                          child: const Text('Ekle'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

void showEditExpenseDialog(
  Expense expense,
  List<String> memberEmails,
  Map<String, String> emailToName,
) {
  String title = expense.title;
  String amount = expense.amount.toString();
  String splitType = expense.splitType;

  final titleController = TextEditingController(text: title);
  final amountController = TextEditingController(text: amount);

  final Map<String, TextEditingController> shareControllers = {};

  for (final email in expense.participants) {
    final shareValue = expense.shares[email];

    shareControllers[email] = TextEditingController(
      text: shareValue != null ? shareValue.toStringAsFixed(2) : "",
    );
  }

  final List<String> selectedParticipants = List.from(expense.participants);

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Harcama Düzenle'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    onChanged: (value) => title = value,
                    decoration: const InputDecoration(
                      hintText: 'Harcama adı',
                    ),
                  ),

                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    onChanged: (value) => amount = value,
                    decoration: const InputDecoration(
                      hintText: 'Tutar',
                    ),
                  ),

                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: splitType,
                    decoration: const InputDecoration(
                      labelText: "Bölüşüm Tipi",
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: "equal",
                        child: Text("Eşit Böl"),
                      ),
                      DropdownMenuItem(
                        value: "custom",
                        child: Text("Kişiye Göre Tutar"),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          splitType = value;
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 12),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Kimler katıldı?',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),

                  ...memberEmails.map((email) {
                    final name = displayNameForEmail(email, emailToName);

                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: selectedParticipants.contains(email),
                      title: Text(name),
                      onChanged: (checked) {
                        setDialogState(() {
                          if (checked == true) {
                            if (!selectedParticipants.contains(email)) {
                              selectedParticipants.add(email);
                            }

                            shareControllers.putIfAbsent(
                              email,
                              () => TextEditingController(text: ""),
                            );
                          } else {
                            selectedParticipants.remove(email);
                          }
                        });
                      },
                    );
                  }).toList(),

                  if (splitType == "custom") ...[
                    const SizedBox(height: 12),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Kişi Payları",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),

                    const SizedBox(height: 8),

                    ...selectedParticipants.map((email) {
                      shareControllers.putIfAbsent(
                        email,
                        () => TextEditingController(
                          text: expense.shares[email]?.toStringAsFixed(2) ?? "",
                        ),
                      );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextField(
                          controller: shareControllers[email],
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText:
                                "${displayNameForEmail(email, emailToName)} payı",
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final parsedAmount =
                      double.tryParse(amount.replaceAll(',', '.'));

                  final Map<String, double> customShares = {};

                  if (title.trim().isNotEmpty &&
                      parsedAmount != null &&
                      selectedParticipants.isNotEmpty) {
                    if (splitType == "custom") {
                      double totalShares = 0;

                      for (final email in selectedParticipants) {
                        final text = shareControllers[email]?.text ?? "0";
                        final value =
                            double.tryParse(text.replaceAll(",", ".")) ?? 0;

                        if (value <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "${displayNameForEmail(email, emailToName)} için tutar gir",
                              ),
                            ),
                          );
                          return;
                        }

                        customShares[email] = value;
                        totalShares += value;
                      }

                      if ((totalShares - parsedAmount).abs() > 0.01) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "Kişi payları toplamı harcama tutarına eşit olmalı. Toplam: ${totalShares.toStringAsFixed(2)}",
                            ),
                          ),
                        );
                        return;
                      }
                    }

                    await updateExpenseFromFirebase(
                      Expense(
                        id: expense.id,
                        title: title.trim(),
                        amount: parsedAmount,
                        splitType: splitType,
                        category: 'general',
                        shares: splitType == "custom" ? customShares : {},
                        currency: expense.currency,
                        paidBy: expense.paidBy,
                        participants: selectedParticipants,
                      ),
                    );
                  }

                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Kaydet'),
              ),
            ],
          );
        },
      );
    },
  );
}

  double calculateTotal(List<Expense> expenseList) {
    double total = 0;
    for (final expense in expenseList) {
      total += expense.amount;
    }
    return total;
  }

  Map<String, double> calculateBalanceFromExpenses(
  List<Expense> expenseList,
  List<String> memberEmails,
) {
  final Map<String, double> balance = {
    for (final email in memberEmails) email: 0.0,
  };

  for (final expense in expenseList) {
    balance[expense.paidBy] =
        (balance[expense.paidBy] ?? 0) + expense.amount;

    if (expense.splitType == "custom") {
      expense.shares.forEach((email, shareAmount) {
        balance[email] = (balance[email] ?? 0) - shareAmount;
      });
    } else {
      if (expense.participants.isEmpty) continue;

      final share = expense.amount / expense.participants.length;

      for (final participant in expense.participants) {
        balance[participant] =
            (balance[participant] ?? 0) - share;
      }
    }
  }

  return balance;
}

  Map<String, double> applyPaymentsToBalance(
    Map<String, double> balance,
    List<Payment> payments,
  ) {
    final updatedBalance = Map<String, double>.from(balance);
    for (final payment in payments) {
      updatedBalance[payment.fromEmail] = (updatedBalance[payment.fromEmail] ?? 0) + payment.amount;
      updatedBalance[payment.toEmail] = (updatedBalance[payment.toEmail] ?? 0) - payment.amount;
    }
    return updatedBalance;
  }

  List<String> calculateDebtsFromBalance(
  Map<String, double> balance,
  String groupCurrency,
) {
    final List<MapEntry<String, double>> creditors = [];
    final List<MapEntry<String, double>> debtors = [];

    balance.forEach((email, value) {
      if (value > 0.01) {
        creditors.add(MapEntry(email, value));
      } else if (value < -0.01) {
        debtors.add(MapEntry(email, value.abs()));
      }
    });

    final List<String> result = [];
    int i = 0;
    int j = 0;

    while (i < debtors.length && j < creditors.length) {
      final amount = debtors[i].value < creditors[j].value ? debtors[i].value : creditors[j].value;
      result.add('${debtors[i].key} → ${creditors[j].key}: ${amount.toStringAsFixed(2)}  $groupCurrency');
      debtors[i] = MapEntry(debtors[i].key, debtors[i].value - amount);
      creditors[j] = MapEntry(creditors[j].key, creditors[j].value - amount);
      if (debtors[i].value <= 0.01) i++;
      if (creditors[j].value <= 0.01) j++;
    }
    return result;
  }

  String displayNameForEmail(String email, Map<String, String> emailToName) {
    return emailToName[email] ?? email.split('@').first;
  }

  Widget _buildChartTab(List<Expense> expenses, Map<String, String> emailToName) {
    if (expenses.isEmpty) {
      return const Center(child: Text('Veri yok'));
    }

    final Map<String, double> totals = {};
    for (final expense in expenses) {
      totals[expense.paidBy] = (totals[expense.paidBy] ?? 0) + expense.amount;
    }

    if (totals.length == 1) {
      final email = totals.keys.first;
      return Center(
        child: Text(
          '${email.split("@").first}\n${totals.values.first.toStringAsFixed(2)} TL ödedi',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );
    }

    final double grandTotal = totals.values.fold(0.0, (sum, value) => sum + value);
    final colors = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple, Colors.teal];
    final entries = totals.entries.toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Column(
              children: const [
                Text(
                  "Kim Ne Kadar Ödedi",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  "Toplam harcamaya göre ödeme dağılımı",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 20),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
              PieChartData(
                sections: List<PieChartSectionData>.generate(entries.length, (i) {
                  final entry = entries[i];
                  final percent = grandTotal == 0 ? 0 : (entry.value / grandTotal * 100);
                  return PieChartSectionData(
                    value: entry.value,
                    color: colors[i % colors.length],
                    title: '${percent.toStringAsFixed(0)}%',
                    radius: 80,
                    titleStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                  );
                }),
              ),
                    ),

                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.pie_chart,
                            color: Colors.deepPurple,
                            size: 28,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Toplam",
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            "${grandTotal.toStringAsFixed(2)} ${expenses.first.currency}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                        
          const SizedBox(height: 20),
          ...List.generate(entries.length, (i) {
            final entry = entries[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),

              child: Row(
                children: [

                  CircleAvatar(
                    radius: 20,
                    backgroundColor: colors[i % colors.length],
                    child: Text(
                      displayNameForEmail(entry.key, emailToName)
                        .substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Text(
                        displayNameForEmail(entry.key, emailToName),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colors[i % colors.length].withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      "${entry.value.toStringAsFixed(2)} ${expenses.first.currency}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colors[i % colors.length],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupName)
          .collection('members')
          .snapshots(),
      builder: (context, memberSnapshot) {
        final memberDocs = memberSnapshot.data?.docs ?? [];
        final memberEmails = memberDocs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return (data['email'] ?? '').toString().trim().toLowerCase();
        }).where((email) => email.isNotEmpty).toList();

        final Map<String, String> emailToName = {};
        final Map<String, String> emailToDocId = {};
        for (final doc in memberDocs) {
          final data = doc.data() as Map<String, dynamic>;
          final email = (data['email'] ?? '').toString().trim().toLowerCase();
          final name = (data['nickname'] ?? data['name'] ?? email).toString();
          if (email.isNotEmpty) {
            emailToName[email] = name;
            emailToDocId[email] = doc.id;
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('groups')
              .doc(widget.groupName)
              .collection('expenses')
              .snapshots(),
          builder: (context, expenseSnapshot) {
            final expenseDocs = expenseSnapshot.data?.docs ?? [];
            final List<Expense> firebaseExpenses = expenseDocs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return Expense(
                id: doc.id,
                title: (data['title'] ?? '').toString(),
                amount: (data['amount'] ?? 0).toDouble(),
                createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
                currency: (data['currency'] ?? 'TRY').toString(),
                paidBy: (data['paidByEmail'] ?? data['paidBy'] ?? '').toString().trim().toLowerCase(),
                participants: List<String>.from(data['participants'] ?? [])
                .map((e) => e.toString().trim().toLowerCase())
                .toList(),
                splitType: (data['splitType'] ?? 'equal').toString(),
                category: data['category'] ?? 'general',
                shares: Map<String, double>.from(
                  (data['shares'] ?? {}).map(
                    (key, value) => MapEntry(
                      key.toString(),
                      (value as num).toDouble(),
                    ),
                  ),
                ),
              );
            }).toList();
            pdfExpenses = expenseDocs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;

            return {
              'title': data['title'] ?? '',
              'amount': data['amount'] ?? 0,
              'createdAt': data['createdAt'],
              'currency': data['currency'] ?? 'TRY',

              // PDF için gerekli ek alanlar
              'paidBy': data['paidBy'] ?? data['payer'] ?? data['odeyen'] ?? '',
              'splitType': data['splitType'] ?? data['bolusumTipi'] ?? 'Eşit Böl',
              'participants': data['participants'] ??
                  data['katilanlar'] ??
                  data['selectedParticipants'] ??
                  [],
            };
          }).toList();    
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('groups')
                  .doc(widget.groupName)
                  .collection('payments')
                  .snapshots(),
              builder: (context, paymentSnapshot) {
                final paymentDocs = paymentSnapshot.data?.docs ?? [];
                final payments = paymentDocs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Payment(
                    id: doc.id,
                    fromEmail: (data['fromEmail'] ?? '').toString().trim().toLowerCase(),
                    toEmail: (data['toEmail'] ?? '').toString().trim().toLowerCase(),
                    amount: (data['amount'] ?? 0).toDouble(),
                  );
                }).toList();

                final totalAmount = calculateTotal(firebaseExpenses);
                final groupCurrency = widget.groupCurrency;

                final perPersonAmount =
                    memberEmails.isEmpty ? 0 : totalAmount / memberEmails.length;
                final rawBalances = calculateBalanceFromExpenses(firebaseExpenses, memberEmails);
                final balances = applyPaymentsToBalance(rawBalances, payments);
                final debts = calculateDebtsFromBalance(balances, groupCurrency);

                return DefaultTabController(
                  length: 5,
                  child: Scaffold(
                    appBar: AppBar(
                      toolbarHeight: 82,
                      title: Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: Text(widget.groupName),
                        ),
                      
                      actions: [
                        IconButton(
                                icon: const Icon(Icons.picture_as_pdf),
                                onPressed: () {
                                  print('PDF harcama sayısı: ${pdfExpenses.length}');
                                  print('PDF harcama içeriği: $pdfExpenses');
                                 generateGroupPdf(
                                    context: context,
                                    groupName: widget.groupName,
                                    expenses: pdfExpenses,
                                  );
                                },
                              ),
                            IconButton(
                              icon: const Icon(Icons.notifications),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const NotificationsPage()),
                            );
                          },
                        ),
                      ],
                     bottom: const TabBar(
                        indicatorColor: Colors.white,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white70,
                        labelStyle: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                        unselectedLabelStyle: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        tabs: [
                          Tab(
                            icon: Icon(Icons.payments, size: 19),
                            text: 'Gider',
                          ),
                          Tab(
                            icon: Icon(Icons.people, size: 19),
                            text: 'Üyeler',
                          ),
                          Tab(
                            icon: Icon(Icons.account_balance, size: 19),
                            text: 'Borç',
                          ),
                          Tab(
                            icon: Icon(Icons.pie_chart, size: 19),
                            text: 'Grafik',
                          ),
                          Tab(
                            icon: Icon(Icons.history, size: 19),
                            text: 'Geçmiş',
                          ),
                        ],
                      ),
                    ),
                    body: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 3,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Toplam Harcama",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                        const SizedBox(height: 6),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            "${totalAmount.toStringAsFixed(2)} $groupCurrency",
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text(
                                          "Kişi Başı",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                        const SizedBox(height: 6),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            "${perPersonAmount.toStringAsFixed(2)} $groupCurrency",
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: TabBarView(
                            children: [
                              _buildExpensesTab(firebaseExpenses, memberEmails, emailToName),
                              _buildMembersTab(memberEmails, emailToName, emailToDocId),
                              _buildDebtsTab(memberEmails, emailToName, balances, debts, groupCurrency),
                              _buildChartTab(firebaseExpenses, emailToName),
                              _buildPaymentsHistoryTab(payments, emailToName),
                            ],
                          ),
                          ),
                        ),
                      ],
                    ),
                    floatingActionButton: FloatingActionButton(
                      onPressed: () => showAddExpenseDialog(memberEmails),
                      child: const Icon(Icons.add),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildExpensesTab(
  List<Expense> firebaseExpenses,
  List<String> memberEmails,
  Map<String, String> emailToName,
) {
  if (firebaseExpenses.isEmpty) {
    return const Center(child: Text('Henüz harcama yok 💸'));
  }

  return ListView(
    children: firebaseExpenses.map((expense) {
      final payerName = displayNameForEmail(expense.paidBy, emailToName);

      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
                categoryIcon(expense.category),
                color: Colors.teal,
              ),
          ),
          title: Text(
            expense.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ödeyen: $payerName'),
              const SizedBox(height: 4),
              Text(
                'Katılanlar: ${expense.participants.map((email) => displayNameForEmail(email, emailToName)).join(", ")}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 2),
              Row(
                    children: [
                      const Icon(
                        Icons.people_outline,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        expense.splitType == "custom"
                            ? "Kişiye Göre"
                            : "Eşit Böl",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
              const SizedBox(height: 2),
              Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        expense.createdAt != null
                            ? "${expense.createdAt!.day.toString().padLeft(2, '0')}.${expense.createdAt!.month.toString().padLeft(2, '0')}.${expense.createdAt!.year} "
                                "${expense.createdAt!.hour.toString().padLeft(2, '0')}:${expense.createdAt!.minute.toString().padLeft(2, '0')}"
                            : "Tarih yok",
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: expense.splitType == "custom"
                      ? Colors.orange.withOpacity(0.12)
                      : Colors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  expense.splitType == "custom" ? "Kişiye Göre" : "Eşit Böl",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: expense.splitType == "custom"
                        ? Colors.orange
                        : Colors.green,
                  ),
                ),
              ),
            ],
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '${expense.amount.toStringAsFixed(2)} ${expense.currency}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.teal,
              ),
            ),
          ),
          onTap: () {
            showEditExpenseDialog(expense, memberEmails, emailToName);
          },
          onLongPress: () {
            showModalBottomSheet(
              context: context,
              builder: (context) {
                return SafeArea(
                  child: Wrap(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.edit),
                        title: const Text('Düzenle'),
                        onTap: () {
                          Navigator.pop(context);
                          showEditExpenseDialog(
                            expense,
                            memberEmails,
                            emailToName,
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.delete, color: Colors.red),
                        title: const Text('Sil'),
                        onTap: () {
                          Navigator.pop(context);
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('Harcamayı Sil'),
                                content: Text('${expense.title} silinsin mi?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('İptal'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () async {
                                      await deleteExpenseFromFirebase(
                                        expense.id,
                                      );
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                    },
                                    child: const Text('Sil'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.close),
                        title: const Text('İptal'),
                        onTap: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      );
    }).toList(),
  );
}

  Widget _buildMembersTab(
    List<String> memberEmails,
    Map<String, String> emailToName,
    Map<String, String> emailToDocId,
  ) {
    return ListView(
      children: [
        const ListTile(
          title: Text('Üyeler'),
          subtitle: Text('Yeni üyeler ana sayfadaki grup kodu ile katılır.'),
        ),
        if (memberEmails.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Text('Henüz üye yok'))
        else
          ...memberEmails.map((email) {
            final name = email.split("@").first;
            final docId = emailToDocId[email];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.teal.shade100,
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
                ),
                title: Text(name),
                subtitle: Text(email),
                onLongPress: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('Üyeyi Çıkar'),
                        content: Text('$name gruptan çıkarılsın mı?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
                          ElevatedButton(
                            onPressed: () async {
                              if (docId != null) await deleteMemberFromFirebase(docId);
                              if (context.mounted) Navigator.pop(context);
                            },
                            child: const Text('Çıkar'),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            );
          }),
      ],
    );
  }

  Widget _buildDebtsTab(
  List<String> memberEmails,
  Map<String, String> emailToName,
  Map<String, double> balances,
  List<String> debts,
  String groupCurrency,
) {
    return ListView(
      children: [
        const ListTile(title: Text('Borç / Alacak Durumu')),
        ...memberEmails.map((email) {
          final value = balances[email] ?? 0;
          final name = email.split("@").first;
          Color color;
          String text;
          if (value > 0) {
            color = Colors.green;
            text = '${value.toStringAsFixed(2)} ${widget.groupCurrency} alacaklı';
          } else if (value < 0) {
            color = Colors.red;
            text = '${(-value).toStringAsFixed(2)} ${widget.groupCurrency} borçlu';
          } else {
            color = Colors.grey;
            text = 'Borcu yok';
          }
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.account_balance_wallet),
              title: Text(name),
              subtitle: Text(text, style: TextStyle(color: color)),
            ),
          );
        }),
        const Divider(),
        const ListTile(title: Text('Kim Kime Ödeyecek')),
        if (debts.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Text('Ödenecek borç yok'))
        else
          ...debts.map((debt) {
            String displayDebt = debt;
            emailToName.forEach((email, name) {
              displayDebt = displayDebt.replaceAll(email, name);
            });
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                leading: const Icon(Icons.swap_horiz, color: Colors.teal),
                title: Text(displayDebt),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_active),
                      onPressed: () async {
                        final parts = debt.split('→');
                        if (parts.length < 2) return;
                        final toEmail = parts[0].trim().toLowerCase();
                        final amount = parts[1].contains(':') ? parts[1].split(':')[1].trim() : '';
                        await sendDebtReminder(toEmail: toEmail, amount: amount);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Hatırlatma gönderildi')),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () async {
                        final parts = debt.split('→');
                        if (parts.length < 2 || !parts[1].contains(':')) return;
                        final fromEmail = parts[0].trim().toLowerCase();
                        final rightPart = parts[1].trim();
                        final toEmail = rightPart.split(':')[0].trim().toLowerCase();
                        final amountText = rightPart.split(':')[1].replaceAll('$groupCurrency', '').trim();
                        final amount = double.tryParse(amountText.replaceAll(',', '.'));
                        if (amount == null) return;
                        await markDebtAsPaid(fromEmail: fromEmail, toEmail: toEmail, amount: amount);
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildPaymentsHistoryTab(
    List<Payment> payments,
    Map<String, String> emailToName,
  ) {
    if (payments.isEmpty) {
      return const Center(child: Text('Henüz ödeme geçmişi yok'));
    }

    final sortedPayments = [...payments];

    return ListView(
      children: sortedPayments.map((payment) {
        final fromName = displayNameForEmail(payment.fromEmail, emailToName);
        final toName = displayNameForEmail(payment.toEmail, emailToName);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const Icon(Icons.check_circle, color: Colors.green),
            title: Text('$fromName → $toName'),
            subtitle: const Text('Ödeme kaydedildi'),
            trailing: Text(
              '${payment.amount.toStringAsFixed(2)} ${widget.groupCurrency}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      }).toList(),
    );
  }

}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String email = '';
  String password = '';

  Future<void> login() async {
  try {
    final cleanEmail = email.trim().toLowerCase();

    final userQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: cleanEmail)
        .limit(1)
        .get();

    if (userQuery.docs.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bu e-posta kayıtlı değil. Lütfen kayıt olun."),
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const RegisterPage(),
        ),
      );
      return;
    }

    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: cleanEmail,
      password: password.trim(),
    );

    final user = credential.user;

    await FirebaseFirestore.instance.collection('users').doc(user?.uid).set({
      'email': cleanEmail,
    }, SetOptions(merge: true));

    await saveFcmToken();
  } on FirebaseAuthException catch (e) {
    if (!mounted) return;

    if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("E-posta veya şifre hatalı.")),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Giriş yapılamadı: ${e.message}")),
    );
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Hata: $e')),
    );
  }
}
Future<void> showForgotPasswordDialog() async {
  String resetEmail = email;

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("Şifre Sıfırla"),
        content: TextField(
          controller: TextEditingController(text: resetEmail),
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: "E-posta adresi",
          ),
          onChanged: (value) {
            resetEmail = value.trim().toLowerCase();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(
                  email: resetEmail,
                );

                if (!mounted) return;

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "Şifre sıfırlama bağlantısı gönderildi.",
                    ),
                  ),
                );
              } on FirebaseAuthException catch (e) {
                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      e.message ?? "Şifre sıfırlama başarısız.",
                    ),
                  ),
                );
              }
            },
            child: const Text("Gönder"),
          ),
        ],
      );
    },
  );
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Giriş Yap')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              onChanged: (value) => email = value,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              obscureText: true,
              onChanged: (value) => password = value,
              decoration: const InputDecoration(labelText: 'Şifre'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: login,
              child: const Text('Giriş Yap'),
            ),
            TextButton(
              onPressed: showForgotPasswordDialog,
              child: const Text("Şifremi Unuttum"),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterPage()),
                );
              },
              child: const Text('Kayıt Ol'),
            )
            
          ],
        ),
      ),
    );
  }
}
class GroupQrPage extends StatelessWidget {
  final String groupName;
  final String groupCode;

  const GroupQrPage({
    super.key,
    required this.groupName,
    required this.groupCode,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Grup QR Kodu"),
      ),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  groupName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                QrImageView(
                  data: groupCode,
                  version: QrVersions.auto,
                  size: 220,
                ),
                const SizedBox(height: 16),
                Text(
                  "Grup Kodu: $groupCode",
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class GroupQrScannerPage extends StatefulWidget {
  const GroupQrScannerPage({super.key});

  @override
  State<GroupQrScannerPage> createState() => _GroupQrScannerPageState();
}

class _GroupQrScannerPageState extends State<GroupQrScannerPage> {
  bool scanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("QR ile Gruba Katıl"),
      ),
      body: MobileScanner(
        onDetect: (capture) {
          if (scanned) return;

          final barcodes = capture.barcodes;
          if (barcodes.isEmpty) return;

          final code = barcodes.first.rawValue;
          if (code == null || code.trim().isEmpty) return;

          scanned = true;
          Navigator.pop(context, code.trim());
        },
      ),
    );
  }
}
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final cleanEmail = user?.email?.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Bildirimler')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notificationRequests')
            .where('toEmail', isEqualTo: cleanEmail)
            .snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Bildirim yok'));
          }

          return ListView(
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  leading: Icon(
                    data['isRead'] == true
                        ? Icons.notifications_none
                        : Icons.notifications_active,
                    color: data['isRead'] == true ? Colors.grey : Colors.teal,
                  ),
                  title: Text(
                    data['title'] ?? '',
                    style: TextStyle(
                      fontWeight: data['isRead'] == true
                          ? FontWeight.normal
                          : FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(data['body'] ?? ''),
                  trailing: data['isRead'] == true
                      ? const Text("Okundu")
                      : const Text("Yeni"),
                  onTap: () async {
                    await doc.reference.update({
                      'isRead': true,
                      'readAt': FieldValue.serverTimestamp(),
                    });
                  },
                )
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  String name = '';
  String email = '';
  String password = '';

  Future<void> register() async {
    try {
      final cleanName = name.trim();
      final cleanEmail = email.trim().toLowerCase();

      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password.trim(),
      );

      final user = credential.user;
      final displayName = cleanName.isNotEmpty ? cleanName : cleanEmail.split('@').first;

      await FirebaseFirestore.instance.collection('users').doc(user?.uid).set({
        'name': displayName,
        'email': cleanEmail,
        'nickname': displayName,
      });

      await saveFcmToken();

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kayıt Ol')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              onChanged: (value) => name = value,
              decoration: const InputDecoration(labelText: 'Ad Soyad'),
            ),
            TextField(
              onChanged: (value) => email = value,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              obscureText: true,
              onChanged: (value) => password = value,
              decoration: const InputDecoration(labelText: 'Şifre'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: register,
              child: const Text('Kayıt Ol'),
            ),
          ],
        ),
      ),
    );
  }
}
