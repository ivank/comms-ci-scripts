#!/usr/bin/env bash
<<COMMENT
Notify :shipit: about a successful deployment.

Should work regardless of whether the PR was merged normally
or 'squash and merge'd.

Required environment variables:
- GITHUB_TOKEN = a GitHub API token with 'repo' scope
- CIRCLE_PROJECT_REPONAME = the GitHub repo name
- CIRCLE_BUILD_NUM
- CIRCLE_BUILD_URL
- SHIPIT_KEY

Arguments: none

Note that we're being naughty here and using the deprecated
merge_commit_sha field in the GitHub Pull Requests API.
Unfortunately there's no other reliable way to work out which PR was merged.
Roberto, who knows more about GitHub than most people, agrees:
https://github.com/guardian/prout/commit/9ec95ec6266eabed1b3f5a2779f2a0e57026d812
COMMENT

set -e

access_token=${GITHUB_TOKEN?"GitHub token must be set as an environment variable"}
repo=${CIRCLE_PROJECT_REPONAME?"Repo name is not set. Am I running in CircleCI?"}
build_num=${CIRCLE_BUILD_NUM?"Build number is not set. Am I running in CircleCI?"}
build_url=${CIRCLE_BUILD_URL?"Build URL is not set. Am I running in CircleCI?"}
shipit_key=${SHIPIT_KEY?"shipit API key must be set as an environment variable"}
git_sha1="${CIRCLE_SHA1:-$(git rev-parse HEAD)}"

team=comms
service=${repo#comms-}

api_url() {
  path_and_query=$1
  separator="?"
  if [[ "$path_and_query" == *"?"* ]]; then
    separator="&"
  fi
  echo "https://api.github.com/repos/ovotech/$repo/$path_and_query${separator}access_token=$access_token"
}

notify_shipit() {
  if [ "$merged_pr_number" == "" ]; then
    curl -s -X POST "https://shipit.ovotech.org.uk/deployments?apikey=$shipit_key" \
      -d "team=$team" \
      -d "service=$service" \
      -d "buildId=$build_num" \
      -d "links[0].title=CircleCI build" \
      -d "links[0].url=$build_url"
  else
    curl -s -X POST "https://shipit.ovo-comms.co.uk/deployments?apikey=$shipit_key" \
      -d "team=$team" \
      -d "service=$service" \
      -d "buildId=$build_num" \
      -d "links[0].title=CircleCI build" \
      -d "links[0].url=$build_url" \
      -d "links[1].title=Pull Request" \
      -d "links[1].url=https://github.com/ovotech/$repo/pull/$merged_pr_number"
  fi
}

# Find the PR whose merge commit == the current HEAD
merged_pr_number=$(curl -s $(api_url "pulls?state=closed&base=master&sort=updated&direction=desc") | \
  jq ".[] | select(.merge_commit_sha == \"$git_sha1\").number")

notify_shipit
