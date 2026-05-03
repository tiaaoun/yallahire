import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_feedback.dart';
import 'notification_service.dart';
import 'user_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final String peerId;
  final String peerName;

  const ChatScreen({super.key, required this.peerId, required this.peerName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final currentUser = FirebaseAuth.instance.currentUser!;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  late final String chatId;

  @override
  void initState() {
    super.initState();
    final ids = [currentUser.uid, widget.peerId]..sort();
    chatId = '${ids[0]}_${ids[1]}';
    _markMessagesAsSeen();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _showError(String text) {
    showAppMessageDialog(context, title: 'Error', message: text);
  }

  int _safeInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse('$value') ?? 0;
  }

  Future<void> _markMessagesAsSeen() async {
    try {
      final chatRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId);

      final unreadMessages =
          await chatRef
              .collection('messages')
              .where('receiverId', isEqualTo: currentUser.uid)
              .where('seen', isEqualTo: false)
              .get();

      for (final doc in unreadMessages.docs) {
        await doc.reference.update({'seen': true});
      }

      final chatDoc = await chatRef.get();
      final chatData = chatDoc.data() ?? {};
      final unreadMap = Map<String, dynamic>.from(
        chatData['unreadCount'] ?? {},
      );

      unreadMap[currentUser.uid] = 0;

      await chatRef.set({
        'participants': [currentUser.uid, widget.peerId],
        'unreadCount': unreadMap,
      }, SetOptions(merge: true));
    } catch (e) {
      _showError('Seen update failed: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    try {
      final chatRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId);
      final ids = [currentUser.uid, widget.peerId]..sort();
      final now = Timestamp.now();
      final senderProfile =
          await FirebaseFirestore.instance
              .collection('profiles')
              .doc(currentUser.uid)
              .get();
      final senderName =
          (senderProfile.data()?['fullName'] ?? 'User').toString();

      final chatDoc = await chatRef.get();
      final chatData = chatDoc.data() ?? {};
      final unreadMap = Map<String, dynamic>.from(
        chatData['unreadCount'] ?? {},
      );

      final peerUnread = _safeInt(unreadMap[widget.peerId]);

      unreadMap[currentUser.uid] = 0;
      unreadMap[widget.peerId] = peerUnread + 1;

      await chatRef.set({
        'participants': ids,
        'lastMessage': text,
        'lastUpdated': now,
        'unreadCount': unreadMap,
      }, SetOptions(merge: true));

      await chatRef.collection('messages').add({
        'senderId': currentUser.uid,
        'receiverId': widget.peerId,
        'text': text,
        'timestamp': now,
        'seen': false,
        'type': 'text',
      });

      await AppNotificationService.createNotification(
        userId: widget.peerId,
        type: 'new_message',
        title: 'New message',
        message: 'You received a new message.',
        relatedChatId: chatId,
        relatedPeerId: currentUser.uid,
        relatedPeerName: senderName,
      );

      _controller.clear();
      _focusNode.requestFocus();
    } catch (e) {
      _showError('Send failed: $e');
    }
  }

  String _formatMessageTime(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final date = timestamp.toDate();
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  bool _shouldShowTimeHeader(List<QueryDocumentSnapshot> messages, int index) {
    final currentData = messages[index].data() as Map<String, dynamic>;
    final currentTimestamp = currentData['timestamp'] as Timestamp?;

    if (currentTimestamp == null) return false;
    if (index == messages.length - 1) return true;

    final nextData = messages[index + 1].data() as Map<String, dynamic>;
    final nextTimestamp = nextData['timestamp'] as Timestamp?;

    if (nextTimestamp == null) return true;

    final currentTime = currentTimestamp.toDate();
    final nextTime = nextTimestamp.toDate();

    return currentTime.hour != nextTime.hour ||
        currentTime.minute != nextTime.minute;
  }

  void _openPeerProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: widget.peerId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: GestureDetector(
          onTap: _openPeerProfile,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey.shade200,
                child: Icon(
                  Icons.person,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(widget.peerName, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('chats')
                        .doc(chatId)
                        .collection('messages')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Something went wrong.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final messages = snapshot.data!.docs;

                  if (messages.isEmpty) {
                    return const Center(
                      child: Text(
                        'Say hi',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    );
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _markMessagesAsSeen();
                  });

                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg =
                          messages[index].data() as Map<String, dynamic>;

                      final isSystem = msg['type'] == 'system';
                      final isMe = msg['senderId'] == currentUser.uid;
                      final timestamp = msg['timestamp'] as Timestamp?;
                      final seen = msg['seen'] == true;

                      final timeText = _formatMessageTime(timestamp);
                      final showTimeHeader = _shouldShowTimeHeader(
                        messages,
                        index,
                      );

                      return Column(
                        children: [
                          if (showTimeHeader)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Center(
                                child: Text(
                                  timeText,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          if (isSystem)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 24,
                              ),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF6E3DE),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    msg['text'] ?? '',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF8A5A50),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            Align(
                              alignment:
                                  isMe
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                              child: Column(
                                crossAxisAlignment:
                                    isMe
                                        ? CrossAxisAlignment.end
                                        : CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                          0.72,
                                    ),
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                      horizontal: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          isMe
                                              ? const Color(0xFFE78D83)
                                              : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      msg['text'] ?? '',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color:
                                            isMe ? Colors.white : Colors.black,
                                      ),
                                    ),
                                  ),
                                  if (isMe)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        right: 6,
                                        bottom: 4,
                                      ),
                                      child: Text(
                                        seen ? 'Seen' : 'Sent',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: const Color(0xFFE78D83),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            isCollapsed: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _sendMessage,
                      icon: const Icon(
                        Icons.send,
                        color: Color(0xFFE78D83),
                        size: 30,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
