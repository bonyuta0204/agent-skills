#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -lt 1 || "$#" -gt 2 ]]; then
  echo "usage: $0 <rds_instance_identifier> [region]" >&2
  exit 1
fi

RDS_INSTANCE_ID="$1"

resolve_region() {
  if [[ -n "${AWS_REGION:-}" ]]; then
    printf '%s\n' "$AWS_REGION"
    return 0
  fi

  local configured
  configured="$(aws configure get region 2>/dev/null || true)"
  if [[ -n "$configured" ]]; then
    printf '%s\n' "$configured"
    return 0
  fi

  printf '%s\n' "us-east-1"
}

REGION="${2:-$(resolve_region)}"

for c in aws jq; do
  if ! command -v "$c" >/dev/null 2>&1; then
    echo "command not found: $c" >&2
    exit 1
  fi
done

rds_json="$(aws rds describe-db-instances \
  --region "$REGION" \
  --db-instance-identifier "$RDS_INSTANCE_ID" \
  --output json)"

echo "== RDS summary =="
echo "$rds_json" | jq -r '
  .DBInstances[0] as $db |
  [
    "identifier=" + ($db.DBInstanceIdentifier // ""),
    "engine=" + ($db.Engine // ""),
    "status=" + ($db.DBInstanceStatus // ""),
    "endpoint=" + ($db.Endpoint.Address // ""),
    "port=" + (($db.Endpoint.Port // 0) | tostring),
    "publicly_accessible=" + (($db.PubliclyAccessible // false) | tostring),
    "vpc_id=" + ($db.DBSubnetGroup.VpcId // ""),
    "subnets=" + (($db.DBSubnetGroup.Subnets | map(.SubnetIdentifier) | join(",")) // ""),
    "sg_ids=" + (($db.VpcSecurityGroups | map(.VpcSecurityGroupId) | join(",")) // "")
  ] | .[]
'

sg_ids=()
while IFS= read -r sg; do
  [[ -n "$sg" ]] && sg_ids+=("$sg")
done < <(echo "$rds_json" | jq -r '.DBInstances[0].VpcSecurityGroups[].VpcSecurityGroupId // empty')

if [[ "${#sg_ids[@]}" -gt 0 ]]; then
  echo
  echo "== RDS SG inbound rules related to TCP 3306 =="
  aws ec2 describe-security-groups --region "$REGION" --group-ids "${sg_ids[@]}" --output json \
    | jq -r '
      .SecurityGroups[] as $sg |
      ($sg.IpPermissions // [])[]? as $p |
      select((($p.IpProtocol == "tcp") or ($p.IpProtocol == "-1")) and (($p.FromPort // 0) <= 3306) and (($p.ToPort // 65535) >= 3306)) |
      {
        sg_id: $sg.GroupId,
        sg_name: $sg.GroupName,
        protocol: $p.IpProtocol,
        from_port: ($p.FromPort // -1),
        to_port: ($p.ToPort // -1),
        source_sg: (($p.UserIdGroupPairs // []) | map(.GroupId) | join(",")),
        source_cidr4: (($p.IpRanges // []) | map(.CidrIp) | join(",")),
        source_cidr6: (($p.Ipv6Ranges // []) | map(.CidrIpv6) | join(","))
      } |
      [
        "sg_id=" + .sg_id,
        "sg_name=" + .sg_name,
        "protocol=" + .protocol,
        "port_range=" + (.from_port|tostring) + "-" + (.to_port|tostring),
        "source_sg=" + (.source_sg // ""),
        "source_cidr4=" + (.source_cidr4 // ""),
        "source_cidr6=" + (.source_cidr6 // "")
      ] | join(" ")
    '
else
  echo
  echo "No RDS security groups found."
fi

echo
echo "== SSM online EC2 instances (bastion candidates) =="
instance_ids=()
while IFS= read -r id; do
  [[ -n "$id" ]] && instance_ids+=("$id")
done < <(
  aws ssm describe-instance-information \
    --region "$REGION" \
    --output json \
    | jq -r '.InstanceInformationList[] | select(.PingStatus == "Online" and .ResourceType == "EC2") | .InstanceId'
)

if [[ "${#instance_ids[@]}" -eq 0 ]]; then
  echo "No online EC2 managed instances found in SSM."
  exit 0
fi

aws ec2 describe-instances --region "$REGION" --instance-ids "${instance_ids[@]}" --output json \
  | jq -r '
    [
      .Reservations[].Instances[]
      | {
          instance_id: .InstanceId,
          state: .State.Name,
          name: ((.Tags // [] | map(select(.Key == "Name") | .Value) | .[0]) // ""),
          vpc_id: (.VpcId // ""),
          subnet_id: (.SubnetId // ""),
          private_ip: (.PrivateIpAddress // ""),
          sg_ids: ((.SecurityGroups // []) | map(.GroupId) | join(",")),
          likely_bastion: (((.Tags // [] | map(select(.Key == "Name") | .Value) | join(" ")) | test("(?i)(bastion|jump|infra|ops|admin)")))
        }
    ]
    | sort_by((.likely_bastion | not), .name, .instance_id)
    | .[]
    | [
        "instance_id=" + .instance_id,
        "state=" + .state,
        "name=" + .name,
        "likely_bastion=" + (.likely_bastion | tostring),
        "vpc_id=" + .vpc_id,
        "subnet_id=" + .subnet_id,
        "private_ip=" + .private_ip,
        "sg_ids=" + .sg_ids
      ]
    | join(" ")
  '
