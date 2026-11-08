// healthcheck.js - healthy only when the game itself answers.
//
// Sends Quake 3's out-of-band `getstatus` (\xff\xff\xff\xffgetstatus) through
// the same WebSocket players use, on 127.0.0.1:27960, and exits 0 only on a
// `statusResponse`. Only a running game loop writes one: the engine reads the
// packet in its frame and answers it there.
//
// NOT THE HANDSHAKE. Up to v1.6.1 the check opened a WebSocket and accepted
// 101 Switching Protocols, which the ws library answers by itself, before any
// game code runs. Every release up to v1.6.1 answered it while the server
// threw away every message a client sent (ws 8 changed the arguments of its
// message event, and the engine's socket layer dropped every packet as text),
// so no player could join and the container reported healthy throughout.
//
// NOT THE LOG. In QuakeJS (retail 1.32 game code) the intermission after the
// fraglimit ends only when a human is ready, and bots never are. An empty
// server can stand on the scoreboard for hours and write nothing, while it
// is perfectly well. getstatus is answered there too, and CI checks exactly
// that: fraglimit 1 with bots, the scoreboard, a silent log, then this.
'use strict';

const WebSocket = require('/quakejs/node_modules/ws');

const port = Number(process.env.QUAKE3_HEALTH_PORT || 27960);
const fail = (why) => {
  console.error(`unhealthy: ${why}`);
  process.exit(1);
};
const timer = setTimeout(() => fail('no statusResponse in 5 s'), 5000);
const ws = new WebSocket(`ws://127.0.0.1:${port}`);

ws.on('open', () => {
  ws.send(Buffer.concat([Buffer.from([0xff, 0xff, 0xff, 0xff]), Buffer.from('getstatus\n')]));
});
ws.on('message', (data) => {
  const b = Buffer.from(data);
  if (b.length >= 18 && b.readUInt32LE(0) === 0xffffffff && b.toString('latin1', 4, 18) === 'statusResponse') {
    clearTimeout(timer);
    console.log('healthy: the game answered getstatus');
    process.exit(0);
  }
});
ws.on('error', (e) => fail(e.message));
