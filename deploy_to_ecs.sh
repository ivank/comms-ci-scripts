#!/usr/bin/env bash
<<COMMENT
Deployment script for services running on AWS EC2 Container Service (ECS).

Creates a new revision of the ECS task definition and then updates the service to use that revision.

Based on https://github.com/circleci/go-ecs-ecr/blob/master/deploy.sh

Assumptions:
- The task definition contains only one container
- Service name == container name
- Family name = $service_name-$environment, e.g. "composer-UAT"
- The Docker image has already been published
- The service already exists

The script builds container definitions by substituting placeholders
in a template. The template can include the following placeholders:
- @@VERSION
- @@AWS_ACCOUNT_ID
- @@ENV

Required environment variables:
- AWS creds
- AWS_ACCOUNT_ID

Arguments:
- $1 = environment (e.g. "UAT")
- $2 = template file (relative to project basedir, e.g. "containers.template.json")
COMMENT

set -e

usage() {
  echo "deploy_to_ecs.sh [-s service name] [-c cluster name] -t [timeout in seconds] <environment> <template>" >&2
}

while getopts "s:c:w:" opt; do
  case $opt in
    s)
      custom_service_name=$OPTARG
      ;;
    c)
      custom_cluster_name=$OPTARG
      ;;
    t)
      custom_timeout=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      ;;
  esac
done

shift "$((OPTIND-1))"
environment=${1?"Environment must be specified"}
template_path=${2?"Container definitions template file must be specified"}
timeout=${custom_timeout:-"180"}
cluster_name=${custom_cluster_name:-"ecs-cluster-$environment"}
service_name=${custom_service_name:-"$CIRCLE_PROJECT_REPONAME"}
task_family="$service_name-$environment"

git_sha1="${CIRCLE_SHA1:-$(git rev-parse HEAD)}"
region=${AWS_REGION:-"eu-west-1"}

basedir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
template=$basedir/$template_path

echo "Deploying version $git_sha1 to ECS in $environment environment."

# more bash-friendly output for jq
JQ="jq --raw-output --exit-status"

configure_aws_cli(){
  aws --version
  aws configure set default.region $region
  aws configure set default.output json
}

make_container_definitions() {
  container_definitions=$(
    sed -e "
      s/@@VERSION/$git_sha1/g;
      s/@@AWS_ACCOUNT_ID/$AWS_ACCOUNT_ID/g;
      s/@@ENV/$environment/g
    " $template
  ) 
}

get_task_role_arn() {
  currentTaskDefinitionArn=$(aws ecs describe-services --cluster "$cluster_name" --services "$service_name" | $JQ '.services[0].taskDefinition')
  taskRoleArn=$(aws ecs describe-task-definition --task-definition "$currentTaskDefinitionArn" | jq --raw-output '.taskDefinition.taskRoleArn')
}

register_task_definition() {
  if [ ! -z "$taskRoleArn" -a "$taskRoleArn" != "null" ]; then 
    # If the currently deployed task has an associated role, make sure to preserve it
    cmd_output=$(aws ecs register-task-definition --container-definitions "$container_definitions" --family "$task_family" --task-role-arn "$taskRoleArn")
  else
    cmd_output=$(aws ecs register-task-definition --container-definitions "$container_definitions" --family "$task_family")
  fi
  if revisionArn=$(echo $cmd_output | $JQ '.taskDefinition.taskDefinitionArn'); then
    echo "Revision: $revisionArn"
  else
    echo "Failed to register task definition"
    return 1
  fi
}

update_service() {
  if [[ $(aws ecs update-service --cluster "$cluster_name" --service "$service_name" --task-definition "$revisionArn" | \
    $JQ '.service.taskDefinition') != "$revisionArn" ]]
  then
    echo "Error updating service."
    return 1
  fi
}

await_stabilization() {
  # wait for older revisions to disappear
  interval=5
  attempts=$(( $timeout / $interval ))
  for attempt in $(seq 1 $attempts); do
    echo "Attempt $attempt of $attempts" 
    if stale=$(aws ecs describe-services --cluster "$cluster_name" --services "$service_name" | \
      $JQ ".services[0].deployments | .[] | select(.taskDefinition != \"$revisionArn\") | .taskDefinition")
    then
      echo "Waiting for stale deployments:"
      echo "$stale"
      sleep $interval
    else
      echo "Deployed!"
      return 0
    fi
  done
  echo "Service update took too long."
  return 1
}

deploy_to_ecs() {
  get_task_role_arn
  make_container_definitions
  register_task_definition
  update_service
  await_stabilization
}

configure_aws_cli
deploy_to_ecs
