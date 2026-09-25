import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/session_models.dart';
import '../providers/remote_provider.dart';

class SessionToolbar extends StatefulWidget {
  final RemoteProvider provider;
  final VoidCallback onToggleKeyboard;
  final VoidCallback onDisconnect;
  final bool isKeyboardVisible;

  const SessionToolbar({
    super.key,
    required this.provider,
    required this.onToggleKeyboard,
    required this.onDisconnect,
    required this.isKeyboardVisible,
  });

  @override
  State<SessionToolbar> createState() => _SessionToolbarState();
}

class _SessionToolbarState extends State<SessionToolbar> {
  bool _isExpanded = false;
  double _x = 20;
  double _y = 40;

  @override
  Widget build(BuildContext context) {
    final ping = widget.provider.relayService.currentPingMs;
    final fps = widget.provider.relayService.fps;

    return Positioned(
      left: _x,
      top: _y,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _x += details.delta.dx;
            _y += details.delta.dy;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: const Color(0xFF101928).withOpacity(0.92),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle / Toggle Button
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isExpanded = !_isExpanded);
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ping < 80 ? const Color(0xFF00E676) : Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${ping}ms | ${fps}fps',
                        style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isExpanded ? Icons.chevron_left : Icons.chevron_right,
                        color: Colors.white70,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),

              if (_isExpanded) ...[
                const SizedBox(width: 4),
                _buildDivider(),

                // Keyboard Toggle
                _buildIconButton(
                  icon: widget.isKeyboardVisible ? Icons.keyboard_hide : Icons.keyboard,
                  tooltip: 'Virtual Keyboard',
                  isActive: widget.isKeyboardVisible,
                  onTap: widget.onToggleKeyboard,
                ),

                // Touch / Trackpad Mode Toggle
                _buildIconButton(
                  icon: widget.provider.controlMode == ControlMode.directTouch
                      ? Icons.touch_app
                      : Icons.mouse,
                  tooltip: widget.provider.controlMode == ControlMode.directTouch
                      ? 'Mode: Direct Touch'
                      : 'Mode: Trackpad',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    final next = widget.provider.controlMode == ControlMode.directTouch
                        ? ControlMode.trackpad
                        : ControlMode.directTouch;
                    widget.provider.setControlMode(next);
                  },
                ),

                // Windows Shortcuts Menu
                _buildShortcutsMenu(context),

                // Stream Quality Selector
                _buildQualityMenu(context),

                // Clipboard Sync
                _buildIconButton(
                  icon: Icons.content_paste,
                  tooltip: 'Sync Clipboard',
                  onTap: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null && data!.text!.isNotEmpty) {
                      widget.provider.relayService.sendClipboard(data.text!);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Clipboard sent to remote PC'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      }
                    }
                  },
                ),

                _buildDivider(),

                // Disconnect Button
                _buildIconButton(
                  icon: Icons.power_settings_new,
                  tooltip: 'Disconnect',
                  color: Colors.redAccent,
                  onTap: widget.onDisconnect,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 20,
      color: Colors.white24,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? color,
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF00E5FF).withOpacity(0.2) : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 18,
            color: color ?? (isActive ? const Color(0xFF00E5FF) : Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildShortcutsMenu(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Windows Shortcuts',
      icon: const Icon(Icons.apps, size: 18, color: Colors.white),
      color: const Color(0xFF132238),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (val) {
        widget.provider.relayService.sendShortcut(val);
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'win',
          child: Row(
            children: [
              Icon(Icons.window, color: Color(0xFF00E5FF), size: 18),
              SizedBox(width: 10),
              Text('Windows Start Menu', style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'win_d',
          child: Row(
            children: [
              Icon(Icons.desktop_windows, color: Color(0xFF00E5FF), size: 18),
              SizedBox(width: 10),
              Text('Show Desktop (Win+D)', style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'alt_tab',
          child: Row(
            children: [
              Icon(Icons.tab, color: Color(0xFF00E5FF), size: 18),
              SizedBox(width: 10),
              Text('Switch Window (Alt+Tab)', style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'ctrl_c',
          child: Row(
            children: [
              Icon(Icons.copy, color: Color(0xFF00E5FF), size: 18),
              SizedBox(width: 10),
              Text('Copy (Ctrl+C)', style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'ctrl_v',
          child: Row(
            children: [
              Icon(Icons.paste, color: Color(0xFF00E5FF), size: 18),
              SizedBox(width: 10),
              Text('Paste (Ctrl+V)', style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'esc',
          child: Row(
            children: [
              Icon(Icons.cancel_outlined, color: Color(0xFF00E5FF), size: 18),
              SizedBox(width: 10),
              Text('Escape (Esc)', style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQualityMenu(BuildContext context) {
    return PopupMenuButton<StreamQuality>(
      tooltip: 'Stream Quality',
      icon: const Icon(Icons.hd_outlined, size: 18, color: Colors.white),
      color: const Color(0xFF132238),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (q) {
        widget.provider.setQuality(q);
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: StreamQuality.high,
          child: Row(
            children: [
              Icon(
                widget.provider.quality == StreamQuality.high ? Icons.check_circle : Icons.circle_outlined,
                color: const Color(0xFF00E5FF),
                size: 16,
              ),
              const SizedBox(width: 10),
              const Text('High Quality (1080p, 45 FPS)', style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: StreamQuality.balanced,
          child: Row(
            children: [
              Icon(
                widget.provider.quality == StreamQuality.balanced ? Icons.check_circle : Icons.circle_outlined,
                color: const Color(0xFF00E5FF),
                size: 16,
              ),
              const SizedBox(width: 10),
              const Text('Balanced (720p, 30 FPS)', style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: StreamQuality.low,
          child: Row(
            children: [
              Icon(
                widget.provider.quality == StreamQuality.low ? Icons.check_circle : Icons.circle_outlined,
                color: const Color(0xFF00E5FF),
                size: 16,
              ),
              const SizedBox(width: 10),
              const Text('Low Bandwidth (540p, 20 FPS)', style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}
