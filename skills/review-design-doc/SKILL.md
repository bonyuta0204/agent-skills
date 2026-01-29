---
name: review-design-doc
description: Review kpiee-designs design docs in GitHub pull requests. Use when asked to review a PR like "https://github.com/f-scratch/kpiee-designs/pull/301", "設計書レビューして", or "PRの設計書をチェックしてコメントして". The workflow includes checking out the PR branch locally, validating design doc templates and content quality, and posting review comments on the PR in Japanese.
---

# Review Design Doc

This document defines the **standards and workflow for reviewing design documents** in the kpiee-designs repository.

The purpose of this review is to keep design documents from becoming mere "implementations in prose" and instead ensure they function as documents that **communicate intent, mechanism, and shared decisions**.

Ultimately, this process aims to raise the team’s overall design and articulation skills.

---

## Workflow

### 1) Gather inputs

* Obtain the PR URL or PR number (ask if missing)
* Confirm the target repository contains design documents intended for review

  * If unclear, ask the user to confirm the scope

---

### 2) Prepare local workspace

* Check worktree safety

  * Run `git status` and avoid destructive commands
* Fetch and check out the PR branch locally

  * `git fetch origin pull/<PR>/head:pr-<PR>`
  * `git checkout pr-<PR>`
* If the branch already exists locally, only run `git checkout`

---

### 3) Identify review scope

* List changed files

  * `git diff --name-only origin/<base>...HEAD`
  * If base is unknown, use PR information or `git show --name-only`
* Focus the review on design documents (e.g. feature, fix, architecture docs)
* Include related image assets under `img/` or equivalent directories

---

### 4) Load repo-specific guidance

* Read and follow the repository guidelines:

  * `AGENTS.md`
  * `CLAUDE.md`
* Verify the correct template from `docs/onboarding/` is used for the document type

---

### 5) Format compliance checks (MUST)

* Section structure, headings, and numbering match the template
* No empty sections or leftover placeholders
* Correct file placement and naming (as defined by the repo)
* Image paths are valid and images are placed under the appropriate image directory

---

### 6) Content quality checks

#### General principles

* The design document must be **understandable without reading the code**
* The role of a design document is not to explain implementation details, but to **share intent, mechanism, and rationale**

---

#### Basic Design

* What / Why / Purpose are clearly explained
* Background, problems, and assumptions are written in plain language
* Interfaces and design philosophy are described without code dependency
* The document does not dive into implementation details

---

#### Detail Design

* The document explains *How*, where *How* means:

  * mechanisms
  * responsibility boundaries
  * data flow
  * invariants
* *How* does **not** mean step-by-step implementation or control flow
* The design is understandable assuming the reader does not open the codebase
* Explanations are not tightly coupled to specific code structures
* There are no large code blocks or full source listings

  * **Excessive code usage is a MUST-level issue**
  * If snippets exist, they are minimal and only clarify intent or behavior
* If the document reads like a code dump, treat it as a **MUST violation** and request a language-based explanation of intent, mechanism, and rationale

---

#### Design decisions & quality

* Major design decisions include explicit rationale:

  * Why this responsibility split?
  * Why this data model?
  * Why this failure behavior?
* The document focuses on elements that survive refactoring:

  * invariants
  * contracts (APIs, schemas, events)
  * boundaries (responsibility, transaction, ownership)
* The document avoids over-specifying volatile details (variable names, internal helpers, UI minutiae)

---

#### Clarity & expression

* Avoid vague phrases such as "handle", "validate", or "serialize" without specifics
* Domain terms and assumptions are explained
* Auto-generated files or regeneration commands are excluded unless essential to design intent

---

#### Questions the reviewer should be able to answer

After reading the design document, the reviewer should be able to answer **without reading code**:

* What problem is being solved?
* What is guaranteed (invariants)?
* Where are the boundaries?
* What happens on failure or re-execution?

If these cannot be answered, request revisions.

---

### 7) Draft review comments (English or Japanese)

* Use inline comments for concrete issues when possible
* Add a short summary comment for overall feedback and positives
* Classify feedback severity:

  * **MUST**: template violations, missing required sections, contradictions, **excessive or code-dependent explanations**
  * **SHOULD**: missing rationale, weak explanations, clarity issues
  * **QUESTION**: areas requiring clarification

---

### 8) Post the review on GitHub

* Create a pending GitHub review and add inline comments
* Select the review event based on severity:

  * MUST issues: `REQUEST_CHANGES`
  * SHOULD / QUESTION only: `COMMENT`

---

### 9) Report back to the user

* Provide a concise summary of what was reviewed and key findings
* Ask follow-up questions if needed

---

## Notes

* Focus on design document quality and clarity; do not introduce new requirements
* If local files differ from the PR view, re-fetch and verify
* Refer to Bad/Good examples:

  * `skills/review-design-doc/references/detail-design-bad-good-samples.md`
