import net from 'net';
import path from 'path';
import os from 'os';

const socketPath = process.argv[2];

const client = net.createConnection(socketPath, () => {
  console.log('Connected to Swift app:', socketPath);
});

client.on('data', (data) => {
  let message = JSON.parse(data.toString());
  let id = message.id;
  let method = message.method;
  console.log('Swift app requested', method);
  client.write(JSON.stringify({
    id: id,
    result: {
      calledMethod: method,
      success: true
    }
  }));
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

// import { Octokit } from "@octokit/rest";

// const octokit = new Octokit();

// octokit.rest.repos
//   .listForOrg({
//     org: "CodeEditApp",
//     type: "public",
//   })
//   .then(({ data }) => {
//     console.log(data)
//   });
