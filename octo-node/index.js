import net from 'net';
import path from 'path';
import os from 'os';

const socketPath = process.argv[2];

const server = net.createServer((socket) => {
  console.log('Swift app connected');

  socket.on('data', (data) => {
    console.log('Swift app requested', data.toString());
  });

  socket.on('end', () => {
    console.log('Swift app disconnected');
  });
});

server.listen(socketPath, () => {
  console.log('Node.js server listening on', socketPath);
});

process.on('SIGINT', () => {
  server.close();
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
