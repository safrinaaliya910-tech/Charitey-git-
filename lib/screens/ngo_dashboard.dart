//ngo_dashboard.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../providers/auth_provider.dart';
import '../models/post_model.dart';
import 'create_post_screen.dart';
import 'profile_screen.dart';

class NgoDashboard extends StatefulWidget {
  final String? targetPostId;
  const NgoDashboard({super.key, this.targetPostId});

  @override
  State<NgoDashboard> createState() => NgoDashboardState();
}

class NgoDashboardState extends State<NgoDashboard>
    with TickerProviderStateMixin {
  final Color themeColor = const Color(0xFFB56F76);
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolled = false;
  bool _showTaggedOnly = false;
  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTarget(List<QueryDocumentSnapshot> posts) {
    if (widget.targetPostId != null && !_hasScrolled) {
      int index = posts.indexWhere((doc) => doc.id == widget.targetPostId);
      if (index != -1) {
        _hasScrolled = true;
        double offset = index * 550.0;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              offset,
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUserModel;
    if (user == null) {
      return Center(child: CircularProgressIndicator(color: themeColor));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Animated background ────────────────────────────
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(
                      math.cos(_bgController.value * math.pi * 2),
                      math.sin(_bgController.value * math.pi * 2),
                    ),
                    end: Alignment(
                      math.cos(_bgController.value * math.pi * 2 + math.pi),
                      math.sin(_bgController.value * math.pi * 2 + math.pi),
                    ),
                    colors: const [
                      Color(0xFFF2D9DB),
                      Color(0xFFE5B8BD),
                      Color(0xFFDCA3A9),
                      Color(0xFFF5E1E4),
                    ],
                    stops: const [0.0, 0.35, 0.7, 1.0],
                  ),
                ),
              );
            },
          ),

          // ── Activity feed ──────────────────────────────────
          Column(
            children: [
              // Show filter bar only for donors/volunteers
              if (user.role != 'ngo') _buildFilterBar(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(color: themeColor),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _buildEmptyState(user.role, taggedOnly: false);
                    }

                    var posts = snapshot.data!.docs;
                    final visiblePosts = posts.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final donorUid = data['donorUid'] ?? '';
                      final volunteerUid = data['volunteerUid'] ?? '';
                      final isTaggedForUser =
                          donorUid == user.uid || volunteerUid == user.uid;

                      // NGO: show all posts (no tagged)
                      if (user.role == 'ngo') {
                        return true;
                      }

                      // Donor/Volunteer: apply filter
                      return !_showTaggedOnly || isTaggedForUser;
                    }).toList();

                    if (visiblePosts.isEmpty) {
                      final noPostsMessage = user.role == 'ngo'
                          ? _buildEmptyState(user.role, taggedOnly: false)
                          : _buildEmptyState(
                              user.role,
                              taggedOnly: _showTaggedOnly,
                            );
                      return noPostsMessage;
                    }

                    _scrollToTarget(posts);

                    return ListView.builder(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 100, top: 10),
                      itemCount: visiblePosts.length,
                      itemBuilder: (context, index) {
                        var post = PostModel.fromMap(
                          visiblePosts[index].data() as Map<String, dynamic>,
                          visiblePosts[index].id,
                        );

                        if (post.image.isEmpty ||
                            !post.image.startsWith('http')) {
                          return const SizedBox.shrink();
                        }

                        bool isTarget = post.postId == widget.targetPostId;

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(post.ngoId)
                              .get(),
                          builder: (context, userSnapshot) {
                            String ngoName = "NGO";
                            if (userSnapshot.hasData &&
                                userSnapshot.data!.exists) {
                              ngoName =
                                  (userSnapshot.data!.data()
                                      as Map<String, dynamic>)['name'] ??
                                  "NGO";
                            }

                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 800),
                              decoration: isTarget
                                  ? BoxDecoration(
                                      boxShadow: [
                                        BoxShadow(
                                          color: themeColor.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 30,
                                          spreadRadius: 8,
                                        ),
                                      ],
                                    )
                                  : const BoxDecoration(),
                              child: PostCardWidget(
                                key: ValueKey(post.postId),   // ADD THIS
                                post: post,
                                ngoName: ngoName,
                                currentUserId: user.uid,
                                themeColor: themeColor,
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),

      // ── FAB (NGO only) ─────────────────────────────────────
      floatingActionButton: user.role == 'ngo'
          ? Padding(
              padding: const EdgeInsets.only(bottom: 90),
              child: FloatingActionButton(
                backgroundColor: themeColor,
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreatePostScreen(),
                    ),
                  );
                },
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildFilterBar() {
    // Only show for donors/volunteers
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterChip(
              'All Posts',
              !_showTaggedOnly,
              () => setState(() => _showTaggedOnly = false),
            ),
          ),
          Expanded(
            child: _buildFilterChip(
              'Tagged Posts',
              _showTaggedOnly,
              () => setState(() => _showTaggedOnly = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? themeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String? role, {bool taggedOnly = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(
              Icons.photo_library_outlined,
              size: 60,
              color: Colors.grey.shade300,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Impact Gallery",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            taggedOnly
                ? "No tagged posts yet.\nPosts you are tagged in will appear here."
                : role == 'ngo'
                ? "No posts yet.\nCheck back later for updates!"
                : "No posts yet.\nCheck back later for updates!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// POST CARD WIDGET
// ================================================================
class PostCardWidget extends StatefulWidget {
  final PostModel post;
  final String ngoName;
  final String currentUserId;
  final Color themeColor;
  final bool showMentions;

  const PostCardWidget({
    Key? key,
    required this.post,
    required this.ngoName,
    required this.currentUserId,
    required this.themeColor,
    this.showMentions = true,
  }) : super(key: key);

  @override
  State<PostCardWidget> createState() => _PostCardWidgetState();
}

class _PostCardWidgetState extends State<PostCardWidget> {
  bool _isLiked = false;
  bool _isSharing = false;


  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.likedBy.contains(widget.currentUserId);   // ADD THIS
  }

@override
  void didUpdateWidget(covariant PostCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _isLiked = widget.post.likedBy.contains(widget.currentUserId);   // ADD THIS
  }

  void _toggleLike() {
    final bool wasLiked = _isLiked;
    setState(() => _isLiked = !wasLiked);

    final postRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.post.postId);

    if (wasLiked) {
      // Unliking
      postRef.update({
        'likes': FieldValue.increment(-1),
        'likedBy': FieldValue.arrayRemove([widget.currentUserId]),
      });
    } else {
      // Liking
      postRef.update({
        'likes': FieldValue.increment(1),
        'likedBy': FieldValue.arrayUnion([widget.currentUserId]),
      });
    }
  }

  Future<void> _sharePost() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Sharing is only supported on mobile devices (Android/iOS).",
          ),
        ),
      );
      return;
    }

    setState(() => _isSharing = true);
    try {
      final url = Uri.parse(widget.post.image);
      final response = await http.get(url);
      final bytes = response.bodyBytes;
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/shared_post_${widget.post.postId}.jpg';
      File(path).writeAsBytesSync(bytes);

      String textToShare = "${widget.post.description}\n\n";
      if (widget.post.donorId.isNotEmpty) {
        textToShare += "✨ ${widget.post.donorId}\n\n";
      }
      textToShare += "Shared via Charitey App❤️";

      await Share.shareXFiles([XFile(path)], text: textToShare);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error sharing post: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  void _deletePost() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Post"),
        content: const Text(
          "Are you sure you want to delete this post? This cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.post.postId)
                  .delete();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Post deleted"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _editPost() {
    TextEditingController descController = TextEditingController(
      text: widget.post.description,
    );
    TextEditingController tagController = TextEditingController(
      text: widget.post.donorId,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Edit Post",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tagController,
              decoration: InputDecoration(
                labelText: "Tag Donor (Optional)",
                prefixIcon: const Icon(Icons.person_add),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: "Description",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.themeColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.post.postId)
                  .update({
                    'description': descController.text.trim(),
                    'donorId': tagController.text.trim(),
                  });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Post updated!"),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat(
      'MMM d, yyyy',
    ).format(widget.post.createdAt);
    bool isMyPost = widget.post.ngoId == widget.currentUserId;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.white, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: avatar + name + menu ──────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Tapping the avatar/name navigates to
                // the NGO's profile page
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ProfileScreen(visitedUserId: widget.post.ngoId),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        // Show ngoProfileImage when available,
                        // fallback to initial letter
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: widget.themeColor.withValues(
                            alpha: 0.15,
                          ),
                          backgroundImage:
                              (widget.post.ngoProfileImage != null &&
                                  widget.post.ngoProfileImage!.isNotEmpty)
                              ? NetworkImage(widget.post.ngoProfileImage!)
                              : null,
                          child:
                              (widget.post.ngoProfileImage == null ||
                                  widget.post.ngoProfileImage!.isEmpty)
                              ? Text(
                                  widget.ngoName.isNotEmpty
                                      ? widget.ngoName[0].toUpperCase()
                                      : 'N',
                                  style: TextStyle(
                                    color: widget.themeColor,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.ngoName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15.5,
                                  letterSpacing: 0.2,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                formattedDate,
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (isMyPost)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_horiz, color: Colors.grey.shade600),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onSelected: (value) {
                      if (value == 'edit') _editPost();
                      if (value == 'delete') _deletePost();
                    },
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_rounded,
                              size: 20,
                              color: Colors.black87,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Edit',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_rounded,
                              size: 20,
                              color: Colors.redAccent,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Delete',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // ── Post image ────────────────────────────────
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 380),
            color: Colors.grey.shade50,
            child: Image.network(
              widget.post.image,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Padding(
                padding: EdgeInsets.all(40.0),
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 50,
                  color: Colors.grey,
                ),
              ),
            ),
          ),

          // ── Like + Share row ──────────────────────────
          Padding(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 14,
              bottom: 8,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _toggleLike,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          return ScaleTransition(
                            scale: animation,
                            child: child,
                          );
                        },
                    child: Icon(
                      _isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      key: ValueKey<bool>(_isLiked),
                      size: 30,
                      color: _isLiked
                          ? const Color(0xFFE63946)
                          : Colors.grey.shade800,
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                GestureDetector(
                  onTap: _isSharing ? null : _sharePost,
                  child: _isSharing
                      ? SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: widget.themeColor,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          Icons.send_rounded,
                          size: 28,
                          color: Colors.grey.shade800,
                        ),
                ),
              ],
            ),
          ),

          // ── Likes count + caption ─────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${widget.post.likes} likes",
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14.5,
                      height: 1.4,
                    ),
                    children: [
                      TextSpan(
                        text: "${widget.ngoName} ",
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      if (widget.showMentions && widget.post.donorId.isNotEmpty)
                        TextSpan(
                          text: "${widget.post.donorId} ",
                          style: TextStyle(
                            color: widget.themeColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      if (widget.showMentions &&
                          widget.post.volunteerName.isNotEmpty)
                        TextSpan(
                          text: "${widget.post.volunteerName} ",
                          style: TextStyle(
                            color: widget.themeColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      TextSpan(
                        text: widget.post.description,
                        style: const TextStyle(fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}