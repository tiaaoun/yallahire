import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'dashboard_screen.dart';

class PostScreen extends StatefulWidget {
  final VoidCallback? onPostSuccess;
  final String? editingPostId;
  final Map<String, dynamic>? initialPostData;

  const PostScreen({
    super.key,
    this.onPostSuccess,
    this.editingPostId,
    this.initialPostData,
  });

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  static const String _moderationUrl =
      'https://us-central1-yallahire-1a289.cloudfunctions.net/moderatePostText';
  static const String _improvePostUrl =
      'https://us-central1-yallahire-1a289.cloudfunctions.net/improvePost';

  final _formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final descController = TextEditingController();
  final cityController = TextEditingController();
  final priceController = TextEditingController();

  String? selectedCategory;
  String? selectedCurrency = '\$';
  String selectedPostType = 'job';

  static const Color kBg = Colors.white;
  static const Color kPrimary = Color(0xFFE89C8A);

  bool _isSubmitting = false;
  bool _isImproving = false;

  final List<String> categories = [
    'General Help',
    'Tutoring',
    'Tech',
    'Childcare',
    'Cleaning',
    'Creative',
    'Delivery',
    'Caregiving',
    'Skilled Labor',
    'Other',
  ];

  final List<String> currencies = ['\$', 'LBP'];

  bool get _isEditing => widget.editingPostId != null;

  @override
  void initState() {
    super.initState();
    _prefillPostData();
  }

  @override
  void dispose() {
    titleController.dispose();
    descController.dispose();
    cityController.dispose();
    priceController.dispose();
    super.dispose();
  }

  void _resetForm() {
    titleController.clear();
    descController.clear();
    cityController.clear();
    priceController.clear();

    setState(() {
      selectedCategory = null;
      selectedCurrency = '\$';
      selectedPostType = 'job';
    });
  }

  void _prefillPostData() {
    final post = widget.initialPostData;
    if (post == null) return;

    titleController.text = (post['title'] ?? '').toString();
    descController.text = (post['description'] ?? '').toString();
    cityController.text = (post['city'] ?? '').toString();
    priceController.text = (post['price'] ?? '').toString();

    selectedCategory =
        (post['category'] ?? '').toString().trim().isEmpty
            ? null
            : (post['category'] ?? '').toString();
    selectedCurrency = (post['currency'] ?? '\$').toString();
    selectedPostType = (post['type'] ?? 'job').toString();
  }

  Future<bool> _hasCompleteProfile() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return false;

    final doc =
        await FirebaseFirestore.instance
            .collection('profiles')
            .doc(u.uid)
            .get();

    final profile = doc.data() ?? {};

    final requiredFields = ['fullName', 'birthYear', 'city', 'occupation'];

    for (final field in requiredFields) {
      final value = (profile[field] ?? '').toString().trim();
      if (value.isEmpty) return false;
    }

    final phone =
        (profile['phoneNumber'] ?? u.phoneNumber ?? '').toString().trim();
    final verified = profile['phoneVerified'] == true;

