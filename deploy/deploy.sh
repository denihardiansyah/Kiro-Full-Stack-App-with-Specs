#!/usr/bin/env bash
#
# Deploy the static guide to ECS Fargate.
#
# Two image sources are supported:
#
#   A. Build locally and push to Amazon ECR (default)
#        ./deploy/deploy.sh
#
#   B. Use an image already published elsewhere, e.g. GitHub Container Registry.
#      Docker is not required in this mode; nothing is built or pushed.
#        IMAGE_URI=ghcr.io/owner/workshop-kiro:sha-abc123 ./deploy/deploy.sh
#
#      For a PRIVATE GHCR package, also pass a Secrets Manager secret holding
#      {"username":"<github-user>","password":"<PAT with read:packages>"}:
#        IMAGE_URI=ghcr.io/owner/workshop-kiro:sha-abc123 \
#        REPOSITORY_CREDENTIALS_SECRET_ARN=arn:aws:secretsmanager:...:secret:ghcr-xxxx \
#        ./deploy/deploy.sh
#
# Other options:
#   AWS_REGION, PROJECT_NAME, STACK_NAME, IMAGE_TAG, DESIRED_COUNT,
#   TASK_SIZE (256/512, 256/1024, 512/1024, 512/2048, 1024/2048, 1024/4096),
#   ALLOWED_CIDR, CERTIFICATE_ARN, LOG_RETENTION_DAYS
#
# Requires: aws CLI v2 (logged in). Docker only for mode A.
#
# Note: the service wait below uses the AWS CLI default timeout. If a first
# rollout is slow the script may exit while the deployment still converges;
# re-run or check the service status in that case.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE_FILE="${REPO_ROOT}/deploy/infrastructure.yaml"
DOCKERFILE="${REPO_ROOT}/deploy/Dockerfile"

command -v aws >/dev/null 2>&1 || { echo "error: 'aws' is required but not found in PATH." >&2; exit 1; }

PROJECT_NAME="${PROJECT_NAME:-kiro-builder-lab}"
STACK_NAME="${STACK_NAME:-${PROJECT_NAME}}"
AWS_REGION="${AWS_REGION:-$(aws configure get region || true)}"
AWS_REGION="${AWS_REGION:-ap-southeast-1}"
IMAGE_URI="${IMAGE_URI:-}"
IMAGE_TAG="${IMAGE_TAG:-$(date -u +%Y%m%d%H%M%S)}"
DESIRED_COUNT="${DESIRED_COUNT:-2}"
TASK_SIZE="${TASK_SIZE:-256/512}"
ALLOWED_CIDR="${ALLOWED_CIDR:-0.0.0.0/0}"
CERTIFICATE_ARN="${CERTIFICATE_ARN:-}"
REPOSITORY_CREDENTIALS_SECRET_ARN="${REPOSITORY_CREDENTIALS_SECRET_ARN:-}"
LOG_RETENTION_DAYS="${LOG_RETENTION_DAYS:-14}"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

if [[ -n "$IMAGE_URI" ]]; then
  # ---------------------------------------------------------------- mode B
  echo "==> Account ${ACCOUNT_ID} | region ${AWS_REGION} | stack ${STACK_NAME}"
  echo "==> Using externally published image, skipping build and push"
  echo "==> Image ${IMAGE_URI}"

  # Check the last path segment so a registry port such as host:5000/owner/repo
  # is not mistaken for a tag.
  if [[ "${IMAGE_URI##*/}" != *:* ]]; then
    echo "error: IMAGE_URI must include an explicit tag, for example ghcr.io/owner/repo:sha-abc123." >&2
    exit 1
  fi

  if [[ "$IMAGE_URI" == *":latest" ]]; then
    echo "warning: tag 'latest' is mutable. ECS will not roll out a new task" >&2
    echo "         definition when the tag content changes. Prefer an immutable" >&2
    echo "         tag such as sha-<commit>." >&2
  fi
