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
	@regions="$$(awk 'NF {print "compute-region-"$$0}' report/regions.txt)"; \
	if [[ -n "$$regions" ]]; then $(MAKE) $$regions; fi
	@$(SCRIPT) compute-merge

compute-region-%:
	@$(SCRIPT) compute-region $*

block-storage: compartments regions
	@regions="$$(awk 'NF {print "block-storage-region-"$$0}' report/regions.txt)"; \
	if [[ -n "$$regions" ]]; then $(MAKE) $$regions; fi
	@$(SCRIPT) block-storage-merge

block-storage-region-%:
	@$(SCRIPT) block-storage-region $*

limits: compute block-storage
	@regions="$$(awk 'NF {print "limits-region-"$$0}' report/regions.txt)"; \
	if [[ -n "$$regions" ]]; then $(MAKE) $$regions; fi
	@$(SCRIPT) limits-merge

limits-region-%:
	@$(SCRIPT) limits-region $*

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
	@echo "  compute-region-<region> Fetch compute for a single region"
	@echo "  block-storage  Build report/storage/storage_inventory.csv"
	@echo "  block-storage-region-<region> Fetch storage for a single region"
	@echo "  limits         Build report/limits/service_limits.csv"
	@echo "  limits-region-<region> Fetch limits for a single region"
	@echo "  regions        Build report/regions.txt"
	@echo "  clean          Remove report artifacts"

.PHONY: all compartments policies compute block-storage limits regions clean help
