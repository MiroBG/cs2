#!/usr/bin/env python3
import argparse
import json
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Dict, List, Optional, Tuple

PATTERNS: List[Tuple[re.Pattern, str, int, str]] = [
    (re.compile(r"failed password|authentication failure", re.IGNORECASE), "ssh_failed_login", 4, "Repeated SSH authentication failures detected"),
    (re.compile(r"xmrig|cryptominer|mining pool|coinhive", re.IGNORECASE), "cryptominer", 9, "Potential cryptominer activity detected"),
    (re.compile(r"data exfiltration|unexpected upload|large outbound transfer|suspicious transfer", re.IGNORECASE), "data_exfiltration", 8, "Potential data exfiltration behavior detected"),
    (re.compile(r"lateral movement|pass-the-hash|psexec|wmic remote|remote exec", re.IGNORECASE), "lateral_movement", 8, "Potential lateral movement behavior detected"),
    (re.compile(r"nmap|port scan|masscan", re.IGNORECASE), "reconnaissance", 5, "Reconnaissance activity detected"),
]

SEVERITY_BY_EVENT_TYPE: Dict[str, int] = {
    "ssh_failed_login": 4,
    "cryptominer": 9,
    "data_exfiltration": 8,
    "lateral_movement": 8,
    "reconnaissance": 5,
}


def _require_aws_cli() -> None:
    if shutil.which("aws") is None:
        raise RuntimeError("aws CLI is required but was not found in PATH")


def _send_event(region: str, event_bus: str, source: str, detail_type: str, detail: Dict[str, object]) -> Dict[str, object]:
    _require_aws_cli()

    entry = [{
        "Source": source,
        "DetailType": detail_type,
        "EventBusName": event_bus,
        "Detail": json.dumps(detail),
    }]

    cmd = [
        "aws",
        "events",
        "put-events",
        "--region",
        region,
        "--entries",
        json.dumps(entry),
    ]

    result = subprocess.run(cmd, check=False, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "aws events put-events failed")

    response = json.loads(result.stdout)
    if response.get("FailedEntryCount", 0) > 0:
        raise RuntimeError(f"put-events reported failed entries: {result.stdout.strip()}")

    return response


def _classify_line(line: str) -> Optional[Tuple[str, int, str]]:
    for pattern, event_type, severity, summary in PATTERNS:
        if pattern.search(line):
            return event_type, severity, summary
    return None


def _read_offset(state_file: Path) -> int:
    if not state_file.exists():
        return 0

    try:
        return int(state_file.read_text().strip())
    except (ValueError, OSError):
        return 0


def _write_offset(state_file: Path, offset: int) -> None:
    state_file.parent.mkdir(parents=True, exist_ok=True)
    state_file.write_text(str(offset))


def _forward_classified(
    *,
    args: argparse.Namespace,
    event_type: str,
    severity: int,
    description: str,
    dry_run: bool,
) -> None:
    if dry_run:
        print(f"DRY RUN event_type={event_type} severity={severity} description={description}")
        return

    detail = {
        "severity": severity,
        "description": description,
        "event_type": event_type,
        "target_instance_id": args.target_instance_id,
        "client_id": args.client_id,
    }

    response = _send_event(
        region=args.region,
        event_bus=args.event_bus,
        source=args.source,
        detail_type="security-alert",
        detail=detail,
    )
    event_id = response.get("Entries", [{}])[0].get("EventId", "unknown")
    print(f"Forwarded event_type={event_type} severity={severity} event_id={event_id}")


def command_send(args: argparse.Namespace) -> int:
    severity = args.severity
    if severity is None:
        severity = SEVERITY_BY_EVENT_TYPE.get(args.event_type, 6)

    detail = {
        "severity": int(severity),
        "description": args.description,
        "event_type": args.event_type,
        "target_instance_id": args.target_instance_id,
        "client_id": args.client_id,
    }

    response = _send_event(
        region=args.region,
        event_bus=args.event_bus,
        source=args.source,
        detail_type="security-alert",
        detail=detail,
    )

    event_id = response.get("Entries", [{}])[0].get("EventId", "unknown")
    print(f"Submitted event_type={args.event_type} severity={severity} event_id={event_id}")
    return 0


def command_parse_log(args: argparse.Namespace) -> int:
    log_path = Path(args.file)
    if not log_path.exists():
        print(f"Log file does not exist: {log_path}", file=sys.stderr)
        return 1

    lines = log_path.read_text(errors="replace").splitlines()
    lines_to_check = lines[-args.tail_lines :] if args.tail_lines > 0 else lines

    matches = 0
    for line in lines_to_check:
        classified = _classify_line(line)
        if not classified:
            continue

        event_type, severity, summary = classified
        description = f"{summary}; raw='{line[:180]}'"
        matches += 1

        _forward_classified(
            args=args,
            event_type=event_type,
            severity=severity,
            description=description,
            dry_run=args.dry_run,
        )

    print(f"Processed {len(lines_to_check)} lines; matched {matches} suspicious events")
    return 0


