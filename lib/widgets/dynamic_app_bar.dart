// lib/widgets/dynamic_app_bar.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:MUJEER/services/config_service.dart';
import 'package:MUJEER/services/webview_service.dart';
import 'package:MUJEER/widgets/header_icon_widget.dart';

class DynamicAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int selectedIndex;

  const DynamicAppBar({super.key, required this.selectedIndex});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final config = ConfigService().config;
    if (config == null || selectedIndex >= config.mainIcons.length) {
      return _buildDefaultAppBar(context);
    }

    final currentItem = config.mainIcons[selectedIndex];
    final titleColor = Colors.white;

    // Check if we have header icons and separate the first one
    final hasHeaderIcons =
        currentItem.headerIcons != null && currentItem.headerIcons!.isNotEmpty;
    final firstHeaderIcon =
        hasHeaderIcons ? currentItem.headerIcons!.first : null;
    final remainingHeaderIcons =
        hasHeaderIcons ? currentItem.headerIcons!.sublist(1) : <dynamic>[];

    return AppBar(
      centerTitle: true,
      // Put remaining icons (all except first) in leading as a list
      leading: remainingHeaderIcons.isNotEmpty
          ? _buildLeadingList(context, remainingHeaderIcons)
          : null,
      title: Padding(
        padding: const EdgeInsets.only(right: 10.0),
        child: _buildTitle(context, currentItem.title, titleColor),
      ),
      // Put first icon in actions
      actions: _buildActions(context, firstHeaderIcon),
      backgroundColor: const Color(0xFF1E1E1E),
      elevation: 0,
      iconTheme: IconThemeData(color: titleColor),
    );
  }

  Widget _buildTitle(BuildContext context, String title, Color titleColor) {
    return Text(
      title,
      style: GoogleFonts.rubik(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: titleColor,
      ),
    );
  }

  // Build leading widget as a list for remaining icons (all except first)
  Widget? _buildLeadingList(BuildContext context, List<dynamic> remainingIcons) {
    if (remainingIcons.isEmpty) return null;
    
    // If there's only one remaining icon, return it directly
    if (remainingIcons.length == 1) {
      final headerIcon = remainingIcons.first;
      return HeaderIconWidget(
        iconUrl: headerIcon.icon,
        title: headerIcon.title,
        size: 24,
        onTap: () => _handleHeaderIconTap(context, headerIcon),
      );
    }
    
    // If there are multiple remaining icons, show them in a Row
    return Container(
      padding: const EdgeInsets.only(left: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: remainingIcons.map<Widget>((headerIcon) {
          return Padding(
            padding: const EdgeInsets.only(right: 4.0),
            child: HeaderIconWidget(
              iconUrl: headerIcon.icon,
              title: headerIcon.title,
              size: 20, // Slightly smaller for multiple icons
              onTap: () => _handleHeaderIconTap(context, headerIcon),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Build actions for first icon only
  List<Widget> _buildActions(BuildContext context, dynamic firstHeaderIcon) {
    final List<Widget> actions = [];
    
    if (firstHeaderIcon != null) {
      actions.add(
        HeaderIconWidget(
          iconUrl: firstHeaderIcon.icon,
          title: firstHeaderIcon.title,
          size: 24,
          onTap: () => _handleHeaderIconTap(context, firstHeaderIcon),
        ),
      );
      actions.add(const SizedBox(width: 8));
    }
    
    return actions;
  }

  void _handleHeaderIconTap(BuildContext context, headerIcon) {
    WebViewService().navigate(
      context,
      url: headerIcon.link,
      linkType: headerIcon.linkType,
      title: headerIcon.title,
    );
  }

  AppBar _buildDefaultAppBar(BuildContext context) {
    return AppBar(
      title: Text(
        'ERPForever',
        style: GoogleFonts.rubik(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      backgroundColor: const Color(0xFF1E1E1E),
      elevation: 0,
    );
  }
}