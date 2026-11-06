---
description: Exploit-audit the current feature
---

Use the `exploit-auditor` agent on the uncommitted changes (`git diff` plus untracked files) and the spec in `docs/specs/` they belong to. Fix every High/Medium finding, re-run `./tools/verify.sh`, and record each finding and its resolution in the spec under "Exploit audit".
