import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'home_screen.dart';
import 'chat_list_screen.dart';
import 'post_screen.dart';
import 'my_posts_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  final int initialIndex;

  const DashboardScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const Color kPrimary = Color(0xFFE78D83);

  late int _currentIndex;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();

    _currentIndex = widget.initialIndex;

    _screens = [
      const HomeScreen(),
      const ChatListScreen(),
      PostScreen(
        onPostSuccess: () {
          setState(() => _currentIndex = 3);
        },
      ),
      const MyPostsScreen(),
      const ProfileScreen(isOnboarding: false),
    ];
  }

  int _safeInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse('$value') ?? 0;
  }

  Widget _buildChatIcon(int unreadChatsCount) {
    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Center(
            child: Icon(Icons.chat),
          ),
          if (unreadChatsCount > 0)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 2,
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                decoration: BoxDecoration(
                  color: kPrimary,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white,
                    width: 1.4,
                  ),
                ),
                child: Center(
                  child: Text(
                    unreadChatsCount > 99 ? '99+' : '$unreadChatsCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  BottomNavigationBar _buildBottomNav(int unreadChatsCount) {
    return BottomNavigationBar(
      backgroundColor: Colors.white,
      type: BottomNavigationBarType.fixed,
      currentIndex: _currentIndex,
      selectedItemColor: kPrimary,
      unselectedItemColor: Colors.grey,
      onTap: (index) => setState(() => _currentIndex = index),
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: _buildChatIcon(unreadChatsCount),
          activeIcon: _buildChatIcon(unreadChatsCount),
          label: 'Chat',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.add_box_outlined),
          activeIcon: Icon(Icons.add_box_outlined),
          label: 'Post',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.article_outlined),
          activeIcon: Icon(Icons.article_outlined),
          label: 'Activity',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: currentUser == null
          ? _buildBottomNav(0)
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('participants', arrayContains: currentUser.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                final chats = snapshot.data?.docs ?? [];
                int unreadChatsCount = 0;

                for (final chat in chats) {
                  final data = chat.data() as Map<String, dynamic>;
                  final unreadMap =
                      Map<String, dynamic>.from(data['unreadCount'] ?? {});
                  final unreadValue = _safeInt(unreadMap[currentUser.uid]);

                  if (unreadValue > 0) {
                    unreadChatsCount++;
                  }
                }

                return _buildBottomNav(unreadChatsCount);
              },
            ),
    );
  }
}