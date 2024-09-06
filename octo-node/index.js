import net from 'net';
import path from 'path';
import os from 'os';

// import { Octokit } from "@octokit/rest";
// const octokit = new Octokit();

class ChunkAssembler {
  constructor() {
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
  }
}

const socketPath = process.argv[2];

const client = net.createConnection(socketPath, () => {
  console.log('Connected to Swift app:', socketPath);
});

const assembler = new ChunkAssembler();
client.on('data', (data) => {
  assembler.processData(data.toString());
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
});

client.on('end', () => {
  console.log('Disconnected from Swift app');
});

client.on('error', (err) => {
  console.error('Connection error:', err);
});

process.on('SIGINT', () => {
  client.end();
  process.exit();
});
