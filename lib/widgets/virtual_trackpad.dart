import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/relay_service.dart';

class VirtualTrackpadOverlay extends StatefulWidget {
  final RelayService relayService;
  final double sensitivity;

  const VirtualTrackpadOverlay({
    super.key,
    required this.relayService,
    this.sensitivity = 1.0,
  });

  @override
  State<VirtualTrackpadOverlay> createState() => _VirtualTrackpadOverlayState();
}

class _VirtualTrackpadOverlayState extends State<VirtualTrackpadOverlay> {
  double _cursorNormX = 0.5;
  double _cursorNormY = 0.5;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      right: 20,
      child: Container(
        width: 220,
        height: 180,
        decoration: BoxDecoration(
          color: const Color(0xFF101928).withOpacity(0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Trackpad touch surface
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) {
                  final dx = (details.delta.dx * widget.sensitivity) / 600.0;
                  final dy = (details.delta.dy * widget.sensitivity) / 600.0;
                  _cursorNormX = (_cursorNormX + dx).clamp(0.0, 1.0);
                  _cursorNormY = (_cursorNormY + dy).clamp(0.0, 1.0);
                  widget.relayService.sendMouseMove(_cursorNormX, _cursorNormY);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.touch_app, color: Color(0xFF6C8DAE), size: 24),
                        SizedBox(height: 4),
                        Text(
                          'Trackpad Surface',
                          style: TextStyle(color: Color(0xFF6C8DAE), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Left & Right Click buttons + Scroll
            Container(
              height: 48,
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFF243B5A), width: 1),
                ),
              ),
              child: Row(
                children: [
                  // Left Click
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        widget.relayService.sendMouseClick('left');
                      },
                      onLongPress: () {
                        HapticFeedback.mediumImpact();
                        widget.relayService.sendMouseClick('left', doubleClick: true);
                      },
                      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16)),
                      child: Container(
                        alignment: Alignment.center,
                        child: const Text(
                          'LEFT',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                  Container(width: 1, color: const Color(0xFF243B5A)),
                  // Scroll strip
                  GestureDetector(
                    onVerticalDragUpdate: (details) {
                      widget.relayService.sendMouseScroll(-details.delta.dy * 15);
                    },
                    child: Container(
                      width: 40,
                      color: const Color(0xFF16253B),
                      child: const Center(
                        child: Icon(Icons.swap_vert, color: Color(0xFF00E5FF), size: 18),
                      ),
                    ),
                  ),
                  Container(width: 1, color: const Color(0xFF243B5A)),
                  // Right Click
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        widget.relayService.sendMouseClick('right');
                      },
                      borderRadius: const BorderRadius.only(bottomRight: Radius.circular(16)),
                      child: Container(
                        alignment: Alignment.center,
                        child: const Text(
                          'RIGHT',
                          style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
