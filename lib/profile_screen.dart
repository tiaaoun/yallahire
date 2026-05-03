import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'app_feedback.dart';
import 'dashboard_screen.dart';
import 'reports_review_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool isOnboarding;

  const ProfileScreen({super.key, this.isOnboarding = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color kPrimary = Color(0xFFE89C8A);

  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  User? get user => FirebaseAuth.instance.currentUser;

  Map<String, dynamic> data = {};
  bool loading = true;
  final int currentYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = user;
    if (u == null) {
      if (mounted) setState(() => loading = false);
      return;
    }

    try {
      final doc = await _firestore.collection('profiles').doc(u.uid).get();

      if (doc.exists) {
        data = doc.data() ?? {};
      }

      data['country'] = 'Lebanon';
      data['phoneNumber'] = u.phoneNumber ?? data['phoneNumber'] ?? '';
      data['phoneVerified'] = true;
    } catch (_) {}

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> _saveProfile({bool showMessage = false}) async {
    final u = user;
    if (u == null) return;

    await _firestore.collection('profiles').doc(u.uid).set({
      ...data,
      'country': 'Lebanon',
      'phoneNumber': u.phoneNumber ?? data['phoneNumber'] ?? '',
      'phoneVerified': true,
    }, SetOptions(merge: true));

    if (!mounted || !showMessage) return;

    await showAppMessageDialog(context, message: 'Profile saved.');
  }

  void _goToDashboard() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
      (route) => false,
    );
  }

  Future<void> _onSaveTopRight() async {
    await _saveProfile();
    if (!mounted) return;
    _goToDashboard();
  }

  void _openSettingsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SettingsScreen(isAdmin: data['isAdmin'] == true),
      ),
    );
  }

  Future<void> _pickImage(ImageSource src) async {
    final u = user;
    if (u == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: src, imageQuality: 75);
    if (picked == null) return;

    if (mounted) Navigator.pop(context);

    try {
      final file = File(picked.path);
      final ref = _storage.ref('profile_pics/${u.uid}.jpg');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      data['imageUrl'] = url;
      await _saveProfile(showMessage: false);

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      await showAppMessageDialog(
        context,
        title: 'Error',
        message: 'Upload failed: $e',
      );
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder:
          (_) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.photo_library,
                    color: Colors.black87,
                  ),
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
    final u = user;
    if (u == null) return;

    if (isYear) {
      String? selected = current;

      final validYears =
          List.generate(currentYear - 1900 + 1, (i) => currentYear - i)
              .where((y) => y <= currentYear - 18)
              .map((y) => y.toString())
              .toList();

      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        builder: (sheetContext) {
          return SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              height: 250,
              child: Column(
                children: [
                  Text(
                    'Set $title',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selected,
                    dropdownColor: Colors.white,
                    iconEnabledColor: Colors.black54,
                    style: const TextStyle(color: Colors.black87, fontSize: 15),
                    items:
                        validYears
                            .map(
                              (y) => DropdownMenuItem(value: y, child: Text(y)),
                            )
                            .toList(),
                    onChanged: (v) => selected = v,
                    decoration: InputDecoration(
                      labelText: title,
                      labelStyle: const TextStyle(color: Colors.black54),
                      floatingLabelStyle: const TextStyle(
                        color: Colors.black54,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Colors.black26),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Colors.black38),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (selected == null) return;

                        data[key] = selected;
                        await _saveProfile(showMessage: false);

                        if (!mounted) return;
                        setState(() {});
                        Navigator.pop(sheetContext);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      return;
    }

    if (key == 'gender') {
      String? selected = current;

      const genderOptions = ['Female', 'Male', 'Prefer not to say'];

      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        builder: (sheetContext) {
          return SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              height: 250,
              child: Column(
                children: [
                  const Text(
                    'Set Gender',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selected,
                    dropdownColor: Colors.white,
                    iconEnabledColor: Colors.black54,
                    style: const TextStyle(color: Colors.black87, fontSize: 15),
                    items:
                        genderOptions
                            .map(
                              (g) => DropdownMenuItem(value: g, child: Text(g)),
                            )
                            .toList(),
                    onChanged: (v) => selected = v,
                    decoration: InputDecoration(
                      labelText: 'Gender',
                      labelStyle: const TextStyle(color: Colors.black54),
                      floatingLabelStyle: const TextStyle(
                        color: Colors.black54,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Colors.black26),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Colors.black38),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (selected == null) return;

                        data[key] = selected;
                        await _saveProfile(showMessage: false);

                        if (!mounted) return;
                        setState(() {});
                        Navigator.pop(sheetContext);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (sheetContext) {
        final ctrl = TextEditingController(text: current ?? '');

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Set $title',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ctrl,
                  cursorColor: Colors.black,
                  style: const TextStyle(color: Colors.black87, fontSize: 15),
                  maxLines: key == 'bio' ? 4 : 1,
                  decoration: InputDecoration(
                    labelText: title,
                    labelStyle: const TextStyle(color: Colors.black54),
                    floatingLabelStyle: const TextStyle(color: Colors.black54),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.black26),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.black38),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final v = ctrl.text.trim();
                      if (v.isEmpty) return;

                      data[key] = v;
                      await _saveProfile(showMessage: false);

                      if (!mounted) return;
                      setState(() {});
                      Navigator.pop(sheetContext);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _simpleRow({
    required String label,
    required String value,
    required VoidCallback? onTap,
    bool readOnly = false,
    Widget? trailing,
  }) {
    final hasValue = value.trim().isNotEmpty;

    return InkWell(
      onTap: readOnly ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasValue ? value : 'Add $label',
                    style: TextStyle(
                      fontSize: 16,
                      color: hasValue ? Colors.black87 : Colors.black38,
                      fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
            if (!readOnly && trailing == null)
              const Icon(Icons.chevron_right, color: Colors.black38),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Divider(height: 1, thickness: 1, color: Colors.grey.shade200);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final u = user;

    if (u == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text('Please log in.')),
      );
    }

    final imageUrl = data['imageUrl']?.toString();
    final phoneNumber =
        (u.phoneNumber ?? data['phoneNumber'] ?? '').toString().trim();

    final fullName = (data['fullName'] ?? '').toString().trim();
    final city = (data['city'] ?? '').toString().trim();
    final occupation = (data['occupation'] ?? '').toString().trim();
    final birthYear = (data['birthYear'] ?? '').toString().trim();
    final gender = (data['gender'] ?? '').toString().trim();
    final bio = (data['bio'] ?? '').toString().trim();

    if (widget.isOnboarding) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'Set up profile',
            style: TextStyle(color: Colors.black),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          leadingWidth: 70,
          leading: TextButton(
            onPressed: _goToDashboard,
            child: const Text(
              'Skip',
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _onSaveTopRight,
              child: const Text(
                'Save',
                style: TextStyle(color: kPrimary, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _showImageOptions,
                  child: CircleAvatar(
                    radius: 42,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage:
                        (imageUrl != null && imageUrl.isNotEmpty)
                            ? NetworkImage(imageUrl)
                            : null,
                    child:
                        (imageUrl == null || imageUrl.isEmpty)
                            ? Icon(
                              Icons.person,
                              size: 42,
                              color: Colors.grey.shade500,
                            )
                            : null,
                  ),
                ),
                const SizedBox(height: 18),
                _simpleRow(
                  label: 'Phone Number',
                  value: phoneNumber,
                  onTap: null,
                  readOnly: true,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      'Verified',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                _divider(),
                _simpleRow(
                  label: 'Full Name',
                  value: fullName,
                  onTap:
                      () => _editField(
                        'fullName',
                        'Full Name',
                        data['fullName']?.toString(),
                        false,
                      ),
                ),
                _divider(),
                _simpleRow(
                  label: 'City',
                  value: city,
                  onTap:
                      () => _editField(
                        'city',
                        'City',
                        data['city']?.toString(),
                        false,
                      ),
                ),
                _divider(),
                _simpleRow(
                  label: 'Occupation',
                  value: occupation,
                  onTap:
                      () => _editField(
                        'occupation',
                        'Occupation',
                        data['occupation']?.toString(),
                        false,
                      ),
                ),
                _divider(),
                _simpleRow(
                  label: 'Birth Year',
                  value: birthYear,
                  onTap:
                      () => _editField(
                        'birthYear',
                        'Birth Year',
                        data['birthYear']?.toString(),
                        true,
                      ),
                ),
                _divider(),
                _simpleRow(
                  label: 'Gender',
                  value: gender,
                  onTap:
                      () => _editField(
                        'gender',
                        'Gender',
                        data['gender']?.toString(),
                        false,
                      ),
                ),
                _divider(),
                _simpleRow(
                  label: 'Bio',
                  value: bio,
                  onTap:
                      () => _editField(
                        'bio',
                        'Bio',
                        data['bio']?.toString(),
                        false,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _openSettingsPage,
            icon: const Icon(Icons.settings_outlined, color: Colors.black87),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            children: [
              GestureDetector(
                onTap: _showImageOptions,
                child: CircleAvatar(
                  radius: 42,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage:
                      (imageUrl != null && imageUrl.isNotEmpty)
                          ? NetworkImage(imageUrl)
                          : null,
                  child:
                      (imageUrl == null || imageUrl.isEmpty)
                          ? Icon(
                            Icons.person,
                            size: 42,
                            color: Colors.grey.shade500,
                          )
                          : null,
                ),
              ),
              const SizedBox(height: 18),
              _simpleRow(
                label: 'Phone Number',
                value: phoneNumber,
                onTap: null,
                readOnly: true,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    'Verified',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              _divider(),
              _simpleRow(
                label: 'Full Name',
                value: fullName,
                onTap:
                    () => _editField(
                      'fullName',
                      'Full Name',
                      data['fullName']?.toString(),
                      false,
                    ),
              ),
              _divider(),
              _simpleRow(
                label: 'City',
                value: city,
                onTap:
                    () => _editField(
                      'city',
                      'City',
                      data['city']?.toString(),
                      false,
                    ),
              ),
              _divider(),
              _simpleRow(
                label: 'Occupation',
                value: occupation,
                onTap:
                    () => _editField(
                      'occupation',
                      'Occupation',
                      data['occupation']?.toString(),
                      false,
                    ),
              ),
              _divider(),
              _simpleRow(
                label: 'Birth Year',
                value: birthYear,
                onTap:
                    () => _editField(
                      'birthYear',
                      'Birth Year',
                      data['birthYear']?.toString(),
                      true,
                    ),
              ),
              _divider(),
              _simpleRow(
                label: 'Gender',
                value: gender,
                onTap:
                    () => _editField(
                      'gender',
                      'Gender',
                      data['gender']?.toString(),
                      false,
                    ),
              ),
              _divider(),
              _simpleRow(
                label: 'Bio',
                value: bio,
                onTap:
                    () => _editField(
                      'bio',
                      'Bio',
                      data['bio']?.toString(),
                      false,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSection {
  final String title;
  final List<String> paragraphs;

  const _SettingsSection({required this.title, required this.paragraphs});
}

class _SettingsPageData {
  final String title;
  final IconData icon;
  final String intro;
  final List<_SettingsSection> sections;
  final bool showIntroIcon;

  const _SettingsPageData({
    required this.title,
    required this.icon,
    required this.intro,
    required this.sections,
    this.showIntroIcon = true,
  });
}

class _SettingsContentScreen extends StatelessWidget {
  final _SettingsPageData page;

  const _SettingsContentScreen({required this.page});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(page.title, style: const TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 18),
                padding: EdgeInsets.symmetric(
                  horizontal: page.showIntroIcon ? 18 : 20,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBFA),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF2DFDA)),
                ),
                child:
                    page.showIntroIcon
                        ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1ED),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                page.icon,
                                color: const Color(0xFFB86E5D),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                page.intro,
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.6,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        )
                        : Text(
                          page.intro,
                          textAlign: TextAlign.left,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.6,
                            color: Colors.black87,
                          ),
                        ),
              ),
              ...page.sections.map((section) {
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...section.paragraphs.map((paragraph) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            paragraph,
                            style: const TextStyle(
                              fontSize: 14.5,
                              height: 1.65,
                              color: Colors.black87,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsScreen extends StatelessWidget {
  final bool isAdmin;

  const _SettingsScreen({required this.isAdmin});

  void _pushSettingsInfoPage(BuildContext context, _SettingsPageData page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _SettingsContentScreen(page: page)),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Log out?',
              style: TextStyle(color: Colors.black),
            ),
            content: const Text(
              'Are you sure you want to log out of your account?',
              style: TextStyle(color: Colors.black87, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text(
                  'Log Out',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );

    if (!context.mounted) return;
    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget item({
      required IconData icon,
      required String title,
      required VoidCallback onTap,
      bool isDestructive = false,
    }) {
      final iconColor =
          isDestructive ? const Color(0xFFB86E5D) : Colors.black87;

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color:
                  isDestructive
                      ? const Color(0xFFFFF1ED)
                      : const Color(0xFFFFF4F1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 21),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: isDestructive ? const Color(0xFFB86E5D) : Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.black26),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 18),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBFA),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF2DFDA)),
              ),
              child: const Text(
                'Support, policies, and account actions for YallaHire.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Colors.black87,
                ),
              ),
            ),
            item(
              icon: Icons.info_outline,
              title: 'How YallaHire Works',
              onTap:
                  () => _pushSettingsInfoPage(context, _howYallaHireWorksPage),
            ),
            item(
              icon: Icons.shield_outlined,
              title: 'Safety Tips',
              onTap: () => _pushSettingsInfoPage(context, _safetyTipsPage),
            ),
            item(
              icon: Icons.groups_outlined,
              title: 'Community Guidelines',
              onTap:
                  () =>
                      _pushSettingsInfoPage(context, _communityGuidelinesPage),
            ),
            item(
              icon: Icons.lock_outline,
              title: 'Privacy Policy',
              onTap: () => _pushSettingsInfoPage(context, _privacyPolicyPage),
            ),
            item(
              icon: Icons.description_outlined,
              title: 'Terms of Use',
              onTap: () => _pushSettingsInfoPage(context, _termsOfUsePage),
            ),
            item(
              icon: Icons.help_outline,
              title: 'Help & Support',
              onTap: () => _pushSettingsInfoPage(context, _helpAndSupportPage),
            ),
            if (isAdmin)
              item(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Review Reports',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ReportsReviewScreen(),
                    ),
                  );
                },
              ),
            const SizedBox(height: 6),
            item(
              icon: Icons.logout,
              title: 'Log Out',
              isDestructive: true,
              onTap: () async {
                await _signOut(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

const _howYallaHireWorksPage = _SettingsPageData(
  title: 'How YallaHire Works',
  icon: Icons.info_outline,
  showIntroIcon: false,
  intro:
      'YallaHire is designed to help people connect for local tasks and services in a simple, flexible, and safer way. You can use the app whether you need help with something or want to offer your own skills to others.',
  sections: [
    _SettingsSection(
      title: 'A. Post a Task',
      paragraphs: [
        'Use this option when you need help with something and want other users to see your request. Tasks can include tutoring, deliveries, cleaning, caregiving, tech help, creative work, general errands, or other everyday support.',
        'When posting a task, you add a title, description, category, city or location, price, and currency. A clear title and detailed description help the right people understand what you need before they respond.',
      ],
    ),
    _SettingsSection(
      title: 'B. Hire for a Task',
      paragraphs: [
        'You can browse available task posts and open the ones that match your skills or availability. Review the post details carefully, including the description, location, and payment information.',
        'Depending on the flow available in the app, you can apply, request the task, or contact the poster through chat. After that, wait for the post owner to accept before assuming the work is confirmed.',
        'Before starting any task, both sides should communicate clearly about timing, expectations, payment, and any important details so there is no confusion later.',
      ],
    ),
    _SettingsSection(
      title: 'C. Post a Skill or Service',
      paragraphs: [
        'If you want to offer something you can do, you can create a service post. This is useful for things like private driving, tutoring, babysitting, design, repairs, delivery help, or other services you are comfortable providing.',
        'A service post lets other users discover what you can offer, where you are available, and what kind of work you are open to doing. The clearer your post is, the easier it is for the right people to find you.',
      ],
    ),
    _SettingsSection(
      title: 'D. Hire a Skill or Service',
      paragraphs: [
        'You can also browse service posts when you are looking for someone with a specific skill. Open the post, review the description, and request help if the service matches what you need.',
        'After that, use chat to agree on the details, ask questions, confirm timing, and make sure both sides are comfortable before moving forward.',
      ],
    ),
    _SettingsSection(
      title: 'Staying Safe While Using YallaHire',
      paragraphs: [
        'Take time to review profiles, posts, and messages carefully before agreeing to anything. Clear communication and realistic expectations help both users avoid misunderstandings.',
        'When possible, keep communication inside the app so there is a record of what was discussed. Avoid sharing sensitive personal information too early, especially before trust has been built.',
        'If you notice suspicious behavior, scams, unsafe requests, harassment, or inappropriate content, use the Report option so the issue can be reviewed.',
      ],
    ),
  ],
);

const _safetyTipsPage = _SettingsPageData(
  title: 'Safety Tips',
  icon: Icons.shield_outlined,
  intro:
      'Safety matters on every task or service. These tips can help you make better decisions, protect your privacy, and use YallaHire more confidently.',
  sections: [
    _SettingsSection(
      title: 'Meet in Safe Public Places When Needed',
      paragraphs: [
        'If a task or service requires meeting in person, choose a safe and public location whenever possible. Daytime meetings and familiar places are usually better than isolated or unfamiliar locations.',
      ],
    ),
    _SettingsSection(
      title: 'Do Not Send Money Before Work Is Confirmed',
      paragraphs: [
        'Be careful with advance payments, especially if the other person is unknown or the details are still unclear. Confirm the task first and only proceed when the arrangement feels legitimate and understood by both sides.',
      ],
    ),
    _SettingsSection(
      title: 'Keep Communication Clear and Respectful',
      paragraphs: [
        'Ask direct questions, confirm the work details, and make sure both people agree on timing, pricing, and expectations. Respectful communication helps prevent confusion and makes the process more professional.',
      ],
    ),
    _SettingsSection(
      title: 'Avoid Sharing Sensitive Personal Information',
      paragraphs: [
        'Do not rush to share private details such as home address, financial information, or unnecessary identity documents. Share only what is needed and only when you feel comfortable.',
      ],
    ),
    _SettingsSection(
      title: 'Trust Your Instincts',
      paragraphs: [
        'If something feels suspicious, rushed, misleading, or unsafe, pause the conversation. You are never required to continue with a task or service that makes you uncomfortable.',
      ],
    ),
    _SettingsSection(
      title: 'Use the Report Option',
      paragraphs: [
        'If you notice suspicious activity, scams, unsafe requests, harassment, or inappropriate content, report it through the app. Reports help keep the YallaHire community safer for everyone.',
      ],
    ),
    _SettingsSection(
      title: 'Tell Someone You Trust',
      paragraphs: [
        'For in-person tasks, let a friend or family member know where you are going, who you are meeting, and when you expect to return. A simple check-in can add an important layer of safety.',
      ],
    ),
  ],
);

const _communityGuidelinesPage = _SettingsPageData(
  title: 'Community Guidelines',
  icon: Icons.groups_outlined,
  intro:
      'YallaHire works best when users treat each other fairly, communicate honestly, and post responsibly. These guidelines help create a respectful and safer community for everyone.',
  sections: [
    _SettingsSection(
      title: 'Be Respectful',
      paragraphs: [
        'Treat other users politely in posts, chats, applications, and requests. Clear and respectful communication is expected throughout the platform.',
      ],
    ),
    _SettingsSection(
      title: 'No Harassment, Hate Speech, Threats, or Discrimination',
      paragraphs: [
        'Abusive language, intimidation, harassment, threats, hate speech, or discriminatory behavior is not allowed on YallaHire.',
      ],
    ),
    _SettingsSection(
      title: 'No Scams or Misleading Posts',
      paragraphs: [
        'Do not create fake jobs, fake services, scam offers, or misleading posts. Posts should accurately describe what is needed or what is being offered.',
      ],
    ),
    _SettingsSection(
      title: 'No Unsafe, Illegal, or Harmful Requests',
      paragraphs: [
        'Users may not post illegal, dangerous, harmful, or clearly unsafe tasks and services. Content that puts others at risk is not allowed.',
      ],
    ),
    _SettingsSection(
      title: 'No Spam',
      paragraphs: [
        'Repeated irrelevant posts, excessive promotion, or cluttering the app with spam-like content is not allowed.',
      ],
    ),
    _SettingsSection(
      title: 'Use Accurate Descriptions and Fair Pricing',
      paragraphs: [
        'Post titles, descriptions, categories, and pricing should be honest and realistic. This helps users make informed decisions before applying or requesting help.',
      ],
    ),
    _SettingsSection(
      title: 'Respect Privacy',
      paragraphs: [
        'Do not pressure other users to share personal information that is not necessary. Respect boundaries and use information responsibly.',
      ],
    ),
    _SettingsSection(
      title: 'Admin Review and Enforcement',
      paragraphs: [
        'Reports may be reviewed by admins. Posts that violate the guidelines may be removed, and accounts may be restricted if they repeatedly break platform rules.',
      ],
    ),
  ],
);

const _privacyPolicyPage = _SettingsPageData(
  title: 'Privacy Policy',
  icon: Icons.lock_outline,
  intro:
      'This Privacy Policy explains, in simple terms, how YallaHire may handle user information inside the app. It is written to be clear and suitable for the current student-project version of the platform.',
  sections: [
    _SettingsSection(
      title: 'What Information YallaHire May Collect',
      paragraphs: [
        'YallaHire may collect information such as your name, email address, phone number, profile details, posts, applications, hire requests, chats, reports, and general usage activity inside the app.',
      ],
    ),
    _SettingsSection(
      title: 'Why This Information Is Used',
      paragraphs: [
        'This information may be used to create and manage accounts, match users with tasks and services, enable communication, support moderation and safety checks, review reports, and improve how the app works.',
      ],
    ),
    _SettingsSection(
      title: 'What Becomes Visible to Other Users',
      paragraphs: [
        'Some information may be visible to other users only when you choose to include it in your profile, posts, or interactions. YallaHire should not publicly share private information unless you decide to provide it as part of using the platform.',
      ],
    ),
    _SettingsSection(
      title: 'Safety and Reports',
      paragraphs: [
        'Reports submitted through the app may be reviewed by admins to help protect users and respond to suspicious, unsafe, or inappropriate activity.',
      ],
    ),
    _SettingsSection(
      title: 'Questions or Concerns',
      paragraphs: [
        'If you have privacy concerns or would like help regarding account information, you can contact support for assistance.',
      ],
    ),
  ],
);

const _termsOfUsePage = _SettingsPageData(
  title: 'Terms of Use',
  icon: Icons.description_outlined,
  intro:
      'These Terms of Use explain the basic responsibilities of using YallaHire. By using the app, users are expected to act honestly, respectfully, and within the platform rules.',
  sections: [
    _SettingsSection(
      title: 'Accurate Information',
      paragraphs: [
        'Users should provide accurate and up-to-date information in their profiles, posts, and messages. Misleading information can harm trust and may lead to action on the account.',
      ],
    ),
    _SettingsSection(
      title: 'Responsibility for Posted Content',
      paragraphs: [
        'Users are responsible for the content they post, including task details, service descriptions, pricing, and communications with others.',
      ],
    ),
    _SettingsSection(
      title: 'Platform Role',
      paragraphs: [
        'YallaHire is a platform that helps connect people for tasks and services. It does not directly employ users or guarantee the performance of any task, service, or agreement between users.',
      ],
    ),
    _SettingsSection(
      title: 'Following Safety Rules and Guidelines',
      paragraphs: [
        'Users are expected to follow YallaHire safety guidance and community guidelines while using the app.',
      ],
    ),
    _SettingsSection(
      title: 'Prohibited Activity',
      paragraphs: [
        'Illegal, harmful, abusive, deceptive, or misleading activity is not allowed. This includes scams, harassment, unsafe requests, fake services, and other harmful behavior.',
      ],
    ),
    _SettingsSection(
      title: 'Restrictions and Removal',
      paragraphs: [
        'Posts or accounts may be restricted, reviewed, or removed if they violate the rules of the platform.',
      ],
    ),
    _SettingsSection(
      title: 'Clear Agreements',
      paragraphs: [
        'Before starting any work, users should discuss the task clearly, including timing, expectations, and payment details, so both sides understand what has been agreed.',
      ],
    ),
  ],
);

const _helpAndSupportPage = _SettingsPageData(
  title: 'Help & Support',
  icon: Icons.help_outline,
  intro:
      'If you need help using YallaHire, this page covers the most common questions and explains where to go next when something feels unclear or unsafe.',
  sections: [
    _SettingsSection(
      title: 'FAQ: How do I post a task?',
      paragraphs: [
        'Open the post flow, choose the task type, then fill in the title, description, category, city or location, price, and currency. A clear post makes it easier for the right users to respond.',
      ],
    ),
    _SettingsSection(
      title: 'FAQ: How do I offer a service?',
      paragraphs: [
        'Use the post flow to create a service post that explains what you can offer. Add a clear title and description so other users understand your skill or service.',
      ],
    ),
    _SettingsSection(
      title: 'FAQ: How do I apply or request help?',
      paragraphs: [
        'Browse posts, open the one you are interested in, review the details, and use the available action to apply or request help. After that, continue the conversation through chat when needed.',
      ],
    ),
    _SettingsSection(
      title: 'FAQ: How do I report a post?',
      paragraphs: [
        'Use the three-dot menu on a post and choose Report. Then select the reason, add optional details, and submit the report for review.',
      ],
    ),
    _SettingsSection(
      title: 'FAQ: What should I do if someone behaves suspiciously?',
      paragraphs: [
        'Stop engaging if something feels unsafe, misleading, or uncomfortable. Avoid sharing more information and use the report option so the issue can be reviewed.',
      ],
    ),
    _SettingsSection(
      title: 'FAQ: How do I edit or delete my post?',
      paragraphs: [
        'Open the three-dot menu on one of your own posts. From there, you can choose Edit to update it or Delete to remove it.',
      ],
    ),
    _SettingsSection(
      title: 'FAQ: How do I contact support?',
      paragraphs: [
        'Contact support at: tiaaounn@gmail.com',
        'You can reach out here if you need help with your account, reporting an issue, or using YallaHire.',
      ],
    ),
  ],
);
