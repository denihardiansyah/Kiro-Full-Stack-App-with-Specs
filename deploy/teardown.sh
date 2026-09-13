#!/usr/bin/env bash
#
# Destroy everything deploy.sh created.
#
# Deleted by default:
#   - The CloudFormation stack: VPC, subnets, IGW, route table, security groups,
#     ALB, listeners, target group, ECS cluster, service, task definition,
#     IAM roles, and the CloudWatch log group.
#
# Kept unless explicitly requested, because these outlive a single deployment:
#   - The ECR repository and its images   -> DELETE_ECR=true
#   - A Secrets Manager registry secret   -> DELETE_SECRET_ARN=<arn>
#   - The GHCR package on GitHub          -> manual, see the note at the end
#
# Usage:
#   ./deploy/teardown.sh
#   DELETE_ECR=true ./deploy/teardown.sh
#   DELETE_SECRET_ARN=arn:aws:secretsmanager:...:secret:ghcr-pull-credentials-AbCdEf ./deploy/teardown.sh
#   DRY_RUN=true ./deploy/teardown.sh        # list what would be deleted, change nothing
#   FORCE=true ./deploy/teardown.sh          # skip the interactive prompt, for CI
#
# Options:
#   PROJECT_NAME, STACK_NAME, AWS_REGION
#   PURGE_SECRET=true    delete the secret immediately instead of a 7-day recovery window

set -euo pipefail

command -v aws >/dev/null 2>&1 || { echo "error: 'aws' is required but not found in PATH." >&2; exit 1; }

PROJECT_NAME="${PROJECT_NAME:-kiro-builder-lab}"
STACK_NAME="${STACK_NAME:-${PROJECT_NAME}}"
AWS_REGION="${AWS_REGION:-$(aws configure get region || true)}"
AWS_REGION="${AWS_REGION:-ap-southeast-1}"
DELETE_ECR="${DELETE_ECR:-false}"
DELETE_SECRET_ARN="${DELETE_SECRET_ARN:-}"
PURGE_SECRET="${PURGE_SECRET:-false}"
DRY_RUN="${DRY_RUN:-false}"
FORCE="${FORCE:-false}"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

echo "Target"
echo "  Account: ${ACCOUNT_ID}"
echo "  Region:  ${AWS_REGION}"
echo "  Stack:   ${STACK_NAME}"
echo

# ---------------------------------------------------------------- discovery
STACK_STATUS="$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$AWS_REGION" \
  --query 'Stacks[0].StackStatus' \
  --output text 2>/dev/null || true)"

STACK_EXISTS=false
if [[ -n "$STACK_STATUS" && "$STACK_STATUS" != "None" ]]; then
  STACK_EXISTS=true
  echo "Stack status: ${STACK_STATUS}"
  echo
  echo "Resources that will be deleted:"
  # Listing is informational, so a transient API failure must not abort the run.
  aws cloudformation list-stack-resources \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION" \
    --query 'StackResourceSummaries[].[ResourceType,LogicalResourceId]' \
    --output text 2>/dev/null | sort | sed 's/^/  /' \
    || echo "  (could not list resources; deletion will still remove the whole stack)"
  echo
else
  echo "Stack '${STACK_NAME}' was not found in ${AWS_REGION}. Nothing to delete there."
  echo
fi

ECR_EXISTS=false
if aws ecr describe-repositories --repository-names "$PROJECT_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
  ECR_EXISTS=true
  ECR_IMAGE_COUNT="$(aws ecr list-images \
    --repository-name "$PROJECT_NAME" \
    --region "$AWS_REGION" \
    --query 'length(imageIds)' \
    --output text 2>/dev/null || echo '?')"
  if [[ "$DELETE_ECR" == "true" ]]; then
    echo "ECR repository '${PROJECT_NAME}' (${ECR_IMAGE_COUNT} image(s)) WILL BE DELETED."
  else
    echo "ECR repository '${PROJECT_NAME}' (${ECR_IMAGE_COUNT} image(s)) will be kept."
  fi
  echo
elif [[ "$DELETE_ECR" == "true" ]]; then
  # Explain the outcome rather than silently reporting nothing to do.
  echo "ECR repository '${PROJECT_NAME}' is not found or not accessible in ${AWS_REGION}, nothing to delete there."
  echo
fi

if [[ -n "$DELETE_SECRET_ARN" ]]; then
  if [[ "$PURGE_SECRET" == "true" ]]; then
    echo "Secret WILL BE DELETED IMMEDIATELY, with no recovery window:"
  else
    echo "Secret will be scheduled for deletion with a 7-day recovery window:"
  fi
  echo "  ${DELETE_SECRET_ARN}"
  echo
fi

ECR_WORK=false
if [[ "$DELETE_ECR" == "true" && "$ECR_EXISTS" == "true" ]]; then
  ECR_WORK=true
fi

