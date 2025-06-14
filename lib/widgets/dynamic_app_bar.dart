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
      leading:
          firstHeaderIcon != null
              ? HeaderIconWidget(
                iconUrl: firstHeaderIcon.icon,
                title: firstHeaderIcon.title,
                size: 24,
                onTap: () => _handleHeaderIconTap(context, firstHeaderIcon),
              )
              : null,
      title: Padding(
        padding: const EdgeInsets.only(right: 10.0),
        child: _buildTitle(context, currentItem.title, titleColor),
      ),
      actions: _buildActions(context, remainingHeaderIcons),
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

  List<Widget> _buildActions(BuildContext context, List<dynamic> headerIcons) {
    final List<Widget> actions = [];

    for (final headerIcon in headerIcons) {
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
