#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <region> <event-bus-name> [severity] [target-instance-id]"
  exit 1
fi

REGION="$1"
EVENT_BUS_NAME="$2"
SEVERITY="${3:-6}"
TARGET_INSTANCE_ID="${4:-}"

DETAIL_JSON=$(cat <<EOF
{
  "severity": ${SEVERITY},
  "description": "Manual SOAR test event from script",
  "target_instance_id": "${TARGET_INSTANCE_ID}"
}
EOF
)

DETAIL_ESCAPED=$(printf '%s' "$DETAIL_JSON" | jq -cRs .)

ENTRY_FILE="$(mktemp)"
trap 'rm -f "$ENTRY_FILE"' EXIT

cat > "$ENTRY_FILE" <<EOF
[
  {
    "Source": "cs2.soar",
    "DetailType": "security-alert",
    "EventBusName": "${EVENT_BUS_NAME}",
    "Detail": ${DETAIL_ESCAPED}
  }
]
EOF

aws events put-events \
  --region "$REGION" \
  --entries "file://${ENTRY_FILE}"

echo "Submitted SOAR test event with severity ${SEVERITY}."
