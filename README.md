# MCP Toolbox

A Docker container that downloads and pre-builds MCP (Model Context Protocol) servers, making them ready for use with Claude Code.

## How It Works

During image build, the container:

1. Reads tool definitions from `config/servers.json`
2. Clones each tool's repository from GitHub
3. Installs dependencies (npm, pip, cargo, go modules)
4. Builds/compiles each tool
5. Packages everything at `/app/tools/<tool-name>/`

The container stays running so tools can be invoked via `docker exec`. MCP tools use **stdio transport** - they read JSON-RPC from stdin and write to stdout, so each invocation is a fresh process (no persistent daemons).

Tools with `docker_volume: true` are stored in the `servers/` directory on the host, allowing persistent data and native execution outside Docker.

## Available Tools

| Tool                      | Type    | Description                                     |
| ------------------------- | ------- | ----------------------------------------------- |
| mcp-nixos                 | Python  | NixOS package and configuration search          |
| tailwind-svelte-assistant | Node.js | Tailwind CSS and SvelteKit documentation        |
| context7                  | Node.js | Up-to-date code documentation for any library   |
| agent-framework           | Node.js | AI-powered code quality: check, confirm, commit |

## Quick Start

```bash
# Build and run
make build && make run

# Check available tools
make status

# Test a tool
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | \
  docker exec -i mcp-toolbox /app/tools/mcp-nixos/venv/bin/python3 -m mcp_nixos.server
```

## Claude Code Configuration

Register the pre-built tools with Claude Code using `claude mcp add`:

```bash
# Tools running inside Docker container
claude mcp add nixos-search -- docker exec -i mcp-toolbox /app/tools/mcp-nixos/venv/bin/python3 -m mcp_nixos.server
claude mcp add tailwind-svelte -- docker exec -i mcp-toolbox node /app/tools/tailwind-svelte-assistant/run.mjs
claude mcp add context7 -- docker exec -i mcp-toolbox npx -y @upstash/context7-mcp

# agent-framework can run natively from the volume (docker_volume: true)
claude mcp add agent-framework -- node /path/to/mcp-server-host/servers/agent-framework/dist/mcp/server.js
# Or via Docker:
# claude mcp add agent-framework -- docker exec -i mcp-toolbox node /app/tools/agent-framework/dist/mcp/server.js
```

Or add to your Claude Code MCP settings (`~/.claude/settings.json`):

```json
{
  "mcpServers": {
    "nixos-search": {
      "command": "docker",
      "args": [
        "exec",
        "-i",
        "mcp-toolbox",
        "/app/tools/mcp-nixos/venv/bin/python3",
        "-m",
        "mcp_nixos.server"
      ]
    },
    "context7": {
      "command": "docker",
      "args": [
        "exec",
        "-i",
        "mcp-toolbox",
        "npx",
        "-y",
        "@upstash/context7-mcp"
      ]
    }
  }
}
```

### NixOS Integration

On NixOS, you can use a system activation script to automatically configure MCP servers. This example removes existing servers and re-adds them on each activation:

```nix
{ pkgs, ... }:

let
  # Paths - adjust these to your setup
  dockerBin = "${pkgs.docker}/bin/docker";
  claudeBin = "${pkgs.claude-code}/bin/claude";
  mcpToolboxPath = "/path/to/mcp-server-host";  # Where this repo is cloned
  serversPath = "${mcpToolboxPath}/servers";     # Volume-mounted servers directory
in
{
  system.activationScripts.claudeMcpSetup = {
    text = ''
      echo "[claude-mcp] Setting up MCP servers..."

      # Run as your user since claude config is per-user
      ${pkgs.sudo}/bin/sudo -u YOUR_USERNAME ${claudeBin} mcp list 2>/dev/null | \
        ${pkgs.gawk}/bin/awk -F: '/^[a-zA-Z0-9_-]+:/ {print $1}' | while read -r server; do
        echo "[claude-mcp] Removing server: $server"
        ${pkgs.sudo}/bin/sudo -u YOUR_USERNAME ${claudeBin} mcp remove --scope user "$server" 2>/dev/null || true
      done

      echo "[claude-mcp] Adding nixos-search server..."
      ${pkgs.sudo}/bin/sudo -u YOUR_USERNAME ${claudeBin} mcp add nixos-search --scope user -- \
        ${dockerBin} exec -i mcp-toolbox sh -c 'exec 2>/dev/null; /app/tools/mcp-nixos/venv/bin/python3 -m mcp_nixos.server'

      echo "[claude-mcp] Adding tailwind-svelte server..."
      ${pkgs.sudo}/bin/sudo -u YOUR_USERNAME ${claudeBin} mcp add tailwind-svelte --scope user -- \
        ${dockerBin} exec -i mcp-toolbox node /app/tools/tailwind-svelte-assistant/run.mjs

      echo "[claude-mcp] Adding context7 server..."
      ${pkgs.sudo}/bin/sudo -u YOUR_USERNAME ${claudeBin} mcp add context7 --scope user -- \
        ${dockerBin} exec -i mcp-toolbox npx -y @upstash/context7-mcp

      # agent-framework runs natively from the volume (docker_volume: true)
      echo "[claude-mcp] Adding agent-framework server (native)..."
      ${pkgs.sudo}/bin/sudo -u YOUR_USERNAME ${claudeBin} mcp add agent-framework --scope user -- \
        ${pkgs.nodejs}/bin/node ${serversPath}/agent-framework/dist/mcp/server.js

      echo "[claude-mcp] MCP servers setup complete"
    '';
  };
}
```

