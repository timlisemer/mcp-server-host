#!/bin/bash
set -e

CONFIG_FILE="${MCP_SERVERS_CONFIG:-/app/config/servers.json}"
TOOLS_DIR="/app/tools"
BUILTIN_DIR="/app/tools-builtin"
SERVERS_DIR="/app/servers"

echo "Initializing MCP Toolbox..."

# Process volume-enabled tools
if [ -d "$BUILTIN_DIR" ]; then
    volume_tools=$(jq -r '.tools | to_entries[] | select(.value.enabled == true and .value.docker_volume == true) | .key' "$CONFIG_FILE" 2>/dev/null || echo "")

    while IFS= read -r name; do
        if [ -z "$name" ]; then
            continue
        fi

        server_dir="$SERVERS_DIR/$name"
        tool_dir="$TOOLS_DIR/$name"
        builtin_dir="$BUILTIN_DIR/$name"

        echo "Setting up volume-enabled tool: $name"

        # Ensure the server directory exists in the mounted volume
        mkdir -p "$server_dir"

        # Check if first-run (volume is empty or missing key files)
        if [ -d "$builtin_dir" ] && [ ! -f "$server_dir/.initialized" ]; then
            echo "  First run detected, copying built artifacts to volume..."
            cp -r "$builtin_dir"/* "$server_dir"/ 2>/dev/null || true
            touch "$server_dir/.initialized"
            echo "  Initialization complete"
        fi

        # Create symlink from tools directory to servers directory
        if [ ! -L "$tool_dir" ]; then
            rm -rf "$tool_dir" 2>/dev/null || true
            ln -s "$server_dir" "$tool_dir"
            echo "  Symlink created: $tool_dir -> $server_dir"
        fi

    done <<< "$volume_tools"
fi

echo "MCP Toolbox ready"
echo ""

# Execute the original command
exec "$@"
