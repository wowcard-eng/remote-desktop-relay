# 🚀 TeamViewer Remote Desktop (Flutter + Windows & Android)

Ek **100% Fully Working**, high-performance, modern cross-platform Windows Remote Control application jo **TeamViewer, AnyDesk aur RustDesk** ki tarah kaam karta hai.

Is project me aap apne **Android mobile phone** ya dusre computer se kisi bhi **Windows PC** ko poori tarah remote control kar sakte hain:
- **Live Desktop Screen Streaming** (Smooth 30 - 45 FPS with low latency).
- **Interactive Mouse Control**: Single tap (Left Click), Double tap, Long press (Right Click), Drag & Drop, Mouse Wheel scroll.
- **Virtual Trackpad Mode**: Mobile screen ko laptop trackpad ki tarah use karne ke liye.
- **Full On-Screen Virtual Keyboard**: Direct typing + Special keys: `[Ctrl]`, `[Alt]`, `[Shift]`, `[Win]`, `[Esc]`, `[Tab]`, `[Del]`, `[Enter]`, `[Arrows]`.
- **Windows Quick Shortcuts**: `Win + D` (Show Desktop), `Alt + Tab` (Switch App), `Ctrl + C`, `Ctrl + V`, `Esc`.
- **QR Code Instant Pairing**: Partner ID & Password type kiye bina seedhe mobile camera/QR se 1-click connect.
- **Relay Server Support**: Local Wi-Fi / LAN par bhi chalta hai aur Internet / Cloud par bhi NAT traversal ke sath.

---

## 🏗️ System Architecture

```text
┌─────────────────────────────────┐               ┌─────────────────────────────────┐
│     Windows Host Engine         │               │     Flutter Client App          │
│   (Screen Capture + Win32 Input)│               │    (Android, Windows, Web)      │
│   - Desktop GDI BitBlt Capture  │               │   - InteractiveViewer (Zoom/Pan)│
│   - SendInput & mouse_event     │               │   - Touch & Gesture Translators │
│   - Win32 API Key Injections    │               │   - Virtual Trackpad & Keyboard │
└────────────────┬────────────────┘               └────────────────▲────────────────┘
                 │                                                 │
                 │      WebSocket Relay / Signaling Server         │
                 │     (Binary Frames + Realtime Control)          │
                 └────────────────► [ PORT 8080 ] ◄────────────────┘
```

---

## 📂 Project Structure

```text
remote desktop/
│
├── lib/                             # Flutter Cross-Platform Client App
│   ├── main.dart                    # App Entry Point & Dark Theme
│   ├── models/                      # Session models, stream quality, recent devices
│   ├── providers/                   # RemoteProvider (State Management)
│   ├── services/                    # RelayService (WebSocket), StorageService
│   ├── screens/
│   │   ├── home_screen.dart         # TeamViewer-style Dashboard (ID, PIN, Connect)
│   │   └── remote_viewer_screen.dart# Live Interactive Remote Screen Viewer
│   └── widgets/
│       ├── session_toolbar.dart     # Floating draggable toolbar & shortcuts
│       ├── virtual_keyboard_bar.dart# On-screen keyboard & function keys
│       └── virtual_trackpad.dart    # Laptop trackpad mode overlay
│
├── host/                            # Windows Host Engine
│   ├── windows_host.py              # Screen grabber + Win32 input simulator + GUI
│   └── requirements.txt             # Python dependencies (pillow, websockets, qrcode)
│
├── server/                          # Relay & Signaling Server
│   ├── relay_server.js              # High-performance Node.js Relay Server
│   ├── relay_server.py              # Zero-dependency Python Relay Server
│   └── package.json                 # Node package configuration
│
├── run_server.bat                   # ⚡ 1-Click launcher for Relay Server
├── run_host.bat                     # ⚡ 1-Click launcher for Windows Host Engine
└── README.md                        # Documentation & Setup Guide
```

---

## ⚡ Quick Start Guide (Kaise Chalayein)

### Step 1: Relay Server Start Karein (Computer Par)
Relay Server host aur client ke beech connection karwata hai.

1. Root folder me **`run_server.bat`** par double click karein.
   - Yeh automatically detect karega ki Node.js hai ya Python aur server start kar dega:
   - Server URL: `ws://localhost:8080` (Local PC) ya `ws://<Aapka-IP>:8080` (LAN/Wi-Fi).

---

### Step 2: Windows Host Start Karein (Jis Computer Ko Control Karna Hai)
Windows PC par screen capture aur mouse/keyboard control active karne ke liye:

