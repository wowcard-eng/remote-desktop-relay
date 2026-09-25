"""
Remote Desktop Cloud Relay & Signaling Server (Python)
Alternative Python WebSocket relay server using 'websockets'
"""

import asyncio
import json
import os
import sys

try:
    import websockets
except ImportError:
    print("Please install websockets: pip install websockets")
    sys.exit(1)

PORT = int(os.environ.get("PORT", 8080))

hosts = {}      # partnerId -> { "ws": ws, "pin": pin, "deviceName": name, "width": w, "height": h, "clientWs": ws }
sessions = {}   # clientWs -> partnerId
sockets = {}    # ws -> partnerId

async def handler(websocket):
    remote = websocket.remote_address
    print(f"[+] Connection from {remote}")

    try:
        async for message in websocket:
            # Binary message: Screen Frame from Host -> forward to paired Client
            if isinstance(message, bytes):
                partner_id = sockets.get(websocket)
                if partner_id and partner_id in hosts:
                    client_ws = hosts[partner_id].get("clientWs")
                    if client_ws:
                        await client_ws.send(message)
                continue

            # JSON message
            try:
                data = json.loads(message)
            except Exception as e:
                print(f"[-] Invalid JSON: {e}")
                continue

            msg_type = data.get("type")

            if msg_type == "register_host":
                partner_id = data.get("partnerId")
                pin = data.get("pin")
                if not partner_id or not pin:
                    await websocket.send(json.dumps({"type": "error", "message": "Missing ID or PIN"}))
                    continue

                hosts[partner_id] = {
                    "ws": websocket,
                    "pin": pin,
                    "deviceName": data.get("deviceName", "Windows PC"),
                    "width": data.get("width", 1920),
                    "height": data.get("height", 1080),
                    "clientWs": None
                }
                sockets[websocket] = partner_id
                print(f"[*] Host registered: {partner_id} ({hosts[partner_id]['deviceName']})")
                await websocket.send(json.dumps({
                    "type": "registered",
                    "partnerId": partner_id,
                    "message": "Host registered successfully"
                }))

            elif msg_type == "connect_host":
                partner_id = data.get("partnerId")
                pin = data.get("pin")
                client_name = data.get("clientName", "Remote Client")

                if partner_id not in hosts:
                    await websocket.send(json.dumps({
                        "type": "connect_failed",
                        "message": "Partner ID not found. Ensure remote PC host is running."
                    }))
                    continue

                host_data = hosts[partner_id]
                if host_data["pin"] != pin:
                    await websocket.send(json.dumps({
                        "type": "connect_failed",
                        "message": "Authentication failed: Incorrect Password / PIN"
                    }))
                    continue

                # Terminate any old client
                old_client = host_data.get("clientWs")
                if old_client:
                    try:
                        await old_client.send(json.dumps({
                            "type": "session_closed",
                            "message": "Session replaced by a new incoming connection"
                        }))
                    except Exception:
                        pass

                host_data["clientWs"] = websocket
                sessions[websocket] = partner_id

                # Notify host
                await host_data["ws"].send(json.dumps({
                    "type": "client_connected",
                    "clientName": client_name
                }))

                # Notify client
                await websocket.send(json.dumps({
                    "type": "connected",
                    "partnerId": partner_id,
                    "deviceName": host_data["deviceName"],
                    "width": host_data["width"],
                    "height": host_data["height"]
                }))
                print(f"[+] Session established: Client -> Host {partner_id}")

            elif msg_type in ("input", "control"):
                # Forward to host
                partner_id = sessions.get(websocket)
                if partner_id and partner_id in hosts:
                    await hosts[partner_id]["ws"].send(message)

            elif msg_type == "clipboard":
                # Forward between peers
                if websocket in sessions:
                    partner_id = sessions[websocket]
                    if partner_id in hosts:
                        await hosts[partner_id]["ws"].send(message)
                elif websocket in sockets:
                    partner_id = sockets[websocket]
                    if partner_id in hosts and hosts[partner_id].get("clientWs"):
                        await hosts[partner_id]["clientWs"].send(message)

            elif msg_type == "ping":
                await websocket.send(json.dumps({"type": "pong", "timestamp": data.get("timestamp")}))

            elif msg_type == "disconnect_session":
                if websocket in sessions:
                    partner_id = sessions.pop(websocket, None)
                    if partner_id and partner_id in hosts:
                        hosts[partner_id]["clientWs"] = None
                        await hosts[partner_id]["ws"].send(json.dumps({"type": "client_disconnected"}))

    except websockets.exceptions.ConnectionClosed:
        pass
    finally:
        # Cleanup
        if websocket in sockets:
            partner_id = sockets.pop(websocket, None)
            if partner_id and partner_id in hosts:
                client_ws = hosts[partner_id].get("clientWs")
                if client_ws:
                    try:
                        await client_ws.send(json.dumps({
                            "type": "session_closed",
                            "message": "Remote host disconnected"
                        }))
                    except Exception:
                        pass
                del hosts[partner_id]
                print(f"[-] Host offline: {partner_id}")

        if websocket in sessions:
            partner_id = sessions.pop(websocket, None)
            if partner_id and partner_id in hosts:
                hosts[partner_id]["clientWs"] = None
                try:
                    await hosts[partner_id]["ws"].send(json.dumps({"type": "client_disconnected"}))
                except Exception:
                    pass

async def main():
    async with websockets.serve(handler, "0.0.0.0", PORT, ping_interval=25, ping_timeout=15):
        print("====================================================")
        print(f"[SERVER] Remote Desktop Relay Server running on port {PORT}")
        print(f"   Local URL: ws://localhost:{PORT}")
        print("====================================================")
        await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(main())
