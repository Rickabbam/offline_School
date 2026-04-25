# AGENT STATE TEMPLATE

Use this file format if the automation system needs a durable progress tracker.

```yaml
current_phase: "PHASE 4 — ACADEMIC CONFIGURATION"
current_subsystem: "4.1 Onboarding wizard completion"
status: "in_progress"
last_green_subsystem: "3.2 Workspace cache and bootstrap"
red_checks: []
blocking_gaps:
  - "step 7 fee structures incomplete offline sync"
next_after_green:
  - "4.1 Onboarding wizard completion / step 7 fee categories and structures"
  - "4.2 Academic reference data sync"
```

Rules:
- update only when checks are re-run
- never mark green without evidence
- if red checks exist, advancement is blocked
