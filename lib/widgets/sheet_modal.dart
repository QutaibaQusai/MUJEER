// lib/widgets/sheet_modal.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // ADD THIS IMPORT
import 'package:MUJEER/services/config_service.dart';
import 'package:MUJEER/services/webview_service.dart';
import 'package:MUJEER/services/refresh_state_manager.dart'; // ADD THIS IMPORT
import 'package:MUJEER/widgets/sheet_action_item.dart';

class SheetModal extends StatefulWidget {
  const SheetModal({super.key});

  @override
  State<SheetModal> createState() => _SheetModalState();
}

class _SheetModalState extends State<SheetModal> {
  RefreshStateManager? _refreshManager;

  @override
  void initState() {
    super.initState();
    
    // NOTIFY REFRESH MANAGER THAT SHEET IS OPENING
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshManager = Provider.of<RefreshStateManager>(context, listen: false);
      _refreshManager?.setSheetOpen(true);
      debugPrint('📋 SheetModal opening - background refresh/scroll DISABLED');
    });
  }

  @override
  void dispose() {
    // NOTIFY REFRESH MANAGER THAT SHEET IS CLOSING
    _refreshManager?.setSheetOpen(false);
    debugPrint('📋 SheetModal closing - background refresh/scroll ENABLED');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ConfigService().config;
    if (config == null || config.sheetIcons.isEmpty) {
      return _buildEmptySheet(context);
    }


    return Container(
      decoration: BoxDecoration(
        color:  Colors.black ,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),
          _buildSheetActions(context, config),
          const SizedBox(height: 30),
          _buildCloseButton(context),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSheetActions(BuildContext context, config) {
    const chunkSize = 3;
    final chunks = <List>[];

    for (int i = 0; i < config.sheetIcons.length; i += chunkSize) {
      chunks.add(
        config.sheetIcons.skip(i).take(chunkSize).toList(),
      );
    }

    return Column(
      children: chunks.map((chunk) => 
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: chunk.map<Widget>((item) => 
              Expanded(
                child: SheetActionItem(
                  title: item.title,
                  iconLineUrl: item.iconLine,
                  iconSolidUrl: item.iconSolid,
                  onTap: () => _handleSheetItemTap(context, item),
                ),
              ),
            ).toList(),
          ),
        ),
      ).toList(),
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // NOTIFY REFRESH MANAGER THAT SHEET IS CLOSING
        _refreshManager?.setSheetOpen(false);
        debugPrint('📋 SheetModal closing via close button - background refresh/scroll ENABLED');
        Navigator.pop(context);
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color:  Colors.white ,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.close,
          color:  Colors.black ,
        ),
      ),
    );
  }

  Widget _buildEmptySheet(BuildContext context) {
    
    return Container(
      decoration: BoxDecoration(
        color:  Colors.black ,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.info_outline,
            size: 48,
            color:  Colors.white ,
          ),
          const SizedBox(height: 16),
          Text(
            'No actions available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color:  Colors.white ,
            ),
          ),
          const SizedBox(height: 30),
          _buildCloseButton(context, ),
        ],
      ),
    );
  }

  void _handleSheetItemTap(BuildContext context, item) {
    // NOTIFY REFRESH MANAGER THAT SHEET IS CLOSING
    _refreshManager?.setSheetOpen(false);
    debugPrint('📋 SheetModal closing via action tap - background refresh/scroll ENABLED');
    
    Navigator.pop(context);
    
    WebViewService().navigate(
      context,
      url: item.link,
      linkType: item.linkType,
      title: item.title,
    );
  }
}