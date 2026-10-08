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
mcp_reachable=0
mcp_http=""
install_blocked=0
step=1

# Exact install commands. print_cli_install prints the one this host should run first.
INSTALL_WITH_SUDO="curl -fsSL 'https://cronitor.io/install-linux?sudo=1' | sh"
INSTALL_AS_ROOT="curl -fsSL 'https://cronitor.io/install-linux' | sh"

# Root runs the installer directly. A non-root user needs sudo. Without either,
# do not print a command that will fail writing /usr/bin.
print_cli_install() {
  install_uid=$(id -u 2>/dev/null || true)
  if [ "$install_uid" != "0" ] && ! command -v sudo >/dev/null 2>&1; then
    install_blocked=1
    echo "   Installing CronitorCLI to /usr/bin needs root or sudo."
    echo "   This user is not root and sudo is not installed."
    if [ "$key_ok" -eq 1 ]; then
      echo "   The REST API still works with this key (HTTP Basic auth, key as the username)."
    else
      echo "   Report 'blocked' and ask the human to re-run as root or install sudo."
    fi
    echo "   macOS and other options: https://cronitor.io/docs/using-cronitor-cli.md#installation"
    return
  fi
  install_blocked=0
  if [ "$install_uid" = "0" ]; then
    echo "   Run:"
    echo "   $INSTALL_AS_ROOT"
    echo "   When sudo is installed and you are not root:"
    echo "   $INSTALL_WITH_SUDO"
  else
    echo "   Run:"
    echo "   $INSTALL_WITH_SUDO"
    echo "   When already root:"
    echo "   $INSTALL_AS_ROOT"
  fi
  echo "   macOS and other options: https://cronitor.io/docs/using-cronitor-cli.md#installation"
}

echo "Cronitor connection doctor"
echo "=========================="

# Version token from a "CronitorCLI version <token>" line. Same rule as the
# Linux installer: the token is the leading [A-Za-z0-9._+-] run, so anything
# after it is not part of the version and is not executed.
extract_cli_version() {
  _version=""
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      *"CronitorCLI version "*)
        _version=${line#*"CronitorCLI version "}
        _version=${_version%%[!A-Za-z0-9._+-]*}
        break
        ;;
    esac
  done
  printf '%s' "$_version"
}

# A future `cronitor --version` may print a bare token instead of the banner.
bare_version_token() {
  case "$1" in
    *[!A-Za-z0-9._+-]*|"")
      printf '%s' ""
      ;;
    *[0-9]*)
      printf '%s' "$1"
      ;;
    *)
      printf '%s' ""
      ;;
  esac
}

# 1. CronitorCLI
if command -v cronitor >/dev/null 2>&1; then
  cli_path=$(command -v cronitor)
  # 33.8 has no --version and no `version` command. Use --version only when
  # that invocation succeeds and yields a version; otherwise parse --help,
  # which prints "CronitorCLI version <token>".
  cli_version=""
  if command -v timeout >/dev/null 2>&1; then
    version_out=$(timeout 10 cronitor --version </dev/null 2>/dev/null)
    version_rc=$?
  else
    version_out=$(cronitor --version </dev/null 2>/dev/null)
    version_rc=$?
  fi
  if [ "$version_rc" -eq 0 ]; then
    cli_version=$(printf '%s\n' "$version_out" | extract_cli_version)
    if [ -z "$cli_version" ]; then
      first=$(printf '%s\n' "$version_out" | head -n 1)
      cli_version=$(bare_version_token "$first")
    fi
  fi
  if [ -z "$cli_version" ]; then
    if command -v timeout >/dev/null 2>&1; then
      help_out=$(timeout 10 cronitor --help </dev/null 2>&1 || true)
    else
      help_out=$(cronitor --help </dev/null 2>&1 || true)
    fi
    cli_version=$(printf '%s\n' "$help_out" | extract_cli_version)
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

