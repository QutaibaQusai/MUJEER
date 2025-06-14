// lib/widgets/header_icon_widget.dart
import 'package:flutter/material.dart';
import 'package:MUJEER/widgets/dynamic_icon.dart';

class HeaderIconWidget extends StatelessWidget {
  final String iconUrl;
  final String title;
  final VoidCallback onTap;
  final double size;

  const HeaderIconWidget({
    super.key,
    required this.iconUrl,
    required this.title,
    required this.onTap,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    
    return IconButton(
      onPressed: onTap,
      tooltip: title,
      icon: DynamicIcon(
        iconUrl: iconUrl,
        size: size,
        color:  Colors.white ,
        showLoading: false,
        fallbackIcon: Icon(
          Icons.widgets_outlined,
          size: size,
          color: Colors.white ,
        ),
      ),
    );
  }
}