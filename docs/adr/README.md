# Architecture Decision Records

ADRs document significant technical decisions made in this project. Each record captures the context, decision, and consequences so future contributors understand not just *what* was decided but *why*.

## Naming convention

Files follow the pattern `XXXX-short-title.md` (e.g. `0001-use-cobra-for-cli.md`).  
Numbers are sequential and never reused — deprecated ADRs are marked, not deleted.

## Template

Copy the block below into a new file when adding a decision.

```markdown
# XXXX — Short Title

**Status:** Accepted  
**Date:** YYYY-MM-DD

## Context

What situation, constraint, or trade-off prompted this decision?

## Decision

What was decided?

## Consequences

What are the positive and negative trade-offs? What follow-on work does this create?
```

## Status values

| Status | Meaning |
|---|---|
| `Accepted` | Active decision in force |
| `Superseded by ADR-XXXX` | Replaced by a newer decision |
| `Deprecated` | No longer applicable; kept for history |

## Guidance

- Write the ADR **before or alongside** the implementation PR, not after.
- Reference the ADR number in commit messages and PR descriptions.
- When a decision is reversed, update the old ADR status and create a new one explaining why.
