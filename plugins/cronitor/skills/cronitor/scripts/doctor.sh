#!/bin/sh
# Cronitor connection doctor.
#
# Reports which Cronitor connection paths are available to an agent on this
# machine. Never prints secret values. Always exits 0 so it is safe to run
# from any harness; read the output, not the exit status.

MCP_URL="${CRONITOR_MCP_URL:-https://cronitor.io/mcp}"
cli_ok=0
cli_auth=""
cli_org=""
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

  # Which account the CLI is signed in to. Only the state and the organization
  # name are printed; keys and the config path never are.
  if command -v timeout >/dev/null 2>&1; then
    auth_out=$(timeout 10 cronitor auth status </dev/null 2>&1)
  else
    auth_out=$(cronitor auth status </dev/null 2>&1)
  fi
  case "$auth_out" in
    *"Machine credential is no longer valid"*)
      cli_auth=expired
      auth_state="saved credential is no longer valid; run 'cronitor auth login'"
      ;;
    *"Not logged in"*)
      cli_auth=none
      auth_state="not signed in"
      ;;
    *"not managed by auth login"*)
      cli_auth=key
      auth_state="API key configured (not from auth login); verify with 'cronitor monitor list'"
      ;;
    *)
      if printf '%s\n' "$auth_out" | grep -q '^[[:space:]]*Logged in[[:space:]]*$'; then
        cli_auth=signed_in
        cli_org=$(printf '%s\n' "$auth_out" | sed -n 's/^[[:space:]]*Organization:[[:space:]]*//p' | head -n 1 | sed 's/[[:space:]]*$//')
        if [ -n "$cli_org" ]; then auth_state="signed in to $cli_org"; else auth_state="signed in"; fi
      else
        cli_auth=unknown
        auth_state="unknown (run 'cronitor auth status')"
      fi
      ;;
  esac
  echo "CronitorCLI auth:   $auth_state"
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
  echo "   and let the human sign in or create an account in the browser."
fi
if [ "$cli_auth" = "signed_in" ]; then
  if [ -n "$cli_org" ]; then
    echo "2. CronitorCLI is signed in to $cli_org. Use it, and verify access with"
  else
    echo "2. CronitorCLI is signed in. Use it, and verify access with"
  fi
  echo "   'cronitor monitor list'."
  if [ "$key_ok" -eq 1 ]; then
    echo "   CRONITOR_API_KEY is also set and may point at a different account;"
    echo "   check which one 'cronitor monitor list' shows."
  fi
  if [ -n "$cli_org" ]; then
    echo "   Confirm with the human that $cli_org is the right organization before you change anything."
  fi
elif [ "$cli_ok" -eq 1 ] && [ "$key_ok" -eq 1 ]; then
  echo "2. CronitorCLI is installed and CRONITOR_API_KEY is set. Verify access with"
  echo "   'cronitor monitor list'; key presence alone does not prove it is valid."
elif [ "$cli_ok" -eq 1 ]; then
  case "$cli_auth" in
    key)
      echo "2. CronitorCLI has an API key configured outside 'cronitor auth login'."
      echo "   Verify it with 'cronitor monitor list' before relying on it."
      ;;
    none)
      echo "2. CronitorCLI is installed but not signed in."
      ;;
    expired)
      echo "2. CronitorCLI's saved credential is no longer valid; sign in again."
      ;;
    *)
      echo "2. CronitorCLI may already have a saved credential even though the environment"
      echo "   key is unset. Try 'cronitor monitor list' with the intended config first."
      ;;
  esac
  echo "   If login is needed, browser login needs CronitorCLI 33.7 or later."
  echo "   Choose a writable config. Locally use 'cronitor auth login'. Remotely,"
  echo "   have the human run 'cronitor auth login --no-browser' in their terminal,"
  echo "   open its URL, then paste the callback URL directly into its hidden prompt."
  echo "   Never request callback URLs, keys, or passwords in chat."
  echo "   Verify with 'cronitor auth status'. Do not log out as task cleanup."
elif [ "$key_ok" -eq 1 ]; then
  echo "2. CRONITOR_API_KEY is set but CronitorCLI is not installed. Use the REST API"
  echo "   with HTTP Basic auth (key as username), or install the CLI:"
  echo "   https://cronitor.io/docs/using-cronitor-cli.md#installation"
fi
if [ "$mcp_ok" -eq 0 ] && [ "$cli_ok" -eq 0 ] && [ "$key_ok" -eq 0 ]; then
  echo "No existing connection path was detected. If a shell is available, follow"
  echo "https://cronitor.io/docs/agent-quickstart.md#connect-cronitor to install the"
  echo "CLI and start browser login with the human. Report 'blocked' if installation"
  echo "or browser approval is unavailable; do not ask for credentials in chat."
fi

exit 0
