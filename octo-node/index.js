import net from 'net';
import path from 'path';
import os from 'os';

import { Octokit } from "@octokit/rest";
const octokit = new Octokit();

const socketPath = process.argv[2];

const client = net.createConnection(socketPath, () => {
  console.log('Connected to Swift app:', socketPath);
});

client.on('data', (data) => {
  let message = JSON.parse(data.toString());
  let id = message.id;
  let method = message.method;
  
  if (method === 'githubListForOrg') {
    let orgName = message.params.orgName;
    console.log('Swift app requested', message);
    
    octokit.rest.repos
      .listForOrg({
        org: orgName,
        type: "public",
      })
      .then(({ data }) => {
        client.write(JSON.stringify({
          id: id,
          result: data.map(item => item.full_name)
        }));
      });
  }
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
