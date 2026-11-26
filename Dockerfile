# VBC Stats API (reporter agent for VBC Stats), built from this repository.
#
# Configure it with the environment variables listed in README.md, e.g.:
#
#   docker build -t vbc-stats-api .
#   docker run -d --name vbc-stats-api --restart unless-stopped \
#     --network host --env-file /etc/vbc-stats-api.env vbc-stats-api
#
# --network host lets the agent reach a node that listens on localhost:8329.

FROM node:24-alpine

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY app.js ./
COPY lib ./lib

ENV NODE_ENV=production
USER node

CMD ["node", "app.js"]
