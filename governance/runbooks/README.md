# Runbooks

Operational procedures for incidents in the Omni-Obs platform.

## Index

- [High error rate on Thanos Query](high-error-rate.md)

## Conventions

Each runbook follows the same structure:

1. **Triggering alert** — which SLO or alert fires this runbook.
2. **Symptom** — what the user sees.
3. **Severity** — burn-rate to severity mapping.
4. **First 5 minutes** — triage steps that work regardless of root cause.
5. **Common causes & fixes** — playbook of known failure modes.
6. **Closing out** — annotations, follow-up tickets, postmortem trigger.
7. **Escalation** — when to page secondary, when to involve adjacent teams.

The goal: an on-call engineer who has never seen this alert before can resolve it from this document alone.
