import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/session_models.dart';
import '../providers/remote_provider.dart';
import '../widgets/session_toolbar.dart';
import '../widgets/virtual_keyboard_bar.dart';
import '../widgets/virtual_trackpad.dart';

class RemoteViewerScreen extends StatefulWidget {
  const RemoteViewerScreen({super.key});

  @override
  State<RemoteViewerScreen> createState() => _RemoteViewerScreenState();
}

class _RemoteViewerScreenState extends State<RemoteViewerScreen> {
  final TransformationController _transformController = TransformationController();
  final GlobalKey _imageKey = GlobalKey();

  bool _isKeyboardVisible = false;
  Uint8List? _latestFrame;
  final bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    // Hide system status bar for immersive remote desktop experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _transformController.dispose();
    super.dispose();
  }

  void _translateTouchToCoordinate(Offset localPos, RenderBox box, Function(double nx, double ny) action) {
    final size = box.size;
    if (size.width == 0 || size.height == 0) return;

    final normX = (localPos.dx / size.width).clamp(0.0, 1.0);
    final normY = (localPos.dy / size.height).clamp(0.0, 1.0);
    action(normX, normY);
  }

  void _handleTap(TapUpDetails details, RemoteProvider provider) {
    if (provider.controlMode == ControlMode.trackpad) return;

    final renderBox = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final localPos = renderBox.globalToLocal(details.globalPosition);
    _translateTouchToCoordinate(localPos, renderBox, (nx, ny) {
      provider.relayService.sendMouseMove(nx, ny);
      provider.relayService.sendMouseClick('left');
    });
  }

  void _handleDoubleTap(RemoteProvider provider) {
    if (provider.controlMode == ControlMode.trackpad) return;
    provider.relayService.sendMouseClick('left', doubleClick: true);
  }

  void _handleLongPress(LongPressEndDetails details, RemoteProvider provider) {
    if (provider.controlMode == ControlMode.trackpad) return;

    final renderBox = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final localPos = renderBox.globalToLocal(details.globalPosition);
    _translateTouchToCoordinate(localPos, renderBox, (nx, ny) {
      provider.relayService.sendMouseMove(nx, ny);
      provider.relayService.sendMouseClick('right');
    });
    HapticFeedback.mediumImpact();
  }

  void _handlePanUpdate(DragUpdateDetails details, RemoteProvider provider) {
    if (provider.controlMode == ControlMode.trackpad) return;

    final renderBox = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final localPos = renderBox.globalToLocal(details.globalPosition);
    _translateTouchToCoordinate(localPos, renderBox, (nx, ny) {
      provider.relayService.sendMouseMove(nx, ny);
    });
  }

  Future<bool> _onWillPop(RemoteProvider provider) async {
    final shouldDisconnect = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF132238),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('End Remote Session?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to disconnect from the remote computer?',
          style: TextStyle(color: Color(0xFFB0CDE8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (shouldDisconnect == true) {
      await provider.disconnect();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RemoteProvider>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final pop = await _onWillPop(provider);
        if (pop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Remote Screen Viewport with Zoom and Pan
            InteractiveViewer(
              transformationController: _transformController,
              minScale: 0.8,
              maxScale: 4.5,
              panEnabled: provider.controlMode == ControlMode.trackpad || _isDragging,
              scaleEnabled: true,
              child: Center(
                child: StreamBuilder<Uint8List>(
                  stream: provider.relayService.frameStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      _latestFrame = snapshot.data;
                    }

                    if (_latestFrame == null) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          CircularProgressIndicator(color: Color(0xFF00E5FF)),
                          SizedBox(height: 16),
                          Text(
                            'Connecting to remote screen stream...',
                            style: TextStyle(color: Color(0xFFB0CDE8), fontSize: 14),
                          ),
                        ],
                      );
                    }

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) => _handleTap(details, provider),
                      onDoubleTap: () => _handleDoubleTap(provider),
                      onLongPressEnd: (details) => _handleLongPress(details, provider),
                      onPanUpdate: (details) => _handlePanUpdate(details, provider),
                      child: Image.memory(
                        _latestFrame!,
                        key: _imageKey,
                        gaplessPlayback: true,
                        fit: BoxFit.contain,
                      ),
                    );
                  },
                ),
              ),
            ),

            // Trackpad Overlay (if enabled)
            if (provider.controlMode == ControlMode.trackpad)
              VirtualTrackpadOverlay(
                relayService: provider.relayService,
                sensitivity: provider.sensitivity,
              ),

            // Floating Draggable Session Toolbar
            SessionToolbar(
              provider: provider,
              isKeyboardVisible: _isKeyboardVisible,
              onToggleKeyboard: () {
                setState(() => _isKeyboardVisible = !_isKeyboardVisible);
              },
              onDisconnect: () async {
                final pop = await _onWillPop(provider);
                if (pop && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),

            // On-screen Virtual Keyboard Toolbar
            if (_isKeyboardVisible)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: VirtualKeyboardBar(
                  relayService: provider.relayService,
                  onClose: () {
                    setState(() => _isKeyboardVisible = false);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
