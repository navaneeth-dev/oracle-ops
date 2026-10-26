#!/usr/bin/env sh
# Grafana MCP server (stdio) for any coding agent. Run from the repository root.
set -eu
cd "$(dirname "$0")/.."
export GRAFANA_URL=https://grafana.oci.fossindia.ovh
exec mise exec -- sops exec-env .mcp/grafana.sops.env 'uvx mcp-grafana@2.1.1 --disable-write'
