"""
Windows Remote Desktop Host Engine
TeamViewer-like Host Application for Windows
Captures screen at high FPS, simulates Win32 mouse/keyboard inputs,
and communicates via WebSocket Relay Server.
"""

import sys
import os
import time
import json
import random
import threading
import io
import ctypes
from ctypes import wintypes
import tkinter as tk
from tkinter import ttk, messagebox
import urllib.request

# Check required libraries
try:
    from PIL import Image, ImageTk
except ImportError:
    print("PIL (Pillow) is required. Installing...")
    os.system(f'"{sys.executable}" -m pip install pillow')
    from PIL import Image, ImageTk

try:
    import websockets
    import asyncio
except ImportError:
    print("websockets is required. Installing...")
    os.system(f'"{sys.executable}" -m pip install websockets')
    import websockets
    import asyncio

try:
    import qrcode
except ImportError:
    print("qrcode is required. Installing...")
    os.system(f'"{sys.executable}" -m pip install qrcode')
    import qrcode

try:
    import pyperclip
except ImportError:
    pyperclip = None

# ==================== Win32 Constants & Structs ====================
user32 = ctypes.windll.user32
gdi32 = ctypes.windll.gdi32
kernel32 = ctypes.windll.kernel32

# DPI Awareness for crisp coordinates
try:
    ctypes.windll.shcore.SetProcessDpiAwareness(2)
except Exception:
    try:
        user32.SetProcessDPIAware()
    except Exception:
        pass

MOUSEEVENTF_MOVE = 0x0001
MOUSEEVENTF_LEFTDOWN = 0x0002
MOUSEEVENTF_LEFTUP = 0x0004
MOUSEEVENTF_RIGHTDOWN = 0x0008
MOUSEEVENTF_RIGHTUP = 0x0010
MOUSEEVENTF_MIDDLEDOWN = 0x0020
MOUSEEVENTF_MIDDLEUP = 0x0040
MOUSEEVENTF_WHEEL = 0x0800
MOUSEEVENTF_ABSOLUTE = 0x8000

KEYEVENTF_EXTENDEDKEY = 0x0001
KEYEVENTF_KEYUP = 0x0002
KEYEVENTF_UNICODE = 0x0004

VK_MAPPING = {
    'backspace': 0x08,
    'tab': 0x09,
    'enter': 0x0D,
    'return': 0x0D,
    'shift': 0x10,
    'ctrl': 0x11,
    'control': 0x11,
    'alt': 0x12,
    'pause': 0x13,
    'capslock': 0x14,
    'esc': 0x1B,
    'escape': 0x1B,
    'space': 0x20,
    'pageup': 0x21,
    'pagedown': 0x22,
    'end': 0x23,
    'home': 0x24,
    'left': 0x25,
    'up': 0x26,
    'right': 0x27,
    'down': 0x28,
    'insert': 0x2D,
    'delete': 0x2E,
    'del': 0x2E,
    'win': 0x5B,
    'windows': 0x5B,
    'f1': 0x70, 'f2': 0x71, 'f3': 0x72, 'f4': 0x73,
    'f5': 0x74, 'f6': 0x75, 'f7': 0x76, 'f8': 0x77,
    'f9': 0x78, 'f10': 0x79, 'f11': 0x7A, 'f12': 0x7B,
}

class BITMAPINFOHEADER(ctypes.Structure):
    _fields_ = [
        ('biSize', ctypes.c_uint32),
        ('biWidth', ctypes.c_int32),
        ('biHeight', ctypes.c_int32),
        ('biPlanes', ctypes.c_uint16),
        ('biBitCount', ctypes.c_uint16),
        ('biCompression', ctypes.c_uint32),
        ('biSizeImage', ctypes.c_uint32),
        ('biXPelsPerMeter', ctypes.c_int32),
        ('biYPelsPerMeter', ctypes.c_int32),
        ('biClrUsed', ctypes.c_uint32),
        ('biClrImportant', ctypes.c_uint32)
    ]

