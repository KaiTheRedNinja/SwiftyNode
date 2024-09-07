import net from 'net';
import path from 'path';
import os from 'os';

// import { Octokit } from "@octokit/rest";
// const octokit = new Octokit();

class ChunkAssembler {
  constructor(chunkCallback) {
    this.chunkCallback = chunkCallback;
    this.buffer = '';
    this.chunks = new Map();
  }

  processData(data) {
    this.buffer += data;
    this.extractChunks();
  }

  extractChunks() {
    const regex = /\[START: (\d+)\]([\s\S]*?)\[END: \1\]/g;
    let match;

    while ((match = regex.exec(this.buffer)) !== null) {
      const [fullMatch, id, content] = match;
      this.processChunk(parseInt(id), content.trim());
      this.buffer = this.buffer.slice(match.index + fullMatch.length);
      regex.lastIndex = 0; // Reset regex index after modifying the buffer
    }
  }

  processChunk(id, content) {
    // Call the external processChunk function here
    console.log('Received chunk ', id, ':', content);
    this.chunkCallback(content);
  }
}

class Mutex {
  constructor() {
    this.locked = false;
    this.queue = [];
  }

  lock() {
    return new Promise((resolve) => {
      if (this.locked) {
        this.queue.push(resolve);
      } else {
        this.locked = true;
        resolve();
      }
    });
  }

  unlock() {
    if (this.queue.length > 0) {
      const nextResolve = this.queue.shift();
      nextResolve();
    } else {
      this.locked = false;
    }
  }
}

class SwiftCommunicator {
  constructor(socketPath) {
    this.socketPath = socketPath;
    this.mutex = new Mutex();
    this.assembler = new ChunkAssembler((content) => {
      this.processChunk(content);
    });
    this.client = net.createConnection(socketPath, () => {
      console.log('Connected to Swift app:', socketPath);
    });

    this.client.on('data', (data) => {
      this.assembler.processData(data.toString());
    });

    this.client.on('end', () => {
      console.log('Disconnected from Swift app');
    });

    this.client.on('error', (err) => {
      console.error('Connection error:', err);
    });
  }

  terminate() {
    this.client.end();
  }

  processChunk(content) {
    let message = JSON.parse(content);
    // Process the chunk here
    console.log('Processing chunk:', content);
    this.write('Hello from JS: ' + message.method);
  }

  sendRequest(request) {
    this.client.write(JSON.stringify(request));
  }

  write(data) {
    // generate a random id between 0 and 10_000
    const id = Math.floor(Math.random() * 10_000);
    const chunk = `[START: ${id}]\n${data}\n[END: ${id}]\n`;
    this.mutex.lock()
      .then(() => {
        this.client.write(chunk, () => {
          this.mutex.unlock();
        });
      });
  }
}

const socketPath = process.argv[2];

const communicator = new SwiftCommunicator(socketPath);

// let message = JSON.parse(data.toString());
// let id = message.id;
// let method = message.method;

// if (method === 'githubListForOrg') {
//   let orgName = message.params.orgName;
//   console.log('Swift app requested', message);
  
//   octokit.rest.repos
//     .listForOrg({
//       org: orgName,
//       type: "public",
//     })
//     .then(({ data }) => {
//       client.write(JSON.stringify({
//         id: id,
//         result: data.map(item => item.full_name)
//       }));
//     });
// }

process.on('SIGINT', () => {
  communicator.terminate();
  process.exit();
});
