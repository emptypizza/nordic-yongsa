#!/usr/bin/env bash
# Ensure .claude/settings.local.json keeps model=fable.
set -euo pipefail

SETTINGS="${CLAUDE_SETTINGS_LOCAL:-$(cd "$(dirname "$0")/.." && pwd)/settings.local.json}"
DESIRED_MODEL="fable"
DESIRED_FALLBACK='["opus"]'

if [[ ! -f "$SETTINGS" ]]; then
  mkdir -p "$(dirname "$SETTINGS")"
  printf '{\n  "model": "%s",\n  "fallbackModel": %s\n}\n' "$DESIRED_MODEL" "$DESIRED_FALLBACK" >"$SETTINGS"
  echo "CREATED: $SETTINGS with model=$DESIRED_MODEL"
  exit 0
fi

result="$(python3 - "$SETTINGS" "$DESIRED_MODEL" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
desired_model = sys.argv[2]
desired_fallback = ["opus"]

try:
    data = json.loads(path.read_text(encoding="utf-8"))
except json.JSONDecodeError:
    data = {}

model = data.get("model")
fallback = data.get("fallbackModel")

if model == desired_model and fallback == desired_fallback:
    print(f"OK model={model!r}")
    sys.exit(0)

data["model"] = desired_model
data["fallbackModel"] = desired_fallback
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
print(f"FIXED was model={model!r} -> {desired_model!r}")
PY
)"

echo "$result"
