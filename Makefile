# Default target when running `make` without arguments.
.DEFAULT_GOAL := all

SHELL := /bin/bash
.SHELLFLAGS := -Eeuo pipefail -c
.ONESHELL:

SCRIPT := ./oci-tenancy-review

all: compartments policies compute block-storage limits

compartments:
	@$(SCRIPT) compartments

policies: compartments
	@$(SCRIPT) policies

compute: compartments regions
	@$(SCRIPT) compute

block-storage: compartments regions
	@$(SCRIPT) block-storage

limits: compute block-storage
	@$(SCRIPT) limits

regions:
	@$(SCRIPT) regions

clean:
	rm -rf report report.tar.gz

help:
	@echo "usage: make <target>"
	@echo ""
	@echo "targets:"
	@echo "  all            Run complete review with dependency-aware scheduling"
	@echo "  compartments   Build report/compartments.csv"
	@echo "  policies       Build report/policies/policy_statements.csv"
	@echo "  compute        Build report/compute/compute_instances.csv"
	@echo "  block-storage  Build report/storage/storage_inventory.csv"
	@echo "  limits         Build report/limits/service_limits.csv"
	@echo "  regions        Build report/regions.txt"
	@echo "  clean          Remove report artifacts"

.PHONY: all compartments policies compute block-storage limits regions clean help
