import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostScreen extends StatefulWidget {
  const PostScreen({super.key});

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final _formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final descController = TextEditingController();
  final cityController = TextEditingController();
  final priceController = TextEditingController();

  String? selectedCategory;
  String? selectedCurrency = '\$';

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

  @override
  void dispose() {
    titleController.dispose();
    descController.dispose();
    cityController.dispose();
    priceController.dispose();
    super.dispose();
  }

  Future<void> _submitPost() async {
    if (_formKey.currentState!.validate()) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to post.')),
        );
        return;
      }

      final jobData = {
        'title': titleController.text.trim(),
        'description': descController.text.trim(),
        'category': selectedCategory,
        'city': cityController.text.trim(),
        'price': priceController.text.trim(),
        'currency': selectedCurrency,
        'createdAt': Timestamp.now(),
        'postedBy': user.uid,
      };

      try {
        await FirebaseFirestore.instance.collection('jobs').add(jobData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Task posted successfully!')),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
      }
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // ✅ Clean white
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Post a Task', style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: titleController,
                decoration: _inputDecoration('Title'),
                validator:
                    (val) => val!.isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: descController,
                decoration: _inputDecoration('Description'),
                maxLines: 3,
                validator:
                    (val) => val!.isEmpty ? 'Please enter a description' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                items:
                    categories
                        .map(
                          (cat) =>
                              DropdownMenuItem(value: cat, child: Text(cat)),
                        )
                        .toList(),
                onChanged: (val) => setState(() => selectedCategory = val),
                decoration: _inputDecoration('Category'),
                validator:
                    (val) => val == null ? 'Please choose a category' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: cityController,
                decoration: _inputDecoration('City'),
                validator: (val) => val!.isEmpty ? 'Please enter a city' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('Price'),
                      validator: (val) => val!.isEmpty ? 'Enter price' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      value: selectedCurrency,
                      items:
                          currencies
                              .map(
                                (cur) => DropdownMenuItem(
                                  value: cur,
                                  child: Text(cur),
                                ),
                              )
                              .toList(),
                      onChanged:
                          (val) => setState(() => selectedCurrency = val),
                      decoration: _inputDecoration(''),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE78D83), // ✅ Salmon
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
