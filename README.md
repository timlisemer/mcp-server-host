# MCP Server Host

A modular Docker container for hosting multiple MCP (Model Context Protocol) servers with remote SSH access support. Perfect for running MCP servers on any Docker-compatible system.

## Features

- **Multi-Language Support**: Go, Rust, Node.js, Python (with virtual environments)
- **Modular Architecture**: Easy to add/remove servers via JSON configuration
- **Process Management**: Supervisor handles all MCP servers automatically
- **Remote Access**: SSH + docker exec integration for Claude Desktop
- **Health Monitoring**: Built-in health checks and logging
- **Virtual Environment Support**: Python servers run in isolated environments

## Quick Start

```bash
# Build and start the container
make build
make start

# Check status
make status

# View logs
make logs
```

## Project Structure

```
mcp-server-host/
├── Dockerfile                    # Ubuntu 25.04 with multi-language support
├── docker-compose.yml           # Container orchestration
├── Makefile                     # Management commands
├── entrypoint.sh               # Container startup script
├── supervisord.conf            # Process management configuration
├── config/
│   └── servers.json           # MCP server configuration
├── scripts/
│   ├── install-servers.sh     # Automated server installation
│   ├── start-servers.sh       # Dynamic supervisor config generation
│   └── health-check.sh        # Health monitoring
└── README.md                  # This file
```

## Server Status

| Server | Status | Type | Description |
|--------|--------|------|-------------|
| mcp-language-server | **DISABLED** | Go | LSP integration with rust-analyzer support |
| mcp-nixos | **ENABLED** | Python | NixOS package search and configuration |
| tailwind-svelte-assistant | **ENABLED** | Node.js | Tailwind CSS and SvelteKit documentation |
| context7 | **ENABLED** | Node.js | Up-to-date code documentation for LLMs |
| agent-framework | **ENABLED** | Node.js | AI-powered code quality agents: check, confirm, commit |

## Currently Running Servers