# ==================== Screen Capturer ====================
class Win32ScreenCapturer:
    def __init__(self):
        self.w = user32.GetSystemMetrics(0)
        self.h = user32.GetSystemMetrics(1)
        self.hdesk = None

    def attach_desktop(self):
        try:
            self.hdesk = user32.OpenInputDesktop(0, False, 0x01FF)
            if self.hdesk:
                user32.SetThreadDesktop(self.hdesk)
        except Exception:
            pass

    def capture_frame(self, target_w=None, target_h=None, quality=65):
        self.attach_desktop()
        w, h = self.w, self.h
        hwnd = user32.GetDesktopWindow()
        hdc = user32.GetDC(hwnd)
        memdc = gdi32.CreateCompatibleDC(hdc)
        bmp = gdi32.CreateCompatibleBitmap(hdc, w, h)
        old = gdi32.SelectObject(memdc, bmp)

        # Blit desktop
        gdi32.BitBlt(memdc, 0, 0, w, h, hdc, 0, 0, 0x00CC0020)

        bmi = BITMAPINFOHEADER()
        bmi.biSize = ctypes.sizeof(BITMAPINFOHEADER)
        bmi.biWidth = w
        bmi.biHeight = -h  # top-down
        bmi.biPlanes = 1
        bmi.biBitCount = 32
        bmi.biCompression = 0

        buf = (ctypes.c_char * (w * h * 4))()
        gdi32.GetDIBits(memdc, bmp, 0, h, buf, ctypes.byref(bmi), 0)

        # Cleanup GDI
        gdi32.SelectObject(memdc, old)
        gdi32.DeleteObject(bmp)
        gdi32.DeleteDC(memdc)
        user32.ReleaseDC(hwnd, hdc)
        if self.hdesk:
            user32.CloseDesktop(self.hdesk)
            self.hdesk = None

        # Convert to PIL Image
        img = Image.frombuffer('RGBA', (w, h), buf, 'raw', 'BGRA', 0, 1).convert('RGB')

        if target_w and target_h and (target_w != w or target_h != h):
            img = img.resize((target_w, target_h), Image.Resampling.BILINEAR)

        out = io.BytesIO()
        img.save(out, format='JPEG', quality=quality, optimize=False)
        return out.getvalue()

# ==================== Input Injector ====================
class Win32InputInjector:
    def __init__(self, screen_w, screen_h):
        self.screen_w = screen_w
        self.screen_h = screen_h

    def mouse_move(self, norm_x, norm_y):
        x = int(norm_x * self.screen_w)
        y = int(norm_y * self.screen_h)
        user32.SetCursorPos(x, y)

    def mouse_down(self, button='left'):
        if button == 'left':
            user32.mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
        elif button == 'right':
            user32.mouse_event(MOUSEEVENTF_RIGHTDOWN, 0, 0, 0, 0)
        elif button == 'middle':
            user32.mouse_event(MOUSEEVENTF_MIDDLEDOWN, 0, 0, 0, 0)

    def mouse_up(self, button='left'):
        if button == 'left':
            user32.mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)
        elif button == 'right':
            user32.mouse_event(MOUSEEVENTF_RIGHTUP, 0, 0, 0, 0)
        elif button == 'middle':
            user32.mouse_event(MOUSEEVENTF_MIDDLEUP, 0, 0, 0, 0)

    def mouse_click(self, button='left', double=False):
        self.mouse_down(button)
        time.sleep(0.015)
        self.mouse_up(button)
        if double:
            time.sleep(0.05)
            self.mouse_down(button)
            time.sleep(0.015)
            self.mouse_up(button)

    def mouse_scroll(self, delta_y):
        # 120 units is one click of the scroll wheel
        user32.mouse_event(MOUSEEVENTF_WHEEL, 0, 0, int(delta_y), 0)

    def key_down(self, vk):
        user32.keybd_event(vk, 0, 0, 0)

    def key_up(self, vk):
        user32.keybd_event(vk, 0, KEYEVENTF_KEYUP, 0)

    def press_key(self, key_str):
        key_lower = key_str.lower()
        if key_lower in VK_MAPPING:
            vk = VK_MAPPING[key_lower]
            self.key_down(vk)
            time.sleep(0.01)
            self.key_up(vk)
        elif len(key_str) == 1:
            char_code = ord(key_str)
            # Unicode keystroke
            self.type_unicode_char(key_str)

    def type_unicode_char(self, char):
        class KEYBDINPUT(ctypes.Structure):
            _fields_ = [
                ("wVk", wintypes.WORD),
                ("wScan", wintypes.WORD),
                ("dwFlags", wintypes.DWORD),
                ("time", wintypes.DWORD),
                ("dwExtraInfo", ctypes.POINTER(wintypes.ULONG)),
            ]
        class INPUT(ctypes.Structure):
            class _I(ctypes.Union):
                _fields_ = [("ki", KEYBDINPUT)]
            _anonymous_ = ("_i",)
            _fields_ = [("type", wintypes.DWORD), ("_i", _I)]

        inp_down = INPUT()
        inp_down.type = 1
        inp_down.ki.wScan = ord(char)
        inp_down.ki.dwFlags = KEYEVENTF_UNICODE

        inp_up = INPUT()
        inp_up.type = 1
        inp_up.ki.wScan = ord(char)
        inp_up.ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP

        user32.SendInput(1, ctypes.byref(inp_down), ctypes.sizeof(INPUT))
        user32.SendInput(1, ctypes.byref(inp_up), ctypes.sizeof(INPUT))

    def execute_shortcut(self, action):
        if action == 'win':
            self.press_key('win')
        elif action == 'alt_tab':
            self.key_down(VK_MAPPING['alt'])
            self.press_key('tab')
            time.sleep(0.05)
            self.key_up(VK_MAPPING['alt'])
        elif action == 'win_d':
            self.key_down(VK_MAPPING['win'])
            self.key_down(ord('D'))
            time.sleep(0.05)
            self.key_up(ord('D'))
            self.key_up(VK_MAPPING['win'])
        elif action == 'esc':
            self.press_key('esc')
        elif action == 'ctrl_c':
            self.key_down(VK_MAPPING['ctrl'])
            self.key_down(ord('C'))
            time.sleep(0.05)
            self.key_up(ord('C'))
            self.key_up(VK_MAPPING['ctrl'])
        elif action == 'ctrl_v':
            self.key_down(VK_MAPPING['ctrl'])
            self.key_down(ord('V'))
            time.sleep(0.05)
            self.key_up(ord('V'))
            self.key_up(VK_MAPPING['ctrl'])

