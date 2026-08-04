const express = require('express');
const cors = require('cors');
const { AccessToken, RoomServiceClient } = require('livekit-server-sdk');

const app = express();
app.use(cors());
app.use(express.json());

const LIVEKIT_API_KEY = process.env.LIVEKIT_API_KEY;
const LIVEKIT_API_SECRET = process.env.LIVEKIT_API_SECRET;
const LIVEKIT_WS_URL = process.env.LIVEKIT_WS_URL || 'ws://localhost:7880';
const LIVEKIT_HOST = process.env.LIVEKIT_HOST || 'http://livekit:7880';
const PORT = process.env.PORT || 8081;

const roomService = new RoomServiceClient(LIVEKIT_HOST, LIVEKIT_API_KEY, LIVEKIT_API_SECRET);
const roomPasswords = new Map();
const roomAdmins = new Map(); // room -> Set of admin identities
const roomDefaultMute = new Map(); // room -> boolean

function isAdmin(room, identity) {
  const admins = roomAdmins.get(room);
  return admins && admins.has(identity);
}

app.post('/token', async (req, res) => {
  const { room, identity, password, isOwner } = req.body;
  if (!room || !identity) {
    return res.status(400).json({ error: 'room and identity required' });
  }

  const storedPassword = roomPasswords.get(room);
  if (storedPassword && password !== storedPassword) {
    return res.status(403).json({ error: 'Contraseña incorrecta' });
  }

  if (isOwner) {
    if (!roomAdmins.has(room)) roomAdmins.set(room, new Set());
    roomAdmins.get(room).add(identity);
  }

  const defaultMute = !isOwner && roomDefaultMute.get(room) === true;
  const at = new AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET, {
    identity,
    ttl: '24h',
    metadata: JSON.stringify({ defaultMute }),
  });

  const grants = { roomJoin: true, roomCreate: true, room };
  if (isOwner) {
    grants.roomAdmin = true;
  }
  at.addGrant(grants);

  try {
    const token = await at.toJwt();
    res.json({ token, wsUrl: LIVEKIT_WS_URL, isOwner: !!isOwner, defaultMute });
  } catch (err) {
    res.status(500).json({ error: 'Failed to generate token' });
  }
});

app.post('/set-password', async (req, res) => {
  const { room, password, identity } = req.body;
  if (!room || !identity) {
    return res.status(400).json({ error: 'room and identity required' });
  }

  if (!isAdmin(room, identity)) {
    return res.status(403).json({ error: 'No eres administrador de la sala' });
  }

  if (password) {
    roomPasswords.set(room, password);
  } else {
    roomPasswords.delete(room);
  }
  res.json({ ok: true, hasPassword: !!password });
});

app.post('/admin/kick', async (req, res) => {
  const { room, identity, targetIdentity } = req.body;
  if (!room || !identity || !targetIdentity) {
    return res.status(400).json({ error: 'room, identity and targetIdentity required' });
  }

  if (!isAdmin(room, identity)) {
    return res.status(403).json({ error: 'No eres administrador de la sala' });
  }

  try {
    await roomService.removeParticipant(room, targetIdentity);
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: 'Error al expulsar: ' + err.message });
  }
});

app.post('/admin/mute', async (req, res) => {
  const { room, identity, targetIdentity, trackSid, muted } = req.body;
  if (!room || !identity || !targetIdentity || !trackSid) {
    return res.status(400).json({ error: 'room, identity, targetIdentity and trackSid required' });
  }

  if (!isAdmin(room, identity)) {
    return res.status(403).json({ error: 'No eres administrador de la sala' });
  }

  try {
    await roomService.mutePublishedTrack(room, targetIdentity, trackSid, muted !== false);
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: 'Error al silenciar: ' + err.message });
  }
});

app.post('/admin/lock-room', async (req, res) => {
  const { room, identity, locked } = req.body;
  if (!room || !identity) {
    return res.status(400).json({ error: 'room and identity required' });
  }

  if (!isAdmin(room, identity)) {
    return res.status(403).json({ error: 'No eres administrador de la sala' });
  }

  try {
    const metadata = JSON.stringify({ locked: locked !== false });
    await roomService.updateRoomMetadata(room, metadata);
    res.json({ ok: true, locked: locked !== false });
  } catch (err) {
    res.status(500).json({ error: 'Error al bloquear sala: ' + err.message });
  }
});

app.post('/admin/set-default-mute', async (req, res) => {
  const { room, identity, defaultMute } = req.body;
  if (!room || !identity) {
    return res.status(400).json({ error: 'room and identity required' });
  }

  if (!isAdmin(room, identity)) {
    return res.status(403).json({ error: 'No eres administrador de la sala' });
  }

  try {
    const muted = defaultMute === true;
    roomDefaultMute.set(room, muted);
    res.json({ ok: true, defaultMute: muted });
  } catch (err) {
    res.status(500).json({ error: 'Error al configurar silencio por defecto: ' + err.message });
  }
});

app.post('/admin/end-room', async (req, res) => {
  const { room, identity } = req.body;
  if (!room || !identity) {
    return res.status(400).json({ error: 'room and identity required' });
  }

  if (!isAdmin(room, identity)) {
    return res.status(403).json({ error: 'No eres administrador de la sala' });
  }

  try {
    const participants = await roomService.listParticipants(room);
    for (const p of participants) {
      if (p.identity !== identity) {
        await roomService.removeParticipant(room, p.identity);
      }
    }
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: 'Error al finalizar sala: ' + err.message });
  }
});

app.post('/admin/update-permissions', async (req, res) => {
  const { room, identity, targetIdentity, canPublish, canSubscribe } = req.body;
  if (!room || !identity || !targetIdentity) {
    return res.status(400).json({ error: 'room, identity and targetIdentity required' });
  }

  if (!isAdmin(room, identity)) {
    return res.status(403).json({ error: 'No eres administrador de la sala' });
  }

  try {
    const permission = {};
    if (canPublish !== undefined) permission.canPublish = canPublish;
    if (canSubscribe !== undefined) permission.canSubscribe = canSubscribe;
    await roomService.updateParticipant(room, targetIdentity, permission);
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: 'Error al actualizar permisos: ' + err.message });
  }
});

app.post('/check-room', (req, res) => {
  const { room } = req.body;
  if (!room) return res.status(400).json({ error: 'room required' });
  const admins = roomAdmins.get(room);
  res.json({
    hasPassword: roomPasswords.has(room),
    hasOwner: admins && admins.size > 0,
    owner: admins ? Array.from(admins)[0] || null : null,
    defaultMute: roomDefaultMute.get(room) === true,
  });
});

app.get('/health', (_req, res) => {
  res.json({ ok: true, livekit: LIVEKIT_WS_URL });
});

app.listen(PORT, () => {
  console.log(`LiveKit token server running on :${PORT}`);
  console.log(`  WS URL: ${LIVEKIT_WS_URL}`);
  console.log(`  LiveKit Host: ${LIVEKIT_HOST}`);
});