### 1. MCP NixOS Server (Python) - ENABLED
- **Type**: Python-based NixOS package search
- **Capabilities**: NixOS package search, configuration assistance
- **Repository**: [utensils/mcp-nixos](https://github.com/utensils/mcp-nixos)
- **Virtual Environment**: `/app/servers/mcp-nixos/venv/`
- **Runtime**: Python 3.13 with isolated dependencies

### 2. Tailwind Svelte Assistant (Node.js) - ENABLED
- **Type**: Node.js MCP server
- **Capabilities**: Tailwind CSS classes, SvelteKit documentation, component snippets
- **Repository**: [CaullenOmdahl/Tailwind-Svelte-Assistant](https://github.com/CaullenOmdahl/Tailwind-Svelte-Assistant)
- **Runtime**: Node.js 20 with TypeScript

### 3. Context7 (Node.js) - ENABLED
- **Type**: Node.js MCP server via npx
- **Capabilities**: Real-time library documentation, code examples
- **Repository**: [upstash/context7](https://github.com/upstash/context7)
- **Runtime**: Executed via `npx @upstash/context7-mcp`
- **Note**: For Claude Desktop/Cursor users, add a rule to auto-invoke Context7:
  ```
  [[calls]]
  match = "when the user requests code examples, setup or configuration steps, or library/API documentation"
  tool  = "context7"
  ```

### 4. Agent Framework (Node.js) - ENABLED
- **Type**: Node.js MCP server
- **Capabilities**: AI-powered code quality gates, automated commit messages, code review
- **Repository**: [timlisemer/agent-framework](https://github.com/timlisemer/agent-framework)
- **Runtime**: Node.js with TypeScript
- **Tools Provided**:
  - `check` - Run linting and make check, return summarized results with recommendations
  - `confirm` - Binary code quality gate (returns CONFIRMED or DECLINED)
  - `commit` - Generate minimal commit message and execute git commit
- **Note**: Requires `ANTHROPIC_API_KEY` environment variable (see `.env.example`)

### Disabled Servers

#### MCP Language Server (Go) - DISABLED
- **Type**: Go-based LSP integration
- **Capabilities**: Rust, Go, Python, TypeScript language support via rust-analyzer
- **Repository**: [isaacphi/mcp-language-server](https://github.com/isaacphi/mcp-language-server)
- **To Enable**: Set `"enabled": true` in `config/servers.json`

## Remote VPS Usage with Claude Code

**This Docker setup is specifically designed for running MCP servers on a remote VPS and connecting to them via SSH.** Unlike typical local MCP integrations, this approach:

1. **Centralizes all MCP servers** on a single remote host
2. **Uses SSH + docker exec** to bridge MCP communication
3. **Works with Claude Code, Claude Desktop, Cursor, and other MCP clients**
4. **No local installation** of individual MCP servers required

### How It Works

The pattern for remote MCP server access:
```
[Claude Code] → SSH → [VPS] → docker exec → [MCP Server in Container]
```

### Claude Code Configuration

Add this to your Claude Code settings to use MCP servers running on your remote VPS:

```json
{
  "mcpServers": {
    "nixos-search": {
      "command": "ssh",
      "args": [
        "user@your-vps-ip",
        "docker", "exec", "mcp-server-host",
        "/app/servers/mcp-nixos/venv/bin/python3",
        "-m", "mcp_nixos.server"
      ]
    },
    "tailwind-svelte": {
      "command": "ssh",
      "args": [
        "user@your-vps-ip",
        "docker", "exec", "mcp-server-host",
        "node", "/app/servers/tailwind-svelte-assistant/dist/index.js"
      ]
    },
    "context7": {
      "command": "ssh",
      "args": [
        "user@your-vps-ip",
        "docker", "exec", "mcp-server-host",
        "npx", "-y", "@upstash/context7-mcp"
      ]
    },
    "agent-framework": {
      "command": "ssh",
      "args": [
        "user@your-vps-ip",
        "docker", "exec", "-i", "mcp-server-host",
        "node", "/app/servers/agent-framework/dist/mcp/server.js"
      ]
    }
  }
}
```

**Important**: Replace `user@your-vps-ip` with your actual VPS SSH credentials.

### SSH Setup Requirements

1. **SSH key authentication** configured between your local machine and VPS
2. **Docker installed** on the VPS
3. **User has docker permissions** (user in docker group or sudo access)
4. **Container running** via `make start` on the VPS

### Claude Code CLI Method

You can also add MCP servers using the Claude Code CLI:

```bash
# Add agent-framework
claude mcp add agent-framework --scope user -- ssh tim-server "docker exec -i mcp-server-host node /app/servers/agent-framework/dist/mcp/server.js"

# Add nixos-search
claude mcp add nixos-search --scope user -- ssh tim-server "docker exec -i mcp-server-host /app/servers/mcp-nixos/venv/bin/python3 -m mcp_nixos.server"

# Add tailwind-svelte
claude mcp add tailwind-svelte --scope user -- ssh tim-server "docker exec -i mcp-server-host node /app/servers/tailwind-svelte-assistant/.smithery/index.cjs"

# Add context7
claude mcp add context7 --scope user -- ssh tim-server "docker exec -i mcp-server-host npx -y @upstash/context7-mcp"
```

**Note**: Replace `tim-server` with your SSH host alias or `user@your-vps-ip`.

## Configuration

### Current Server Configuration

The `config/servers.json` file controls which servers are active. Set `"enabled"` to `true` or `false` to control each server:

```json
{
  "servers": {
    "mcp-language-server": {
      "enabled": false,  // Currently DISABLED
      "type": "go",
      "description": "MCP Language Server with Rust support via rust-analyzer"
    },
    "mcp-nixos": {
      "enabled": true,   // Currently ENABLED
      "type": "python",
      "description": "NixOS package and configuration search MCP server"
    },
    "tailwind-svelte-assistant": {
      "enabled": true,   // Currently ENABLED
      "type": "node",
      "description": "Tailwind CSS and SvelteKit documentation MCP server"
    },
    "context7": {
      "enabled": true,   // Currently ENABLED
      "type": "node",
      "description": "Up-to-date code documentation for LLMs"
    },
    "agent-framework": {
      "enabled": true,   // Currently ENABLED
      "type": "node",
      "description": "AI-powered code quality agents: check, confirm, commit"
    }
  }
}
```

### Managing Servers

#### Enable/Disable Servers
1. **Edit `config/servers.json`** - Set `"enabled"` to `true` or `false`
2. **Run `make update-config`** - Apply changes without rebuilding
3. **Check status** - Run `make status` to verify

#### Add New Servers
1. **Edit `config/servers.json`** - Add your server configuration with `"enabled": true`
2. **Run `make rebuild`** - Rebuild container with new server
3. **Update Claude Code config** - Add SSH command for new server

### Supported Server Types

- **go**: Go-based servers (uses `go install` or `go build`)
- **rust**: Rust-based servers (uses `cargo build --release`)
- **node**: Node.js servers (uses `npm install` and optional `npm run build`)
- **python**: Python servers (creates virtual environment and uses `pip install`)

## Docker Infrastructure

### Base Image
- **Ubuntu 25.04** with Python 3.13 support
- **Multi-language toolchain**: Go 1.24+, Rust (latest), Node.js 20, Python 3.13
- **rust-analyzer** pre-installed for Rust language support

### Volume Mounts
```yaml
volumes:
  - ./workspace:/workspace:rw     # Shared workspace
  - ./data:/app/data:rw          # Persistent data
  - ./logs:/var/log:rw           # Log files
  - ./config:/app/config:ro      # Configuration (read-only)
```

## Management Commands

```bash
# Container Operations
make build          # Build Docker image
make start          # Start container
make stop           # Stop container
make restart        # Restart container
make rebuild        # Clean rebuild (recommended after config changes)

# Monitoring
make logs           # View container logs
make health         # Run health check
make status         # Show MCP server status
make supervisor-logs # View supervisor logs
make server-logs    # View specific server logs (prompts for server name)

# Development
make shell          # Open container shell
make ssh-test       # Test SSH connectivity
make update-config  # Update configuration without rebuild
make info          # Show container information
```

## Technical Details

### Python Virtual Environments
Python servers automatically get isolated virtual environments:
- Created at `/app/servers/{server-name}/venv/`
- Dependencies installed via pip in the virtual environment
- Supervisor uses the venv Python binary: `/app/servers/{server-name}/venv/bin/python3`

### Process Management
- **Supervisor** manages all MCP servers as background processes
- Automatic restart on failure
- Structured logging to `/var/log/mcp/`
- Health monitoring and status reporting

### Networking
- Container runs without special network requirements
- Accessible via `docker exec` commands over SSH
- No exposed ports needed for MCP communication

## Troubleshooting

### Check Server Status
```bash
# View all servers
make status

# Check specific server logs
docker exec mcp-server-host tail -n 50 /var/log/mcp/mcp-language-server.err.log
docker exec mcp-server-host tail -n 50 /var/log/mcp/mcp-nixos.err.log
```

### Test Servers Individually
```bash
# Test language server
docker exec mcp-server-host /root/go/bin/mcp-language-server --help

# Test NixOS server
docker exec mcp-server-host /app/servers/mcp-nixos/venv/bin/python3 -m mcp_nixos.server --help

# Test agent-framework server
docker exec mcp-server-host node /app/servers/agent-framework/dist/mcp/server.js --help
```

### Restart Failed Servers
```bash
# Restart specific server
docker exec mcp-server-host supervisorctl restart mcp-mcp-nixos
docker exec mcp-server-host supervisorctl restart mcp-mcp-language-server
docker exec mcp-server-host supervisorctl restart mcp-agent-framework

# Restart all servers
docker exec mcp-server-host supervisorctl restart all
```

### SSH Access Issues
```bash
# Test SSH connection
ssh tim@tim-server "docker exec mcp-server-host echo 'SSH works'"

# Test specific MCP server via SSH
ssh tim@tim-server "docker exec mcp-server-host /root/go/bin/mcp-language-server --help"
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `LOG_LEVEL` | `info` | Logging level for MCP servers |
| `WORKSPACE_PATH` | `/workspace` | Working directory for projects |
| `MCP_SERVERS_CONFIG` | `/app/config/servers.json` | Server configuration file |

## Docker Compose Integration

The container runs without network dependencies:

```yaml
version: '3.8'
services:
  mcp-server-host:
    build: .
    image: mcp-server-host:latest
    container_name: mcp-server-host
    restart: unless-stopped
    volumes:
      - ./workspace:/workspace:rw
      - ./data:/app/data:rw
      - ./logs:/var/log:rw
      - ./config:/app/config:ro
    environment:
      - LOG_LEVEL=${LOG_LEVEL:-info}
      - WORKSPACE_PATH=/workspace
    ports:
      - "8080:8080"  # Optional: for web-based servers
```