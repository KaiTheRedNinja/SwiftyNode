import { SwiftCommunicator } from './communicator.js';

import { Octokit } from "@octokit/rest";
const octokit = new Octokit();

const communicator = new SwiftCommunicator(process.argv[2]);

communicator.registerFunction('githubListForOrg', (params) => {
  let orgName = params.orgName;
  
  return octokit.rest.repos
    .listForOrg({
      org: orgName,
      type: "public",
    })
    .then(({ data }) => {
      return data.map(item => item.full_name)
    });
});

communicator.registerFunction('echo', (params) => {
  communicator.notify('echo', params);
  return Promise.resolve();
});

process.on('SIGINT', () => {
  communicator.terminate();
  process.exit();
});
