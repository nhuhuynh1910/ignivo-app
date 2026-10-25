import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/theme/brand_tokens.dart';

class IgnivoUserAvatar extends StatelessWidget {
  const IgnivoUserAvatar({
    super.key,
    this.name,
    this.photoUrl,
    this.data,
    this.radius = 24,
    this.showBorder = false,
    this.showEditIcon = false,
    this.onTap,
  });

  final String? name;
  final String? photoUrl;
  final Map<String, dynamic>? data;
  final double radius;
  final bool showBorder;
  final bool showEditIcon;
  final VoidCallback? onTap;

  String _resolvePhotoUrl() {
    if (photoUrl != null && photoUrl!.trim().isNotEmpty) {
      return photoUrl!.trim();
    }
    if (data != null) {
      final keys = ['photoUrl', 'photoURL', 'avatar_url', 'avatar', 'photo'];
      for (final k in keys) {
        final val = data![k]?.toString().trim();
        if (val != null && val.isNotEmpty) {
          return val;
        }
      }
    }
    try {
      final authPhoto = FirebaseAuth.instance.currentUser?.photoURL?.trim();
      if (authPhoto != null && authPhoto.isNotEmpty) {
        return authPhoto;
      }
    } catch (_) {}
    return '';
  }

  String _resolveInitials() {
    String resolvedName = name?.trim() ?? '';
    if (resolvedName.isEmpty && data != null) {
      resolvedName = (data!['name'] ?? data!['displayName'] ?? '').toString().trim();
    }
    if (resolvedName.isEmpty) {
      try {
        resolvedName = FirebaseAuth.instance.currentUser?.displayName?.trim() ?? '';
      } catch (_) {}
    }
    if (resolvedName.isEmpty) {
      return 'I';
    }

    final parts = resolvedName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'I';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = _resolvePhotoUrl();
    final initials = _resolveInitials();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final avatarContent = CircleAvatar(
      radius: radius,
      backgroundColor: isDark ? BrandTokens.darkSurfaceVariant : BrandTokens.brandTint,
      child: resolvedUrl.isNotEmpty
          ? ClipOval(
              child: Image.network(
                resolvedUrl,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _FallbackText(
                  initials: initials,
                  radius: radius,
                  isDark: isDark,
                ),
              ),
            )
          : _FallbackText(
              initials: initials,
              radius: radius,
              isDark: isDark,
            ),
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius * 2),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(showBorder ? 3.0 : 0.0),
            decoration: showBorder
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9),
                      width: 2.0,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                      ),
                    ],
                  )
                : null,
            child: avatarContent,
          ),
          if (showEditIcon)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: BrandTokens.brandPrimary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FallbackText extends StatelessWidget {
  const _FallbackText({
    required this.initials,
    required this.radius,
    required this.isDark,
  });

  final String initials;
  final double radius;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      initials,
      style: TextStyle(
        fontSize: radius * 0.7,
        fontWeight: FontWeight.w800,
        color: isDark ? BrandTokens.darkPrimary : BrandTokens.brandPrimary,
      ),
    );
  }
}
