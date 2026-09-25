# CareRoster Recovery Checklist

## Document information

- Document ID: HA-CR-003
- Hospital: Hospital A
- Application: CareRoster
- Environment: Production
- Version: 1.0
- Status: Approved for fictional demonstration
- Owner: Application Operations
- Last reviewed: 2026-09-25
- Data classification: Public synthetic demonstration data

## Purpose

Verify that CareRoster is usable after an application or login outage.

All systems, teams and procedures in this document are fictional.
This checklist is for the demonstration project.

## When to use this checklist

Start after the responsible technical team reports that
corrective work is complete.

Record the incident reference and the affected environment.

## Step 1 Confirm technical availability

Using authorized monitoring:

- Confirm that the application is reachable.
- Confirm the application's health check succeeds.
- Review the status of dependencies relevant to the incident.
- Record any remaining errors or unavailable monitoring.

A successful health check confirms only what that check measures.
It does not prove that users can sign in or view schedules.

## Step 2 Verify login

Using an authorized test account:

- Open the CareRoster login page.
- Complete the normal sign-in process.
- Confirm that the expected application page loads.
- Confirm that the original login error no longer occurs.

Do not bypass authentication or use another person's credentials.

## Step 3 Verify the affected function

For a login or schedule-viewing incident:

- Open the approved test schedule.
- Confirm that the expected schedule information is displayed.
- Confirm that navigation between the relevant pages works.
- Sign out normally.

This checklist does not authorize changes to real staff schedules.

## Step 4 Obtain operational confirmation

Ask the designated hospital operational representative to confirm
that the affected workflow is usable.

Record:

- The role providing confirmation.
- The verification time.
- Any remaining limitations.

Technical verification and operational confirmation are
separate checks.

## Step 5 Decide whether recovery is complete

Recovery can be recorded when:

- The relevant technical checks pass.
- Login and affected-function checks pass.
- Operational confirmation has been obtained.
- Remaining limitations are documented and accepted
  by the responsible incident owner.

If a required check fails:

- Record the failed check and observed error.
- Return the incident to Application Operations.
- Continue the applicable investigation procedure.
- Do not report full recovery.

## Step 6 Record the recovery evidence

Update the incident record with:

- Incident reference.
- Hospital, application and environment.
- Corrective action reference supplied by the responsible team.
- Checks performed and their results.
- Verification timestamps.
- Operational confirmation.
- Remaining limitations and follow-up actions.

Do not include passwords, access tokens or patient information.

## Related documents

- HA-CR-001: CareRoster Application Overview
- HA-CR-002: CareRoster Login Failure Runbook