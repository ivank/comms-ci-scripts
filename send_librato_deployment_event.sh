#!/usr/bin/env bash
<<COMMENT
Attempt to leave a comment on the last merged PR
to indicate that it has successfully deployed to production.

Required environment variables:
- LIBRATO_USERNAME
- LIBRATO_TOKEN
- CIRCLE_PROJECT_REPONAME
- CIRCLE_BUILD_NUM
- CIRCLE_BUILD_URL

Arguments: none

COMMENT

librato_username=${LIBRATO_USERNAME?"Librato username and token must be set as environment variables"}
librato_token=${LIBRATO_TOKEN?"Librato username and token must be set as environment variables"}
repo=${CIRCLE_PROJECT_REPONAME?"Repo name is not set. Am I running in CircleCI?"}
build_num=${CIRCLE_BUILD_NUM?"Build number is not set. Am I running in CircleCI?"}
build_url=${CIRCLE_BUILD_URL?"Build URL is not set. Am I running in CircleCI?"}
git_sha1="${CIRCLE_SHA1:-$(git rev-parse HEAD)}"

curl -s -X POST \
  "https://metrics-api.librato.com/v1/annotations/${repo}-deployments" \
  -u "${librato_username}:${librato_token}" \
  -d "title=Deployed build #$build_num of $repo" \
  -d "links[0][label]=CircleCI build" \
  -d "links[0][href]=$build_url" \
  -d "links[0][rel]=circleci" \
  -d "links[1][label]=View commit on GitHub" \
  -d "links[1][href]=https://github.com/ovotech/${repo}/commit/$git_sha1" \
  -d "links[1][rel]=github"
