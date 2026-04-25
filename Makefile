SHELL := /bin/bash

CODEX_HOME  ?= $(HOME)/.codex
CLAUDE_HOME ?= $(HOME)/.claude
SKILLS_DIR  := $(CURDIR)/skills
SKILL_NAMES := \
	collaborative-design-development \
	create-company-presentation-slides \
	create-design-doc \
	create-explanatory-diagram \
	create-mermaid-diagram \
	code-architecture-review \
	github-create-pr \
	github-issue-stocktake \
	github-pr-stockgtake \
	github-pr-review-stocktake \
	kpiee-bastion-ops \
	kpiee-local-smoke-check \
	kpiee-playwright-auth \
	kpiee-pm-ops \
	kpiee-stg-log-db-check \
	pr-implementation-review \
	review-product-doc-set \
	review-design-doc \
	review-test-case \
	slack-ng-to-issue

# Destination directories for each tool
CODEX_SKILLS  := $(CODEX_HOME)/skills
CLAUDE_SKILLS := $(CLAUDE_HOME)/skills

.PHONY: help link link-all unlink list

help:
	@echo "Targets:"
	@echo "  make list                       List available skills"
	@echo "  make link [SKILL=name]           Link skill(s) to Codex and Claude Code"
	@echo "  make link-all                    Link all skills (alias for link)"
	@echo "  make unlink [SKILL=name]         Unlink skill(s) from Codex and Claude Code"
	@echo "Variables:"
	@echo "  CODEX_HOME=~/.codex              Override Codex home directory"
	@echo "  CLAUDE_HOME=~/.claude            Override Claude Code home directory"

list:
	@printf '%s\n' $(SKILL_NAMES)

# _link_one DEST SKILL – symlink a single skill into DEST/skills/SKILL
define _link_one
	mkdir -p "$(1)"; \
	target="$(1)/$(2)"; \
	rm -rf "$$target"; \
	ln -sfn "$(SKILLS_DIR)/$(2)" "$$target";
endef

link:
	@if [ -n "$(SKILL)" ]; then \
		$(call _link_one,$(CODEX_SKILLS),$(SKILL)) \
		$(call _link_one,$(CLAUDE_SKILLS),$(SKILL)) \
		echo "linked $(SKILL) -> codex + claude"; \
	else \
		for name in $(SKILL_NAMES); do \
			$(call _link_one,$(CODEX_SKILLS),$$name) \
			$(call _link_one,$(CLAUDE_SKILLS),$$name) \
			echo "linked $$name -> codex + claude"; \
		done; \
	fi

link-all:
	@$(MAKE) link SKILL=

# _unlink_one DEST SKILL – remove a single skill symlink from DEST/skills/SKILL
define _unlink_one
	target="$(1)/$(2)"; \
	rm -rf "$$target";
endef

unlink:
	@if [ -n "$(SKILL)" ]; then \
		$(call _unlink_one,$(CODEX_SKILLS),$(SKILL)) \
		$(call _unlink_one,$(CLAUDE_SKILLS),$(SKILL)) \
		echo "unlinked $(SKILL) <- codex + claude"; \
	else \
		for name in $(SKILL_NAMES); do \
			$(call _unlink_one,$(CODEX_SKILLS),$$name) \
			$(call _unlink_one,$(CLAUDE_SKILLS),$$name) \
			echo "unlinked $$name <- codex + claude"; \
		done; \
	fi