else
  # ---------------------------------------------------------------- mode A
  command -v docker >/dev/null 2>&1 || { echo "error: 'docker' is required to build the image. Set IMAGE_URI to skip building." >&2; exit 1; }
  docker info >/dev/null 2>&1 || { echo "error: docker daemon is not running." >&2; exit 1; }

  REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
  IMAGE_URI="${REGISTRY}/${PROJECT_NAME}:${IMAGE_TAG}"

  echo "==> Account ${ACCOUNT_ID} | region ${AWS_REGION} | stack ${STACK_NAME}"
  echo "==> Image ${IMAGE_URI}"

  echo "==> Ensuring ECR repository exists"
  if ! aws ecr describe-repositories --repository-names "$PROJECT_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
    aws ecr create-repository \
      --repository-name "$PROJECT_NAME" \
      --region "$AWS_REGION" \
      --image-scanning-configuration scanOnPush=true \
      --image-tag-mutability IMMUTABLE \
      --encryption-configuration encryptionType=AES256 \
      >/dev/null
    echo "    created repository ${PROJECT_NAME}"
  else
    echo "    repository ${PROJECT_NAME} already present"
  fi

  echo "==> Building image for linux/amd64"
  # --platform keeps the image compatible with the X86_64 Fargate runtime even when
  # the build runs on an Apple Silicon Mac.
  docker build \
    --platform linux/amd64 \
    -f "$DOCKERFILE" \
    -t "$IMAGE_URI" \
    "$REPO_ROOT"

  echo "==> Logging in to ECR"
  aws ecr get-login-password --region "$AWS_REGION" \
    | docker login --username AWS --password-stdin "$REGISTRY"

  echo "==> Pushing image"
  docker push "$IMAGE_URI"
fi

echo "==> Deploying CloudFormation stack"
PARAM_OVERRIDES=(
  "ProjectName=${PROJECT_NAME}"
  "ImageUri=${IMAGE_URI}"
  "DesiredCount=${DESIRED_COUNT}"
  "TaskSize=${TASK_SIZE}"
  "AllowedCidr=${ALLOWED_CIDR}"
  "LogRetentionInDays=${LOG_RETENTION_DAYS}"
)
# Optional parameters are appended only when set. An empty shorthand value has
# been handled inconsistently across AWS CLI releases, and omitting a parameter
# falls back to the template default.
if [[ -n "$CERTIFICATE_ARN" ]]; then
  PARAM_OVERRIDES+=("CertificateArn=${CERTIFICATE_ARN}")
fi
if [[ -n "$REPOSITORY_CREDENTIALS_SECRET_ARN" ]]; then
  PARAM_OVERRIDES+=("RepositoryCredentialsSecretArn=${REPOSITORY_CREDENTIALS_SECRET_ARN}")
fi

aws cloudformation deploy \
  --stack-name "$STACK_NAME" \
  --template-file "$TEMPLATE_FILE" \
  --region "$AWS_REGION" \
  --capabilities CAPABILITY_IAM \
  --no-fail-on-empty-changeset \
  --parameter-overrides "${PARAM_OVERRIDES[@]}"

echo "==> Waiting for the service to stabilise"
CLUSTER_NAME="$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='ClusterName'].OutputValue" --output text)"
SERVICE_NAME="$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='ServiceName'].OutputValue" --output text)"

aws ecs wait services-stable \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --region "$AWS_REGION"

SITE_URL="$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='SiteUrl'].OutputValue" --output text)"

echo
echo "Deployment complete."
echo "  URL:     ${SITE_URL}"
echo "  Image:   ${IMAGE_URI}"
echo "  Cluster: ${CLUSTER_NAME}"
echo "  Service: ${SERVICE_NAME}"
echo "  Logs:    aws logs tail /ecs/${PROJECT_NAME} --follow --region ${AWS_REGION}"

if [[ -z "$CERTIFICATE_ARN" ]]; then
  echo
  echo "Note: no ACM certificate was supplied, so the guide is served over plaintext HTTP."
  echo "      Pass CERTIFICATE_ARN to enable HTTPS and redirect port 80 to 443."
fi
