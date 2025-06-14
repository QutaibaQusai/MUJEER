import 'package:MUJEER/services/refresh_state_manager.dart';
import 'package:MUJEER/themes/dynamic_theme.dart';
import 'package:MUJEER/widgets/connection_status_widget.dart';
import 'package:MUJEER/widgets/screenshot_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:MUJEER/services/config_service.dart';
import 'package:MUJEER/services/theme_service.dart';
import 'package:MUJEER/pages/main_screen.dart';
import 'package:MUJEER/pages/no_internet_page.dart';
import 'package:MUJEER/services/internet_connection_service.dart';

void main() async {
  // Preserve the native splash screen
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Initialize services
  final configService = ConfigService();
  final themeService = ThemeService();
  final internetService = InternetConnectionService(); 

  // Load configuration
  debugPrint('🚀 ERPForever App Starting...');
  debugPrint('📡 Loading configuration from remote source...');

  await configService.loadConfig();

  // Initialize internet connection monitoring
  await internetService.initialize();
  debugPrint('🌐 Internet connection service initialized');

  // Log configuration status
  final cacheStatus = await configService.getCacheStatus();
  debugPrint('💾 Cache Status: $cacheStatus');

  if (configService.config != null) {
    debugPrint('✅ Configuration loaded successfully');
    debugPrint('🔗 Main Icons: ${configService.config!.mainIcons.length}');
    debugPrint('📋 Sheet Icons: ${configService.config!.sheetIcons.length}');
    debugPrint('🌍 Language: ${configService.config!.lang}');
    debugPrint('🌍 Direction: ${configService.config!.theme.direction}');
  } else {
    debugPrint('⚠️ Using fallback configuration');
  }

  debugPrint('🌙 Theme: Always dark mode');

  // Log initial internet status
  debugPrint('🌐 Initial internet status: ${internetService.isConnected}');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: configService),
        ChangeNotifierProvider(create: (_) => themeService),
        ChangeNotifierProvider(create: (_) => RefreshStateManager()),
        ChangeNotifierProvider(create: (_) => SplashStateManager()),
        ChangeNotifierProvider.value(value: internetService), 
      ],
      child: MyApp(
        hasInternet: internetService.isConnected,
      ),
    ),
  );
}

class SplashStateManager extends ChangeNotifier {
  bool _isWebViewReady = false;
  bool _isMinTimeElapsed = false;
  bool _isSplashRemoved = false;
  bool _hasInternet = true;
  late DateTime _startTime;

  SplashStateManager() {
    _startTime = DateTime.now();
    _startMinTimeTimer();
  }

  bool get isSplashRemoved => _isSplashRemoved;

  void setInternetStatus(bool hasInternet) {
    _hasInternet = hasInternet;
    debugPrint('🌐 Splash Manager - Internet status: ${hasInternet ? "CONNECTED" : "DISCONNECTED"}');
    
    if (!hasInternet) {
      debugPrint('🚫 No internet detected - will remove splash after minimum time to show no internet page');
      _checkSplashRemoval();
    } else {
      debugPrint('✅ Internet connected - checking splash removal conditions');
      _checkSplashRemoval();
    }
  }

  void _startMinTimeTimer() {
    Future.delayed(const Duration(seconds: 2), () {
      _isMinTimeElapsed = true;
      debugPrint('⏱️ Minimum 2 seconds elapsed');
      _checkSplashRemoval();
    });
  }

  void setWebViewReady() {
    if (!_isWebViewReady) {
      _isWebViewReady = true;
      debugPrint('🌐 First WebView is ready');
      _checkSplashRemoval();
    }
  }

  void _checkSplashRemoval() {
    bool shouldRemove = _isMinTimeElapsed && 
                       (_isWebViewReady || !_hasInternet) && 
                       !_isSplashRemoved;
    
    debugPrint('🔍 Splash removal check:');
    debugPrint('   - Min time elapsed: $_isMinTimeElapsed');
    debugPrint('   - WebView ready: $_isWebViewReady');
    debugPrint('   - Has internet: $_hasInternet');
    debugPrint('   - Should remove: $shouldRemove');
    
    if (shouldRemove) {
      _removeSplash();
    }
  }

  void _removeSplash() {
    if (_isSplashRemoved) return;
    
    _isSplashRemoved = true;

    try {
      FlutterNativeSplash.remove();
      debugPrint('✅ Splash screen removed successfully!');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error removing splash screen: $e');
    }
  }
}

class MyApp extends StatelessWidget {
  final bool hasInternet;

  const MyApp({
    super.key, 
    required this.hasInternet,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer3<ConfigService, ThemeService, InternetConnectionService>(
      builder: (context, configService, themeService, internetService, child) {
        // Monitor internet connection changes for splash management
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            try {
              final splashManager = Provider.of<SplashStateManager>(context, listen: false);
              splashManager.setInternetStatus(internetService.isConnected);
            } catch (e) {
              debugPrint('❌ Error updating splash manager with internet status: $e');
            }
          }
        });

        final textDirection = configService.getTextDirection();

        // Enhanced config loading with context after app is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            _enhanceConfigWithContext(context, configService);
          }
        });

        return Directionality(
          textDirection: textDirection,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'ERPForever',
            themeMode: ThemeMode.dark,
            theme: DynamicTheme.buildTheme(configService.config),
            darkTheme: DynamicTheme.buildTheme(configService.config),
            home: ScreenshotWrapper(
              child: ConnectionStatusWidget(
                child: _buildHomePage(internetService),
              ),
            ),
            builder: (context, widget) {
              return Directionality(
                textDirection: textDirection,
                child: widget ?? Container(),
              );
            },
          ),
        );
      },
    );
  }

  // NEW: Simplified home page - only MainScreen or NoInternetPage
  Widget _buildHomePage(InternetConnectionService internetService) {
    return Consumer<InternetConnectionService>(
      builder: (context, connectionService, _) {
        debugPrint('🏠 Building home page - Internet: ${connectionService.isConnected}');
        
        // If no internet, show no internet page
        if (!connectionService.isConnected) {
          debugPrint('🚫 No internet - showing NoInternetPage');
          return const NoInternetPage();
        }
        
        // If internet is available, always show MainScreen
        debugPrint('✅ Internet available - showing MainScreen');
        return const MainScreen();
      },
    );
  }

  void _enhanceConfigWithContext(
    BuildContext context,
    ConfigService configService,
  ) async {
    try {
      debugPrint('🔧 Enhancing configuration with context for better app data...');

      final cacheStatus = await configService.getCacheStatus();
      final cacheAgeMinutes = (cacheStatus['cacheAge'] as int? ?? 0) / (1000 * 60);

      if (cacheAgeMinutes > 1 || !configService.isLoaded) {
        debugPrint('🔄 Reloading configuration with enhanced app data...');
        await configService.loadConfig(context);
        debugPrint('✅ Configuration enhanced with context-aware app data');
      } else {
        debugPrint('⏩ Recent config available, skipping context enhancement');
      }
    } catch (e) {
      debugPrint('❌ Error enhancing config with context: $e');
    }
  }
}