if [[ "$STACK_EXISTS" == "false" && "$ECR_WORK" == "false" && -z "$DELETE_SECRET_ARN" ]]; then
  echo "Nothing to do."
  exit 0
fi

if [[ "$DRY_RUN" == "true" ]]; then
  echo "DRY_RUN=true, so nothing was changed."
  exit 0
fi

# ------------------------------------------------------------- confirmation
if [[ "$FORCE" != "true" ]]; then
  if [[ ! -t 0 ]]; then
    echo "error: no terminal available for confirmation. Re-run with FORCE=true to proceed non-interactively." >&2
    exit 1
  fi
  echo "This cannot be undone."
  # `|| CONFIRM=''` keeps the Aborted message on EOF, e.g. Ctrl-D at the prompt.
  read -r -p "Type the stack name '${STACK_NAME}' to confirm: " CONFIRM || CONFIRM=''
  [[ "$CONFIRM" == "$STACK_NAME" ]] || { echo "Aborted." >&2; exit 1; }
  echo
fi

# --------------------------------------------------------------- stack delete
if [[ "$STACK_EXISTS" == "true" ]]; then
  echo "==> Deleting stack ${STACK_NAME}"
  aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$AWS_REGION"

  echo "    waiting for deletion to finish, this usually takes a few minutes"
  if aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" --region "$AWS_REGION" 2>/dev/null; then
    echo "    stack deleted"
  else
    echo >&2
    echo "error: stack deletion did not complete. Most recent failures:" >&2
    aws cloudformation describe-stack-events \
      --stack-name "$STACK_NAME" \
      --region "$AWS_REGION" \
      --query 'reverse(StackEvents[?ResourceStatus==`DELETE_FAILED`].[LogicalResourceId,ResourceStatusReason])' \
      --output text 2>/dev/null | head -20 | sed 's/^/  /' >&2 || true
    echo >&2
    echo "Common causes and next steps:" >&2
    echo "  - A resource was modified outside CloudFormation. Remove the change, then re-run." >&2
    echo "  - An ENI is still attached. Wait a few minutes and re-run." >&2
    echo "  - To skip resources that refuse to delete:" >&2
    echo "      aws cloudformation delete-stack --stack-name ${STACK_NAME} --region ${AWS_REGION} \\" >&2
    echo "        --retain-resources <LogicalId> [...]" >&2
    exit 1
  fi
fi

# ----------------------------------------------------------------- ecr delete
if [[ "$DELETE_ECR" == "true" ]]; then
  if [[ "$ECR_EXISTS" == "true" ]]; then
    echo "==> Deleting ECR repository ${PROJECT_NAME} and all images"
    aws ecr delete-repository --repository-name "$PROJECT_NAME" --region "$AWS_REGION" --force >/dev/null
    echo "    repository deleted"
  else
    echo "==> ECR repository ${PROJECT_NAME} not present, skipping"
  fi
fi

# -------------------------------------------------------------- secret delete
if [[ -n "$DELETE_SECRET_ARN" ]]; then
  echo "==> Deleting secret"
  if [[ "$PURGE_SECRET" == "true" ]]; then
    aws secretsmanager delete-secret \
      --secret-id "$DELETE_SECRET_ARN" \
      --region "$AWS_REGION" \
      --force-delete-without-recovery >/dev/null
    echo "    secret deleted immediately"
  else
    aws secretsmanager delete-secret \
      --secret-id "$DELETE_SECRET_ARN" \
      --region "$AWS_REGION" \
      --recovery-window-in-days 7 >/dev/null
    echo "    secret scheduled for deletion in 7 days"
    echo "    restore with: aws secretsmanager restore-secret --secret-id ${DELETE_SECRET_ARN} --region ${AWS_REGION}"
  fi
fi

# --------------------------------------------------------------------- report
echo
echo "Teardown complete."
echo
echo "Not deleted by this run:"

if [[ "$DELETE_ECR" != "true" && "$ECR_EXISTS" == "true" ]]; then
  echo "  - ECR repository '${PROJECT_NAME}'. Images still incur storage cost."
  echo "    Remove with: DELETE_ECR=true ./deploy/teardown.sh"
fi

if [[ -z "$DELETE_SECRET_ARN" ]]; then
  echo "  - Any Secrets Manager registry secret created for a private GHCR package."
  echo "    Remove with: DELETE_SECRET_ARN=<arn> ./deploy/teardown.sh"
fi

echo "  - The GHCR package on GitHub, which the AWS CLI cannot touch."
echo "    Delete it from the package settings page, or with the gh CLI:"
echo "      gh api --method DELETE /user/packages/container/<PACKAGE_NAME>"
echo "    For an organisation package use /orgs/<ORG>/packages/container/<PACKAGE_NAME>."
echo "  - Any ACM certificate, Route 53 record, or ECR pull-through cache rule,"
echo "    since this stack never created them."
echo
echo "Confirm the region has no leftovers before assuming billing has stopped."
