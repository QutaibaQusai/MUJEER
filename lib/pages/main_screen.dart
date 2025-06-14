import 'dart:convert';
import 'package:MUJEER/main.dart';
import 'package:MUJEER/pages/no_internet_page.dart';
import 'package:MUJEER/services/internet_connection_service.dart';
import 'package:MUJEER/services/location_service.dart';
import 'package:MUJEER/services/pull_to_refresh_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:MUJEER/services/config_service.dart';
import 'package:MUJEER/services/webview_service.dart';
import 'package:MUJEER/services/webview_controller_manager.dart';
import 'package:MUJEER/widgets/dynamic_bottom_navigation.dart';
import 'package:MUJEER/widgets/dynamic_app_bar.dart';
import 'package:MUJEER/widgets/loading_widget.dart';
import 'package:MUJEER/pages/barcode_scanner_page.dart';
import 'package:MUJEER/services/alert_service.dart';
import 'package:MUJEER/services/refresh_state_manager.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  BuildContext? get _currentContext => mounted ? context : null;
  WebViewController? get _currentController {
    try {
      return _controllerManager.getController(_selectedIndex, '', context);
    } catch (e) {
      return null;
    }
  }

  int _selectedIndex = 0;
  late ConfigService _configService;
  late WebViewControllerManager _controllerManager;

  final Map<int, bool> _loadingStates = {};
  final Map<int, bool> _isAtTopStates = {};
  final Map<int, bool> _isRefreshingStates = {};
  final Map<int, bool> _channelAdded = {};
  final Map<int, bool> _refreshChannelAdded = {};
  final Map<int, String> _refreshChannelNames = {};
  DateTime? _backgroundTime;
  static const Duration _backgroundThreshold = Duration(minutes: 3);
  bool _hasNotifiedSplash = false;

  bool _hasStartedPreloading = false;

  @override
  void initState() {
    super.initState();
    _configService = ConfigService();
    _controllerManager = WebViewControllerManager();

    _initializeLoadingStates();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
        debugPrint('📱 App going to background - recording timestamp');
        _backgroundTime =
            DateTime.now(); // 🆕 NEW: Record when app went to background
        _preserveWebViewState();
        break;
      case AppLifecycleState.resumed:
        debugPrint(
          '📱 App resumed from background - checking background duration',
        );
        _handleAppResume(); // 🆕 NEW: Handle resume with time-based logic
        break;
      default:
        break;
    }
  }

  void _handleAppResume() {
    if (_backgroundTime == null) {
      debugPrint('⚠️ No background time recorded, skipping background checks');
      return;
    }

    final backgroundDuration = DateTime.now().difference(_backgroundTime!);
    debugPrint(
      '⏱️ App was in background for: ${backgroundDuration.inMinutes} minutes ${backgroundDuration.inSeconds % 60} seconds',
    );

    if (backgroundDuration >= _backgroundThreshold) {
      debugPrint(
        '🔄 Background duration exceeded ${_backgroundThreshold.inMinutes} minutes - refreshing current tab',
      );
      _refreshAfterLongBackground();
    } else {
      debugPrint(
        '✅ Background duration under ${_backgroundThreshold.inMinutes} minutes - preserving WebView state',
      );
      _restoreWebViewStateOnly();
    }

    // Reset background time
    _backgroundTime = null;
  }

  // 🆕 NEW: Refresh only after long background
  Future<void> _refreshAfterLongBackground() async {
    try {
      debugPrint(
        '🔄 Refreshing current tab $_selectedIndex after long background',
      );

      setState(() {
        _loadingStates[_selectedIndex] = true;
      });

      final controller = _controllerManager.getController(
        _selectedIndex,
        '',
        context,
      );
      await controller.reload();

      debugPrint('✅ Background refresh initiated for tab $_selectedIndex');
    } catch (e) {
      debugPrint('❌ Error refreshing after background: $e');
      if (mounted) {
        setState(() {
          _loadingStates[_selectedIndex] = false;
        });
      }
    }
  }

  // 🆕 NEW: Restore state without refresh for short background
  void _restoreWebViewStateOnly() {
    try {
      debugPrint('📱 Restoring WebView state without refresh');

      final controller = _controllerManager.getController(
        _selectedIndex,
        '',
        context,
      );

      // Just restore scroll position without refreshing
      controller.runJavaScript('''
        try {
          if (window.savedAppState && window.savedAppState.scrollX !== undefined) {
            setTimeout(() => {
              window.scrollTo(window.savedAppState.scrollX, window.savedAppState.scrollY);
              console.log('📍 Scroll position restored after short background');
            }, 100);
          }
        } catch (error) {
          console.error('❌ Error restoring scroll after short background:', error);
        }
      ''');

      debugPrint('✅ WebView state restored without refresh');
    } catch (e) {
      debugPrint('❌ Error restoring WebView state: $e');
    }
  }

  void _preserveWebViewState() {
    try {
      final config = _configService.config;
      if (config == null) return;

      // Save scroll position and URL for current tab
      final controller = _controllerManager.getController(
        _selectedIndex,
        '',
        context,
      );
      controller.runJavaScript('''
      try {
        // Save current state in memory
        window.savedAppState = {
          url: window.location.href,
          scrollX: window.pageXOffset || document.documentElement.scrollLeft || 0,
          scrollY: window.pageYOffset || document.documentElement.scrollTop || 0,
          timestamp: Date.now()
        };
        console.log('💾 State saved before backgrounding');
      } catch (error) {
        console.error('❌ Error saving state:', error);
      }
    ''');
    } catch (e) {
      debugPrint('❌ Error preserving state: $e');
    }
  }


  Future<bool> _checkWebViewHasContent(int tabIndex) async {
    try {
      final controller = _controllerManager.getController(
        tabIndex,
        '',
        context,
      );

      final result = await controller.runJavaScriptReturningResult('''
      (function() {
        try {
          // Check multiple indicators of content presence
          const hasBody = document.body !== null;
          const hasChildren = document.body && document.body.children.length > 0;
          const hasText = document.body && document.body.innerText.trim().length > 0;
          const isNotBlank = !document.body.innerHTML.includes('about:blank');
          const hasScripts = typeof window.ERPForever !== 'undefined';
          
          // Consider content present if we have DOM elements and text
          const hasContent = hasBody && hasChildren && (hasText || hasScripts) && isNotBlank;
          
          return JSON.stringify({
            hasContent: hasContent,
            childrenCount: hasChildren ? document.body.children.length : 0,
            textLength: hasText ? document.body.innerText.length : 0,
            hasScripts: hasScripts,
            url: window.location.href
          });
        } catch (error) {
          return JSON.stringify({hasContent: false, error: error.toString()});
        }
      })();
    ''');

      if (result != null) {
        final data = jsonDecode(result.toString());
        final hasContent = data['hasContent'] == true;

        debugPrint(
          '📊 Content check for tab $tabIndex: $hasContent (children: ${data['childrenCount']}, text: ${data['textLength']})',
        );

        return hasContent;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error checking content: $e');
      return false; // Assume no content if check fails
    }
  }


    void _initializeLoadingStates() {
    final config = _configService.config;
    if (config != null && config.mainIcons.isNotEmpty) {
      for (int i = 0; i < config.mainIcons.length; i++) {
        _loadingStates[i] = i == 0 ? true : false; 
        _isAtTopStates[i] = true;
        _isRefreshingStates[i] = false;
        _channelAdded[i] = false;
        _refreshChannelAdded[i] = false;
        _refreshChannelNames[i] = 'MainScreenRefresh_${i}_${DateTime.now().millisecondsSinceEpoch}';
      }

      debugPrint('✅ Initialized all ${config.mainIcons.length} tabs for lazy loading');
      debugPrint('🏠 Tab 0 (Home) will start loading immediately');
    }
  }

  void _notifyWebViewReady() {
    if (!_hasNotifiedSplash) {
      _hasNotifiedSplash = true;

      try {
        final splashManager = Provider.of<SplashStateManager>(
          context,
          listen: false,
        );

        // NEW: Only notify if we have internet connection
        final internetService = Provider.of<InternetConnectionService>(
          context,
          listen: false,
        );

        if (internetService.isConnected) {
          splashManager.setWebViewReady();
          debugPrint(
            '🌐 MainScreen: Notified splash manager that WebView is ready',
          );

          // Start preloading other tabs after splash notification
          _startPreloadingOtherTabs();
        } else {
          debugPrint(
            '🚫 MainScreen: Skipping WebView ready notification - no internet',
          );
        }
      } catch (e) {
        debugPrint('❌ MainScreen: Error notifying splash manager: $e');
      }
    }
  }

  void _startPreloadingOtherTabs() async {
    if (_hasStartedPreloading) return;
    _hasStartedPreloading = true;

    final config = _configService.config;
    if (config == null || config.mainIcons.length <= 1) {
      debugPrint('⚠️ No other tabs to preload');
      return;
    }

    debugPrint(
      '🔄 Starting to preload other tabs with FULL pull-to-refresh setup...',
    );

    // Wait for splash to be handled
    await Future.delayed(const Duration(milliseconds: 1000));

    // Preload tabs 1, 2, 3, etc. with complete setup
    for (int i = 1; i < config.mainIcons.length; i++) {
      try {
        final mainIcon = config.mainIcons[i];

        // Skip sheet_webview tabs
        if (mainIcon.linkType == 'sheet_webview') {
          debugPrint('⏭️ Skipping sheet tab $i: ${mainIcon.title}');
          continue;
        }

        debugPrint('📱 Preloading tab $i with FULL setup: ${mainIcon.title}');

        // ✅ FIXED: Ensure complete initialization
        _ensureTabInitialized(i);

        // ✅ FIXED: Get controller and set up completely
        final controller = _controllerManager.getController(
          i,
          mainIcon.link,
          context,
        );
        _setupTabControllerForPullRefresh(controller, i);

        // ✅ FIXED: Add refresh channel immediately
        _addRefreshChannelSafely(controller, i);

        debugPrint('✅ Tab $i preloaded with complete pull-to-refresh setup');

        // Delay between preloads
        if (i < config.mainIcons.length - 1) {
          await Future.delayed(const Duration(milliseconds: 600));
        }
      } catch (e) {
        debugPrint('❌ Error preloading tab $i: $e');
      }
    }

    debugPrint(
      '🎉 All tabs preloaded with COMPLETE pull-to-refresh functionality!',
    );
  }


  @override
  Widget build(BuildContext context) {
    return Consumer2<ConfigService, InternetConnectionService>(
      builder: (context, configService, internetService, child) {
        // NEW: If no internet, show no internet page
        if (!internetService.isConnected) {
          return const NoInternetPage();
        }

        if (!configService.isLoaded) {
          return const Scaffold(
            body: Center(
              child: LoadingWidget(message: "Loading configuration..."),
            ),
          );
        }

        if (configService.error != null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Configuration Error',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      configService.error!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => configService.reloadConfig(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        return _buildMainScaffold(configService.config!);
      },
    );
  }

  Widget _buildMainScaffold(config) {
    return Scaffold(
      appBar: DynamicAppBar(selectedIndex: _selectedIndex),
      body: _buildBody(config),
      bottomNavigationBar: DynamicBottomNavigation(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
      floatingActionButton: null,
    );
  }

Widget _buildBody(config) {
  debugPrint('🏗️ Building body for main screen');
  debugPrint('📊 Config main icons length: ${config.mainIcons.length}');
  debugPrint('🎯 Selected index: $_selectedIndex');
  
  if (config.mainIcons.isEmpty) {
    debugPrint('❌ No navigation items configured');
    return const Center(child: Text('No navigation items configured'));
  }

  if (_selectedIndex >= config.mainIcons.length) {
    debugPrint('❌ Selected index $_selectedIndex is out of range (max: ${config.mainIcons.length - 1})');
    return const Center(child: Text('Invalid tab selection'));
  }

  final selectedIcon = config.mainIcons[_selectedIndex];
  debugPrint('📱 Selected tab: ${selectedIcon.title} (${selectedIcon.linkType})');
  debugPrint('🔗 Tab URL: ${selectedIcon.link}');

  // ✅ Build the currently selected tab content
  final tabContent = _buildTabContent(_selectedIndex, selectedIcon);
  debugPrint('✅ Tab content built for index $_selectedIndex');
  
  return tabContent;
}

  Widget _buildTabContent(int index, mainIcon) {
    debugPrint('🏗️ Building tab content for index $index: ${mainIcon.title}');
    
    if (mainIcon.linkType == 'sheet_webview') {
      debugPrint('📋 Tab $index is sheet type - showing placeholder');
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Tap to open in sheet',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Consumer<RefreshStateManager>(
      builder: (context, refreshManager, child) {
        final isRefreshAllowed = refreshManager.isRefreshEnabled;

        return RefreshIndicator(
          onRefresh:
              isRefreshAllowed
                  ? () => _refreshWebView(index)
                  : () async {
                    debugPrint('🚫 Refresh blocked - sheet is open');
                    return;
                  },
          child: Stack(
            children: [
              _buildWebView(index, mainIcon.link),
              if (_loadingStates[index] == true ||
                  _isRefreshingStates[index] == true)
                const LoadingWidget(),
              if (_isAtTopStates[index] == true &&
                  _isRefreshingStates[index] == false &&
                  isRefreshAllowed)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(height: 2, color: Colors.transparent),
                ),
            ],
          ),
        );
      },
    );
  }
  Future<void> _refreshWebView(int index) async {
    final refreshManager = Provider.of<RefreshStateManager>(
      context,
      listen: false,
    );

    if (!refreshManager.shouldAllowRefresh()) {
      debugPrint('🚫 Refresh blocked by RefreshStateManager');
      return;
    }
    if (_isRefreshingStates[index] == true)
      return; // Prevent multiple refreshes

    debugPrint('🔄 Refreshing WebView at index $index');

    setState(() {
      _isRefreshingStates[index] = true;
    });

    try {
      final controller = _controllerManager.getController(index, '', context);
      await controller.reload();

      // Wait for page to start loading
      await Future.delayed(const Duration(milliseconds: 800));

      debugPrint('✅ WebView refreshed successfully');
    } catch (e) {
      debugPrint('❌ Error refreshing WebView: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingStates[index] = false;
        });
      }
    }
  }

