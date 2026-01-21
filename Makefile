SHELL := /bin/bash

CODEX_HOME ?= $(HOME)/.codex
SKILLS_DIR := $(CURDIR)/skills

.PHONY: help link link-all unlink list

help:
	@echo "Targets:"
	@echo "  make list                       List available skills"
	@echo "  make link [SKILL=name]           Link all or one skill to $(CODEX_HOME)/skills"
	@echo "  make link-all                    Link all skills to $(CODEX_HOME)/skills"
	@echo "  make unlink [SKILL=name]         Unlink all or one skill from $(CODEX_HOME)/skills"
	@echo "Variables:"
	@echo "  CODEX_HOME=~/.codex              Override Codex home directory"

list:
	@ls -1 "$(SKILLS_DIR)"

link:
	@mkdir -p "$(CODEX_HOME)/skills"
	@if [ -n "$(SKILL)" ]; then \
		target="$(CODEX_HOME)/skills/$(SKILL)"; \
		rm -rf "$$target"; \
		ln -sfn "$(SKILLS_DIR)/$(SKILL)" "$$target"; \
		echo "linked $(SKILL)"; \
	else \
		for d in $(SKILLS_DIR)/*; do \
			name=$$(basename "$$d"); \
			target="$(CODEX_HOME)/skills/$$name"; \
			rm -rf "$$target"; \
			ln -sfn "$$d" "$$target"; \
			echo "linked $$name"; \
		done; \
	fi

link-all:
	@$(MAKE) link SKILL=

unlink:
	@if [ -n "$(SKILL)" ]; then \
		target="$(CODEX_HOME)/skills/$(SKILL)"; \
		rm -rf "$$target"; \
		echo "unlinked $(SKILL)"; \
	else \
		for d in $(SKILLS_DIR)/*; do \
			name=$$(basename "$$d"); \
			target="$(CODEX_HOME)/skills/$$name"; \
			rm -rf "$$target"; \
			echo "unlinked $$name"; \
		done; \
	fi
