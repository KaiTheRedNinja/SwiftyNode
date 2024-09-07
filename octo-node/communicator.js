import net from 'net';

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

export class SwiftCommunicator {
  constructor(socketPath) {
    this.socketPath = socketPath;
    this.mutex = new Mutex();
    this.functions = new Map();
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

  registerFunction(name, callback) {
    this.functions.set(name, callback);
  }
  
  terminate() {
    this.client.end();
  }
  
  processChunk(content) {
    let message = JSON.parse(content);
    let method = message.method;
    let params = message.params;
    let id = message.id;

    console.log("Calling method: ", method);

    // if message has an id, we need to send a response
    if (id) {
      if (this.functions.has(method)) {
        this.functions.get(method)(params, )
          .then((result) => {
            this.write(JSON.stringify({
              id: id,
              result: result
            }));
          })
          .catch((error) => {
            this.write(JSON.stringify({
              id: id,
              error: {
                code: -32000,
                message: error.message
              }
            }));
          });
      } else {
        console.error("Call method not found: ", method);
        this.write(JSON.stringify({
          id: id,
          error: {
            code: -32601,
            message: "Method not found"
          }
        }));
      }
    } else {
      // just call the method without sending a response
      if (this.functions.has(method)) {
        this.functions.get(method)(params);
      } else {
        console.error("Notification method not found: ", method);
      }
    }
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
