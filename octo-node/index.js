import { SwiftCommunicator } from './communicator.js';

import { Octokit } from "@octokit/rest";
const octokit = new Octokit();

const communicator = new SwiftCommunicator(process.argv[2]);

communicator.notify('drawButtons', {
  buttons: [
    { title: "This is a button", id: "button1" },
    { title: "Idk if they do anything rn", id: "button2" }
  ]
});

communicator.register('buttonPressed', (params) => {
  console.log('Button pressed:', params.id);
  communicator.notify('writeToTextDisplay', {
    text: `Button ${params.id} was pressed`
  });
});

// communicator.register('githubListForOrg', (params) => {
//   let orgName = params.orgName;
  
//   return octokit.rest.repos
//     .listForOrg({
//       org: orgName,
//       type: "public",
//     })
//     .then(({ data }) => {
//       return data.map(item => item.full_name)
//     });
// });

// communicator.register('nodeEcho', (params) => {
//   communicator.request('swiftEcho', params)
//     .then((response) => {
//       console.log('Echo response from Swift:', response);
//     });
//   return Promise.resolve();
// });