Widget _buildWebView(int index, String url) {
    debugPrint('🌐 Building WebView for tab $index with URL: $url');
    
    final controller = _controllerManager.getController(index, url, context);

    // ✅ CRITICAL: Always ensure tab is initialized for pull-to-refresh
    _ensureTabInitialized(index);

    // ✅ CRITICAL: Always set up the controller properly, regardless of tab index
    _setupTabControllerForPullRefresh(controller, index);

    // ✅ CRITICAL: Always add refresh channel - with better error handling
    if (_refreshChannelAdded[index] != true) {
      _addRefreshChannelSafely(controller, index);
    }

    debugPrint('✅ WebView widget created for tab $index');
    return WebViewWidget(controller: controller);
  }


  void _ensureTabInitialized(int index) {
    if (!_loadingStates.containsKey(index)) {
      debugPrint('🔧 Initializing tab $index for pull-to-refresh');

      _loadingStates[index] = false; // Start as not loading for existing tabs
      _isAtTopStates[index] = true;
      _isRefreshingStates[index] = false;
      _channelAdded[index] = false;
      _refreshChannelAdded[index] = false;
      _refreshChannelNames[index] =
          'MainScreenRefresh_${index}_${DateTime.now().millisecondsSinceEpoch}';

      debugPrint(
        '✅ Tab $index initialized with channel: ${_refreshChannelNames[index]}',
      );
    }
  }

 void _setupTabControllerForPullRefresh(
    WebViewController controller,
    int index,
  ) {
    // Only set up if not already done
    if (_channelAdded[index] == true) {
      debugPrint('⏩ Tab $index controller already set up, skipping...');
      return;
    }

    debugPrint('🔧 Setting up controller for tab $index pull-to-refresh...');

    controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (String url) {
          debugPrint('🔄 Tab $index page started loading: $url');
          if (mounted) {
            setState(() {
              _loadingStates[index] = true;
              _isAtTopStates[index] = true;
            });
          }
        },
        onPageFinished: (String url) {
          debugPrint('✅ Tab $index page finished loading: $url');

          if (mounted) {
            setState(() {
              _loadingStates[index] = false;
            });
          }

          // ✅ CRITICAL: Always notify splash for tab 0 that finishes loading
          if (index == 0) {
            _notifyWebViewReady();
          }

          // ✅ FIXED: Always inject scroll monitoring for every tab
          _injectScrollMonitoring(controller, index);

          // ✅ FIXED: Always inject pull-to-refresh for every tab
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) {
              _injectNativePullToRefresh(controller, index);
            }
          });

          // ✅ FIXED: Always inject background state handling
          _injectBackgroundStateHandling(controller, index);

          debugPrint('🎯 Tab $index fully set up for pull-to-refresh!');
        },
        onWebResourceError: (WebResourceError error) {
          debugPrint(
            '❌ WebResource error for tab $index: ${error.description}',
          );
          if (mounted) {
            setState(() {
              _loadingStates[index] = false;
            });
          }
        },
        onNavigationRequest: (NavigationRequest request) {
          WebViewService().updateController(controller, context);
          return _handleNavigationRequest(request);
        },
      ),
    );

    // Mark as set up
    _channelAdded[index] = true;
    debugPrint('✅ Tab $index controller setup completed');
  }
  void _addRefreshChannelSafely(WebViewController controller, int index) {
    final refreshChannelName = _refreshChannelNames[index]!;

    try {
      controller.addJavaScriptChannel(
        refreshChannelName,
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'refresh') {
            debugPrint(
              '🔄 Pull-to-refresh triggered from JavaScript for tab $index',
            );
            _handleJavaScriptRefresh(index);
          }
        },
      );
      _refreshChannelAdded[index] = true;
      debugPrint('✅ Refresh channel added for tab $index: $refreshChannelName');
    } catch (e) {
      debugPrint('❌ Error adding refresh channel for tab $index: $e');
      _refreshChannelAdded[index] = false;

      // Retry with a new channel name
      _refreshChannelNames[index] =
          'MainScreenRefresh_${index}_retry_${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('🔄 Retrying with new channel name for tab $index');
    }
  }

  void _injectBackgroundStateHandling(WebViewController controller, int index) {
    controller.runJavaScript('''
    (function() {
      console.log('🔧 Setting up background state handling for tab $index');
      
      // Listen for visibility changes
      document.addEventListener('visibilitychange', function() {
        if (document.visibilityState === 'visible') {
          console.log('👁️ Tab $index became visible - checking page state');
          
          // Check if page content is intact
          const hasContent = document.body && document.body.children.length > 0;
          const hasScripts = typeof window.ERPForever !== 'undefined';
          
          if (!hasContent) {
            console.log('⚠️ Tab $index: Page content missing after background');
            // Could dispatch an event to let user know page may need refresh
            var event = new CustomEvent('pageContentMissing', { 
              detail: { tabIndex: $index } 
            });
            document.dispatchEvent(event);
          } else if (!hasScripts) {
            console.log('⚠️ Tab $index: JavaScript context lost after background');
            // Scripts missing but content there - might work with re-injection
            var event = new CustomEvent('scriptsNeedReinjection', { 
              detail: { tabIndex: $index } 
            });
            document.dispatchEvent(event);
          } else {
            console.log('✅ Tab $index: Page state intact after background');
          }
        }
      });
      
      // Prevent automatic reloads
      window.addEventListener('beforeunload', function(e) {
        // Don't prevent unload, just log it
        console.log('📱 Tab $index: Page unloading');
      });
      
      console.log('✅ Background state handling ready for tab $index');
    })();
  ''');
  }

  void _injectNativePullToRefresh(WebViewController controller, int index) {
    try {
      final refreshChannelName = _refreshChannelNames[index]!;

      debugPrint('🔄 Using PullToRefreshService for main screen tab $index...');

      // Use the reusable service
      PullToRefreshService().injectNativePullToRefresh(
        controller: controller,
        context: RefreshContext.mainScreen,
        tabIndex: index,
        refreshChannelName: refreshChannelName,
        flutterContext: context, // Pass Flutter context for theme detection
      );

      debugPrint('✅ PullToRefreshService injected for main screen tab $index');
    } catch (e) {
      debugPrint('❌ Error injecting refresh for main screen tab $index: $e');
    }
  }

  Future<void> _handleJavaScriptRefresh(int index) async {
    final refreshManager = Provider.of<RefreshStateManager>(
      context,
      listen: false,
    );

    if (!refreshManager.shouldAllowRefresh()) {
      debugPrint('🚫 JavaScript refresh blocked - sheet is open');
      return;
    }

    debugPrint('🔄 Handling JavaScript refresh request for tab $index');

    if (_isRefreshingStates[index] == true) {
      debugPrint('❌ Already refreshing tab $index, ignoring request');
      return;
    }

    try {
      setState(() {
        _isRefreshingStates[index] = true;
        _loadingStates[index] = true;
      });

      final controller = _controllerManager.getController(index, '', context);
      await controller.reload();

      // Wait for page to start loading
      await Future.delayed(const Duration(milliseconds: 800));

      debugPrint('✅ JavaScript refresh completed successfully for tab $index');
    } catch (e) {
      debugPrint('❌ Error during JavaScript refresh for tab $index: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingStates[index] = false;
          // Note: Don't set _loadingStates[index] = false here
          // Let the onPageFinished callback handle it
        });
      }
    }
  }

  void _injectScrollJavaScript(WebViewController controller, int index) {
    controller.runJavaScript('''
    (function() {
      let isAtTop = true;
      let scrollTimeout;
      const channelName = 'ScrollMonitor_$index';
      
      function checkScrollPosition() {
        const scrollTop = window.pageYOffset || document.documentElement.scrollTop || document.body.scrollTop || 0;
        const newIsAtTop = scrollTop <= 5;
        
        if (newIsAtTop !== isAtTop) {
          isAtTop = newIsAtTop;
          
          if (window[channelName] && window[channelName].postMessage) {
            window[channelName].postMessage(isAtTop.toString());
          }
        }
      }
      
      function onScroll() {
        if (scrollTimeout) {
          clearTimeout(scrollTimeout);
        }
        scrollTimeout = setTimeout(checkScrollPosition, 50);
      }
      
      // Remove existing listeners
      window.removeEventListener('scroll', onScroll);
      
      // Add scroll listener
      window.addEventListener('scroll', onScroll, { passive: true });
      
      // Initial check
      setTimeout(checkScrollPosition, 100);
      
      console.log('✅ Scroll monitoring re-initialized for tab $index');
    })();
  ''');

    // Add bottom margin for navigation bar
    controller.runJavaScript('''
    document.body.style.marginBottom = '85px';
    document.body.style.boxSizing = 'border-box';
    console.log('✅ Bottom margin added for tab $index navigation bar');
  ''');

    // Register with refresh manager
    final refreshManager = Provider.of<RefreshStateManager>(
      context,
      listen: false,
    );
    refreshManager.registerController(controller);
    debugPrint('✅ Tab $index controller registered with RefreshStateManager');
  }

  void _injectScrollMonitoring(WebViewController controller, int index) {
    // ✅ FIXED: Always check if channel is already added
    if (_channelAdded[index] == true) {
      debugPrint(
        '📍 Scroll monitoring already set up for tab $index, updating JavaScript only...',
      );

      // Just re-inject the JavaScript part
      _injectScrollJavaScript(controller, index);
      return;
    }

    try {
      // Add JavaScript channel first
      controller.addJavaScriptChannel(
        'ScrollMonitor_$index',
        onMessageReceived: (JavaScriptMessage message) {
          try {
            final isAtTop = message.message == 'true';

            if (mounted && _isAtTopStates[index] != isAtTop) {
              setState(() {
                _isAtTopStates[index] = isAtTop;
              });
              debugPrint(
                '📍 Tab $index scroll position: ${isAtTop ? "TOP" : "SCROLLED"}',
              );
            }
          } catch (e) {
            debugPrint('❌ Error parsing scroll message for tab $index: $e');
          }
        },
      );

      // Mark channel as added
      _channelAdded[index] = true;
      debugPrint('✅ Scroll channel added for tab $index');

      // Inject the JavaScript
      _injectScrollJavaScript(controller, index);
    } catch (e) {
      debugPrint('❌ Error adding scroll channel for tab $index: $e');
      _channelAdded[index] = false;
    }
  }

  NavigationDecision _handleNavigationRequest(NavigationRequest request) {
    debugPrint("Navigation request: ${request.url}");

    // NEW: Handle external URLs with ?external=1 parameter
    if (request.url.contains('?external=1')) {
      _handleExternalNavigation(request.url);
      return NavigationDecision.prevent;
    }
    if (request.url.startsWith('toast://')) {
      _handleToastRequest(request.url);
      return NavigationDecision.prevent;
    }

    // NEW: Handle external URLs with ?external=1 parameter
    if (request.url.contains('?external=1')) {
      _handleExternalNavigation(request.url);
      return NavigationDecision.prevent;
    }

    if (request.url.startsWith('get-location://')) {
      _handleLocationRequest();
      return NavigationDecision.prevent;
    }

    // Contacts requests
    if (request.url.startsWith('get-contacts')) {
      _handleContactsRequest();
      return NavigationDecision.prevent;
    }

    // Other navigation requests
    if (request.url.startsWith('new-web://')) {
      _handleNewWebNavigation(request.url);
      return NavigationDecision.prevent;
    }

    if (request.url.startsWith('new-sheet://')) {
      _handleSheetNavigation(request.url);
      return NavigationDecision.prevent;
    }

    // NEW: Handle continuous barcode scanning
    if (request.url.startsWith('continuous-barcode://')) {
      _handleContinuousBarcodeScanning(request.url);
      return NavigationDecision.prevent;
    }

    // Regular barcode requests
    if (request.url.contains('barcode') || request.url.contains('scan')) {
      _handleBarcodeScanning(request.url);
      return NavigationDecision.prevent;
    }

    if (request.url.startsWith('take-screenshot://')) {
      _handleScreenshotRequest();
      return NavigationDecision.prevent;
    }

    // Image save requests
    if (request.url.startsWith('save-image://')) {
      _handleImageSaveRequest(request.url);
      return NavigationDecision.prevent;
    }

    if (request.url.startsWith('save-pdf://')) {
      _handlePdfSaveRequest(request.url);
      return NavigationDecision.prevent;
    }

    if (request.url.startsWith('alert://') ||
        request.url.startsWith('confirm://') ||
        request.url.startsWith('prompt://')) {
      _handleAlertRequest(request.url);
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  void _handleToastRequest(String url) {
    debugPrint('🍞 Toast requested from WebView: $url');

    try {
      // Extract message from the URL
      String message = url.replaceFirst('toast://', '');

      // Decode URL encoding if present
      message = Uri.decodeComponent(message);

      // Show the toast message using web scripts (same as WebViewPage)
      if (mounted && message.isNotEmpty) {
        final controller = _controllerManager.getController(
          _selectedIndex,
          '',
          context,
        );

        controller.runJavaScript('''
        try {
          console.log('🍞 Toast message received in MainScreen: $message');
          
          // Try to find and call web-based toast functions first
          if (typeof showWebToast === 'function') {
            showWebToast('$message');
            console.log('✅ Called showWebToast() function');
          } else if (typeof window.showToast === 'function') {
            window.showToast('$message');
            console.log('✅ Called window.showToast() function');
          } else if (typeof displayToast === 'function') {
            displayToast('$message');
            console.log('✅ Called displayToast() function');
          } else {
            // ✅ ENHANCED: Flutter SnackBar-style black toast
            console.log('💡 Creating Flutter SnackBar-style black toast...');
            
            // Remove any existing toast
            var existingToast = document.getElementById('flutter-toast');
            if (existingToast) existingToast.remove();
            
            // Create toast container
            var toastDiv = document.createElement('div');
            toastDiv.id = 'flutter-toast';
            toastDiv.innerHTML = '$message';
            
            // ✅ Flutter SnackBar-style CSS - BLACK background with WHITE font
            toastDiv.style.cssText = \`
              position: fixed;
              bottom: 24px;
              left: 16px;
              right: 16px;
              background: #323232;
              color: #ffffff;
              padding: 14px 16px;
              border-radius: 8px;
              z-index: 10000;
              font-size: 16px;
              font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
              font-weight: 400;
              line-height: 1.4;
              box-shadow: 0 4px 8px rgba(0, 0, 0, 0.3), 0 2px 4px rgba(0, 0, 0, 0.2);
              animation: slideUpAndFadeIn 0.3s cubic-bezier(0.4, 0.0, 0.2, 1);
              transform: translateY(0);
              opacity: 1;
              max-width: 600px;
              margin: 0 auto;
              word-wrap: break-word;
              text-align: left;
            \`;
            
            // Add enhanced CSS animations if not already present
            if (!document.getElementById('flutter-toast-styles')) {
              var styles = document.createElement('style');
              styles.id = 'flutter-toast-styles';
              styles.innerHTML = \`
                @keyframes slideUpAndFadeIn {
                  from { 
                    opacity: 0; 
                    transform: translateY(100%); 
                  }
                  to { 
                    opacity: 1; 
                    transform: translateY(0); 
                  }
                }
                @keyframes slideDownAndFadeOut {
                  from { 
                    opacity: 1; 
                    transform: translateY(0); 
                  }
                  to { 
                    opacity: 0; 
                    transform: translateY(100%); 
                  }
                }
                
                #flutter-toast {
                  /* Force white text even with external CSS */
                  color: #ffffff !important;
                  background: #323232 !important;
                }
                
                #flutter-toast * {
                  color: #ffffff !important;
                }
              \`;
              document.head.appendChild(styles);
            }
            
            // Add to page
            document.body.appendChild(toastDiv);
            
            // Auto-remove after 4 seconds with slide-out animation
            setTimeout(function() {
              if (toastDiv && toastDiv.parentNode) {
                toastDiv.style.animation = 'slideDownAndFadeOut 0.3s cubic-bezier(0.4, 0.0, 0.2, 1)';
                setTimeout(function() {
                  if (toastDiv && toastDiv.parentNode) {
                    toastDiv.parentNode.removeChild(toastDiv);
                  }
                }, 300);
              }
            }, 4000);
            
            console.log('✅ Flutter SnackBar-style black toast displayed: $message');
          }
          
          // Dispatch toast event for any listeners
          var toastEvent = new CustomEvent('toastShown', { 
            detail: { message: '$message', style: 'flutter-snackbar' }
          });
          document.dispatchEvent(toastEvent);
          
        } catch (error) {
          console.error('❌ Error handling toast in WebView:', error);
        }
      ''');

        debugPrint(
          '✅ Enhanced black toast processed via web scripts: $message',
        );
      } else {
        debugPrint('❌ Empty toast message');
      }
    } catch (e) {
      debugPrint('❌ Error handling toast request: $e');
    }
  }

  void _handleContinuousBarcodeScanning(String url) {
    debugPrint("Continuous barcode scanning triggered: $url");

    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder:
            (context) => BarcodeScannerPage(
              isContinuous: true, // Always continuous for this URL
              onBarcodeScanned: (String barcode) {
                _handleContinuousBarcodeResult(barcode);
              },
            ),
      ),
    );
  }

  // 6. Add new method for continuous barcode results
  void _handleContinuousBarcodeResult(String barcode) {
    debugPrint("Continuous barcode scanned: $barcode");

    final controller = _controllerManager.getController(
      _selectedIndex,
      '',
      context,
    );

    controller.runJavaScript('''
      if (typeof getBarcodeContinuous === 'function') {
        getBarcodeContinuous("$barcode");
        console.log("Called getBarcodeContinuous() with: $barcode");
      } else if (typeof window.handleContinuousBarcodeResult === 'function') {
        window.handleContinuousBarcodeResult("$barcode");
        console.log("Called handleContinuousBarcodeResult with: $barcode");
      } else {
        // Fallback to regular barcode handling
        if (typeof getBarcode === 'function') {
          getBarcode("$barcode");
          console.log("Called getBarcode() (fallback) with: $barcode");
        } else {
          var event = new CustomEvent('continuousBarcodeScanned', { 
            detail: { result: "$barcode" } 
          });
          document.dispatchEvent(event);
          console.log("Dispatched continuousBarcodeScanned event");
        }
      }
    ''');
  }

  void _handleExternalNavigation(String url) {
    debugPrint('🌐 External navigation detected in MainScreen: $url');

    try {
      // Remove the ?external=1 parameter to get the clean URL
      String cleanUrl = url.replaceAll('?external=1', '');

      // Also handle case where there are other parameters after external=1
      cleanUrl = cleanUrl.replaceAll('&external=1', '');
      cleanUrl = cleanUrl.replaceAll('external=1&', '');
      cleanUrl = cleanUrl.replaceAll('external=1', '');

      // Clean up any leftover ? or & at the end
      if (cleanUrl.endsWith('?') || cleanUrl.endsWith('&')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }

      debugPrint('🔗 Clean URL for external browser: $cleanUrl');

      // Validate URL
      if (cleanUrl.isEmpty ||
          (!cleanUrl.startsWith('http://') &&
              !cleanUrl.startsWith('https://'))) {
        debugPrint('❌ Invalid URL for external navigation: $cleanUrl');
        _showUrlError('Invalid URL format');
        return;
      }

      // Launch in default browser
      _launchInDefaultBrowser(cleanUrl);
    } catch (e) {
      debugPrint('❌ Error handling external navigation: $e');
      _showUrlError('Failed to open external URL');
    }
  }

  Future<void> _launchInDefaultBrowser(String url) async {
    try {
      debugPrint('🌐 Opening URL in default browser: $url');

      final Uri uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        final bool launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );

        if (launched) {
          debugPrint('✅ Successfully opened URL in default browser');

          // Use web scripts instead of native SnackBar
          if (mounted) {
            final controller = _controllerManager.getController(
              _selectedIndex,
              '',
              context,
            );
            controller.runJavaScript('''
              if (window.ToastManager) {
                window.ToastManager.postMessage('toast://' + encodeURIComponent('Opening in browser...'));
              } else {
                window.location.href = 'toast://' + encodeURIComponent('Opening in browser...');
              }
            ''');
          }
        } else {
          debugPrint('❌ Failed to launch URL in browser');
          _showUrlError('Could not open URL in browser');
        }
      } else {
        debugPrint('❌ Cannot launch URL: $url');
        _showUrlError('Cannot open this type of URL');
      }
    } catch (e) {
      debugPrint('❌ Error launching URL in browser: $e');
      _showUrlError('Failed to open browser: ${e.toString()}');
    }
  }

  // NEW: Add this helper method to show URL errors
  void _showUrlError(String message) {
    if (mounted) {
      final controller = _controllerManager.getController(
        _selectedIndex,
        '',
        context,
      );
      controller.runJavaScript('''
        const errorMessage = '$message';
        if (window.AlertManager) {
          window.AlertManager.postMessage('alert://' + encodeURIComponent(errorMessage));
        } else {
          window.location.href = 'alert://' + encodeURIComponent(errorMessage);
        }
      ''');
    }
  }

  void _handleAlertRequest(String url) async {
    debugPrint('🚨 Alert request received in main screen: $url');

    try {
      Map<String, dynamic> result;
      String alertType = AlertService().getAlertType(url);

      switch (alertType) {
        case 'alert':
          result = await AlertService().showAlertFromUrl(url, context);
          break;
        case 'confirm':
          result = await AlertService().showConfirmFromUrl(url, context);
          break;
        case 'prompt':
          result = await AlertService().showPromptFromUrl(url, context);
          break;
        default:
          result = await AlertService().showAlertFromUrl(url, context);
          break;
      }

      // Send result back to WebView
      _sendAlertResultToCurrentWebView(result, alertType);
    } catch (e) {
      debugPrint('❌ Error handling alert in main screen: $e');

      _sendAlertResultToCurrentWebView({
        'success': false,
        'error': 'Failed to handle alert: ${e.toString()}',
        'errorCode': 'UNKNOWN_ERROR',
      }, 'alert');
    }
  }

  // Add this method to send alert results to the current WebView:
  void _sendAlertResultToCurrentWebView(
    Map<String, dynamic> result,
    String alertType,
  ) {
    final controller = _controllerManager.getController(
      _selectedIndex,
      '',
      context,
    );

    final success = result['success'] ?? false;
    final error = (result['error'] ?? '').replaceAll('"', '\\"');
    final errorCode = result['errorCode'] ?? '';
    final message = (result['message'] ?? '').replaceAll('"', '\\"');
    final userResponse = (result['userResponse'] ?? '').replaceAll('"', '\\"');
    final userInput = (result['userInput'] ?? '').replaceAll('"', '\\"');
    final confirmed = result['confirmed'] ?? false;
    final cancelled = result['cancelled'] ?? false;
    final dismissed = result['dismissed'] ?? false;

    controller.runJavaScript('''
      try {
        console.log("🚨 Alert result from main screen: Type=$alertType, Success=$success");
        
        var alertResult = {
          success: $success,
          type: "$alertType",
          message: "$message",
          userResponse: "$userResponse",
          userInput: "$userInput",
          confirmed: $confirmed,
          cancelled: $cancelled,
          dismissed: $dismissed,
          error: "$error",
          errorCode: "$errorCode"
        };
        
        // Try specific callback functions
        if ("$alertType" === "alert" && typeof getAlertCallback === 'function') {
          getAlertCallback($success, "$message", "$userResponse", "$error");
        } else if ("$alertType" === "confirm" && typeof getConfirmCallback === 'function') {
          getConfirmCallback($success, "$message", $confirmed, $cancelled, "$error");
        } else if ("$alertType" === "prompt" && typeof getPromptCallback === 'function') {
          getPromptCallback($success, "$message", "$userInput", $confirmed, "$error");
        } else if (typeof handleAlertResult === 'function') {
          handleAlertResult(alertResult);
        } else {
          var event = new CustomEvent('alertResult', { detail: alertResult });
          document.dispatchEvent(event);
        }
        
      } catch (error) {
        console.error("❌ Error handling alert result:", error);
      }
    ''');
  }

  void _handlePdfSaveRequest(String url) {
    debugPrint('📄 PDF save requested from WebView: $url');

    final controller = _controllerManager.getController(
      _selectedIndex,
      '',
      context,
    );

    controller.runJavaScript('''
      if (window.PdfSaver && window.PdfSaver.postMessage) {
        window.PdfSaver.postMessage("$url");
        console.log("✅ PDF save request sent");
      } else {
        console.log("❌ PdfSaver not found");
      }
    ''');
  }

  void _handleImageSaveRequest(String url) {
    debugPrint('🖼️ Image save requested from WebView: $url');

    final controller = _controllerManager.getController(
      _selectedIndex,
      '',
      context,
    );

    controller.runJavaScript('''
      if (window.ImageSaver && window.ImageSaver.postMessage) {
        window.ImageSaver.postMessage("$url");
        console.log("✅ Image save request sent");
      } else {
        console.log("❌ ImageSaver not found");
      }
    ''');
  }

  void _handleScreenshotRequest() {
    debugPrint('📸 Screenshot requested from WebView');

    final controller = _controllerManager.getController(
      _selectedIndex,
      '',
      context,
    );

    controller.runJavaScript('''
      if (window.ScreenshotManager && window.ScreenshotManager.postMessage) {
        window.ScreenshotManager.postMessage('takeScreenshot');
        console.log("✅ Screenshot request sent");
      } else {
        console.log("❌ ScreenshotManager not found");
      }
    ''');
  }

  void _handleContactsRequest() {
    debugPrint('📞 Contacts requested from WebView');

    final controller = _controllerManager.getController(
      _selectedIndex,
      '',
      context,
    );

    controller.runJavaScript('''
      if (window.ContactsManager && window.ContactsManager.postMessage) {
        window.ContactsManager.postMessage('getAllContacts');
        console.log("✅ Contacts request sent");
      } else {
        console.log("❌ ContactsManager not found");
      }
    ''');
  }

  void _handleLocationRequest() async {
    if (_currentContext == null || _currentController == null) {
      debugPrint('❌ No context or controller available for location request');
      return;
    }

    debugPrint('🌍 Processing location request silently...');

    try {
      // NO LOADING DIALOG - just process silently
      Map<String, dynamic> locationResult =
          await LocationService().getCurrentLocation();
      _sendLocationToWebView(locationResult);
    } catch (e) {
      debugPrint('❌ Error handling location request: $e');
      _sendLocationToWebView({
        'success': false,
        'error': 'Failed to get location: ${e.toString()}',
        'errorCode': 'UNKNOWN_ERROR',
      });
    }
  }

  void _sendLocationToWebView(Map<String, dynamic> locationData) {
    final controller = _controllerManager.getController(
      _selectedIndex,
      '',
      context,
    );

    if (controller == null) {
      debugPrint('❌ No WebView controller available for location result');
      return;
    }

    debugPrint('📱 Sending location data to WebView');

    final success = locationData['success'] ?? false;
    final latitude = locationData['latitude'];
    final longitude = locationData['longitude'];
    final error = (locationData['error'] ?? '').replaceAll('"', '\\"');
    final errorCode = locationData['errorCode'] ?? '';

    controller.runJavaScript('''
    try {
      console.log("📍 Location received: Success=$success");
      
      var locationResult = {
        success: $success,
        latitude: ${latitude ?? 'null'},
        longitude: ${longitude ?? 'null'},
        error: "$error",
        errorCode: "$errorCode"
      };
      
      // Try callback functions
      if (typeof getLocationCallback === 'function') {
        console.log("✅ Calling getLocationCallback()");
        getLocationCallback($success, ${latitude ?? 'null'}, ${longitude ?? 'null'}, "$error", "$errorCode");
      } else if (typeof window.handleLocationResult === 'function') {
        console.log("✅ Calling window.handleLocationResult()");
        window.handleLocationResult(locationResult);
      } else if (typeof handleLocationResult === 'function') {
        console.log("✅ Calling handleLocationResult()");
        handleLocationResult(locationResult);
      } else {
        console.log("✅ Using fallback - triggering event");
        
        var event = new CustomEvent('locationReceived', { detail: locationResult });
        document.dispatchEvent(event);
      }
      
      // Use web scripts instead of native alerts
      if ($success) {
        const lat = ${latitude ?? 'null'};
        const lng = ${longitude ?? 'null'};
        const message = 'Location: ' + lat + ', ' + lng;
        
        if (window.ToastManager) {
          window.ToastManager.postMessage('toast://' + encodeURIComponent(message));
        } else {
          window.location.href = 'toast://' + encodeURIComponent(message);
        }
      } else {
        const errorMessage = 'Location Error: $error';
        if (window.AlertManager) {
          window.AlertManager.postMessage('alert://' + encodeURIComponent(errorMessage));
        } else {
          window.location.href = 'alert://' + encodeURIComponent(errorMessage);
        }
      }
      
    } catch (error) {
      console.error("❌ Error handling location result:", error);
    }
  ''');
  }

  void _handleNewWebNavigation(String url) {
    String targetUrl = 'https://mobile.erpforever.com/';

    if (url.contains('?')) {
      try {
        Uri uri = Uri.parse(url.replaceFirst('new-web://', 'https://'));
        if (uri.queryParameters.containsKey('url')) {
          targetUrl = uri.queryParameters['url']!;
        }
      } catch (e) {
        debugPrint("Error parsing URL parameters: $e");
      }
    }

    WebViewService().navigate(
      context,
      url: targetUrl,
      linkType: 'regular_webview',
      title: 'Web View',
    );
  }

  void _handleSheetNavigation(String url) {
    String targetUrl = 'https://mujeer.com';

    if (url.contains('?')) {
      try {
        Uri uri = Uri.parse(url.replaceFirst('new-sheet://', 'https://'));
        if (uri.queryParameters.containsKey('url')) {
          targetUrl = uri.queryParameters['url']!;
        }
      } catch (e) {
        debugPrint("Error parsing URL parameters: $e");
      }
    }

    WebViewService().navigate(
      context,
      url: targetUrl,
      linkType: 'sheet_webview',
      title: 'Web View',
    );
  }

  void _handleBarcodeScanning(String url) {
    debugPrint("Barcode scanning triggered: $url");

    bool isContinuous =
        url.contains('continuous') || url.contains('Continuous');

    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder:
            (context) => BarcodeScannerPage(
              isContinuous: isContinuous,
              onBarcodeScanned: (String barcode) {
                _handleBarcodeResult(barcode);
              },
            ),
      ),
    );
  }

  void _handleBarcodeResult(String barcode) {
    debugPrint("Barcode scanned: $barcode");

    final controller = _controllerManager.getController(
      _selectedIndex,
      '',
      context,
    );

    controller.runJavaScript('''
      if (typeof getBarcode === 'function') {
        getBarcode("$barcode");
        console.log("Called getBarcode() with: $barcode");
      } else if (typeof window.handleBarcodeResult === 'function') {
        window.handleBarcodeResult("$barcode");
        console.log("Called handleBarcodeResult with: $barcode");
      } else {
        var inputs = document.querySelectorAll('input[type="text"]');
        if(inputs.length > 0) {
          inputs[0].value = "$barcode";
          inputs[0].dispatchEvent(new Event('input'));
          console.log("Filled input field with: $barcode");
        }
        
        var event = new CustomEvent('barcodeScanned', { detail: { result: "$barcode" } });
        document.dispatchEvent(event);
      }
    ''');
  }

  void _onItemTapped(int index) {
    final config = _configService.config;
    if (config == null) return;

    final item = config.mainIcons[index];

    if (item.linkType == 'sheet_webview') {
      WebViewService().navigate(
        context,
        url: item.link,
        linkType: item.linkType,
        title: item.title,
      );
    } else {
      debugPrint('🔄 Switching to tab $index: ${item.title}');

      setState(() {
        _selectedIndex = index;
      });

      // 🆕 UPDATED: Check if this tab needs refresh when accessed (only if we had a long background)
      Future.delayed(Duration(milliseconds: 100), () async {
        // Only check content if we had a long background session
        if (_backgroundTime != null) {
          final backgroundDuration = DateTime.now().difference(
            _backgroundTime!,
          );
          if (backgroundDuration >= _backgroundThreshold) {
            final hasContent = await _checkWebViewHasContent(index);
            if (!hasContent) {
              debugPrint(
                '🔄 Tab $index is empty after long background - refreshing',
              );
              await _refreshTabAtIndex(index);
            }
          }
        }
      });
    }
  }

  Future<void> _refreshTabAtIndex(int index) async {
    try {
      setState(() {
        _loadingStates[index] = true;
      });

      final controller = _controllerManager.getController(index, '', context);
      await controller.reload();

      debugPrint('✅ Tab $index refresh initiated');
    } catch (e) {
      debugPrint('❌ Error refreshing tab $index: $e');
      if (mounted) {
        setState(() {
          _loadingStates[index] = false;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // Clear WebViewService controller reference
    WebViewService().clearCurrentController();

    // Clean up when disposing
    _controllerManager.clearControllers();

    super.dispose();
  }
}
