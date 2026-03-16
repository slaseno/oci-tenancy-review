# OCI Tenancy Review

This initiative should help our customers identify bottlenecks, gaps and future potentials running on OCI. 

- [OCI Tenancy Review](#oci-tenancy-review)
  - [Prerequisites](#prerequisites)
  - [1. Discovery + architecture walkthrough](#1-discovery--architecture-walkthrough)
  - [2. Availability \& resiliency assessment](#2-availability--resiliency-assessment)
  - [3. Architecture \& scalability review](#3-architecture--scalability-review)
    - [Policy Statements](#policy-statements)
  - [4. Readout + actionable plan](#4-readout--actionable-plan)


## Prerequisites

* [OCI CLI](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm)
* [jq](https://github.com/jqlang/jq) (already installed in OCI cloud shell by default)


## 1. Discovery + architecture walkthrough
> (current-state goals, workloads, constraints) - through Zoom

## 2. Availability & resiliency assessment
> (HA patterns, DR considerations, failure modes, backup/restore)

## 3. Architecture & scalability review
> (service choices, patterns, integration points, bottlenecks)

### Policy Statements

To review all policy statements in an OCI compartment and format it as a CSV, use the following.
This is especially useful to spot duplicate policies and ensure any leaf compartment is below 500 policy statements total.

```bash
# get all policies of a specific compartment
oci iam policy list -c COMPARTMENT_ID --all > policies_root.json

# to csv, flattened by policy statement
jq -r '["policy-name","created-by","time-created","the actual statement","id"], (.data[] as $p | ($p.statements // [])[] | [$p.name, ($p["defined-tags"]["Oracle-Tags"]["C
reatedBy"] // ""), $p["time-created"], ., $p.id]) | @csv' policies_root.json > policy_statements.csv
```

## 4. Readout + actionable plan 

> (findings, prioritized recommendations, quick wins vs. longer-term items)



