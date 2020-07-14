const protons = require("protons");

const { Request, Stats } = protons(`
message Request {
  required int64 updatedSeed = 2;
}
`);

class Chat {
  /**
   *
   * @param {Libp2p} libp2p A Libp2p node to communicate through
   * @param {string} topic The topic to subscribe to
   * @param {function(Message)} messageHandler Called with every `Message` received on `topic`
   */
  constructor(libp2p, topic, messageHandler) {
    this.libp2p = libp2p;
    this.topic = topic;
    this.messageHandler = messageHandler;
    this.userHandles = new Map([[libp2p.peerId.toB58String(), "Me"]]);

    this.connectedPeers = new Set();
    this.libp2p.connectionManager.on("peer:connect", (connection) => {
      if (this.connectedPeers.has(connection.remotePeer.toB58String())) return;
      this.connectedPeers.add(connection.remotePeer.toB58String());
      //this.sendStats(Array.from(this.connectedPeers));
    });
    this.libp2p.connectionManager.on("peer:disconnect", (connection) => {
      if (this.connectedPeers.delete(connection.remotePeer.toB58String())) {
        //this.sendStats(Array.from(this.connectedPeers));
      }
    });

    // Join if libp2p is already on
    if (this.libp2p.isStarted()) this.join();
  }

  /**
   * Handler that is run when `this.libp2p` starts
   */
  onStart() {
    this.join();
  }

  /**
   * Handler that is run when `this.libp2p` stops
   */
  onStop() {
    this.leave();
  }

  /**
   * Subscribes to `Chat.topic`. All messages will be
   * forwarded to `messageHandler`
   * @private
   */
  join() {
    this.libp2p.pubsub.subscribe(this.topic, (message) => {
      try {
        const request = Request.decode(message.data);
        this.messageHandler(request);
      } catch (err) {
        console.error(err);
      }
    });
  }

  /**
   * Unsubscribes from `Chat.topic`
   * @private
   */
  leave() {
    this.libp2p.pubsub.unsubscribe(this.topic);
  }

  /**
   * Publishes the given `message` to pubsub peers
   * @throws
   * @param {Buffer|string} message The chat message to send
   */
  async send(seed) {
    const msg = Request.encode({
      updatedSeed: seed,
    });

    await this.libp2p.pubsub.publish(this.topic, msg);
  }
}

module.exports = Chat;
module.exports.TOPIC = "/libp2p/rayo/1.0.0";
module.exports.CLEARLINE = "\033[1A";
