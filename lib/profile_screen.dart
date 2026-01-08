import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  Map<String, dynamic> data = {};
  bool loading = true;

  final int currentYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (user == null) return;
    final doc = await _firestore.collection('profiles').doc(user!.uid).get();
    if (doc.exists) data = doc.data()!;
    setState(() => loading = false);
  }

  Future<void> _pickImage(ImageSource src) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: src, imageQuality: 75);
    if (picked == null) return;

    Navigator.pop(context); // Close bottom sheet first

    final file = File(picked.path);
    final ref = _storage.ref('profile_pics/${user!.uid}.jpg');
    await ref.putFile(file);
    final url = await ref.getDownloadURL();

    data['imageUrl'] = url;
    await _firestore
        .collection('profiles')
        .doc(user!.uid)
        .set(data, SetOptions(merge: true));

    setState(() {}); // refresh UI
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      builder:
          (_) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Choose from Gallery'),
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _editField(
    String key,
    String title,
    String? current,
    bool isYear,
  ) async {
    String? result = current ?? '';
    if (isYear) {
      result = current;
      await showModalBottomSheet(
        context: context,
        builder: (_) {
          String? selected = result;
          final valid =
              List.generate(currentYear - 1900 + 1, (i) => currentYear - i)
                  .where((y) => y <= currentYear - 18)
                  .map((y) => y.toString())
                  .toList();

          return SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              height: 240,
              child: Column(
                children: [
                  Text(
                    'Set $title',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    items:
                        valid
                            .map(
                              (y) => DropdownMenuItem(value: y, child: Text(y)),
                            )
                            .toList(),
                    value: selected,
                    onChanged: (v) => selected = v,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (selected != null) {
                        data[key] = selected;
                        _firestore
                            .collection('profiles')
                            .doc(user!.uid)
                            .set(data, SetOptions(merge: true));
                        setState(() {});
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      await showModalBottomSheet(
        context: context,
        builder: (_) {
          final ctrl = TextEditingController(text: current);
          return SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Set $title',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: ctrl,
                    decoration: InputDecoration(labelText: title),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (ctrl.text.trim().isNotEmpty) {
                        data[key] = ctrl.text.trim();
                        _firestore
                            .collection('profiles')
                            .doc(user!.uid)
                            .set(data, SetOptions(merge: true));
                        setState(() {});
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  Widget _tile(String label, String key, bool isYear) {
    return ListTile(
      title: Text(label),
      subtitle: Text(data[key]?.toString() ?? 'Tap to set'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _editField(key, label, data[key]?.toString(), isYear),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        children: [
          Center(
            child: GestureDetector(
              onTap: _showImageOptions,
              child: CircleAvatar(
                radius: 50,
                backgroundColor: const Color(0xFFE78D83),
                backgroundImage:
                    data['imageUrl'] != null
                        ? NetworkImage(data['imageUrl'])
                        : null,
                child:
                    data['imageUrl'] == null
                        ? const Icon(
                          Icons.person,
                          size: 50,
                          color: Colors.white,
                        )
                        : null,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            title: const Text('Email'),
            subtitle: Text(user?.email ?? ''),
          ),
          _tile('Full Name', 'fullName', false),
          _tile('Phone Number', 'phoneNumber', false),
          _tile('Birth Year', 'birthYear', true),
          _tile('Gender', 'gender', false),
          _tile('City', 'city', false),
          _tile('Occupation', 'occupation', false),
          _tile('Bio', 'bio', false),
        ],
      ),
    );
  }
}
