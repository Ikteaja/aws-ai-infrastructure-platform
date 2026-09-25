# CareRoster Login Failure Runbook

## Document information

- Document ID: HA-CR-002
- Hospital: Hospital A
- Application: CareRoster
- Environment: Production
- Version: 1.0
- Status: Approved for fictional demonstration
- Owner: Application Operations
- Last reviewed: 2026-09-25
- Data classification: Public synthetic demonstration data

## Purpose

Provide an investigation procedure when staff cannot sign in
to CareRoster.

All systems, teams and procedures in this document are fictional.
This document does not authorize actions on a real hospital system.

## When to use this procedure

Use this runbook when:

- The CareRoster login page reports "Sign-in unavailable".
- Multiple users report authentication failures.
- Users are repeatedly returned to the login page.

If users can sign in but cannot view schedules, select a procedure
covering application or database problems instead.

## Step 1 Record the incident

Record:

- Hospital, application and environment.
- Time the problem started, including timezone.
- Exact error message.
- Whether one user or multiple users are affected.
- Whether the login page loads.
- Incident reference number, if available.

Do not record passwords, access tokens or patient information.

## Step 2 Establish the scope

Check whether:

- The issue affects one user or multiple users.
- Other applications using the same identity service are affected.
- The application is reachable before authentication.

A shared symptom can suggest a dependency to investigate.
It does not prove the root cause.

## Step 3 Review available evidence

Using authorized monitoring and change records:

1. Check the reported availability of the identity service.
2. Check the reported availability of the CareRoster application.
3. Review recent authentication-related configuration changes.
4. Record the observations and their timestamps.

If monitoring is unavailable, record that limitation.
Do not assume a component is healthy or unhealthy without evidence.

## Step 4 Route the investigation

| Observation | Next action | Responsible team |
|---|---|---|
| One user is affected while others can sign in | Follow the approved individual account-support procedure | Service Desk |
| Several applications using the same identity service are affected | Escalate with the collected authentication evidence | Identity Operations |
| Only CareRoster is affected | Investigate the application and its authentication integration | Application Operations |
| The login page cannot be reached | Investigate application reachability and network routing | Application Operations and Infrastructure Operations |
| Evidence is missing or contradictory | Continue incident coordination and request specialist review | Application Operations |

## Step 5 Control changes

This runbook does not authorize:

- Restarting production services.
- Changing authentication configuration.
- Disabling security controls.
- Resetting accounts outside the approved account-support procedure.
- Making database changes.

Any corrective action must follow its own approved procedure
and the applicable authorization process.

## Step 6 Escalate operational impact

Application Operations coordinates the technical investigation.

If staff cannot access required schedules, notify the designated
hospital operational owner.

The operational owner decides whether to activate the hospital's
approved downtime procedure.

The detailed downtime procedure is not included in this sample.

## Step 7 Verify recovery

After the responsible team reports that corrective work is complete,
follow HA-CR-003, the CareRoster Recovery Checklist.

Do not declare recovery based only on a successful health endpoint.

## Related documents

- HA-CR-001: CareRoster Application Overview
- HA-CR-003: CareRoster Recovery Checklist