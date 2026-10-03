"""Read-only project IAM inventory. Requires AWS CLI credentials; never modifies AWS."""
import argparse
import datetime
import json
import subprocess
from pathlib import Path

ACCOUNT = "429496640190"


def aws(*args):
    result = subprocess.run(["aws", *args, "--output", "json", "--no-cli-pager"],
                            check=True, capture_output=True, text=True)
    return json.loads(result.stdout)


def inventory():
    identity = aws("sts", "get-caller-identity")
    if identity["Account"] != ACCOUNT:
        raise ValueError("Refusing inventory of unexpected AWS account")
    roles = aws("iam", "list-roles")["Roles"]
    result = {"account": ACCOUNT, "captured_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "roles": {}, "managed_policies": {}, "oidc_providers": {},
              "excluded_roles": sorted(r["RoleName"] for r in roles if not r["RoleName"].startswith("healthops-"))}
    for role in roles:
        name = role["RoleName"]
        if not name.startswith("healthops-"):
            continue
        detail = aws("iam", "get-role", "--role-name", name)["Role"]
        detail.pop("RoleLastUsed", None)
        detail["InlinePolicies"] = {
            p: aws("iam", "get-role-policy", "--role-name", name, "--policy-name", p)["PolicyDocument"]
            for p in aws("iam", "list-role-policies", "--role-name", name)["PolicyNames"]}
        detail["AttachedPolicies"] = aws("iam", "list-attached-role-policies", "--role-name", name)["AttachedPolicies"]
        result["roles"][name] = detail
    for policy in aws("iam", "list-policies", "--scope", "Local")["Policies"]:
        if not policy["PolicyName"].startswith("healthops-"):
            continue
        arn = policy["Arn"]
        detail = aws("iam", "get-policy", "--policy-arn", arn)["Policy"]
        detail["Document"] = aws("iam", "get-policy-version", "--policy-arn", arn,
                                 "--version-id", detail["DefaultVersionId"])["PolicyVersion"]["Document"]
        detail["Tags"] = aws("iam", "list-policy-tags", "--policy-arn", arn)["Tags"]
        result["managed_policies"][arn] = detail
    for provider in aws("iam", "list-open-id-connect-providers")["OpenIDConnectProviderList"]:
        arn = provider["Arn"]
        if arn.endswith("oidc-provider/token.actions.githubusercontent.com"):
            result["oidc_providers"][arn] = aws("iam", "get-open-id-connect-provider", "--open-id-connect-provider-arn", arn)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--baseline", type=Path, help="Fail on drift from a reviewed inventory")
    args = parser.parse_args()
    result = inventory()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"Inventoried {len(result['roles'])} project roles, {len(result['managed_policies'])} managed policies and {len(result['oidc_providers'])} OIDC providers: {args.output}")
    if args.baseline:
        differences = compare(json.loads(args.baseline.read_text(encoding="utf-8")), result)
        for difference in differences:
            print(f"DRIFT: {difference}")
        if differences:
            raise SystemExit(2)
        print("No project IAM drift from the reviewed baseline.")


def normalize(value):
    # IAM returns tags, statements and action lists in arbitrary order.
    ignored = {"captured_at", "CreateDate", "UpdateDate", "RoleLastUsed", "DefaultVersionId"}
    if isinstance(value, dict):
        return {k: normalize(v) for k, v in sorted(value.items()) if k not in ignored}
    if isinstance(value, list):
        return sorted((normalize(v) for v in value), key=lambda v: json.dumps(v, sort_keys=True))
    return value


def compare(expected, actual):
    differences = []
    if expected["account"] != actual["account"]:
        differences.append("AWS account changed")
    for category in ("roles", "managed_policies", "oidc_providers"):
        for name in sorted(set(expected[category]) | set(actual[category])):
            if name not in expected[category]:
                differences.append(f"Unexpected {category}: {name}")
            elif name not in actual[category]:
                differences.append(f"Missing {category}: {name}")
            elif normalize(expected[category][name]) != normalize(actual[category][name]):
                differences.append(f"Changed {category}: {name}")
    return differences


if __name__ == "__main__":
    main()
