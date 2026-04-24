# Deprecated: please use bash install.sh --platform claude
#!/bin/bash
# Claude legacy entry point compatibility wrapper
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

exec bash "$SCRIPT_DIR/install.sh" --platform claude "$@"
