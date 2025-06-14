import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

import 'package:MUJEER/services/config_service.dart';
import 'package:MUJEER/services/webview_service.dart';
import 'package:MUJEER/widgets/dynamic_navigation_icon.dart';

class DynamicBottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const DynamicBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    final config = ConfigService().config;
    if (config == null) return const SizedBox.shrink();


    final primaryColor = getColorFromHex(config.theme.primaryColor);
    debugPrint('$primaryColor ');


    return Container(
      decoration: BoxDecoration(
        color:  const Color(0xFF1E1E1E) ,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8),
          child: GNav(
            rippleColor:  Colors.grey[800]! ,
            hoverColor:  Colors.grey[700]! ,
            haptic: true,
            tabBorderRadius: 25,
            tabActiveBorder: Border.all(color: primaryColor, width: 1),
            tabBorder: Border.all(color: Colors.transparent, width: 1),
            curve: Curves.easeIn,
            duration: const Duration(milliseconds: 200),
            gap: 8,
            color: Colors.white,
            activeColor: primaryColor,
            iconSize: 24,
            tabBackgroundColor: primaryColor.withOpacity(0.2),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            selectedIndex: selectedIndex,
            onTabChange: (index) {
              HapticFeedback.lightImpact();
              final item = config.mainIcons[index];
              _onItemTapped(context, index, item);
            },
            tabs: _buildNavigationTabs(
              context,
              config,
              primaryColor,
              Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Color getColorFromHex(String hexColor) {
    try {
      String cleaned = hexColor.trim().toUpperCase().replaceAll('#', '');
      if (cleaned.length == 6) {
        cleaned = 'FF$cleaned'; 
      }
      return Color(int.parse('0x$cleaned'));
    } catch (e) {
      debugPrint('❌ Invalid hex color: $hexColor. Error: $e');
      return const Color(0xFFFF0000); 
    }
  }

  List<GButton> _buildNavigationTabs(
    BuildContext context,
    dynamic config,
    Color primaryColor,
    Color inactiveColor,
  ) {
    return List.generate(
      config.mainIcons.length,
      (index) => GButton(
        icon: Icons.circle,
        text: config.mainIcons[index].title,
        leading: SizedBox(
          width: 24,
          height: 24,
          child: DynamicNavigationIcon(
            iconLineUrl: config.mainIcons[index].iconLine,
            iconSolidUrl: config.mainIcons[index].iconSolid,
            isSelected: selectedIndex == index,
            size: 24,
            selectedColor: primaryColor,
            unselectedColor: inactiveColor,
          ),
        ),
        textStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: primaryColor,
        ),
      ),
    );
  }

  void _onItemTapped(BuildContext context, int index, dynamic item) {
    if (item.linkType == 'sheet_webview') {
      WebViewService().navigate(
        context,
        url: item.link,
        linkType: item.linkType,
        title: item.title,
      );
    } else {
      onItemTapped(index);
    }
  }
}
