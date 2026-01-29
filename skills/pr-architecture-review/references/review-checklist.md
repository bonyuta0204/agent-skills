# PR Review Checklist (Format + Architecture)

## Scope

- Focus on formatting/style consistency and architecture alignment.
- Not a bug hunt unless a change clearly violates architectural or style rules.

## Checklist

1. Architecture style and boundaries
   - Clean/onion/DDD layering rules honored.
   - Dependencies point inward; no cross-layer leaks.
   - Usecases/controllers/services reside in expected layers.

2. File placement and module structure
   - New files placed in correct feature or layer directory.
   - Similar functionality follows existing folder patterns.

3. Public API shape and naming
   - Public entry points are minimal and consistent.
   - Names communicate intent and scope.

4. Formatting and style
   - Formatting matches repo tooling (lint/format rules).
   - Code style consistent with adjacent files.

5. Consistency with existing patterns
   - Similar files are used as a reference and patterns are followed.
   - Avoid parallel or redundant abstractions.

6. Docs and tests (only if rules require)
   - Docs updated if new modules or rules were added.
   - Tests updated if required by repo conventions.

## Review Output Template

- Findings (ordered by severity)
  1) [Architecture] path:line - issue and expectation
  2) [Placement] path:line - issue and expectation
  3) [Style] path:line - issue and expectation
- Questions / assumptions
  - Clarify any intent if architecture choice is ambiguous.
- If clean
  - "No findings." List what was checked (docs, diff, similar files).
