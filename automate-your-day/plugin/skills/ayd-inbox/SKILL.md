---
name: ayd-inbox
description: Walk the user through automate-your-day (ayd) items waiting on them - questions the agent asked and outward actions it proposed for approval. Use when the user asks what is waiting on them, to review the queue, or to approve/reject agent proposals.
---

# ayd inbox

1. Run `ayd inbox`. `qN` are questions, `aN` are proposed actions.
2. Present each item with its task and text. For questions, ask the user and record: `ayd answer qN "<answer>"`. For actions, quote the exact action; the user decides: `ayd approve aN` or `ayd reject aN "<reason>"`. Never approve on the user's behalf.
3. Approved actions are executed by that task's next run (or run it now: `ayd run <task>`). Answers are acted on at the next run too.
4. Summarize what was answered, approved, and rejected.
