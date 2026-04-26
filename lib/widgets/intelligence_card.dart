import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 280,
        margin: const EdgeInsets.only(right: 20, bottom: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              widget.accentColor.withOpacity(0.9),
              widget.accentColor.withOpacity(1.0),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: widget.accentColor.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        widget.subtitle,
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  Icon(Icons.insights_rounded, color: Colors.white.withOpacity(0.7), size: 20),
                ],
              ),
              const SizedBox(height: 20),
              widget.content,
            ],
          ),
        ),
      ),
    );
  }
}
