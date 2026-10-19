.DEFAULT_GOAL := help

PYTHON			?= python3
testdir			:= $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

.PHONY: help list slice6 slice7
help:
	@printf '%s\n' \
	  'Real-world validation only; no tests run by default.' \
	  'make -C Tools/tests list    List the active case and implementation commit' \
	  'make -C Tools/tests slice6  Run real Mini-XML validation (network/builds)'
	@printf '%s\n' \
	  'make -C Tools/tests slice7  Run real Git worktree/cache validation'

list:
	@cat "$(testdir)/manifest.json"

slice6:
	@$(PYTHON) "$(testdir)/slice6/check-mxml-source-live.py"

slice7:
	@$(PYTHON) "$(testdir)/slice7/check-scm-worktree-live.py"