1. Root folder me **`run_host.bat`** par double click karein.
2. Screen par ek modern **TeamViewer-like Host Window** khulegi jo dikhayegi:
   - **YOUR ID**: Jaise `482 195 382`
   - **ONE-TIME PASSWORD / PIN**: Jaise `8492`
   - **Status Badge**: `● Ready (Online)`
   - **Show QR Code**: Is button ko click karke QR code bhi dekh sakte hain!

---

### Step 3: Flutter App Chalayein (Android Phone ya Browser Par)

#### Option A: Android Mobile Phone Par Run Karein:
Apne Android phone ko USB cable se connect karein (USB Debugging ON):
```bash
flutter run -d <device-id>
```
Ya APK build karne ke liye:
```bash
flutter build apk --release
```
*Generated APK location: `build/app/outputs/flutter-apk/app-release.apk`*

#### Option B: Chrome / Web Par Test Karein:
```bash
flutter run -d chrome
```

---

## 🎮 Mobile Se Windows PC Ko Kaise Control Karein?

1. Mobile me app open karein.
2. **Settings** tab me jakar check karein ki Relay URL aapke PC ka Wi-Fi IP hai (e.g. `ws://10.212.90.238:8080`).
3. **Control Remote** tab me:
   - Windows Host par dikh raha **Partner ID** dalein.
   - **PIN** dalein.
   - **CONNECT TO PC** par tap karein.
4. Boom! 🚀 Aapka Windows desktop aapke mobile screen par live show hoga!

### Touch Gestures:
- **Single Tap**: Left Click karega.
- **Double Tap**: Double Click karega (Folder ya App open karne ke liye).
- **Long Press**: Right Click karega (Context menu open karne ke liye).
- **Drag / Pan**: Mouse move karega / Windows drag karega.
- **Pinch-to-Zoom**: Mobile screen par Windows desktop ko zoom aur pan kar sakte hain taaki chhota text bhi aasaani se padh sakein.
- **Floating Toolbar**:
  - `[Keyboard Icon]`: Mobile keyboard aur Windows special keys (`Ctrl`, `Alt`, `Shift`, `Win`, `Esc`, `Tab`) open karega.
  - `[Mouse Icon]`: Trackpad mode toggle karega.
  - `[Apps Icon]`: `Win + D`, `Alt + Tab`, `Ctrl + C`, `Ctrl + V` shortcuts send karega.
  - `[Power Icon]`: Remote session cleanly disconnect karega.

---

## 🌐 Render.com Par Free Relay Server Deploy Karne Ka Complete Guide

Render.com par aapka Relay Server bilkul **FREE** me 24/7 chalega aur aap bina kisi router port-forwarding ke internet ke through apna PC control kar sakenge.

### Step 1: Code Ko GitHub Par Push Karein
1. Apne terminal me ye commands run karein:
   ```bash
   git init
   git add .
   git commit -m "Remote desktop project"
   ```
2. [GitHub.com](https://github.com) par ek new repository banayein (jaise `remote-desktop`).
3. Repository push karein:
   ```bash
   git remote add origin https://github.com/YOUR_USERNAME/remote-desktop.git
   git branch -M main
   git push -u origin main
   ```

### Step 2: Render.com Par Web Service Banayein
1. [Render.com](https://render.com) par account banakar login karein.
2. Dashboard par **New +** par click karein aur **Web Service** choose karein.
3. Apna GitHub repository connect karein.
4. Settings me ye exact values bharein:
   - **Name**: `my-remote-relay` *(ya koi bhi unique name)*
   - **Region**: `Singapore` *(India ke liye sabse fast latency)*
   - **Root Directory**: `server`
   - **Runtime**: `Node`
   - **Build Command**: `npm install`
   - **Start Command**: `node relay_server.js`
   - **Instance Type**: `Free`
5. **Deploy Web Service** par click karein.

### Step 3: WebSocket URL Se Connect Karein
1. 1-2 minute me service **Live** ho jayegi.
2. Render aapko ek URL dega:
   `https://my-remote-relay.onrender.com`
3. Is URL ke `https://` ko badal kar `wss://` kar dein:
   👉 `wss://my-remote-relay.onrender.com`
4. Ab:
   - **Windows Host App**: "Relay Server URL" me ye `wss://...` paste karke **Reconnect** dabayein.
   - **Flutter Android App**: **Settings** tab me jakar "Relay Server URL" me ye paste karke **Save URL** dabayein.
5. Kaam ho gaya! Ab aap duniya me kahin se bhi apna PC control kar sakte hain! 🚀
