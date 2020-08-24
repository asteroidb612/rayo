"use strict";

import { Elm } from "./src/Main.elm";

// Libp2p Core
const Libp2p = require("libp2p");
// Transports
const Websockets = require("libp2p-websockets");
const WebrtcStar = require("libp2p-webrtc-star");
const wrtc = require("wrtc");
// Stream Muxer
const Mplex = require("libp2p-mplex");
// Connection Encryption
const { NOISE } = require("libp2p-noise");
const Secio = require("libp2p-secio");
// Chat over Pubsub
const PubsubChat = require("./chat");
// Peer Discovery
const Bootstrap = require("libp2p-bootstrap");
const KadDHT = require("libp2p-kad-dht");
// PubSub implementation
const Gossipsub = require("libp2p-gossipsub");

const app = Elm.Main.init({ node: document.getElementById("elm") });

async function main() {
  // Create the Node
  const libp2p = await Libp2p.create({
    addresses: {
      listen: [`/dns4/wrtc-star2.sjc.dwebops.pub/tcp/443/wss/p2p-webrtc-star`],
    },
    modules: {
      transport: [Websockets, WebrtcStar],
      streamMuxer: [Mplex],
      connEncryption: [NOISE, Secio],
      peerDiscovery: [Bootstrap],
      dht: KadDHT,
      pubsub: Gossipsub,
    },
    config: {
      transport: {
        [WebrtcStar.prototype[Symbol.toStringTag]]: {
          wrtc,
        },
      },
      peerDiscovery: {
        bootstrap: {
          list: [
            "/dnsaddr/sjc-1.bootstrap.libp2p.io/tcp/4001/ipfs/QmNnooDu7bfjPFoTZYxMNLWUQJyrVwtbZg5gBMjTezGAJN",
          ],
        },
      },
      dht: {
        enabled: true,
        randomWalk: {
          enabled: true,
        },
      },
    },
  });

  // Listen on libp2p for `peer:connect` and log the provided connection.remotePeer.toB58String() peer id string.
  libp2p.connectionManager.on("peer:connect", (connection) => {
    console.info(`Connected to ${connection.remotePeer.toB58String()}!`);
  });

  // Start libp2p
  await libp2p.start();

  // Log our PeerId and Multiaddrs
  console.info(`${libp2p.peerId.toB58String()} listening on addresses:`);
  console.info(
    libp2p.multiaddrs.map((addr) => addr.toString()).join("\n"),
    "\n"
  );

  var currentNumber = 0;

  // Create our PubsubChat client
  const pubsubChat = new PubsubChat(
    libp2p,
    PubsubChat.TOPIC,
    ({ from, message }) => {
      let fromMe = from === libp2p.peerId.toB58String();
      let user = from.substring(0, 6);
      if (pubsubChat.userHandles.has(from)) {
        user = pubsubChat.userHandles.get(from);
      }
      console.info(
        `${fromMe ? PubsubChat.CLEARLINE : ""}${user}(${new Date(
          message.created
        ).toLocaleTimeString()}): ${message.data}`
      );
    },
    ({ seed }) => {
      app.ports.changes.send(seed);
    }
  );

  // Set up our input handler
  setInterval(async () => {
    // Remove trailing newline
    // If there was a command, exit early
    //if (pubsubChat.checkCommand("")) return;

    try {
      // Publish the message
      await pubsubChat.send("Checking in");
    } catch (err) {
      console.error("Could not publish chat", err);
    }
  }, 1000);

  async function roll() {
    try {
      await pubsubChat.sendNumber();
    } catch (err) {
      console.error("Could not publish number", err);
    }
  }

  //Roll at random intervals
  //setInterval(roll, 10000 + 5000 * Math.random());
  // Roll on click
  app.ports.roll.subscribe(roll);
}

main();
