#!/usr/bin/env bash
<<COMMENT
Wrapper around `sbt docker:publish`.

Assumes that sbt will take care of logging into ECR before publishing.

Publishes a Docker image tagged with the git SHA1
and also tagged as "latest".

Required environment variables: none
Arguments: none
COMMENT

git_sha1="${CIRCLE_SHA1:-$(git rev-parse HEAD)}"

echo Publishing docker image to ECR with version $git_sha1

# Assume sbt is in charge of logging in to ECR
sbt "; set version := \"$git_sha1\"; set dockerUpdateLatest := true; docker:publish"


