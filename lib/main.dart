import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:live_activities/live_activities.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeNotifications();
  runApp(const PrismApp());
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _initializeNotifications() async {
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  
  const DarwinInitializationSettings iosSettings =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  
  const InitializationSettings settings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );
  
  await flutterLocalNotificationsPlugin.initialize(settings);
}

Future<void> _showTimerCompleteNotification() async {
  const AndroidNotificationDetails androidDetails =
      AndroidNotificationDetails(
    'timer_channel',
    'Timer Notifications',
    channelDescription: 'Notifications when focus timer completes',
    importance: Importance.high,
    priority: Priority.high,
  );
  
  const DarwinNotificationDetails iosDetails =
      DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );
  
  const NotificationDetails details = NotificationDetails(
    android: androidDetails,
    iOS: iosDetails,
  );
  
  await flutterLocalNotificationsPlugin.show(
    0,
    'Prism',
    'Time\'s up — take a break',
    details,
  );
}

class PrismApp extends StatelessWidget {
  const PrismApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Prism',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: const FocusTimerPage(),
    );
  }
}

class FocusTimerPage extends StatefulWidget {
  const FocusTimerPage({super.key});
  @override
  State<FocusTimerPage> createState() => _FocusTimerPageState();
}

class _FocusTimerPageState extends State<FocusTimerPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _bgController;
  late Animation<double> _bgAnimation;

  static const int totalSeconds = 25 * 60;
  int remainingSeconds = totalSeconds;
  Timer? _timer;
  bool isRunning = false;
  
  final LiveActivities _liveActivities = LiveActivities();
  String? _activityId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bgController = AnimationController(
      duration: const Duration(seconds: 12),
      vsync: this,
    )..repeat();
    _bgAnimation = Tween<double>(begin: 0, end: 1).animate(_bgController);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _bgController.dispose();
    _endLiveActivity();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && isRunning) {
      _updateLiveActivity();
    } else if (state == AppLifecycleState.resumed) {
      _endLiveActivity();
    }
  }

  Future<void> _startLiveActivity() async {
    try {
      final activity = await _liveActivities.createActivity(
        data: {
          'title': 'Prism',
          'remainingSeconds': remainingSeconds,
          'totalSeconds': totalSeconds,
          'progress': progress,
          'formattedTime': formatTime(remainingSeconds),
        },
      );
      _activityId = activity?.id;
    } catch (e) {
      // Live Activities may fail silently on simulator
    }
  }

  Future<void> _updateLiveActivity() async {
    if (_activityId == null) {
      await _startLiveActivity();
      return;
    }
    
    try {
      await _liveActivities.updateActivity(
        activityId: _activityId!,
        data: {
          'title': 'Prism',
          'remainingSeconds': remainingSeconds,
          'totalSeconds': totalSeconds,
          'progress': progress,
          'formattedTime': formatTime(remainingSeconds),
        },
      );
    } catch (e) {
      // Activity may have expired
      _activityId = null;
    }
  }

  Future<void> _endLiveActivity() async {
    if (_activityId != null) {
      try {
        await _liveActivities.endActivity(activityId: _activityId!);
      } catch (e) {
        // Ignore errors
      }
      _activityId = null;
    }
  }

  void toggleTimer() {
    if (isRunning) {
      _timer?.cancel();
      _endLiveActivity();
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (remainingSeconds > 0) {
          setState(() => remainingSeconds--);
          if (remainingSeconds % 5 == 0) {
            _updateLiveActivity();
          }
        } else {
          _timer?.cancel();
          setState(() => isRunning = false);
          _endLiveActivity();
          _showTimerCompleteNotification();
        }
      });
      _startLiveActivity();
    }
    setState(() => isRunning = !isRunning);
  }

  void resetTimer() {
    _timer?.cancel();
    _endLiveActivity();
    setState(() {
      remainingSeconds = totalSeconds;
      isRunning = false;
    });
  }

  String formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  double get progress => 1 - (remainingSeconds / totalSeconds);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(
                      const Color(0xFF0F2027), const Color(0xFF2C5364), _bgAnimation.value)!,
                  Color.lerp(
                      const Color(0xFF203A43), const Color(0xFF1CB5E0), _bgAnimation.value)!,
                  Color.lerp(
                      const Color(0xFF2C5364), const Color(0xFF000046), _bgAnimation.value)!,
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 100,
                  left: 20,
                  child: _glassOrb(90, _bgAnimation.value),
                ),
                Positioned(
                  bottom: 150,
                  right: 10,
                  child: _glassOrb(70, 1 - _bgAnimation.value),
                ),
                Positioned(
                  top: 400,
                  right: 50,
                  child: _glassOrb(50, _bgAnimation.value * 0.7),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Prism',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w100,
                            color: Colors.white70,
                            letterSpacing: 6,
                          ),
                        ),
                        const Spacer(),
                        Center(
                          child: _buildTimerCard(),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _glassOrb(double size, double opacity) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.05 + (opacity * 0.1)),
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimerCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(50),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: 320,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 30),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
              width: 1.5,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.15),
                Colors.white.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PrismLogo(size: 80),
              const SizedBox(height: 25),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 6,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                  Text(
                    formatTime(remainingSeconds),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w200,
                      color: Colors.white,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _controlButton(
                    icon: isRunning ? Icons.pause : Icons.play_arrow,
                    onTap: toggleTimer,
                  ),
                  const SizedBox(width: 20),
                  _controlButton(
                    icon: Icons.refresh,
                    onTap: resetTimer,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controlButton({required IconData icon, required VoidCallback onTap}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(30),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                ),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}

class PrismLogo extends StatelessWidget {
  final double size;
  const PrismLogo({super.key, this.size = 60});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.2),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.cyan.withOpacity(0.4),
                Colors.purple.withOpacity(0.3),
                Colors.blue.withOpacity(0.4),
              ],
            ),
            borderRadius: BorderRadius.circular(size * 0.2),
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: CustomPaint(
            painter: PrismPainter(),
          ),
        ),
      ),
    );
  }
}

class PrismPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.white.withOpacity(0.8);

    final path = Path();
    path.moveTo(size.width * 0.5, size.height * 0.25);
    path.lineTo(size.width * 0.8, size.height * 0.7);
    path.lineTo(size.width * 0.2, size.height * 0.7);
    path.close();

    canvas.drawPath(path, paint);

    final beamPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withOpacity(0.2);

    canvas.drawRect(
      Rect.fromLTWH(
          size.width * 0.45, size.height * 0.7, size.width * 0.1, size.height * 0.2),
      beamPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
