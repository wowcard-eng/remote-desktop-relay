import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/relay_service.dart';

class VirtualKeyboardBar extends StatefulWidget {
  final RelayService relayService;
  final VoidCallback onClose;

  const VirtualKeyboardBar({
    super.key,
    required this.relayService,
    required this.onClose,
  });

  @override
  State<VirtualKeyboardBar> createState() => _VirtualKeyboardBarState();
}

class _VirtualKeyboardBarState extends State<VirtualKeyboardBar> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _ctrlActive = false;
  bool _altActive = false;
  bool _shiftActive = false;
  bool _winActive = false;

  @override
  void initState() {
    super.initState();
    // Auto request focus to bring up keyboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendSpecialKey(String key, int vk) {
    HapticFeedback.lightImpact();
    widget.relayService.sendKeyDown(vk);
    Future.delayed(const Duration(milliseconds: 30), () {
      widget.relayService.sendKeyUp(vk);
    });
  }

  void _toggleModifier(String name, int vk, bool currentState, Function(bool) setter) {
    HapticFeedback.mediumImpact();
    final newState = !currentState;
    setter(newState);
    if (newState) {
      widget.relayService.sendKeyDown(vk);
    } else {
      widget.relayService.sendKeyUp(vk);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101928),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
        border: const Border(
          top: BorderSide(color: Color(0xFF243B5A), width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Direct text input field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF16253B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF2C456B)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Type here to send text directly to PC...',
                        hintStyle: TextStyle(color: Color(0xFF6B87AC), fontSize: 13),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 9),
                      ),
                      onSubmitted: (text) {
                        if (text.isNotEmpty) {
                          widget.relayService.sendText(text);
                          widget.relayService.sendShortcut('enter');
                          _textController.clear();
                          _focusNode.requestFocus();
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF00E5FF), size: 20),
                  onPressed: () {
                    final text = _textController.text;
                    if (text.isNotEmpty) {
                      widget.relayService.sendText(text);
                      _textController.clear();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.keyboard_hide, color: Colors.grey, size: 20),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),

          // Row 2: Special modifier keys & shortcuts
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                _buildModifierKey('Ctrl', 0x11, _ctrlActive, (v) => _ctrlActive = v),
                _buildModifierKey('Alt', 0x12, _altActive, (v) => _altActive = v),
                _buildModifierKey('Shift', 0x10, _shiftActive, (v) => _shiftActive = v),
                _buildModifierKey('Win', 0x5B, _winActive, (v) => _winActive = v),
                const SizedBox(width: 8),
                _buildActionKey('Esc', () => _sendSpecialKey('esc', 0x1B)),
                _buildActionKey('Tab', () => _sendSpecialKey('tab', 0x09)),
                _buildActionKey('Del', () => _sendSpecialKey('delete', 0x2E)),
                _buildActionKey('⌫', () => _sendSpecialKey('backspace', 0x08)),
                _buildActionKey('↵ Enter', () => _sendSpecialKey('enter', 0x0D), isPrimary: true),
                const SizedBox(width: 8),
                _buildActionKey('←', () => _sendSpecialKey('left', 0x25)),
                _buildActionKey('↑', () => _sendSpecialKey('up', 0x26)),
                _buildActionKey('↓', () => _sendSpecialKey('down', 0x28)),
                _buildActionKey('→', () => _sendSpecialKey('right', 0x27)),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildModifierKey(String label, int vk, bool isActive, Function(bool) setter) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        onTap: () => _toggleModifier(label, vk, isActive, setter),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF00E5FF) : const Color(0xFF1E324F),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive ? const Color(0xFF00E5FF) : const Color(0xFF2C456B),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionKey(String label, VoidCallback onTap, {bool isPrimary = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isPrimary ? const Color(0xFF007ACC) : const Color(0xFF16253B),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isPrimary ? const Color(0xFF00E5FF) : const Color(0xFF243B5A),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isPrimary ? Colors.white : const Color(0xFFB0CDE8),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
