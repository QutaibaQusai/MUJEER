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
    
    // Get text direction from config (default to LTR if not specified)
    final isRTL = config.theme?.direction?.toUpperCase() == 'RTL';

    // Check if we have header icons and separate the first one
    final hasHeaderIcons =
        currentItem.headerIcons != null && currentItem.headerIcons!.isNotEmpty;
    final firstHeaderIcon =
        hasHeaderIcons ? currentItem.headerIcons!.first : null;
    final remainingHeaderIcons =
        hasHeaderIcons ? currentItem.headerIcons!.sublist(1) : <dynamic>[];

    return AppBar(
      centerTitle: true,
      // Leading positioning based on direction
      leading: _getLeadingWidget(context, firstHeaderIcon, remainingHeaderIcons, isRTL),
      title: Padding(
        padding: const EdgeInsets.only(right: 10.0),
        child: _buildTitle(context, currentItem.title, titleColor),
      ),
      // Actions positioning based on direction
      actions: _getActionsWidget(context, firstHeaderIcon, remainingHeaderIcons, isRTL),
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

  // Get leading widget based on direction
  Widget? _getLeadingWidget(BuildContext context, dynamic firstHeaderIcon, 
      List<dynamic> remainingHeaderIcons, bool isRTL) {
    if (isRTL) {
      // RTL: First element goes to leading
      return firstHeaderIcon != null 
          ? _buildSingleIcon(context, firstHeaderIcon)
          : null;
    } else {
      // LTR: Remaining elements go to leading
      return remainingHeaderIcons.isNotEmpty
          ? _buildIconsList(context, remainingHeaderIcons)
          : null;
    }
  }

  // Get actions widget based on direction
  List<Widget> _getActionsWidget(BuildContext context, dynamic firstHeaderIcon, 
      List<dynamic> remainingHeaderIcons, bool isRTL) {
    if (isRTL) {
      // RTL: Remaining elements go to actions
      return _buildActionsFromList(context, remainingHeaderIcons);
    } else {
      // LTR: First element goes to actions
      return _buildActionsFromSingle(context, firstHeaderIcon);
    }
  }

  // Build single icon widget
  Widget _buildSingleIcon(BuildContext context, dynamic headerIcon) {
    return HeaderIconWidget(
      iconUrl: headerIcon.icon,
      title: headerIcon.title,
      size: 24,
      onTap: () => _handleHeaderIconTap(context, headerIcon),
    );
  }

  // Build multiple icons as a list (for leading position)
  Widget _buildIconsList(BuildContext context, List<dynamic> headerIcons) {
    if (headerIcons.isEmpty) return const SizedBox.shrink();
    
    // If there's only one icon, return it directly
    if (headerIcons.length == 1) {
      return _buildSingleIcon(context, headerIcons.first);
    }
    
    // If there are multiple icons, show them in a Row
    return Container(
      padding: const EdgeInsets.only(left: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: headerIcons.map<Widget>((headerIcon) {
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

  // Build actions from single icon (for LTR)
  List<Widget> _buildActionsFromSingle(BuildContext context, dynamic firstHeaderIcon) {
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

  // Build actions from list of icons (for RTL)
  List<Widget> _buildActionsFromList(BuildContext context, List<dynamic> remainingIcons) {
    final List<Widget> actions = [];
    
    for (final headerIcon in remainingIcons) {
      actions.add(
        HeaderIconWidget(
          iconUrl: headerIcon.icon,
          title: headerIcon.title,
          size: 24,
          onTap: () => _handleHeaderIconTap(context, headerIcon),
        ),
      );
    }
    
    if (actions.isNotEmpty) {
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