def command_poll_log(args: argparse.Namespace) -> int:
    log_path = Path(args.file)
    if not log_path.exists():
        print(f"Log file does not exist: {log_path}", file=sys.stderr)
        return 1

    state_file = Path(args.state_file) if args.state_file else Path(f"/tmp/soar-forwarder-{log_path.name}.offset")

    while True:
        try:
            current_size = log_path.stat().st_size
        except OSError as exc:
            print(f"Unable to stat log file {log_path}: {exc}", file=sys.stderr)
            return 1

        last_offset = _read_offset(state_file)
        if last_offset > current_size:
            last_offset = 0

        with log_path.open("r", errors="replace") as f:
            f.seek(last_offset)
            new_lines = f.readlines()
            new_offset = f.tell()

        if args.max_lines > 0 and len(new_lines) > args.max_lines:
            new_lines = new_lines[-args.max_lines :]

        matches = 0
        for line in new_lines:
            classified = _classify_line(line)
            if not classified:
                continue

            event_type, severity, summary = classified
            description = f"{summary}; raw='{line.strip()[:180]}'"
            matches += 1

            _forward_classified(
                args=args,
                event_type=event_type,
                severity=severity,
                description=description,
                dry_run=args.dry_run,
            )

        _write_offset(state_file, new_offset)

        if new_lines or matches:
            print(
                f"Poll cycle processed_lines={len(new_lines)} matched={matches} "
                f"offset={new_offset} state_file={state_file}"
            )

        if args.once:
            break

        time.sleep(args.interval)

    return 0


def command_simulate_flavor_a(args: argparse.Namespace) -> int:
    scenarios = [
        ("cryptominer", "Flavor A simulation: cryptominer process signature detected"),
        ("data_exfiltration", "Flavor A simulation: unusual outbound data transfer detected"),
        ("lateral_movement", "Flavor A simulation: lateral movement behavior detected"),
    ]

    for event_type, description in scenarios:
        severity = SEVERITY_BY_EVENT_TYPE[event_type]
        detail = {
            "severity": severity,
            "description": description,
            "event_type": event_type,
            "target_instance_id": args.target_instance_id,
            "client_id": args.client_id,
        }

        if args.dry_run:
            print(f"DRY RUN event_type={event_type} severity={severity} description={description}")
            continue

        response = _send_event(
            region=args.region,
            event_bus=args.event_bus,
            source=args.source,
            detail_type="security-alert",
            detail=detail,
        )
        event_id = response.get("Entries", [{}])[0].get("EventId", "unknown")
        print(f"Submitted event_type={event_type} severity={severity} event_id={event_id}")

    print(f"Completed Flavor A simulation for client_id={args.client_id}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Forward client-side security signals to EventBridge for SOAR processing"
    )
    parser.add_argument("--region", required=True, help="AWS region, e.g. eu-central-1")
    parser.add_argument("--event-bus", default="default", help="EventBridge bus name")
    parser.add_argument("--source", default="cs2.soar", help="EventBridge source")
    parser.add_argument("--client-id", default="client-unknown", help="Client identifier")
    parser.add_argument("--target-instance-id", default="", help="Optional affected instance ID")

    subparsers = parser.add_subparsers(dest="command", required=True)

    send = subparsers.add_parser("send", help="Send one explicit security event")
    send.add_argument("--event-type", required=True, choices=sorted(SEVERITY_BY_EVENT_TYPE.keys()))
    send.add_argument("--severity", type=int, help="Optional explicit severity override")
    send.add_argument("--description", required=True, help="Event description")
    send.set_defaults(func=command_send)

    parse_log = subparsers.add_parser("parse-log", help="Parse a client log file and forward matching events")
    parse_log.add_argument("--file", required=True, help="Path to log file")
    parse_log.add_argument("--tail-lines", type=int, default=200, help="How many latest lines to inspect")
    parse_log.add_argument("--dry-run", action="store_true", help="Print mapped events without sending")
    parse_log.set_defaults(func=command_parse_log)

    poll_log = subparsers.add_parser("poll-log", help="Continuously parse new log lines and forward matches")
    poll_log.add_argument("--file", required=True, help="Path to log file")
    poll_log.add_argument("--state-file", help="Path to file offset state (default: /tmp/soar-forwarder-<log>.offset)")
    poll_log.add_argument("--interval", type=int, default=10, help="Polling interval in seconds")
    poll_log.add_argument("--max-lines", type=int, default=500, help="Max new lines processed per poll cycle")
    poll_log.add_argument("--once", action="store_true", help="Run one poll cycle and exit")
    poll_log.add_argument("--dry-run", action="store_true", help="Print mapped events without sending")
    poll_log.set_defaults(func=command_poll_log)

    simulate = subparsers.add_parser("simulate-flavor-a", help="Send core Flavor A simulation scenarios")
    simulate.add_argument("--dry-run", action="store_true", help="Print scenarios without sending")
    simulate.set_defaults(func=command_simulate_flavor_a)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    try:
        return args.func(args)
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
