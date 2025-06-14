// lib/widgets/adaptive_app_bar.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:MUJEER/services/config_service.dart';
import 'package:MUJEER/services/webview_service.dart';
import 'package:MUJEER/widgets/header_icon_widget.dart';

class AdaptiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int selectedIndex;
  final bool showLogo;
  final String? customTitle;

  const AdaptiveAppBar({
    super.key,
    required this.selectedIndex,
    this.showLogo = false,
    this.customTitle,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final config = ConfigService().config;
    if (config == null) return _buildFallbackAppBar(context);

    return AppBar(
      centerTitle: false,
      title: _buildAdaptiveTitle(context),
      actions: _buildAdaptiveActions(context, selectedIndex),
      backgroundColor: _hexToColor(config.theme.darkSurface),
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
    );
  }

  Widget _buildAdaptiveTitle(BuildContext context) {
    if (showLogo) {
      return Container(
        height: 20,
        child: Image.asset(
          "assets/erpforever-white.png",
          errorBuilder:
              (context, error, stackTrace) => Text(
                customTitle ?? 'ERPForever',
                style: GoogleFonts.rubik(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
        ),
      );
    }

    return Text(
      customTitle ?? 'ERPForever',
      style: GoogleFonts.rubik(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );
  }

  List<Widget> _buildAdaptiveActions(BuildContext context, int selectedIndex) {
    final config = ConfigService().config;
    if (config == null || selectedIndex >= config.mainIcons.length) {
      return [];
    }

    final currentItem = config.mainIcons[selectedIndex];
    final List<Widget> actions = [];

    if (currentItem.headerIcons != null) {
      for (final headerIcon in currentItem.headerIcons!) {
        actions.add(
          HeaderIconWidget(
            iconUrl: headerIcon.icon,
            title: headerIcon.title,
            size: 24,
            onTap: () {
              WebViewService().navigate(
                context,
                url: headerIcon.link,
                linkType: headerIcon.linkType,
                title: headerIcon.title,
              );
            },
          ),
        );
      }
    }

    return actions;
  }

  AppBar _buildFallbackAppBar(BuildContext context) {
    return AppBar(
      title: Text(
        'MUJEER',
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

  Color _hexToColor(String hexColor) {
    return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
  }
}