# 3. Hosted MCP server reachability.
#    2xx, 3xx, 401, and 405 mean the endpoint answered. The live server returns
#    401 to an unauthenticated probe; that does not say whether this agent has
#    an MCP client. Reachability must not hide CLI install guidance.
if command -v curl >/dev/null 2>&1; then
  mcp_http=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$MCP_URL" 2>/dev/null)
  case "$mcp_http" in
    2*|3*|401|405)
      echo "Hosted MCP server:  reachable ($MCP_URL, HTTP $mcp_http)"
      mcp_reachable=1
      ;;
    000|"")
      echo "Hosted MCP server:  unreachable ($MCP_URL, no response within 5s)"
      ;;
    *)
      echo "Hosted MCP server:  responded with HTTP $mcp_http ($MCP_URL)"
      ;;
  esac
else
  echo "Hosted MCP server:  not checked (curl is not installed)"
fi

echo ""
echo "Recommended path"
echo "----------------"
if [ "$mcp_reachable" -eq 1 ]; then
  echo "$step. Hosted MCP server at $MCP_URL, preferred when your agent supports MCP clients."
  echo "   If it is not connected yet, add it: https://cronitor.io/docs/mcp-server.md#connect-your-mcp-client"
  echo "   and let the human sign in or create an account in the browser."
  step=$((step + 1))
fi
if [ "$cli_auth" = "signed_in" ]; then
  if [ -n "$cli_org" ]; then
    echo "$step. CronitorCLI is signed in to $cli_org. Use it, and verify access with"
  else
    echo "$step. CronitorCLI is signed in. Use it, and verify access with"
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
  echo "$step. CronitorCLI is installed and CRONITOR_API_KEY is set. Verify access with"
  echo "   'cronitor monitor list'; key presence alone does not prove it is valid."
elif [ "$cli_ok" -eq 1 ]; then
  case "$cli_auth" in
    key)
      echo "$step. CronitorCLI has an API key configured outside 'cronitor auth login'."
      echo "   Verify it with 'cronitor monitor list' before relying on it."
      ;;
    none)
      echo "$step. CronitorCLI is installed but not signed in."
      ;;
    expired)
      echo "$step. CronitorCLI's saved credential is no longer valid; sign in again."
      ;;
    *)
      echo "$step. CronitorCLI may already have a saved credential even though the environment"
      echo "   key is unset. Try 'cronitor monitor list' with the intended config first."
      ;;
  esac
  echo "   If login is needed, browser login needs CronitorCLI 33.7 or later."
  echo "   Choose a writable config. On this machine use 'cronitor auth login --timeout 30m'."
  echo "   Use '--no-browser' only when the browser is on another machine: the human runs"
  echo "   'cronitor auth login --no-browser --timeout 30m' in their terminal, opens its URL,"
  echo "   then pastes the callback URL directly into its hidden prompt."
  echo "   Pass '--timeout 30m' so the CLI waits long enough for a relayed link"
  echo "   (CronitorCLI 33.8 and earlier default to 5 minutes)."
  echo "   Once you open the link, finish signing in within about 5 minutes."
  echo "   Restarting login invalidates the previous URL."
  echo "   Never request callback URLs, keys, or passwords in chat."
  echo "   Verify with 'cronitor auth status'. Do not log out as task cleanup."
elif [ "$key_ok" -eq 1 ]; then
  echo "$step. CRONITOR_API_KEY is set but CronitorCLI is not installed. Use the REST API"
  echo "   with HTTP Basic auth (key as the username), or install the CLI."
  echo "   Explain the change and obtain approval unless already authorized."
  print_cli_install
else
  echo "$step. CronitorCLI is not installed. Explain the change and obtain approval unless"
  echo "   already authorized."
  print_cli_install
  if [ "$install_blocked" -eq 0 ]; then
    echo "   Then sign in with 'cronitor auth login --timeout 30m'."
    echo "   Pass '--timeout 30m' so the CLI waits long enough for a relayed link"
    echo "   (CronitorCLI 33.8 and earlier default to 5 minutes)."
    echo "   Use '--no-browser' only when the browser is on another machine."
    echo "   Once you open the link, finish signing in within about 5 minutes."
    echo "   Restarting login invalidates the previous URL."
    echo "   Report 'blocked' if installation or browser approval is unavailable;"
    echo "   do not ask for credentials in chat."
  fi
fi

exit 0
