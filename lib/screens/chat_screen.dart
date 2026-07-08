//chat_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../models/message_model.dart';
import '../services/chat_service.dart';
import '../providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data'; // NEW
import 'camera_capture_screen.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart'; // for Clipboard
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:async'; // NEW - for StreamSubscription
import 'dart:io'; // NEW - for File (used in download/save)
import 'package:path_provider/path_provider.dart'; // NEW
import 'package:gal/gal.dart'; // NEW - save to gallery
import 'package:mime/mime.dart'; // NEW - correct MIME detection
import 'video_viewer_screen.dart'; // NEW
import 'media_preview_screen.dart'; // NEW
import 'package:flutter/foundation.dart' show kIsWeb;

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String? otherUserProfileImage;

  const ChatScreen({
    Key? key,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserProfileImage,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final Color themeColor = const Color(0xFF7D444C);
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  bool _hasScrolledToBottomOnce = false; // NEW: only auto-jump on initial chat open
  MessageModel? _replyingTo;          // NEW
  bool _isBlockedByMe = false;        // NEW
  bool _amIBlockedByThem = false;     // NEW
  StreamSubscription<bool>? _blockedByMeSub;   // NEW
  StreamSubscription<bool>? _blockedThemSub;   // NEW

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markAsRead());
    _listenToBlockStatus(); // NEW
  }

  void _listenToBlockStatus() {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUserModel;
    if (user == null) return;
    _blockedByMeSub = _chatService.isBlockedByMe(user.uid, widget.otherUserId).listen((blocked) {
      if (mounted) setState(() => _isBlockedByMe = blocked);
    });
    _blockedThemSub = _chatService.amIBlockedByThem(user.uid, widget.otherUserId).listen((blocked) {
      if (mounted) setState(() => _amIBlockedByThem = blocked);
    });
  }

  void _markAsRead() {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUserModel;
    if (user == null) return;
    _chatService.markMessagesAsRead(user.uid, widget.otherUserId);
  }

  // NEW: jumps the list to the latest message (bottom), since messages are
  // ordered oldest → newest and ListView.builder defaults to showing the top.
  void _scrollToBottom({bool animate = false}) {
    if (!_scrollController.hasClients) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (animate) {
      _scrollController.animateTo(
        maxExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(maxExtent);
    }
  }

  void sendMessage() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUserModel;
    if (user == null || _messageController.text.trim().isEmpty) return;
    if (_isBlockedByMe || _amIBlockedByThem) {  // NEW guard
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot send messages in this chat.')),
      );
      return;
    }

    String message = _messageController.text.trim();
    _messageController.clear();
    final replyMsg = _replyingTo; // NEW capture before clearing
    setState(() => _replyingTo = null); // NEW clear reply bar

    try {
      await _chatService.sendMessage(
        user.uid,
        user.name,
        widget.otherUserId,
        widget.otherUserName,
        message,
        senderPhone: user.phone,
        senderLocation: user.location,
        senderRole: user.role,
        replyToId: replyMsg?.messageId,                         // NEW
        replyToMessage: replyMsg == null
            ? null
            : (replyMsg.type == 'text'
                ? replyMsg.message
                : replyMsg.type == 'image'
                    ? '📷 Photo'
                    : replyMsg.type == 'video'
                        ? '🎥 Video'
                        : '📄 ${replyMsg.fileName}'), // NEW
        replyToSenderName: replyMsg?.senderId == user.uid ? 'You' : widget.otherUserName, // NEW
        replyToType: replyMsg?.type, // NEW
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  //
  void _showAttachmentOptions() {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
  leading: Icon(Icons.photo_camera, color: themeColor),
  title: const Text('Camera'),
  onTap: () async {
    // FIX: `sheetContext` belongs to the bottom sheet itself and is torn
    // down the instant we pop it below. Using it for navigation afterwards
    // (once the camera screen returns, seconds later) threw a null-check
    // crash inside Navigator.of — which silently killed the flow right
    // before the caption/preview screen could open. We now close the sheet
    // with `sheetContext`, but do every subsequent push with this State's
    // own long-lived `context`.
    Navigator.pop(sheetContext);
    final CaptureResult? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
    );
    if (result == null) return;

    // NEW: WhatsApp-style preview with caption before actually sending
    final caption = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (_) => MediaPreviewScreen(bytes: result.bytes, type: result.type, fileName: result.fileName),
      ),
    );
    if (caption == null) return; // user hit cancel (X)

    if (result.type == 'image') {
      await _sendImageBytes(result.bytes, result.fileName, caption: caption);
    } else {
      await _sendVideoBytes(result.bytes, result.fileName, caption: caption);
    }
  },
),
          ListTile(
            leading: Icon(Icons.photo_library, color: themeColor),
            title: const Text('Gallery'),
            onTap: () {
              Navigator.pop(sheetContext);
              _pickAndSendImage(ImageSource.gallery);
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> _pickAndSendImage(ImageSource source) async {
  final XFile? picked = await _picker.pickImage(source: source, imageQuality: 70);
  if (picked == null) return;
  final bytes = await picked.readAsBytes();
  final fileName = picked.name.isNotEmpty ? picked.name : 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';

  final caption = await Navigator.push<String?>( // NEW
    context,
    MaterialPageRoute(builder: (_) => MediaPreviewScreen(bytes: bytes, type: 'image', fileName: fileName)),
  );
  if (caption == null) return; // cancelled

  await _sendImageBytes(bytes, fileName, caption: caption);
}

Future<void> _sendImageBytes(Uint8List bytes, String fileName, {String? caption}) async { // NEW: caption param
  final user = Provider.of<AuthProvider>(context, listen: false).currentUserModel;
  if (user == null) return;

  final replyMsg = _replyingTo;
  setState(() {
    _isUploading = true;
    _replyingTo = null;
  });
  try {
    await _chatService.sendMediaMessage(
      bytes: bytes,
      fileName: fileName,
      senderId: user.uid,
      senderName: user.name,
      receiverId: widget.otherUserId,
      receiverName: widget.otherUserName,
      type: 'image',
      caption: caption, // NEW
      senderPhone: user.phone,
      senderLocation: user.location,
      senderRole: user.role,
      replyToId: replyMsg?.messageId,
      replyToMessage: replyMsg == null
          ? null
          : (replyMsg.type == 'text'
              ? replyMsg.message
              : replyMsg.type == 'image'
                  ? '📷 Photo'
                  : replyMsg.type == 'video'
                      ? '🎥 Video'
                      : '📄 ${replyMsg.fileName}'),
      replyToSenderName: replyMsg?.senderId == user.uid ? 'You' : widget.otherUserName,
      replyToType: replyMsg?.type,
    );
  } catch (e) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send image: $e')));
  } finally {
    if (mounted) setState(() => _isUploading = false);
  }
}

Future<void> _sendVideoBytes(Uint8List bytes, String fileName, {String? caption}) async { // NEW: caption param
  final user = Provider.of<AuthProvider>(context, listen: false).currentUserModel;
  if (user == null) return;

  final replyMsg = _replyingTo;
  setState(() {
    _isUploading = true;
    _replyingTo = null;
  });
  try {
    await _chatService.sendMediaMessage(
      bytes: bytes,
      fileName: fileName,
      senderId: user.uid,
      senderName: user.name,
      receiverId: widget.otherUserId,
      receiverName: widget.otherUserName,
      type: 'video',
      caption: caption, // NEW
      senderPhone: user.phone,
      senderLocation: user.location,
      senderRole: user.role,
      replyToId: replyMsg?.messageId,
      replyToMessage: replyMsg == null
          ? null
          : (replyMsg.type == 'text'
              ? replyMsg.message
              : replyMsg.type == 'image'
                  ? '📷 Photo'
                  : replyMsg.type == 'video'
                      ? '🎥 Video'
                      : '📄 ${replyMsg.fileName}'),
      replyToSenderName: replyMsg?.senderId == user.uid ? 'You' : widget.otherUserName,
      replyToType: replyMsg?.type,
    );
  } catch (e) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send video: $e')));
  } finally {
    if (mounted) setState(() => _isUploading = false);
  }
}

