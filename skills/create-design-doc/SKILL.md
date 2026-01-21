---
name: create-design-doc
description: Create kpiee design docs (basic or detail) in kpiee-designs using repo templates. Use when asked to draft 基本設計書 or 詳細設計書, or to write a detailed design based on a spec or an existing basic design, including file creation and VitePress sidebar updates. Supports Notion specs via Notion MCP when available.
---

# Create Design Doc

## Overview

Create kpiee design documents in this repository by selecting the correct template, filling all required sections, creating files in the right location, and updating the VitePress sidebar.

## Workflow

### 1) Intake and scope

- Read `AGENTS.md` and `CLAUDE.md` for repo-specific rules and follow them.
- Confirm document type: basic design or detail design.
- Confirm source materials: spec URL/Notion page, or existing basic design to reference.
- Collect required identifiers: category, ticket/ID, target title.
- Decide detail format: single-file or multi-file.
- Ask only for missing info; do not infer.

### 2) Choose the correct format

Use repo templates under `docs/onboarding/`.

- Basic design: `docs/onboarding/basic-design-format.md`
- Detail design (single file): `docs/onboarding/single-file-design-format.md`
- Detail design (multi file entrypoint): `docs/onboarding/multi-file-detail-design-format.md`
- Detail design (multi file guide): `docs/onboarding/multi-file-design-format.md`
- Multi-file structure template: `docs/onboarding/multi-file-structure-template.yaml`

If the user asks for bugfix docs, confirm scope because this skill is for basic/detail only.

### 3) Load sources (Notion and/or repo docs)

- If a Notion URL/ID is provided and Notion MCP is available, fetch it and extract only relevant sections.
- If Notion MCP is not available, ask the user to paste the needed content.
- If referencing an existing basic design, read it and align the detail design to it.

### 4) Create files in the correct location

- Basic design path: `feature/[category]/[ticket_id]/basic_design.md`
- Detail design path: `feature/[category]/[ticket_id]/detail_design.md`
- For multi-file detail design, create the directory layout specified by the template.

Use exact file names; do not add extra files (e.g., `test_case.md`) unless explicitly requested.

### 5) Fill every required section

- Follow the template structure and numbering exactly.
- Do not leave empty sections or placeholder text.
- Keep basic design at What/Why/Purpose level; avoid implementation details.
- Detail design should explain How and align with the basic design.

### 6) Update the VitePress sidebar

- Edit `docs/.vitepress/config.mts` to add links for new docs in the correct section.
- Keep ordering consistent with existing categories.

### 7) Final checks

- Ensure no template artifacts remain.
- Ensure sections are complete and logically consistent.
- Ensure no test cases or release/rollback steps are added unless explicitly required.

## Output checklist

- Correct template used and fully completed.
- Files created in the correct directory and naming.
- Sidebar updated in `docs/.vitepress/config.mts`.
- No extra files or inferred features beyond the request.
