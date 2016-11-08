#!/usr/bin/env bash
<<COMMENT
Attempts to leave a comment on the last merged PR
to indicate that it has successfully deployed to production.

Should work regardless of whether the PR was merged normally
or 'squash and merge'd.

Required environment variables:
- GITHUB_TOKEN = a GitHub API token with 'repo' scope
- CIRCLE_PROJECT_REPONAME = the GitHub repo name
- CIRCLE_BUILD_NUM
- CIRCLE_BUILD_URL

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
git_sha1="${CIRCLE_SHA1:-$(git rev-parse HEAD)}"

api_url() {
  path_and_query=$1
  separator="?"
  if [[ "$path_and_query" == *"?"* ]]; then
    separator="&"
  fi
  echo "https://api.github.com/repos/ovotech/$repo/$path_and_query${separator}access_token=$access_token"
}

post_comment() {
  timestamp=$(TZ=Europe/London date "+%Y-%m-%d %H:%M %Z")
  curl -s -X POST -H "Content-Type: application/json" \
    $(api_url "issues/$merged_pr_number/comments") \
    -d "{ \"body\": \"This PR was successfully deployed to production by [CircleCI build $build_num]($build_url) at $timestamp.\" }"
}

# Find the PR whose merge commit == the current HEAD
merged_pr_number=$(curl -s $(api_url "pulls?state=closed&base=master&sort=updated&direction=desc") | \
  jq ".[] | select(.merge_commit_sha == \"$git_sha1\").number")

if [ "$merged_pr_number" != "" ]
then
  echo "Looks like this was a merge commit for PR #$merged_pr_number. Leaving a comment on the PR."
  post_comment
else
  echo "Looks like this was NOT a merge commit for a PR. Nothing to do."
fi