# ==================== Host Application Core ====================
class RemoteHostApp:
    def __init__(self, root):
        self.root = root
        self.root.title("TeamViewer Remote Control - Windows Host")
        self.root.geometry("450x640")
        self.root.resizable(False, False)
        self.root.configure(bg="#0E1626")

        # Session credentials
        self.partner_id = self.load_or_generate_partner_id()
        self.pin = f"{random.randint(1000, 9999)}"
        self.server_url = "ws://localhost:8080"
        self.device_name = os.environ.get("COMPUTERNAME", "Windows PC")

        self.capturer = Win32ScreenCapturer()
        self.injector = Win32InputInjector(self.capturer.w, self.capturer.h)

        # Streaming state
        self.is_running = False
        self.is_connected_to_server = False
        self.is_client_active = False
        self.fps = 25
        self.quality = 65
        self.scale = 0.75
        self.target_w = int(self.capturer.w * self.scale)
        self.target_h = int(self.capturer.h * self.scale)

        self.ws = None
        self.loop = None
        self.worker_thread = None

        self.setup_ui()
        self.start_service()

    def load_or_generate_partner_id(self):
        config_path = os.path.join(os.path.expanduser("~"), ".remote_desktop_id.txt")
        if os.path.exists(config_path):
            try:
                with open(config_path, "r") as f:
                    val = f.read().strip()
                    if len(val) == 9 and val.isdigit():
                        return val
            except Exception:
                pass
        # Generate new 9-digit ID
        new_id = f"{random.randint(100, 999)}{random.randint(100, 999)}{random.randint(100, 999)}"
        try:
            with open(config_path, "w") as f:
                f.write(new_id)
        except Exception:
            pass
        return new_id

    def format_id(self, val):
        return f"{val[:3]} {val[3:6]} {val[6:]}"

    def setup_ui(self):
        # Header banner
        header = tk.Frame(self.root, bg="#132238", height=70)
        header.pack(fill="x", side="top")

        title_lbl = tk.Label(
            header,
            text="Remote Control Host",
            font=("Segoe UI", 16, "bold"),
            fg="#00E5FF",
            bg="#132238"
        )
        title_lbl.pack(side="left", padx=20, pady=15)

        self.status_badge = tk.Label(
            header,
            text="● Offline",
            font=("Segoe UI", 10, "bold"),
            fg="#FF5252",
            bg="#132238"
        )
        self.status_badge.pack(side="right", padx=20, pady=15)

        # Main Card
        card = tk.Frame(self.root, bg="#162235", padx=20, pady=20)
        card.pack(fill="both", expand=True, padx=20, pady=15)

        # Allow Remote Control Label
        sec_title = tk.Label(
            card,
            text="ALLOW REMOTE CONTROL",
            font=("Segoe UI", 10, "bold"),
            fg="#7E9BB8",
            bg="#162235"
        )
        sec_title.pack(anchor="w", pady=(0, 10))

        desc_lbl = tk.Label(
            card,
            text="Share this ID and Password to allow remote control from your Android phone or another computer.",
            font=("Segoe UI", 9),
            fg="#9BB5D1",
            bg="#162235",
            wraplength=370,
            justify="left"
        )
        desc_lbl.pack(anchor="w", pady=(0, 15))

        # Partner ID box
        id_frame = tk.Frame(card, bg="#0E1626", padx=15, pady=10, relief="flat", highlightthickness=1, highlightbackground="#243852")
        id_frame.pack(fill="x", pady=6)

        id_lbl_title = tk.Label(id_frame, text="YOUR ID", font=("Segoe UI", 8, "bold"), fg="#6C829D", bg="#0E1626")
        id_lbl_title.pack(anchor="w")

        id_row = tk.Frame(id_frame, bg="#0E1626")
        id_row.pack(fill="x", pady=(2, 0))

        self.id_display = tk.Label(
            id_row,
            text=self.format_id(self.partner_id),
            font=("Consolas", 20, "bold"),
            fg="#FFFFFF",
            bg="#0E1626"
        )
        self.id_display.pack(side="left")

        copy_btn = tk.Button(
            id_row,
            text="Copy",
            font=("Segoe UI", 9),
            bg="#1E324D",
            fg="#00E5FF",
            activebackground="#2A4568",
            activeforeground="#FFFFFF",
            bd=0,
            padx=10,
            pady=3,
            cursor="hand2",
            command=self.copy_id
        )
        copy_btn.pack(side="right")

        # Password / PIN box
        pin_frame = tk.Frame(card, bg="#0E1626", padx=15, pady=10, relief="flat", highlightthickness=1, highlightbackground="#243852")
        pin_frame.pack(fill="x", pady=6)

        pin_lbl_title = tk.Label(pin_frame, text="ONE-TIME PASSWORD / PIN", font=("Segoe UI", 8, "bold"), fg="#6C829D", bg="#0E1626")
        pin_lbl_title.pack(anchor="w")

        pin_row = tk.Frame(pin_frame, bg="#0E1626")
        pin_row.pack(fill="x", pady=(2, 0))

        self.pin_display = tk.Label(
            pin_row,
            text=self.pin,
            font=("Consolas", 18, "bold"),
            fg="#00E5FF",
            bg="#0E1626"
        )
        self.pin_display.pack(side="left")

        regen_btn = tk.Button(
            pin_row,
            text="New PIN",
            font=("Segoe UI", 9),
            bg="#1E324D",
            fg="#00E5FF",
            activebackground="#2A4568",
            activeforeground="#FFFFFF",
            bd=0,
            padx=10,
            pady=3,
            cursor="hand2",
            command=self.regen_pin
        )
        regen_btn.pack(side="right")

        # QR Code button / preview
        self.qr_btn = tk.Button(
            card,
            text="[QR] Show Mobile Pairing QR Code",
            font=("Segoe UI", 10, "bold"),
            bg="#007ACC",
            fg="#FFFFFF",
            activebackground="#0098FF",
            activeforeground="#FFFFFF",
            bd=0,
            pady=8,
            cursor="hand2",
            command=self.show_qr_popup
        )
        self.qr_btn.pack(fill="x", pady=(15, 10))

        # Active Session Details Frame (Hidden until connected)
        self.session_frame = tk.Frame(card, bg="#10253F", padx=12, pady=10, highlightthickness=1, highlightbackground="#00E5FF")
        self.session_lbl = tk.Label(
            self.session_frame,
            text="● Live Session: Connected",
            font=("Segoe UI", 9, "bold"),
            fg="#00E5FF",
            bg="#10253F"
        )
        self.session_lbl.pack(anchor="w")

        self.session_stats = tk.Label(
            self.session_frame,
            text="Resolution: 1920x1080 | FPS: 30",
            font=("Segoe UI", 8),
            fg="#8EC3EB",
            bg="#10253F"
        )
        self.session_stats.pack(anchor="w", pady=(2, 6))

        disc_btn = tk.Button(
            self.session_frame,
            text="Disconnect Client",
            font=("Segoe UI", 9, "bold"),
            bg="#D32F2F",
            fg="#FFFFFF",
            activebackground="#F44336",
            bd=0,
            pady=4,
            cursor="hand2",
            command=self.disconnect_client
        )
        disc_btn.pack(fill="x")

        # Relay Server Settings
        server_frame = tk.Frame(card, bg="#162235")
        server_frame.pack(fill="x", side="bottom", pady=(10, 0))

        server_lbl = tk.Label(server_frame, text="Relay Server URL:", font=("Segoe UI", 8), fg="#7E9BB8", bg="#162235")
        server_lbl.pack(anchor="w")

        self.server_entry = tk.Entry(
            server_frame,
            font=("Segoe UI", 9),
            bg="#0E1626",
            fg="#FFFFFF",
            insertbackground="#00E5FF",
            bd=0,
            highlightthickness=1,
            highlightbackground="#243852"
        )
        self.server_entry.insert(0, self.server_url)
        self.server_entry.pack(fill="x", pady=(2, 5), ipady=3)

        reconnect_btn = tk.Button(
            server_frame,
            text="Reconnect to Relay",
            font=("Segoe UI", 8),
            bg="#1A2D45",
            fg="#7E9BB8",
            activebackground="#263E5E",
            activeforeground="#FFFFFF",
            bd=0,
            pady=3,
            cursor="hand2",
            command=self.reconnect_relay
        )
        reconnect_btn.pack(anchor="e")

    def copy_id(self):
        self.root.clipboard_clear()
        self.root.clipboard_append(self.partner_id)
        messagebox.showinfo("Copied", f"Partner ID {self.format_id(self.partner_id)} copied to clipboard!")

    def regen_pin(self):
        self.pin = f"{random.randint(1000, 9999)}"
        self.pin_display.config(text=self.pin)
        if self.is_running and self.ws:
            asyncio.run_coroutine_threadsafe(self.send_registration(), self.loop)

    def show_qr_popup(self):
        qr_data = json.dumps({
            "id": self.partner_id,
            "pin": self.pin,
            "server": self.server_entry.get().strip(),
            "name": self.device_name
        })
        qr = qrcode.QRCode(box_size=6, border=2)
        qr.add_data(qr_data)
        qr.make(fit=True)
        img = qr.make_image(fill_color="#00E5FF", back_color="#0E1626")

        win = tk.Toplevel(self.root)
        win.title("Scan to Connect")
        win.geometry("320x380")
        win.configure(bg="#0E1626")
        win.resizable(False, False)

        tk.Label(win, text="Scan with Mobile App", font=("Segoe UI", 12, "bold"), fg="#FFFFFF", bg="#0E1626").pack(pady=10)

        photo = ImageTk.PhotoImage(img)
        img_lbl = tk.Label(win, image=photo, bg="#0E1626")
        img_lbl.image = photo
        img_lbl.pack(pady=5)

        tk.Label(win, text=f"ID: {self.format_id(self.partner_id)}  |  PIN: {self.pin}", font=("Consolas", 10), fg="#00E5FF", bg="#0E1626").pack(pady=10)

    def disconnect_client(self):
        if self.ws and self.loop:
            asyncio.run_coroutine_threadsafe(
                self.ws.send(json.dumps({"type": "disconnect_session"})),
                self.loop
            )
        self.on_client_disconnected()

    def reconnect_relay(self):
        self.server_url = self.server_entry.get().strip()
        self.stop_service()
        time.sleep(0.5)
        self.start_service()

    def update_status(self, connected, client_active=False, message=None):
        def _update():
            if not connected:
                self.status_badge.config(text="● Offline", fg="#FF5252")
                self.session_frame.pack_forget()
            elif client_active:
                self.status_badge.config(text="● In Session", fg="#00E5FF")
                if message:
                    self.session_lbl.config(text=f"● Live Session: {message}")
                self.session_frame.pack(fill="x", pady=(15, 0))
            else:
                self.status_badge.config(text="● Ready (Online)", fg="#00E676")
                self.session_frame.pack_forget()
        self.root.after(0, _update)

    def on_client_connected(self, client_name):
        self.is_client_active = True
        self.update_status(True, True, client_name)

    def on_client_disconnected(self):
        self.is_client_active = False
        self.update_status(True, False)

    # ==================== Background WebSocket Client ====================
    def start_service(self):
        self.is_running = True
        self.worker_thread = threading.Thread(target=self._run_async_loop, daemon=True)
        self.worker_thread.start()

    def stop_service(self):
        self.is_running = False
        if self.loop:
            self.loop.call_soon_threadsafe(self.loop.stop)

    def _run_async_loop(self):
        self.loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self.loop)
        self.loop.run_until_complete(self._client_loop())

    async def _client_loop(self):
        while self.is_running:
            try:
                self.update_status(False)
                url = self.server_url
                print(f"Connecting to Relay Server: {url}...")
                async with websockets.connect(url, max_size=10_000_000, ping_interval=20, ping_timeout=15) as ws:
                    self.ws = ws
                    self.is_connected_to_server = True
                    self.update_status(True)
                    print("[+] Connected to Relay Server!")

                    await self.send_registration()

                    # Start concurrent screen streamer and message receiver
                    stream_task = asyncio.create_task(self._screen_stream_loop())
                    recv_task = asyncio.create_task(self._receive_messages_loop())

                    done, pending = await asyncio.wait(
                        [stream_task, recv_task],
                        return_when=asyncio.FIRST_COMPLETED
                    )
                    for t in pending:
                        t.cancel()

            except Exception as e:
                print(f"[-] Connection error: {e}")
                self.is_connected_to_server = False
                self.is_client_active = False
                self.update_status(False)
                await asyncio.sleep(3)

    async def send_registration(self):
        msg = {
            "type": "register_host",
            "partnerId": self.partner_id,
            "pin": self.pin,
            "deviceName": self.device_name,
            "width": self.capturer.w,
            "height": self.capturer.h
        }
        await self.ws.send(json.dumps(msg))

    async def _screen_stream_loop(self):
        while self.is_running and self.ws:
            if self.is_client_active:
                frame_start = time.time()
                try:
                    # Run capture in thread pool to prevent blocking async loop
                    jpeg_bytes = await self.loop.run_in_executor(
                        None,
                        self.capturer.capture_frame,
                        self.target_w,
                        self.target_h,
                        self.quality
                    )
                    await self.ws.send(jpeg_bytes)
                except Exception as e:
                    print(f"Stream error: {e}")
                    await asyncio.sleep(0.05)

                elapsed = time.time() - frame_start
                delay = max(0.001, (1.0 / self.fps) - elapsed)
                await asyncio.sleep(delay)
            else:
                await asyncio.sleep(0.2)

    async def _receive_messages_loop(self):
        while self.is_running and self.ws:
            try:
                raw = await self.ws.recv()
                if isinstance(raw, str):
                    data = json.loads(raw)
                    self.handle_server_message(data)
            except websockets.exceptions.ConnectionClosed:
                break
            except Exception as e:
                print(f"Recv error: {e}")
                break

    def handle_server_message(self, data):
        mtype = data.get("type")

        if mtype == "client_connected":
            self.on_client_connected(data.get("clientName", "Remote Client"))

        elif mtype == "client_disconnected":
            self.on_client_disconnected()

        elif mtype == "input":
            action = data.get("action")
            if action == "move":
                self.injector.mouse_move(data.get("x", 0), data.get("y", 0))
            elif action == "click":
                self.injector.mouse_click(data.get("button", "left"), data.get("double", False))
            elif action == "mouse_down":
                self.injector.mouse_down(data.get("button", "left"))
            elif action == "mouse_up":
                self.injector.mouse_up(data.get("button", "left"))
            elif action == "scroll":
                self.injector.mouse_scroll(data.get("deltaY", 0))
            elif action == "key_down":
                vk = data.get("vk")
                if vk:
                    self.injector.key_down(vk)
            elif action == "key_up":
                vk = data.get("vk")
                if vk:
                    self.injector.key_up(vk)
            elif action == "press_key":
                self.injector.press_key(data.get("key", ""))
            elif action == "type_text":
                text = data.get("text", "")
                for char in text:
                    self.injector.type_unicode_char(char)
            elif action == "shortcut":
                self.injector.execute_shortcut(data.get("name", ""))

        elif mtype == "control":
            # Dynamic quality / scaling change
            if "quality" in data:
                self.quality = int(data["quality"])
            if "scale" in data:
                self.scale = float(data["scale"])
                self.target_w = int(self.capturer.w * self.scale)
                self.target_h = int(self.capturer.h * self.scale)
            if "fps" in data:
                self.fps = int(data["fps"])

        elif mtype == "clipboard":
            text = data.get("text")
            if text and pyperclip:
                try:
                    pyperclip.copy(text)
                except Exception:
                    pass

def main():
    root = tk.Tk()
    app = RemoteHostApp(root)
    root.protocol("WM_DELETE_WINDOW", lambda: (app.stop_service(), root.destroy(), sys.exit(0)))
    root.mainloop()

if __name__ == "__main__":
    main()
