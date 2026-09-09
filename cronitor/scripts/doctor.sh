#!/bin/sh
# Cronitor connection doctor.
#
# Reports which Cronitor connection paths are available to an agent on this
# machine. Never prints secret values. Always exits 0 so it is safe to run
# from any harness; read the output, not the exit status.

MCP_URL="https://cronitor.io/mcp"
cli_ok=0
key_ok=0
mcp_ok=0

echo "Cronitor connection doctor"
echo "=========================="

# 1. CronitorCLI
if command -v cronitor >/dev/null 2>&1; then
  cli_path=$(command -v cronitor)
  cli_version=$(cronitor --version 2>/dev/null | head -n 1)
  if [ -z "$cli_version" ]; then
    cli_version=$(cronitor version 2>/dev/null | head -n 1)
  fi
  [ -z "$cli_version" ] && cli_version="version unknown"
  echo "CronitorCLI:        installed ($cli_path, $cli_version)"
  cli_ok=1
else
  echo "CronitorCLI:        not installed"
fi

# 2. API key (presence only; the value is never printed)
if [ -n "${CRONITOR_API_KEY:-}" ]; then
  echo "CRONITOR_API_KEY:   set"
  key_ok=1
else
  echo "CRONITOR_API_KEY:   not set"
fi

# 3. Hosted MCP server reachability. A 401 means the server answered and is
#    asking for OAuth or a bearer token, which counts as reachable.
if command -v curl >/dev/null 2>&1; then
  http_code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$MCP_URL" 2>/dev/null)
  case "$http_code" in
    2*|3*|401|405)
      echo "Hosted MCP server:  reachable ($MCP_URL, HTTP $http_code)"
      mcp_ok=1
      ;;
    000|"")
      echo "Hosted MCP server:  unreachable ($MCP_URL, no response within 5s)"
      ;;
    *)
      echo "Hosted MCP server:  responded with HTTP $http_code ($MCP_URL)"
      ;;
  esac
else
  echo "Hosted MCP server:  not checked (curl is not installed)"
fi

echo ""
echo "Recommended path"
echo "----------------"
if [ "$mcp_ok" -eq 1 ]; then
  echo "1. Hosted MCP server at $MCP_URL if your client already has it connected."
  echo "   Otherwise follow https://cronitor.io/docs/mcp-server.md#connect-your-mcp-client"
  echo "   and let the human complete OAuth in the browser."
fi
if [ "$cli_ok" -eq 1 ] && [ "$key_ok" -eq 1 ]; then
  echo "2. CronitorCLI is installed and CRONITOR_API_KEY is set: 'cronitor status',"
  echo "   'cronitor monitor list', and the other resource commands will work."
elif [ "$cli_ok" -eq 1 ]; then
  echo "2. CronitorCLI is installed but CRONITOR_API_KEY is not set. Ask the human to"
  echo "   inject the SDK Integration key into the environment; do not paste it in chat."
elif [ "$key_ok" -eq 1 ]; then
  echo "2. CRONITOR_API_KEY is set but CronitorCLI is not installed. Use the REST API"
  echo "   with HTTP Basic auth (key as username), or install the CLI:"
  echo "   https://cronitor.io/docs/using-cronitor-cli.md#installation"
fi
if [ "$mcp_ok" -eq 0 ] && [ "$cli_ok" -eq 0 ] && [ "$key_ok" -eq 0 ]; then
  echo "No connection path is available. Report 'blocked' and link"
  echo "https://cronitor.io/docs/agent-quickstart.md#connect-cronitor for the human."
fi

exit 0
