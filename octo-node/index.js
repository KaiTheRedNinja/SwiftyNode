import { Octokit } from "@octokit/rest";

const octokit = new Octokit();

octokit.rest.repos
  .listForOrg({
    org: "CodeEditApp",
    type: "public",
  })
  .then(({ data }) => {
    console.log(data)
  });
