#!/usr/bin/env bash
<<COMMENT
Uploads a Lambda artifact to S3 and then
updates the Lambda function to point to the uploaded file.

Required environment variables:
- AWS creds
- CIRCLE_BUILD_NUM
- CIRCLE_PROJECT_REPONAME

Arguments:
  $1 = environment (e.g. UAT)
  $2 = lambda function name (defaults to the CIRCLE_PROJECT_REPONAME if unset)
COMMENT

set -e

build_num=${CIRCLE_BUILD_NUM?"Build number is not set. Am I running in CircleCI?"}
repo=${CIRCLE_PROJECT_REPONAME?"Repo name is not set. Am I running in CircleCI?"}
region=${AWS_REGION:-"eu-west-1"}

environment=${1:-Environment must be passed as second argument}
function_name=${2:-$repo}

basedir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
artifact=$basedir/target/scala-2.*/*-assembly-*.jar

environment_function_name="${function_name}-${environment}"
zipfile_name=lambda.zip

s3_bucket=ovo-comms-platform-lambdas
s3_key="$lambda_name/$build_num/$zipfile_name"

# Upload the artifact to S3
aws --region "$region" \
  s3 cp $artifact "s3://$s3_bucket/$s3_key"

# Update the Lambda to point to the new artifact
aws --region "$region" \
  lambda update-function-code \
  --function-name "$environment_function_name" \
  --s3-bucket "$s3_bucket" \
  --s3-key "$s3_key"
