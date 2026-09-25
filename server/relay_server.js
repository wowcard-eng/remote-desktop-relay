/**
 * Remote Desktop Cloud Relay & Signaling Server
 * High performance WebSocket relay for TeamViewer-like remote control.
 */

const http = require('http');
const WebSocket = require('ws');

const PORT = process.env.PORT || 8080;
const server = http.createServer((req, res) => {
  if (req.url === '/health' || req.url === '/') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      status: 'online',
      activeHosts: Object.keys(hosts).length,
      activeSessions: Object.keys(sessions).length,
      uptimeSeconds: Math.floor(process.uptime()),
      timestamp: new Date().toISOString()
    }));
  } else {
    res.writeHead(404);
    res.end();
  }
});

const wss = new WebSocket.Server({ server });

// Map of partnerId -> { ws, pin, deviceName, width, height, clientWs }
const hosts = new Map();
// Map of clientWs -> partnerId
const sessions = new Map();
// Map of ws -> role ('host' | 'client')
const sockets = new Map();

wss.on('connection', (ws, req) => {
  const clientIp = req.headers['x-forwarded-for'] || req.socket.remoteAddress;
  console.log(`[+] New WebSocket connection from ${clientIp}`);

  ws.isAlive = true;
  ws.on('pong', () => { ws.isAlive = true; });

  ws.on('message', (message, isBinary) => {
    // If it's a binary message (Screen Frame JPEG from Host), forward immediately to Client
    if (isBinary) {
      const partnerId = sockets.get(ws);
      if (partnerId && hosts.has(partnerId)) {
        const hostData = hosts.get(partnerId);
        if (hostData.clientWs && hostData.clientWs.readyState === WebSocket.OPEN) {
          hostData.clientWs.send(message, { binary: true });
        }
      }
      return;
    }

    // Otherwise, parse JSON control message
    try {
      const data = JSON.parse(message.toString());
      handleMessage(ws, data);
    } catch (err) {
      console.error('[-] Error handling message:', err.message);
    }
  });

  ws.on('close', () => {
    handleDisconnect(ws);
  });

  ws.on('error', (err) => {
    console.error('[-] Socket error:', err.message);
    handleDisconnect(ws);
  });
});

