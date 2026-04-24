import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'dart:ui';

class IntelligenceCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final Widget content;
  final Color accentColor;

  const IntelligenceCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.content,
    required this.accentColor,
  });

  @override
  State<IntelligenceCard> createState() => _IntelligenceCardState();
}

class _IntelligenceCardState extends State<IntelligenceCard> {
  double _tiltX = 0;
  double _tiltY = 0;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      if (mounted) {
        setState(() {
          // Subtle tilt mapping
          _tiltX = (event.x / 10).clamp(-1.0, 1.0);
          _tiltY = (event.y / 10).clamp(-1.0, 1.0);
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Transform(
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001) // Perspective
        ..rotateX(_tiltY * 0.1)
        ..rotateY(-_tiltX * 0.1),
      alignment: Alignment.center,
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 20, bottom: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withOpacity(isDark ? 0.8 : 1.0),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: widget.accentColor.withOpacity(isDark ? 0.2 : 0.1),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.accentColor.withOpacity(isDark ? 0.1 : 0.05),
              blurRadius: 15,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              color: widget.accentColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      Icon(Icons.insights_rounded, color: widget.accentColor.withOpacity(0.5), size: 20),
                    ],
                  ),
                  const Spacer(),
                  widget.content,
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