void _openFullImage(String url) {
  showDialog(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: InteractiveViewer(
        child: Image.network(url, fit: BoxFit.contain),
      ),
    ),
  );
}
//

  Future<void> _makePhoneCall() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUserId)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        var data = userDoc.data() as Map<String, dynamic>;
        
        String? phoneNumber = data['phone'] ?? data['ngoPhone'];

        if (phoneNumber != null && phoneNumber.trim().isNotEmpty) {
          final Uri launchUri = Uri(
            scheme: 'tel',
            path: phoneNumber.trim(),
          );
          
          if (await canLaunchUrl(launchUri)) {
            await launchUrl(launchUri);
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not open the phone dialer.')),
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Phone number not available for this user.')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching phone number: $e')),
        );
      }
    }
  }

  // ============ BLOCK / UNBLOCK ============
  Future<void> _toggleBlock() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUserModel;
    if (user == null) return;

    final bool isCurrentlyBlocked = _isBlockedByMe;
    final action = isCurrentlyBlocked ? 'Unblock' : 'Block';

    bool confirmChecked = false; // NEW: checkbox state, only relevant for Block flow

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder( // NEW: lets checkbox rebuild the dialog
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('$action ${widget.otherUserName}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isCurrentlyBlocked
                  ? 'They will be able to message you again.'
                  : 'They will no longer be able to send you messages, and you won\'t receive messages from them.'),
              if (!isCurrentlyBlocked) ...[ // NEW: checkbox only shown when blocking, not unblocking
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => setDialogState(() => confirmChecked = !confirmChecked),
                  child: Row(
                    children: [
                      Checkbox(
                        value: confirmChecked,
                        onChanged: (val) => setDialogState(() => confirmChecked = val ?? false),
                        activeColor: themeColor,
                      ),
                      Expanded(
                        child: Text(
                          'I confirm I want to block ${widget.otherUserName}.',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              // NEW: disabled until checkbox is ticked, but only for the Block flow
              onPressed: (!isCurrentlyBlocked && !confirmChecked)
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: Text(action),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    if (isCurrentlyBlocked) {
      await _chatService.unblockUser(user.uid, widget.otherUserId);
    } else {
      await _chatService.blockUser(user.uid, widget.otherUserId);
    }
  }

  // ============ CLEAR CHAT ============
  Future<void> _confirmClearChat() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUserModel;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Chat?'),
        content: const Text('This will remove all messages from your view. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm Clear Chat')),
        ],
      ),
    );
    if (confirmed == true) {
      await _chatService.clearChatForMe(user.uid, widget.otherUserId);
    }
  }

  // ============ COPY / DOWNLOAD / SHARE ============
  void _copyText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }

  // NEW: actually downloads bytes and saves them to the device correctly,
  // instead of just opening the URL in a browser tab.
  Future<void> _downloadFile(String url, String? fileName, String type) async {
  try {
    if (kIsWeb) {
      // NEW: on web, just open the URL directly — browser handles download/view natively
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) throw Exception('Server returned ${response.statusCode}');
    final bytes = response.bodyBytes;
    final safeName = fileName ?? 'file_${DateTime.now().millisecondsSinceEpoch}';

    if (type == 'image') {
      await Gal.putImageBytes(bytes, name: safeName);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image saved to gallery')));
    } else if (type == 'video') {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$safeName');
      await tempFile.writeAsBytes(bytes);
      await Gal.putVideo(tempFile.path);
      await tempFile.delete();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video saved to gallery')));
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$safeName');
      await file.writeAsBytes(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved: ${file.path}')));
      }
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
  }
}

  Future<void> _shareMedia(String url, String? fileName) async {
    try {
      final response = await http.get(Uri.parse(url));
      final bytes = response.bodyBytes;
      final name = fileName ?? 'shared_file';
      final mimeType = lookupMimeType(name) ?? 'application/octet-stream'; // NEW: explicit MIME
      final xFile = XFile.fromData(bytes, name: name, mimeType: mimeType); // NEW: mimeType added
      await Share.shareXFiles([xFile]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to share: $e')));
      }
    }
  }

  // ============ REPLY ============
  void _startReply(MessageModel message) {
    setState(() => _replyingTo = message);
  }

  // ============ DELETE ============
  Future<void> _deleteForMe(MessageModel message) async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUserModel;
    if (user == null) return;
    final chatRoomId = _chatService.getChatRoomId(user.uid, widget.otherUserId);
    await _chatService.deleteMessageForMe(chatRoomId, message.messageId, user.uid);
  }

  Future<void> _deleteForEveryone(MessageModel message) async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUserModel;
    if (user == null) return;
    final chatRoomId = _chatService.getChatRoomId(user.uid, widget.otherUserId);
    await _chatService.deleteMessageForEveryone(chatRoomId, message.messageId);
  }

  // ============ LONG-PRESS ACTION SHEET ============
  void _showMessageActions(MessageModel message, bool isMe) {
    if (message.isDeletedForEveryone) return; // nothing to do on a deleted message

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                _startReply(message);
              },
            ),
            if (message.type == 'text')
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy'),
                onTap: () {
                  Navigator.pop(context);
                  _copyText(message.message);
                },
              ),
            if (message.type == 'image' || message.type == 'document' || message.type == 'video') ...[ // NEW: added video
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Download'),
                onTap: () {
                  Navigator.pop(context);
                  if (message.mediaUrl != null) _downloadFile(message.mediaUrl!, message.fileName, message.type); // NEW: pass type
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share / Forward'),
                onTap: () {
                  Navigator.pop(context);
                  if (message.mediaUrl != null) _shareMedia(message.mediaUrl!, message.fileName);
                },
              ),
              // REMOVED: "Copy Image Link" option, per request
            ],
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete for me'),
              onTap: () {
                Navigator.pop(context);
                _deleteForMe(message);
              },
            ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Delete for everyone', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteForEveryone(message);
                },
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _blockedByMeSub?.cancel(); // NEW
    _blockedThemSub?.cancel(); // NEW
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUserModel;
    if (user == null) return const Scaffold(body: Center(child: Text('User not logged in')));
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                // 👇 FIXED: Changed 'O' to the number '0' in the hex code
                colors: [Color(0xFFFDF7F8), Color(0xFFEEDAE0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.1, 1.0],
              ),
            ),
          ),
          Column(
            children: [
              _buildGlassAppBar(),
              Expanded(
                child: StreamBuilder<List<MessageModel>>(
                  stream: _chatService.getMessages(user.uid, widget.otherUserId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator(color: themeColor));
                    }
                    
                    List<MessageModel> messages = snapshot.data ?? [];

                    // --- NEW: Read receipts ---
                    // If a new incoming message arrives while this screen is
                    // already open, mark it read too. Cheap no-op once caught up,
                    // since markMessagesAsRead only touches unread docs.
                    if (messages.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) => _markAsRead());

                      // NEW: jump straight to the newest message the very first
                      // time this snapshot has content — i.e. right when the
                      // chat screen opens — so the user lands at the latest
                      // message instead of the very first one in the thread.
                      if (!_hasScrolledToBottomOnce) {
                        _hasScrolledToBottomOnce = true;
                        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                      }
                    }
                    
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        bool isMe = message.senderId == user.uid;
                        return _SwipeToReplyWrapper( // NEW: wraps each bubble for swipe-to-reply
                          onReply: () => _startReply(message),
                          child: _buildMessageBubble(message, isMe),
                        );
                      },
                    );
                  },
                ),
              ),
              if (_replyingTo != null) _buildReplyPreview(), // FIX: re-added, was dropped
              _buildInputArea(),
            ],
          ),
        ],
      ),
    );
  }

  // NEW
  Widget _buildReplyPreview() {
    final r = _replyingTo!;
    final previewText = r.type == 'text'
            ? r.message
            : r.type == 'image'
                ? '📷 Photo'
                : r.type == 'video'
                    ? '🎥 Video'
                    : '📄 ${r.fileName}';    
      return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          Container(width: 4, height: 36, color: themeColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(previewText, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13)),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _replyingTo = null),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassAppBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AppBar(
          backgroundColor: Colors.white.withOpacity(0.7),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: themeColor.withOpacity(0.1),
                radius: 18,
                backgroundImage: (widget.otherUserProfileImage != null && widget.otherUserProfileImage!.isNotEmpty)
                    ? NetworkImage(widget.otherUserProfileImage!)
                    : null,
                child: (widget.otherUserProfileImage == null || widget.otherUserProfileImage!.isEmpty)
                    ? Text(
                        widget.otherUserName[0].toUpperCase(),
                        style: TextStyle(color: themeColor, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.otherUserName,
                  style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.call_rounded, color: themeColor, size: 24),
              onPressed: _makePhoneCall,
              tooltip: 'Call User',
            ),
            PopupMenuButton<String>(   // NEW
              icon: Icon(Icons.more_vert, color: themeColor),
              onSelected: (value) {
                if (value == 'block') _toggleBlock();
                if (value == 'clear') _confirmClearChat();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'block',
                  child: Text(_isBlockedByMe ? 'Unblock User' : 'Block User'),
                ),
                const PopupMenuItem(value: 'clear', child: Text('Clear Chat')),
              ],
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
  return DateFormat('hh:mm a').format(dt); // e.g. "09:41 AM"
}

  Widget _buildMessageBubble(MessageModel message, bool isMe) {
    
    final bool isImage = message.type == 'image';
    final bool isDocument = message.type == 'document';
    final bool isVideo = message.type == 'video'; // NEW


  return Align(
    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
    child: GestureDetector(
      onLongPress: () => _showMessageActions(message, isMe),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: isImage
          ? const EdgeInsets.all(6)
          : const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      constraints: const BoxConstraints(maxWidth: 260),
      decoration: BoxDecoration(
        color: isMe ? themeColor : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: isMe ? const Radius.circular(20) : Radius.zero,
          bottomRight: isMe ? Radius.zero : const Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           // --- NEW: quoted reply preview ---
          if (message.replyToId != null)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isMe ? Colors.white : themeColor).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border(left: BorderSide(color: isMe ? Colors.white : themeColor, width: 3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.replyToSenderName ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isMe ? Colors.white : themeColor,
                    ),
                  ),
                  Text(
                    message.replyToMessage ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: isMe ? Colors.white70 : Colors.black54),
                  ),
                ],
              ),
            ),

          // --- NEW: "deleted for everyone" placeholder ---
          if (message.isDeletedForEveryone)
            Text(
              'This message was deleted',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 14,
                color: isMe ? Colors.white70 : Colors.black45,
              ),
            )
          else if (isImage && message.mediaUrl != null)
            GestureDetector(
              onTap: () => _openFullImage(message.mediaUrl!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  message.mediaUrl!,
                  width: 200,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                      width: 200,
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stack) => const SizedBox(
                    width: 200,
                    height: 120,
                    child: Center(child: Icon(Icons.broken_image)),
                  ),
                ),
              ),
            )

          


          else if (isVideo && message.mediaUrl != null) // NEW: video bubble
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => VideoViewerScreen(url: message.mediaUrl!)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 200,
                  height: 160,
                  color: Colors.black87,
                  child: const Center(
                    child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 48),
                  ),
                ),
              ),
            )
          else if (isDocument && message.mediaUrl != null)
            InkWell(
              onTap: () async {
                final uri = Uri.parse(message.mediaUrl!);
                if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              child: Row(
                children: [
                  Icon(Icons.insert_drive_file, color: isMe ? Colors.white : themeColor),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      message.fileName ?? 'Document',
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              message.message,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),

          // NEW: shows caption text under media (image/video/document), only when a real caption was typed
          if (message.type != 'text' &&
              message.message.isNotEmpty &&
              message.message != '[Image]' &&
              message.message != '[Video]' &&
              !message.message.startsWith('[Document]'))
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
              child: Text(
                message.message,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
              ),
            ),

            // --- NEW: timestamp + read receipt row (time shows for all messages, tick only for mine) ---
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: isMe
                          ? Colors.white70
                          : (isImage ? Colors.black54 : Colors.black45),
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.delivered ? Icons.done_all_rounded : Icons.done_rounded,
                      size: 15,
                      color: message.read ? Colors.lightBlueAccent : Colors.white70,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildInputArea() {
    if (_isBlockedByMe || _amIBlockedByThem) {  // NEW
      return Container(
        padding: const EdgeInsets.all(16),
        color: Colors.grey.shade200,
        child: Text(
          _isBlockedByMe
              ? 'You have blocked this user. Unblock to send messages.'
              : 'You cannot reply to this conversation.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54),
        ),
      );
    }
          return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, -5))],
    ),
    child: Row(
      children: [
        IconButton(
          icon: Icon(Icons.attach_file_rounded, color: themeColor),
          onPressed: _isUploading ? null : _showAttachmentOptions,
        ),
        Expanded(
          child: TextField(
            controller: _messageController,
            decoration: InputDecoration(
              hintText: 'Type your message...',
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _isUploading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : FloatingActionButton(
                backgroundColor: themeColor,
                elevation: 0,
                onPressed: sendMessage,
                child: const Icon(Icons.send_rounded, color: Colors.white),
              ),
        ],
      ),
    );
  }
}

