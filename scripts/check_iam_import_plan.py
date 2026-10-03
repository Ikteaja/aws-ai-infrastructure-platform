"""Fail unless a Terraform JSON plan only adopts the mapped bootstrap resources."""
import argparse
import json
from pathlib import Path


def check(plan, resource_map):
    if plan.get("errored") or plan.get("complete") is False:
        raise ValueError("Plan failed or is incomplete")
    expected = {r["address"]: r["import_id"] for r in resource_map["resources"] if r["root"] == "bootstrap"}
    imported = {}
    for resource in plan.get("resource_changes", []):
        change = resource["change"]
        if resource.get("mode") == "data" and change["actions"] in (["read"], ["no-op"]):
            continue
        if change["actions"] != ["no-op"]:
            raise ValueError(f"Live mutation forbidden during adoption: {resource['address']} {change['actions']}")
        if change.get("importing"):
            imported[resource["address"]] = change["importing"].get("id")
    if imported != expected:
        raise ValueError("Import addresses/IDs do not exactly match the reviewed bootstrap resource map")
    for name, change in plan.get("output_changes", {}).items():
        if change["actions"] != ["no-op"]:
            raise ValueError(f"Unexpected output change during adoption: {name}")
    return len(imported)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("plan", type=Path)
    parser.add_argument("--map", type=Path, default=Path("docs/iam-resource-map.json"))
    args = parser.parse_args()
    count = check(json.loads(args.plan.read_text(encoding="utf-8-sig")),
                  json.loads(args.map.read_text(encoding="utf-8")))
    print(f"PASS: {count} imports; zero live resource or output changes.")
