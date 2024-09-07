import net from 'net';
import { v4 as uuidv4 } from 'uuid';

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
    this.callResponses = new Map();
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

  notify(method, params) {
    this.write(JSON.stringify({
      method: method,
      params: params
    }));
  }

  request(method, params) {
    const id = uuidv4();
    this.write(JSON.stringify({
      method: method,
      params: params,
      id: id,
    }));

    return new Promise((resolve, reject) => {
      // store the resolve and reject functions in the callResponses map, with the id as the key
      this.callResponses.set(id, { resolve, reject });

      console.log(`Promise created for id: ${id}`);
    });
  }

  register(name, callback) {
    this.functions.set(name, callback);
  }

  terminate() {
    this.client.end();
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
  
  processChunk(content) {
    console.log("Got chunk: ", content);
    let message = JSON.parse(content);
    let method = message.method;
    let id = message.id;

    if (method) { // request by swift for node to process
      let params = message.params;
      this.processRequest(method, params, id);
    } else { // response from swift to node
      let result = message.result;
      let error = message.error;
      this.processResponse(result, error, id);
    }
  }

  processRequest(method, params, id) {
    console.log("Calling method: ", method);

    // determine if the method exists, send an error back if the method is not found
    if (!this.functions.has(method)) {
      console.error("Method not found: ", method);
      this.write(JSON.stringify({
        id: id,
        error: {
          code: -32601,
          message: "Method not found"
        }
      }));
      return
    }

    // call the method
    let call = this.functions.get(method)(params, )

    // if message has an id, we need to send a response
    if (id) {
      call
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
    }
    // else, just call the method without sending a response. No extra work to be done.
  }

  processResponse(result, error, id) {
    console.log(`Processing response for id: ${id}: ${result}`);

    let promise = this.callResponses.get(id);

    if (promise) {
      if (error) {
        promise.reject(error);
      } else {
        promise.resolve(result);
      }

      this.callResponses.delete(id);
    }
  }
}