// NEW: Swipe-right-to-reply wrapper, WhatsApp-style
class _SwipeToReplyWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;

  const _SwipeToReplyWrapper({
    required this.child,
    required this.onReply,
  });

  @override
  State<_SwipeToReplyWrapper> createState() => _SwipeToReplyWrapperState();
}

class _SwipeToReplyWrapperState extends State<_SwipeToReplyWrapper> {
  double _dragExtent = 0;
  static const double _triggerDrag = 55;
  static const double _maxDrag = 70;
  bool _triggered = false;

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragExtent += details.delta.dx;
      if (_dragExtent < 0) _dragExtent = 0; // only allow right swipe
      if (_dragExtent > _maxDrag) _dragExtent = _maxDrag;
    });

    if (_dragExtent >= _triggerDrag && !_triggered) {
      _triggered = true;
      HapticFeedback.lightImpact(); // subtle buzz when crossing the trigger point
    } else if (_dragExtent < _triggerDrag) {
      _triggered = false;
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_dragExtent >= _triggerDrag) {
      widget.onReply();
    }
    setState(() {
      _dragExtent = 0;
      _triggered = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dragExtent / _triggerDrag).clamp(0.0, 1.0);
    return GestureDetector(
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Positioned(
            left: 8,
            child: Opacity(
              opacity: progress,
              child: Icon(Icons.reply, color: Colors.grey.shade600, size: 22),
            ),
          ),
          AnimatedContainer(
            duration: _dragExtent == 0 ? const Duration(milliseconds: 200) : Duration.zero,
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_dragExtent, 0, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}