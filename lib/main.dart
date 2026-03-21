// import 'package:firebase_core/firebase_core.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:seed/screens/welcome_screen.dart';
import 'package:seed/theme/app_theme.dart';
import 'package:seed/services/user_service.dart';
import 'package:seed/services/voice_assistant_service.dart';
import 'package:seed/screens/voice_assistant_overlay.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // await Firebase.initializeApp(); // Only enable this if you have configured Firebase with the CLI

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  // Fetch and store the owner into RAM before the app starts
  await UserService().initUser();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<VoiceAssistantState>? _voiceStateSub;
  OverlayEntry? _voiceOverlayEntry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startVoiceAssistant());
  }

  void _startVoiceAssistant() {
    VoiceAssistantService().startWakeWordListener();

    _voiceStateSub = VoiceAssistantService().stateStream.listen((state) {
      if (state == VoiceAssistantState.orderListening ||
          state == VoiceAssistantState.processing ||
          state == VoiceAssistantState.showingResult) {
        _showVoiceOverlay();
      }
    });
  }

  void _showVoiceOverlay() {
    if (_voiceOverlayEntry != null) return;
    _voiceOverlayEntry = OverlayEntry(
      builder: (_) => VoiceAssistantOverlay(onDismiss: _hideVoiceOverlay),
    );
    navigatorKey.currentState?.overlay?.insert(_voiceOverlayEntry!);
  }

  void _hideVoiceOverlay() {
    _voiceOverlayEntry?.remove();
    _voiceOverlayEntry = null;
  }

  @override
  void dispose() {
    _voiceStateSub?.cancel();
    _voiceOverlayEntry?.remove();
    VoiceAssistantService().stopAll(); // async, fire-and-forget on dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SEED',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      home: const WelcomeScreen(),
    );
  }
}

// ── Shared header used across screens ────────────────────────────────────────
// Left: avatar + subtitle + title (same structure as the home page header)
// Right: caller-supplied [trailing] widget (e.g. notification bell, streak badge)
class AppHeader extends StatelessWidget {
  final String subtitle; // e.g. "Welcome back! 👋" or "Let's Learn,"
  final String title; // e.g. owner name or "Edmund!"
  final Widget trailing;

  const AppHeader({
    super.key,
    required this.subtitle,
    required this.title,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(
              image: AssetImage('assets/images/Default_PFP.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: AppTheme.extraSmallTextSize,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: AppTheme.smallTextSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
        trailing,
      ],
    );
  }
}

class AppLayout extends StatelessWidget {
  final Widget body;
  final int currentIndex;
  final VoidCallback? onFabPressed;
  final void Function(int)? onNavPressed;
  final bool extendBody;
  final Color? backgroundColor;

  const AppLayout({
    super.key,
    required this.body,
    required this.currentIndex,
    this.onFabPressed,
    this.onNavPressed,
    this.extendBody = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: extendBody,
      backgroundColor: backgroundColor,
      body: body,
      floatingActionButton: FloatingActionButton(
        onPressed: onFabPressed ?? () {},
        backgroundColor: Colors.black,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        height: 45,
        shape: const CircularNotchedRectangle(),
        notchMargin: 3.0,
        color: Colors.white,
        child: SizedBox(
          height: 30,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: const Icon(Icons.home, size: 28),
                onPressed: () => onNavPressed?.call(0),
                color: currentIndex == 0 ? Colors.black : Colors.grey,
              ),
              IconButton(
                icon: const Icon(Icons.bar_chart, size: 28),
                onPressed: () => onNavPressed?.call(1),
                color: currentIndex == 1 ? Colors.black : Colors.grey,
              ),
              const SizedBox(width: 48), // Space for FAB
              IconButton(
                icon: const Icon(Icons.book, size: 28),
                onPressed: () => onNavPressed?.call(2),
                color: currentIndex == 2 ? Colors.black : Colors.grey,
              ),
              IconButton(
                icon: const Icon(Icons.account_balance, size: 24),
                onPressed: () => onNavPressed?.call(3),
                color: currentIndex == 3 ? Colors.black : Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
