# Official Penpot MCP server + plugin server, built from source.
#
# WHY THIS EXISTS (and not the community sebathi image):
#   The sebathi/penpot-mcp-docker image only runs the MCP server (4401) and the
#   websocket bridge (4402). It does NOT run the plugin web server (4400) that
#   serves the plugin manifest Penpot loads in the browser. Without that, there
#   is no manifest URL to paste into Penpot's Plugins dialog, so the pipeline
#   cannot connect. This image builds the official Penpot MCP workspace from
#   source (penpot/penpot `mcp/`), which runs BOTH the MCP server and the plugin
#   server, exactly as upstream documents.
#
# VERSION PINNING:
#   PENPOT_TAG is a real penpot/penpot git TAG (e.g. 2.14.1). Note: the npm docs
#   mention "mcp-prod-*" branches, but those DO NOT exist in the repo -- the mcp/
#   workspace lives in the mainline release tags. Keep PENPOT_TAG in lockstep
#   with the penpotapp/* image tags in the compose file; the plugin warns in-UI
#   if the MCP version and Penpot version disagree.
#
# SOURCE FACTS (verified against tag 2.14.1, mcp/):
#   - mcp/ is a pnpm workspace (packageManager pnpm@10.28.2), node v22.
#   - top-level scripts: build = `pnpm -r run build`; start = `pnpm -r --parallel
#     run start`; bootstrap = install+build+start (do NOT use at runtime, it
#     rebuilds every start).
#   - server pkg: build = esbuild bundle + copy static/data; start = node dist.
#   - plugin pkg: build = tsc + vite build (static assets).
#   - env vars are *_LISTEN_ADDRESS (not *_HOST as the npm README shows).

ARG NODE_IMAGE=node:22-slim
# a real penpot/penpot tag. see VERSION PINNING above.
ARG PENPOT_TAG=2.14.1

# the websocket URL the browser plugin uses to reach the bridge. the plugin reads
# process.env.WS_URI at BUILD time (vite define) -- NOT PENPOT_MCP_SERVER_ADDRESS,
# despite the older assumption. must be reachable from the DESIGNER'S browser:
#   local: http://localhost:4402
#   vps:   http://<tailnet-host>:4402
# defaults to localhost for local builds; the vps deploy passes the tailnet host.
ARG WS_URI=http://localhost:4402

# ---------------------------------------------------------------------------
# builder: sparse-clone just mcp/, install, build (no start)
# ---------------------------------------------------------------------------
FROM ${NODE_IMAGE} AS builder
ARG PENPOT_TAG
# make WS_URI available to the plugin's vite build (it reads process.env.WS_URI).
ARG WS_URI
ENV WS_URI=${WS_URI}

# git for the sparse clone; build tooling for native deps (sharp). corepack
# provides the pnpm version the repo pins.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git ca-certificates rsync python3 build-essential \
    && rm -rf /var/lib/apt/lists/* \
    && corepack enable

WORKDIR /src

# sparse, shallow clone of just the mcp/ workspace at the target tag, plus the
# sibling plugins/ dir (the type-doc generator references ../../plugins).
RUN git clone --branch "${PENPOT_TAG}" --depth 1 --filter=blob:none --sparse \
        https://github.com/penpot/penpot.git . \
    && git sparse-checkout set mcp plugins

WORKDIR /src/mcp

# PATCH the plugin's vite config: upstream hardcodes `preview: { allowedHosts: [] }`,
# which makes the plugin server (4400) reject any non-localhost Host header (e.g. a
# tailnet hostname) with a 403 "host not allowed", and no env var can override a
# hardcoded value. Rewrite it to read a comma-separated list from the
# PENPOT_MCP_PLUGIN_ALLOWED_HOSTS env var at RUNTIME (empty -> defaults only, same
# as before). This keeps the allowed host runtime-configurable (no rebuild to
# change it). Fails the build loudly if the expected line isn't found (upstream
# changed), so we don't silently ship a broken allowlist.
RUN node -e ' \
  const fs = require("fs"); \
  const f = "packages/plugin/vite.config.ts"; \
  let s = fs.readFileSync(f, "utf8"); \
  const needle = "allowedHosts: []"; \
  if (!s.includes(needle)) { console.error("PATCH FAILED: \"allowedHosts: []\" not found in " + f + " (upstream changed?)"); process.exit(1); } \
  s = s.replace(needle, "allowedHosts: (process.env.PENPOT_MCP_PLUGIN_ALLOWED_HOSTS || \"\").split(\",\").map(x => x.trim()).filter(Boolean)"); \
  fs.writeFileSync(f, s); \
  console.log("Patched allowedHosts in " + f); \
' && grep -n allowedHosts packages/plugin/vite.config.ts

# install deps for all workspace packages (equivalent to ./scripts/setup).
RUN pnpm -r install --frozen-lockfile

# build all components WITHOUT starting them. build:types can try to spin up a
# local caddy file-server to source the plugin API docs; point it at the public
# docs instead so the build needs no caddy and no long-running server.
ENV PENPOT_PLUGINS_API_DOC_URL=https://penpot.github.io/penpot-plugins/
RUN pnpm run build

# ---------------------------------------------------------------------------
# runtime: copy built workspace, start both servers (no rebuild)
# ---------------------------------------------------------------------------
FROM ${NODE_IMAGE} AS runtime

RUN apt-get update \
    && apt-get install -y --no-install-recommends dumb-init ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && corepack enable

RUN useradd --system --uid 1001 --create-home --home-dir /home/penpot penpot

WORKDIR /app
COPY --from=builder --chown=penpot:penpot /src/mcp /app

USER penpot

# 4400 plugin web server (serves manifest.json for the browser)
# 4401 mcp http/sse endpoint (ai client connects here)
# 4402 websocket bridge (browser plugin connects here)
EXPOSE 4400 4401 4402

# bind all interfaces inside the container so the host port mapping can reach
# the servers. public exposure is prevented by the 127.0.0.1 host binding in
# compose, not by these values. PENPOT_MCP_SERVER_ADDRESS is the hostname baked
# into the plugin's ws:// URL, so the browser can reach the bridge; compose sets
# it per-environment (localhost locally, tailnet host on the vps).
ENV PENPOT_MCP_SERVER_LISTEN_ADDRESS=0.0.0.0 \
    PENPOT_MCP_PLUGIN_SERVER_LISTEN_ADDRESS=0.0.0.0 \
    PENPOT_MCP_SERVER_ADDRESS=localhost \
    PENPOT_MCP_SERVER_PORT=4401 \
    PENPOT_MCP_WEBSOCKET_PORT=4402 \
    PENPOT_MCP_REMOTE_MODE=true \
    PENPOT_MCP_LOG_LEVEL=info

# start only (bootstrap would rebuild on every boot). single-user remote mode.
ENTRYPOINT ["dumb-init", "--"]
CMD ["pnpm", "run", "start"]
