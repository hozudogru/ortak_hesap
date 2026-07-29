import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class VersionCheckService {
  static const String _defaultIosStoreUrl =
      'https://apps.apple.com/app/id6767764634';

  static Future<void> check(BuildContext context) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('appVersion')
          .get();

      if (!doc.exists) return;

      final data = doc.data();
      if (data == null) return;

      final minVersion = data['minVersion']?.toString();
      final latestVersion = data['latestVersion']?.toString();
      final iosUrl = data['iosUrl']?.toString();
      final androidUrl = data['androidUrl']?.toString();

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final storeUrl = Platform.isIOS
          ? ((iosUrl != null && iosUrl.isNotEmpty) ? iosUrl : _defaultIosStoreUrl)
          : (androidUrl ?? '');

      if (!context.mounted) return;

      if (minVersion != null &&
          _compareVersions(currentVersion, minVersion) < 0) {
        _showDialog(
          context,
          mandatory: true,
          storeUrl: storeUrl,
        );
        return;
      }

      if (latestVersion != null &&
          _compareVersions(currentVersion, latestVersion) < 0) {
        _showDialog(
          context,
          mandatory: false,
          storeUrl: storeUrl,
        );
      }
    } catch (e) {
      debugPrint('Sürüm kontrolü hatası: $e');
    }
  }

  static int _compareVersions(String a, String b) {
    final partsA = a.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final partsB = b.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final length = partsA.length > partsB.length ? partsA.length : partsB.length;

    for (var i = 0; i < length; i++) {
      final valueA = i < partsA.length ? partsA[i] : 0;
      final valueB = i < partsB.length ? partsB[i] : 0;
      if (valueA != valueB) return valueA.compareTo(valueB);
    }
    return 0;
  }

  static Future<void> _openStore(String storeUrl) async {
    if (storeUrl.isEmpty) return;
    final uri = Uri.parse(storeUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static void _showDialog(
    BuildContext context, {
    required bool mandatory,
    required String storeUrl,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !mandatory,
      builder: (dialogContext) {
        return PopScope(
          canPop: !mandatory,
          child: AlertDialog(
            title: const Text('Güncelleme Mevcut'),
            content: Text(
              mandatory
                  ? 'Uygulamayı kullanmaya devam edebilmek için güncellemeniz gerekiyor.'
                  : 'Uygulamanın yeni bir sürümü mevcut. Güncellemek ister misiniz?',
            ),
            actions: [
              if (!mandatory)
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Daha Sonra'),
                ),
              ElevatedButton(
                onPressed: () => _openStore(storeUrl),
                child: const Text('Güncelle'),
              ),
            ],
          ),
        );
      },
    );
  }
}
