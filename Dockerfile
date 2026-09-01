ARG BASE_IMAGE=nousresearch/hermes-agent:latest
FROM ${BASE_IMAGE}

ARG NODE_VERSION=24.15.0
# Node 分发与 npm registry 均可参数化：境外直连在 docker build 网络下易长连接停滞，
# 国内构建传 --build-arg NODE_DIST_MIRROR=https://npmmirror.com/mirrors/node --build-arg NPM_REGISTRY=https://registry.npmmirror.com
ARG NODE_DIST_MIRROR=https://nodejs.org/dist
ARG NPM_REGISTRY=https://registry.npmjs.org

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    ffmpeg \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

RUN ARCH=$(dpkg --print-architecture) \
    && if [ "$ARCH" = "amd64" ]; then NODE_ARCH="x64"; else NODE_ARCH="$ARCH"; fi \
    && echo "Downloading Node.js v${NODE_VERSION} for ${NODE_ARCH}" \
    && curl -fsSL "${NODE_DIST_MIRROR}/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.gz" \
       -o /tmp/node.tar.gz \
    && rm -rf /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/corepack \
       /usr/local/bin/node /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack \
    && tar -xzf /tmp/node.tar.gz -C /usr/local --strip-components=1 \
    && rm -f /tmp/node.tar.gz \
    && node --version \
    && npm --version

WORKDIR /app

COPY package*.json ./
# Increase Node.js memory limit to prevent OOM during build
ENV NODE_OPTIONS=--max-old-space-size=4096
RUN npm ci --ignore-scripts --registry=${NPM_REGISTRY} && npm rebuild node-pty --registry=${NPM_REGISTRY}

COPY . .

# 构建期特性开关：docker build --build-arg VITE_DISABLED_FEATURES="devices,apiRelay,pet,usage,performance,versionPreview"
ARG VITE_DISABLED_FEATURES=""
ENV VITE_DISABLED_FEATURES=${VITE_DISABLED_FEATURES}

RUN npm run build && npm prune --omit=dev
RUN npm run verify:sharp-runtime

ENV NODE_ENV=production
ENV HOME=/home/agent
ENV HERMES_HOME=/home/agent/.hermes
ENV HERMES_WEB_UI_MANAGED_GATEWAY=1
ENV PATH=/opt/hermes/.venv/bin:$PATH

EXPOSE 6060

# 强制覆盖基础镜像的默认启动脚本，让镜像本身具备独立运行的能力
ENTRYPOINT ["node", "dist/server/index.js"]
CMD []
