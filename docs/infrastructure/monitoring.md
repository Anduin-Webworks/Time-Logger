# Monitoring and logging

No telemetry, remote monitoring, structured log file, error reporter, or health endpoint is present in the repository.

The observable signals are local:

- localized chat messages for migration, prune, restore, copy failures, and invalid input;
- the in-game table and totals;
- WoW's own addon error reporting;
- the SavedVariables contents after a client save/reload.

Alerting thresholds, log retention, and production monitoring are **Unknown** and do not appear to apply to the current client-only architecture.

