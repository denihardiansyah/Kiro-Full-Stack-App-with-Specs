# Kiro Builder Lab — static workshop guide on ECS Fargate
#
# Build from the repository root so the static assets are in the build context:
#   docker build --platform linux/amd64 -f deploy/Dockerfile -t kiro-builder-lab .
#
# The base image runs as an unprivileged user (uid 101) and listens on 8080,
# so no root privileges and no privileged port are required in the task.
FROM nginxinc/nginx-unprivileged:1.27-alpine

# Static site only. No build step, no runtime dependencies.
COPY --chown=nginx:nginx deploy/nginx.conf /etc/nginx/nginx.conf
COPY --chown=nginx:nginx deploy/security-headers.conf /etc/nginx/security-headers.conf
COPY --chown=nginx:nginx index.html styles.css app.js /usr/share/nginx/html/

EXPOSE 8080

# nginx-unprivileged already defines a non-root USER and the default CMD.
# Declared explicitly so the runtime identity stays obvious during review.
USER 101

CMD ["nginx", "-g", "daemon off;"]
