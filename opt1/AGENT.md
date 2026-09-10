# Agent Instructions — CS251 Project 4

## Knowledge-gap tracking (always-on)

Whenever the user asks a question — conceptual, syntactic, debugging, or "what did we do for X" — treat it as a knowledge gap and update `knowledge.md` in this directory.

**Workflow:**
1. Answer the question first.
2. Then append (or update) an entry in `knowledge.md` under the right checkpoint section, using the existing format:
   ```
   ### Gap N — <short title> <tag>
   **Date:** YYYY-MM-DD
   **What I didn't know:** <one line>
   **Fix:** <minimum thing to remember>
   ```
3. Tags: 🔴 blocker · 🟡 fuzzy (got it after a hint) · 🟢 resolved (re-tested)
4. Number gaps sequentially within their checkpoint section. If the question spans checkpoints, put it under the most relevant one.
5. If the question maps to an item already listed in **Open / not-yet-tested concepts**, move it into a numbered gap and remove the checkbox.
6. If the same gap already exists, update the existing entry instead of duplicating.

**Skip the log only when** the question is purely about workflow/tooling/this repo's state (e.g. "how much have I finished?", "where is file X?") — those aren't knowledge gaps.

**Don't ask permission** — just do it as part of the response.
