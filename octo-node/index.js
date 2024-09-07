import { SwiftCommunicator } from './communicator.js';

import { Octokit } from "@octokit/rest";
const octokit = new Octokit();

const communicator = new SwiftCommunicator(process.argv[2]);

communicator.register('githubListForOrg', (params) => {
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

communicator.register('echo', (params) => {
  communicator.notify('echo', params);
  return Promise.resolve();
});

process.on('SIGINT', () => {
  communicator.terminate();
  process.exit();
});
