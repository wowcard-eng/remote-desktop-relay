import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/session_models.dart';
import '../providers/remote_provider.dart';
import 'remote_viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController _partnerIdController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _relayUrlController = TextEditingController();

  bool _obscurePin = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _partnerIdController.dispose();
    _pinController.dispose();
    _relayUrlController.dispose();
    super.dispose();
  }

  String _formatId(String val) {
    final clean = val.replaceAll(' ', '');
    if (clean.length <= 3) return clean;
    if (clean.length <= 6) return '${clean.substring(0, 3)} ${clean.substring(3)}';
    return '${clean.substring(0, 3)} ${clean.substring(3, 6)} ${clean.substring(6)}';
  }

  void _handleConnect(RemoteProvider provider) async {
    final partnerId = _partnerIdController.text.trim();
    final pin = _pinController.text.trim();

    if (partnerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Partner ID')),
      );
      return;
    }

    if (pin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Password / PIN')),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    final success = await provider.connect(
      partnerId: partnerId,
      pin: pin,
    );

    if (success && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const RemoteViewerScreen()),
      );
    } else if (mounted && provider.errorMessage.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RemoteProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0A111E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101C2F),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.desktop_windows_outlined, color: Color(0xFF00E5FF), size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'TeamViewer Remote',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        actions: [
          // Relay connection indicator
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF16253B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF243B5A)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF00E676),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Relay Ready',
                    style: TextStyle(color: Color(0xFF8BB5DB), fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00E5FF),
          indicatorWeight: 3,
          labelColor: const Color(0xFF00E5FF),
          unselectedLabelColor: const Color(0xFF7E9BB8),
          tabs: const [
            Tab(icon: Icon(Icons.connect_without_contact, size: 20), text: 'Control Remote'),
            Tab(icon: Icon(Icons.share, size: 20), text: 'Share Screen'),
            Tab(icon: Icon(Icons.settings, size: 20), text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildControlRemoteTab(provider),
          _buildShareScreenTab(provider),
          _buildSettingsTab(provider),
        ],
      ),
    );
  }

  // ==================== TAB 1: CONTROL REMOTE ====================
  Widget _buildControlRemoteTab(RemoteProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          const Text(
            'CONTROL REMOTE COMPUTER',
            style: TextStyle(color: Color(0xFF7E9BB8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
          ),
          const SizedBox(height: 6),
          const Text(
            'Enter the Partner ID and Password of the computer you want to control.',
            style: TextStyle(color: Color(0xFF9BB5D1), fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Partner ID Input Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF132238),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF243B5A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PARTNER ID', style: TextStyle(color: Color(0xFF6C8DAE), fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _partnerIdController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                        decoration: const InputDecoration(
                          hintText: 'e.g. 482 195 382',
                          hintStyle: TextStyle(color: Color(0xFF4C6684), fontSize: 16, letterSpacing: 1.0),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (val) {
                          final formatted = _formatId(val);
                          if (formatted != val) {
                            _partnerIdController.value = TextEditingValue(
                              text: formatted,
                              selection: TextSelection.collapsed(offset: formatted.length),
                            );
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.paste, color: Color(0xFF00E5FF), size: 20),
                      tooltip: 'Paste from clipboard',
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        if (data?.text != null) {
                          setState(() {
                            _partnerIdController.text = _formatId(data!.text!);
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Password / PIN Input Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF132238),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF243B5A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PASSWORD / PIN', style: TextStyle(color: Color(0xFF6C8DAE), fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _pinController,
                        obscureText: _obscurePin,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
                        decoration: const InputDecoration(
                          hintText: '4-digit PIN',
                          hintStyle: TextStyle(color: Color(0xFF4C6684), fontSize: 15, letterSpacing: 1),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(_obscurePin ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF6C8DAE), size: 20),
                      onPressed: () {
                        setState(() => _obscurePin = !_obscurePin);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Connect Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007ACC),
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: const Color(0xFF00E5FF).withOpacity(0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: provider.status == ConnectionStateStatus.connecting
                  ? null
                  : () => _handleConnect(provider),
              child: provider.status == ConnectionStateStatus.connecting
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                        ),
                        SizedBox(width: 14),
                        Text('Connecting to Remote PC...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow_rounded, size: 24),
                        SizedBox(width: 8),
                        Text('CONNECT TO PC', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 32),

          // Recent Connections Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'RECENT COMPUTERS',
                style: TextStyle(color: Color(0xFF7E9BB8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
              ),
              if (provider.recentConnections.isNotEmpty)
                TextButton(
                  onPressed: () => provider.clearRecentHistory(),
                  child: const Text('Clear', style: TextStyle(color: Color(0xFF6C8DAE), fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (provider.recentConnections.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF101928),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1E324F)),
              ),
              child: Column(
                children: const [
                  Icon(Icons.devices_other, color: Color(0xFF385375), size: 36),
                  SizedBox(height: 8),
                  Text('No recent connections yet', style: TextStyle(color: Color(0xFF6C8DAE), fontSize: 13)),
                  SizedBox(height: 4),
                  Text('Computers you connect to will appear here for fast access', style: TextStyle(color: Color(0xFF476282), fontSize: 11)),
                ],
              ),
            )
          else
            ...provider.recentConnections.map(
              (conn) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF132238),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF243B5A)),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2E4A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.laptop_windows, color: Color(0xFF00E5FF), size: 20),
                  ),
                  title: Text(
                    conn.deviceName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    _formatId(conn.partnerId),
                    style: const TextStyle(color: Color(0xFF7E9BB8), fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, color: Color(0xFF00E5FF), size: 16),
                    onPressed: () {
                      _partnerIdController.text = _formatId(conn.partnerId);
                      _pinController.clear();
                      FocusScope.of(context).requestFocus();
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==================== TAB 2: SHARE SCREEN (HOST MODE) ====================
  Widget _buildShareScreenTab(RemoteProvider provider) {
    final qrData = jsonEncode({
      'id': provider.myPartnerId,
      'pin': provider.myPin,
      'server': provider.relayUrl,
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ALLOW REMOTE CONTROL',
            style: TextStyle(color: Color(0xFF7E9BB8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
          ),
          const SizedBox(height: 6),
          const Text(
            'Give these credentials to the partner who wants to connect to and control this device.',
            style: TextStyle(color: Color(0xFF9BB5D1), fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Your ID Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF132238),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF243B5A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('YOUR PARTNER ID', style: TextStyle(color: Color(0xFF6C8DAE), fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatId(provider.myPartnerId),
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E324F),
                        foregroundColor: const Color(0xFF00E5FF),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: provider.myPartnerId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Partner ID copied to clipboard!')),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // One-Time Password / PIN Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF132238),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF243B5A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ONE-TIME PASSWORD / PIN', style: TextStyle(color: Color(0xFF6C8DAE), fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      provider.myPin,
                      style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 3),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Color(0xFF00E5FF)),
                      tooltip: 'Generate new PIN',
                      onPressed: () => provider.refreshMyPin(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // QR Code Pairing
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 160.0,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Scan QR code from phone for instant 1-tap connection',
              style: TextStyle(color: Color(0xFF6C8DAE), fontSize: 12),
            ),
          ),
          const SizedBox(height: 24),

          // Windows Host Launcher Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF102035),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF00E5FF), size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Controlling Windows PC?',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'On Windows, double-click run_host.bat to launch the screen capture & Win32 input engine.',
                        style: TextStyle(color: Color(0xFF90B5D8), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== TAB 3: SETTINGS ====================
  Widget _buildSettingsTab(RemoteProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NETWORK & RELAY SERVER',
            style: TextStyle(color: Color(0xFF7E9BB8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
          ),
          const SizedBox(height: 10),

          // Relay Server Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF132238),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF243B5A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('RELAY SERVER URL', style: TextStyle(color: Color(0xFF6C8DAE), fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: _relayUrlController..text = provider.relayUrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'ws://192.168.1.100:8080 or wss://relay.yourdomain.com',
                    hintStyle: TextStyle(color: Color(0xFF4C6684), fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onSubmitted: (val) {
                    provider.setRelayUrl(val);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Relay Server URL saved')),
                    );
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E324F),
                        foregroundColor: const Color(0xFF00E5FF),
                      ),
                      onPressed: () {
                        provider.setRelayUrl(_relayUrlController.text);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Relay Server URL updated')),
                        );
                      },
                      child: const Text('Save URL'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'STREAMING & INPUT SETTINGS',
            style: TextStyle(color: Color(0xFF7E9BB8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
          ),
          const SizedBox(height: 10),

          // Quality selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF132238),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF243B5A)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Stream Quality', style: TextStyle(color: Colors.white, fontSize: 14)),
                DropdownButton<StreamQuality>(
                  value: provider.quality,
                  dropdownColor: const Color(0xFF132238),
                  style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 14, fontWeight: FontWeight.bold),
                  underline: const SizedBox(),
                  onChanged: (q) {
                    if (q != null) provider.setQuality(q);
                  },
                  items: const [
                    DropdownMenuItem(value: StreamQuality.high, child: Text('High (1080p, 45 FPS)')),
                    DropdownMenuItem(value: StreamQuality.balanced, child: Text('Balanced (720p, 30 FPS)')),
                    DropdownMenuItem(value: StreamQuality.low, child: Text('Low Bandwidth (540p)')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Touch Mode selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF132238),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF243B5A)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Input Mode', style: TextStyle(color: Colors.white, fontSize: 14)),
                DropdownButton<ControlMode>(
                  value: provider.controlMode,
                  dropdownColor: const Color(0xFF132238),
                  style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 14, fontWeight: FontWeight.bold),
                  underline: const SizedBox(),
                  onChanged: (m) {
                    if (m != null) provider.setControlMode(m);
                  },
                  items: const [
                    DropdownMenuItem(value: ControlMode.directTouch, child: Text('Direct Touch (Tap = Click)')),
                    DropdownMenuItem(value: ControlMode.trackpad, child: Text('Virtual Trackpad (Cursor)')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Mouse Sensitivity slider
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF132238),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF243B5A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Mouse Sensitivity', style: TextStyle(color: Colors.white, fontSize: 14)),
                    Text('${provider.sensitivity.toStringAsFixed(1)}x', style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: provider.sensitivity,
                  min: 0.5,
                  max: 2.5,
                  divisions: 20,
                  activeColor: const Color(0xFF00E5FF),
                  inactiveColor: const Color(0xFF243B5A),
                  onChanged: (val) => provider.setSensitivity(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // About app
          Center(
            child: Column(
              children: const [
                Text('TeamViewer Remote Desktop v1.0.0', style: TextStyle(color: Color(0xFF6C8DAE), fontSize: 12, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Cross-Platform Flutter & Windows Remote Control', style: TextStyle(color: Color(0xFF476282), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
