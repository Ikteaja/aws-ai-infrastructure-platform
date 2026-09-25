# CareRoster Application Overview

## Document information

- Document ID: HA-CR-001
- Hospital: Hospital A
- Application: CareRoster
- Environment: Production
- Version: 1.0
- Status: Approved for fictional demonstration
- Owner: Application Operations
- Last reviewed: 2026-09-25
- Data classification: Public synthetic demonstration data

## Purpose

CareRoster is a fictional staff-scheduling application.

Hospital staff use it to view their assigned shifts.
Scheduling coordinators use it to maintain staff schedules.

## Operational impact

When CareRoster is unavailable, staff may be unable to view
current schedules or make scheduling changes.

The responsible operational team must follow the hospital's
approved downtime procedure.

## Application dependencies

| Component | Responsibility | Support owner |
|---|---|---|
| Identity service | Authenticate staff signing in | Identity Operations |
| Application service | Display and manage schedules | Application Operations |
| Database | Store scheduling information | Database Operations |
| Network and load balancer | Route requests to the application | Infrastructure Operations |

## Initial incident information

Record the following before selecting a troubleshooting procedure:

- Affected hospital and application.
- Affected environment.
- Time the issue started.
- Exact error message.
- Whether one user or multiple users are affected.
- Whether the problem affects login or occurs after login.

## Support ownership

Application Operations coordinates the initial investigation.

Specialist teams investigate their respective dependencies
when the applicable runbook calls for escalation.

## Documentation boundary

This overview identifies the application and its dependencies.

It does not authorize restarts, database changes or configuration
changes. Those actions require the relevant approved procedure.

All names and operational details in this document are fictional.