function handleMessage(ws, data) {
  const type = data.type;

  switch (type) {
    case 'register_host': {
      const { partnerId, pin, deviceName, width, height } = data;
      if (!partnerId || !pin) {
        ws.send(JSON.stringify({ type: 'error', message: 'Partner ID and PIN are required' }));
        return;
      }

      // Check if already registered
      if (hosts.has(partnerId)) {
        const oldHost = hosts.get(partnerId);
        if (oldHost.ws !== ws && oldHost.ws.readyState === WebSocket.OPEN) {
          oldHost.ws.close();
        }
      }

      hosts.set(partnerId, {
        ws,
        pin,
        deviceName: deviceName || 'Windows PC',
        width: width || 1920,
        height: height || 1080,
        clientWs: null,
        registeredAt: Date.now()
      });

      sockets.set(ws, partnerId);
      console.log(`[*] Host registered: ${partnerId} (${deviceName})`);
      ws.send(JSON.stringify({
        type: 'registered',
        partnerId,
        message: 'Host successfully registered with relay server'
      }));
      break;
    }

    case 'connect_host': {
      const { partnerId, pin, clientName } = data;
      console.log(`[*] Client connecting to Partner ID: ${partnerId}`);

      if (!hosts.has(partnerId)) {
        ws.send(JSON.stringify({
          type: 'connect_failed',
          message: 'Partner ID not found. Make sure the remote host is running and connected.'
        }));
        return;
      }

      const hostData = hosts.get(partnerId);
      if (hostData.pin !== pin) {
        ws.send(JSON.stringify({
          type: 'connect_failed',
          message: 'Authentication failed: Incorrect Password / PIN'
        }));
        return;
      }

      // If already connected to another client, disconnect previous client
      if (hostData.clientWs && hostData.clientWs.readyState === WebSocket.OPEN) {
        hostData.clientWs.send(JSON.stringify({
          type: 'session_closed',
          message: 'Session terminated by a new incoming connection'
        }));
      }

      hostData.clientWs = ws;
      sessions.set(ws, partnerId);

      // Notify host of incoming client connection
      hostData.ws.send(JSON.stringify({
        type: 'client_connected',
        clientName: clientName || 'Remote Client',
        timestamp: Date.now()
      }));

      // Notify client of successful connection
      ws.send(JSON.stringify({
        type: 'connected',
        partnerId,
        deviceName: hostData.deviceName,
        width: hostData.width,
        height: hostData.height,
        message: 'Connected to remote host successfully!'
      }));

      console.log(`[+] Session established: Client -> Host ${partnerId}`);
      break;
    }

    case 'input': {
      // Forward input event from client to host
      const partnerId = sessions.get(ws);
      if (partnerId && hosts.has(partnerId)) {
        const hostData = hosts.get(partnerId);
        if (hostData.ws && hostData.ws.readyState === WebSocket.OPEN) {
          hostData.ws.send(JSON.stringify(data));
        }
      }
      break;
    }

    case 'control': {
      // Quality change, resolution request, or session command
      const partnerId = sessions.get(ws);
      if (partnerId && hosts.has(partnerId)) {
        const hostData = hosts.get(partnerId);
        if (hostData.ws && hostData.ws.readyState === WebSocket.OPEN) {
          hostData.ws.send(JSON.stringify(data));
        }
      }
      break;
    }

    case 'clipboard': {
      // Forward clipboard between peers
      if (sessions.has(ws)) {
        // Client sent clipboard to Host
        const partnerId = sessions.get(ws);
        const hostData = hosts.get(partnerId);
        if (hostData && hostData.ws && hostData.ws.readyState === WebSocket.OPEN) {
          hostData.ws.send(JSON.stringify(data));
        }
      } else if (sockets.has(ws)) {
        // Host sent clipboard to Client
        const partnerId = sockets.get(ws);
        const hostData = hosts.get(partnerId);
        if (hostData && hostData.clientWs && hostData.clientWs.readyState === WebSocket.OPEN) {
          hostData.clientWs.send(JSON.stringify(data));
        }
      }
      break;
    }

    case 'ping': {
      // Latency probe
      ws.send(JSON.stringify({ type: 'pong', timestamp: data.timestamp }));
      break;
    }

    case 'disconnect_session': {
      handleSessionEnd(ws);
      break;
    }

    default:
      console.log('[?] Unknown message type:', type);
  }
}

function handleSessionEnd(ws) {
  if (sessions.has(ws)) {
    const partnerId = sessions.get(ws);
    sessions.delete(ws);
    if (hosts.has(partnerId)) {
      const hostData = hosts.get(partnerId);
      hostData.clientWs = null;
      if (hostData.ws && hostData.ws.readyState === WebSocket.OPEN) {
        hostData.ws.send(JSON.stringify({ type: 'client_disconnected' }));
      }
    }
  }
}

function handleDisconnect(ws) {
  // If host disconnected
  if (sockets.has(ws)) {
    const partnerId = sockets.get(ws);
    sockets.delete(ws);
    if (hosts.has(partnerId)) {
      const hostData = hosts.get(partnerId);
      if (hostData.clientWs && hostData.clientWs.readyState === WebSocket.OPEN) {
        hostData.clientWs.send(JSON.stringify({
          type: 'session_closed',
          message: 'Remote host has disconnected'
        }));
      }
      hosts.delete(partnerId);
      console.log(`[-] Host offline: ${partnerId}`);
    }
  }

  // If client disconnected
  handleSessionEnd(ws);
}

// Keep-alive heartbeat
const heartbeat = setInterval(() => {
  wss.clients.forEach((ws) => {
    if (ws.isAlive === false) return ws.terminate();
    ws.isAlive = false;
    ws.ping();
  });
}, 25000);

wss.on('close', () => clearInterval(heartbeat));

server.listen(PORT, '0.0.0.0', () => {
  console.log(`====================================================`);
  console.log(`🚀 Remote Desktop Relay Server running on port ${PORT}`);
  console.log(`   Local URL: ws://localhost:${PORT}`);
  console.log(`   Health Check: http://localhost:${PORT}/health`);
  console.log(`====================================================`);
});
