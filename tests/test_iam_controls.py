import copy
import unittest
from scripts.iam_inventory import compare
from scripts.check_iam_import_plan import check


class IAMControlsTest(unittest.TestCase):
    def setUp(self):
        self.baseline = {"account": "123", "roles": {"test": {"Tags": [{"Key": "a", "Value": "b"}], "InlinePolicies": {}, "AttachedPolicies": []}}, "managed_policies": {}, "oidc_providers": {}}
        self.mapping = {"resources": [{"root": "bootstrap", "address": "aws_iam_role.test", "import_id": "test"}]}
        self.plan = {"complete": True, "resource_changes": [{"address": "aws_iam_role.test", "change": {"actions": ["no-op"], "importing": {"id": "test"}}}]}

    def test_import_only(self):
        self.assertEqual(check(self.plan, self.mapping), 1)

    def test_reject_live_mutations(self):
        for action in (["create"], ["update"], ["delete"], ["delete", "create"]):
            plan = copy.deepcopy(self.plan)
            plan["resource_changes"][0]["change"]["actions"] = action
            with self.assertRaises(ValueError):
                check(plan, self.mapping)

    def test_reject_wrong_import(self):
        self.plan["resource_changes"][0]["change"]["importing"]["id"] = "wrong"
        with self.assertRaises(ValueError):
            check(self.plan, self.mapping)

    def test_reject_missing_import(self):
        with self.assertRaises(ValueError):
            check({"resource_changes": []}, self.mapping)

    def test_detect_unmanaged_policy_and_role(self):
        live = copy.deepcopy(self.baseline)
        live["roles"]["test"]["InlinePolicies"]["unexpected-admin"] = {"Action": "*"}
        self.assertTrue(compare(self.baseline, live))
        live = copy.deepcopy(self.baseline)
        live["roles"]["new"] = {}
        self.assertTrue(compare(self.baseline, live))

    def test_detect_attachment(self):
        live = copy.deepcopy(self.baseline)
        live["roles"]["test"]["AttachedPolicies"] = [{"PolicyArn": "unexpected"}]
        self.assertTrue(compare(self.baseline, live))

    def test_ignore_timestamp(self):
        live = copy.deepcopy(self.baseline)
        live["roles"]["test"]["RoleLastUsed"] = {"LastUsedDate": "today"}
        self.assertEqual(compare(self.baseline, live), [])


if __name__ == "__main__":
    unittest.main()
