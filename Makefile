SHELL := /bin/bash

CODEX_HOME ?= $(HOME)/.codex
SKILLS_DIR := $(CURDIR)/skills

.PHONY: link unlink list

list:
	@ls -1 "$(SKILLS_DIR)"

link:
	@mkdir -p "$(CODEX_HOME)/skills"
	@if [ -n "$(SKILL)" ]; then \
		ln -sfn "$(SKILLS_DIR)/$(SKILL)" "$(CODEX_HOME)/skills/$(SKILL)"; \
		echo "linked $(SKILL)"; \
	else \
		for d in $(SKILLS_DIR)/*; do \
			name=$$(basename "$$d"); \
			ln -sfn "$$d" "$(CODEX_HOME)/skills/$$name"; \
			echo "linked $$name"; \
		done; \
	fi

unlink:
	@if [ -n "$(SKILL)" ]; then \
		rm -f "$(CODEX_HOME)/skills/$(SKILL)"; \
		echo "unlinked $(SKILL)"; \
	else \
		for d in $(SKILLS_DIR)/*; do \
			name=$$(basename "$$d"); \
			rm -f "$(CODEX_HOME)/skills/$$name"; \
			echo "unlinked $$name"; \
		done; \
	fi
