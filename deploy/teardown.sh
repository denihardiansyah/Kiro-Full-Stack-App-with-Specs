#!/usr/bin/env bash
#
# Delete the ECS Fargate stack created by deploy.sh. The ECR repository and its
# images are kept unless DELETE_ECR=true is passed explicitly.
#
# Usage:
#   ./deploy/teardown.sh
#   DELETE_ECR=true ./deploy/teardown.sh

set -euo pipefail

command -v aws >/dev/null 2>&1 || { echo "error: 'aws' is required but not found in PATH." >&2; exit 1; }

PROJECT_NAME="${PROJECT_NAME:-kiro-builder-lab}"
STACK_NAME="${STACK_NAME:-${PROJECT_NAME}}"
AWS_REGION="${AWS_REGION:-$(aws configure get region || true)}"
AWS_REGION="${AWS_REGION:-ap-southeast-1}"
DELETE_ECR="${DELETE_ECR:-false}"

echo "This will delete CloudFormation stack '${STACK_NAME}' in ${AWS_REGION},"
echo "including the VPC, load balancer, ECS cluster, and CloudWatch log group."
if [[ "$DELETE_ECR" == "true" ]]; then
  echo "It will ALSO delete the ECR repository '${PROJECT_NAME}' and every image in it."
fi
read -r -p "Type the stack name to confirm: " CONFIRM
[[ "$CONFIRM" == "$STACK_NAME" ]] || { echo "Aborted."; exit 1; }

echo "==> Deleting stack ${STACK_NAME}"
aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$AWS_REGION"
aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" --region "$AWS_REGION"
echo "    stack deleted"

if [[ "$DELETE_ECR" == "true" ]]; then
  echo "==> Deleting ECR repository ${PROJECT_NAME}"
  aws ecr delete-repository --repository-name "$PROJECT_NAME" --region "$AWS_REGION" --force >/dev/null
  echo "    repository deleted"
else
  echo
  echo "ECR repository '${PROJECT_NAME}' was kept. Images still incur storage cost."
  echo "Remove it with: DELETE_ECR=true ./deploy/teardown.sh"
fi
