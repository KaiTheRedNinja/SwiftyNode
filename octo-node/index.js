import net from 'net';
import path from 'path';
import os from 'os';

// The communication URL will always be the second argument
const socketPath = process.argv[2];
console.log(socketPath);

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