    return phone.isNotEmpty && verified;
  }

  Future<bool> _ensureCompleteProfile() async {
    final ok = await _hasCompleteProfile();

    if (ok) return true;
    if (!mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF4F1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: kPrimary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Complete your profile',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'You need to complete your profile before you can post.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black54,
                            side: const BorderSide(color: Colors.black12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Not now',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Complete',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );

    if (result == true && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const DashboardScreen(initialIndex: 4),
        ),
      );
    }

    return false;
  }

  Future<void> _showSimpleDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Text(
              title,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(
              message,
              style: const TextStyle(color: Colors.black87, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _improveWithAI() async {
    final title = titleController.text.trim();
    final description = descController.text.trim();
    final oldDescription = description;

    if (description.isEmpty) {
      await _showSimpleDialog(
        title: 'Nothing to improve',
        message: 'Write a description first.',
      );
      return;
    }

    setState(() => _isImproving = true);

    try {
      final url = _improvePostUrl;
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': title,
          'description': description,
          'postType': selectedPostType,
        }),
      );

      debugPrint('improvePost URL: $url');
      debugPrint('improvePost statusCode: ${response.statusCode}');
      debugPrint('improvePost raw body: ${response.body}');

      Map<String, dynamic>? body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          body = decoded;
        }
      } catch (_) {
        body = null;
      }

      if (body == null) {
        await _showSimpleDialog(
          title: 'AI error',
          message:
              'URL: $url\n\nStatus: ${response.statusCode}\n\nResponse:\n${response.body}',
        );
        return;
      }

      if (response.statusCode != 200) {
        await _showSimpleDialog(
          title: 'AI error',
          message:
              'URL: $url\n\nStatus: ${response.statusCode}\n\nResponse:\n${response.body}',
        );
        return;
      }

      final improvedDescription =
          (body['improvedDescription'] ?? '').toString().trim();

      if (improvedDescription.isEmpty) {
        await _showSimpleDialog(
          title: 'No visible improvement',
          message:
              'The server returned an empty improvedDescription.\n\nReturned JSON:\n${response.body}',
        );
        return;
      }

      if (improvedDescription == oldDescription) {
        await _showSimpleDialog(
          title: 'No visible improvement',
          message:
              'Returned text is unchanged.\n\nReturned text:\n$improvedDescription',
        );
        return;
      }

      descController.text = improvedDescription;

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('improvePost exception: $e');
      await _showSimpleDialog(title: 'AI error', message: '$e');
    } finally {
      if (mounted) setState(() => _isImproving = false);
    }
  }

  Future<Map<String, String>> _moderatePostText({
    required String title,
    required String description,
  }) async {
    final response = await http.post(
      Uri.parse(_moderationUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'title': title, 'description': description}),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw Exception(body['error'] ?? 'Failed to moderate content.');
    }

    return {
      'status': (body['status'] ?? 'safe').toString(),
      'reason': (body['reason'] ?? '').toString(),
    };
  }

  Future<void> _submitPost() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await _showSimpleDialog(
        title: 'Not logged in',
        message: 'You must be logged in to post.',
      );
      return;
    }

    final profileOk = await _ensureCompleteProfile();
    if (!profileOk) return;

    setState(() => _isSubmitting = true);

    try {
      final title = titleController.text.trim();
      final description = descController.text.trim();

      final moderation = await _moderatePostText(
        title: title,
        description: description,
      );

      final moderationStatus = moderation['status'] ?? 'safe';
      final moderationReason = moderation['reason'] ?? '';

      if (moderationStatus == 'blocked') {
        await _showSimpleDialog(
          title: 'Post blocked',
          message:
              moderationReason.isEmpty
                  ? 'This post cannot be published.'
                  : moderationReason,
        );
        return;
      }

      if (moderationStatus == 'flagged') {
        await _showSimpleDialog(
          title: 'Please edit your post',
          message:
              moderationReason.isEmpty
                  ? 'This post may violate safety rules.'
                  : moderationReason,
        );
        return;
      }

      final profileDoc =
          await FirebaseFirestore.instance
              .collection('profiles')
              .doc(user.uid)
              .get();

      final profileData = profileDoc.data() ?? {};
      final posterName =
          (profileData['fullName']?.toString().trim().isNotEmpty ?? false)
              ? profileData['fullName'].toString()
              : 'User';
      final posterImageUrl = (profileData['imageUrl'] ?? '').toString();

      final postData = {
        'type': selectedPostType,
        'title': title,
        'description': description,
        'category': selectedCategory,
        'city': cityController.text.trim(),
        'price': priceController.text.trim(),
        'currency': selectedCurrency,
        'createdAt': Timestamp.now(),
        'postedBy': user.uid,
        'posterName': posterName,
        'posterImageUrl': posterImageUrl,
      };

      if (_isEditing) {
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.editingPostId)
            .update({
              'type': selectedPostType,
              'title': title,
              'description': description,
              'category': selectedCategory,
              'city': cityController.text.trim(),
              'price': priceController.text.trim(),
              'currency': selectedCurrency,
              'posterName': posterName,
              'posterImageUrl': posterImageUrl,
              'updatedAt': Timestamp.now(),
            });

        if (!mounted) return;

        Navigator.pop(context, true);
        return;
      }

      await FirebaseFirestore.instance.collection('posts').add(postData);

      if (!mounted) return;

      _resetForm();
      widget.onPostSuccess?.call();
    } catch (e) {
      await _showSimpleDialog(title: 'Error', message: '$e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.black54),
      alignLabelWithHint: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.black26),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kPrimary, width: 2),
      ),
      floatingLabelStyle: const TextStyle(color: kPrimary),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          _isEditing
              ? 'Edit Post'
              : (selectedPostType == 'job' ? 'Post a Task' : 'Offer a Service'),
          style: const TextStyle(color: Colors.black),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: selectedPostType,
                decoration: _inputDecoration('Post Type'),
                items: const [
                  DropdownMenuItem(value: 'job', child: Text('Hiring')),
                  DropdownMenuItem(
                    value: 'service',
                    child: Text('Looking for Work'),
                  ),
                ],
                onChanged:
                    (_isSubmitting || _isImproving)
                        ? null
                        : (val) =>
                            setState(() => selectedPostType = val ?? 'job'),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: titleController,
                cursorColor: kPrimary,
                decoration: _inputDecoration('Title'),
                validator:
                    (val) => val!.isEmpty ? 'Please enter a title' : null,
                enabled: !_isSubmitting && !_isImproving,
              ),
              const SizedBox(height: 18),
              Stack(
                children: [
                  TextFormField(
                    controller: descController,
                    cursorColor: kPrimary,
                    minLines: 3,
                    maxLines: 4,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: _inputDecoration('Description').copyWith(
                      contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 48),
                    ),
                    validator:
                        (val) =>
                            val!.isEmpty ? 'Please enter a description' : null,
                    enabled: !_isSubmitting && !_isImproving,
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap:
                            (_isImproving || _isSubmitting)
                                ? null
                                : _improveWithAI,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1ED),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFF3C7BC)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _isImproving
                                  ? const SizedBox(
                                    height: 12,
                                    width: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: kPrimary,
                                    ),
                                  )
                                  : const Icon(
                                    Icons.auto_fix_high,
                                    size: 14,
                                    color: kPrimary,
                                  ),
                              const SizedBox(width: 5),
                              Text(
                                _isImproving ? '...' : 'Improve with AI',
                                style: const TextStyle(
                                  color: kPrimary,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                isDense: true,
                decoration: _inputDecoration('Category'),
                items:
                    categories
                        .map(
                          (cat) =>
                              DropdownMenuItem(value: cat, child: Text(cat)),
                        )
                        .toList(),
                onChanged:
                    (_isSubmitting || _isImproving)
                        ? null
                        : (val) => setState(() => selectedCategory = val),
                validator:
                    (val) => val == null ? 'Please choose a category' : null,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: cityController,
                cursorColor: kPrimary,
                decoration: _inputDecoration('City'),
                validator: (val) => val!.isEmpty ? 'Please enter a city' : null,
                enabled: !_isSubmitting && !_isImproving,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: TextFormField(
                      controller: priceController,
                      cursorColor: kPrimary,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('Price'),
                      validator: (val) => val!.isEmpty ? 'Enter price' : null,
                      enabled: !_isSubmitting && !_isImproving,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: selectedCurrency,
                      isExpanded: true,
                      decoration: _inputDecoration('Currency').copyWith(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                      items:
                          currencies
                              .map(
                                (cur) => DropdownMenuItem(
                                  value: cur,
                                  child: Text(
                                    cur,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged:
                          (_isSubmitting || _isImproving)
                              ? null
                              : (val) => setState(() => selectedCurrency = val),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      (_isSubmitting || _isImproving) ? null : _submitPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 2,
                  ),
                  child:
                      _isSubmitting
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : Text(
                            _isEditing
                                ? 'Save Changes'
                                : (selectedPostType == 'job'
                                    ? 'Submit Task'
                                    : 'Submit Service'),
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