**Key points:**

- Replace `YOUR_USERNAME` with your actual username
- Replace `/path/to/mcp-server-host` with the actual path to this repository
- `agent-framework` runs natively from `servers/agent-framework/` since it has `docker_volume: true`
- Other tools run via `docker exec` inside the container

## Adding New Tools

1. Edit `config/servers.json` - add your tool definition
2. Run `make rebuild`

### Tool Configuration

```json
{
  "tools": {
    "my-tool": {
      "enabled": true,
      "docker_volume": false,
      "type": "node",
      "description": "What the tool does",
      "repository": "https://github.com/user/repo",
      "build_command": "npm install && npm run build",
      "binary_path": "dist/index.js",
      "capabilities": ["feature1", "feature2"]
    }
  }
}
```

**Configuration Options:**

| Option          | Type    | Description                                                             |
| --------------- | ------- | ----------------------------------------------------------------------- |
| `enabled`       | boolean | Whether to build and enable this tool                                   |
| `docker_volume` | boolean | If `true`, tool data persists in `servers/<name>/` and can run natively |
| `type`          | string  | Runtime type: `node`, `python`, `go`, `rust`                            |
| `repository`    | string  | Git repository URL to clone                                             |
| `build_command` | string  | Command to build the tool after cloning                                 |
| `binary_path`   | string  | Path to the executable relative to tool directory                       |
| `capabilities`  | array   | List of tool capabilities (documentation only)                          |

### Docker Volume Feature

When `docker_volume: true` is set for a tool:

1. **Build time**: Tool is built normally, then moved to `/app/tools-builtin/<name>/`
2. **First run**: Built artifacts are copied to `/app/servers/<name>/` (mounted volume)
3. **Runtime**: A symlink `/app/tools/<name>/` -> `/app/servers/<name>/` is created

This allows:

- **Persistent data**: Tool data survives container rebuilds
- **Native execution**: Tools can be run directly from `servers/<name>/` on the host without Docker
- **Easy updates**: Modify tool code directly in the volume

Currently enabled for: `agent-framework`

## Project Structure

```
mcp-toolbox/
├── Dockerfile           # Build environment with Node/Python/Go/Rust
├── docker-compose.yml   # Container configuration
├── Makefile             # Management commands
├── config/
│   └── servers.json     # Tool definitions
├── scripts/
│   ├── install.sh       # Build script for all tools
│   └── entrypoint.sh    # Runtime initialization (symlinks, volume setup)
└── servers/             # Persistent storage for docker_volume tools (git-ignored)
    └── <tool-name>/     # Tool data (e.g., servers/agent-framework/)
```

## Commands

```bash
make build    # Build Docker image
make run      # Run container (foreground, Ctrl+C to stop)
make stop     # Stop container
make restart  # Restart container
make logs     # View container logs
make shell    # Open container shell
make status   # List available MCP tools
make test     # Test MCP tools respond
make clean    # Remove container and image
make rebuild  # Clean rebuild
```

## Environment Variables

The `agent-framework` tool requires API credentials. Two options are supported:

**Option A: Direct Anthropic API**

```bash
ANTHROPIC_API_KEY=sk-ant-...
```

**Option B: OpenRouter (Anthropic-compatible)**

```bash
ANTHROPIC_API_KEY=           # Leave empty
ANTHROPIC_BASE_URL=https://openrouter.ai/api
ANTHROPIC_AUTH_TOKEN=sk-or-...  # Your OpenRouter key
```

See `.env.example` for the full template.

## Troubleshooting

### Test a tool manually

```bash
# Enter the container
docker exec -it mcp-toolbox /bin/bash

# Test mcp-nixos (inside container)
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | \
  /app/tools/mcp-nixos/venv/bin/python3 -m mcp_nixos.server

# Test agent-framework (inside container via symlink)
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | \
  node /app/tools/agent-framework/dist/mcp/server.js

# Test agent-framework natively (from host, docker_volume: true)
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | \
  node /path/to/mcp-server-host/agent-framework/dist/mcp/server.js
```

### Check tool binaries exist

```bash
# Check all tools
docker exec mcp-toolbox ls -la /app/tools/

# Check volume-enabled tools (should show symlinks)
docker exec mcp-toolbox ls -la /app/tools/agent-framework
```
