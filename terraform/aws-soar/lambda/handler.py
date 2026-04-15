import json
import os
import time
import uuid
from datetime import datetime, timezone

import boto3


ddb = boto3.resource("dynamodb")
sns = boto3.client("sns")
ec2 = boto3.client("ec2")
cloudwatch = boto3.client("cloudwatch")


def _to_int(value, default=0):
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def lambda_handler(event, context):
    detail = event.get("detail", {}) if isinstance(event, dict) else {}
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    incident_id = f"{timestamp}-{uuid.uuid4().hex[:8]}"

    severity = _to_int(detail.get("severity"), 0)
    event_source = event.get("source", "unknown")
    detail_type = event.get("detail-type", "unknown")
    description = detail.get("description", detail.get("message", "No description provided"))
    target_instance_id = detail.get("target_instance_id")

    table_name = os.environ["INCIDENT_TABLE_NAME"]
    topic_arn = os.environ["ALERT_TOPIC_ARN"]
    metric_namespace = os.environ.get("METRIC_NAMESPACE", "CS2/SOAR")
    enable_shutdown = os.environ.get("ENABLE_INSTANCE_SHUTDOWN", "false").lower() == "true"
    shutdown_threshold = _to_int(os.environ.get("SHUTDOWN_SEVERITY_THRESHOLD"), 8)
    response_tag_key = os.environ.get("RESPONSE_TAG_KEY", "SOARIncident")
    response_tag_prefix = os.environ.get("RESPONSE_TAG_VALUE_PREFIX", "cs2")

    table = ddb.Table(table_name)
    expires_at = int(time.time()) + (30 * 24 * 60 * 60)

    incident_record = {
        "incident_id": incident_id,
        "created_at": timestamp,
        "source": event_source,
        "detail_type": detail_type,
        "severity": severity,
        "description": description,
        "target_instance_id": target_instance_id or "",
        "raw_event": json.dumps(event)[:3000],
        "expires_at": expires_at,
    }

    table.put_item(Item=incident_record)

    message = {
        "incident_id": incident_id,
        "severity": severity,
        "source": event_source,
        "detail_type": detail_type,
        "description": description,
        "target_instance_id": target_instance_id,
    }

    sns.publish(
        TopicArn=topic_arn,
        Subject=f"CS2 SOAR alert: {detail_type}",
        Message=json.dumps(message, indent=2),
    )

    cloudwatch.put_metric_data(
        Namespace=metric_namespace,
        MetricData=[
            {
                "MetricName": "IncidentsProcessed",
                "Value": 1,
                "Unit": "Count",
            },
            {
                "MetricName": "HighSeverityAlerts",
                "Value": 1 if severity >= shutdown_threshold else 0,
                "Unit": "Count",
            },
        ],
    )

    actions = ["stored-in-dynamodb", "published-sns-alert", "published-custom-metric"]

    if target_instance_id:
        ec2.create_tags(
            Resources=[target_instance_id],
            Tags=[
                {
                    "Key": response_tag_key,
                    "Value": f"{response_tag_prefix}-{incident_id}",
                }
            ],
        )
        actions.append(f"tagged-instance:{target_instance_id}")

    if enable_shutdown and severity >= shutdown_threshold and target_instance_id:
        ec2.stop_instances(InstanceIds=[target_instance_id])
        actions.append(f"stopped-instance:{target_instance_id}")

    cloudwatch.put_metric_data(
        Namespace=metric_namespace,
        MetricData=[
            {
                "MetricName": "ActionsExecuted",
                "Value": len(actions),
                "Unit": "Count",
            }
        ],
    )

    return {
        "statusCode": 200,
        "incident_id": incident_id,
        "actions": actions,
        "record": incident_record,
        "received_at": timestamp,
        "request_id": getattr(context, "aws_request_id", "unknown"),
    }