# OCI Tenancy Review

This initiative should help our customers identify bottlenecks, gaps and future potentials running on OCI. 

- [OCI Tenancy Review](#oci-tenancy-review)
  - [Prerequisites](#prerequisites)
  - [1. Discovery + architecture walkthrough](#1-discovery--architecture-walkthrough)
    - [Inventory: Compute Instances](#inventory-compute-instances)
  - [2. Availability \& resiliency assessment](#2-availability--resiliency-assessment)
  - [3. Architecture \& scalability review](#3-architecture--scalability-review)
    - [Policy Statements](#policy-statements)
  - [4. Readout + actionable plan](#4-readout--actionable-plan)


## Prerequisites

* [OCI CLI](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm), tested with v3.76.0
* [jq](https://github.com/jqlang/jq) (already installed in OCI cloud shell by default)

Scope note:
* `--compartment-id "$TENANCY_OCID"` targets the root compartment (tenancy) only.
* To cover all subcompartments, use `--compartment-id-in-subtree true` when a command supports it.
* If a command does not support subtree listing (for example `oci iam policy list`), iterate through all compartments.


## 1. Discovery + architecture walkthrough
> (current-state goals, workloads, constraints) - through Zoom

### Inventory: Compute Instances

```bash
# assumes TENANCY_OCID is already set (see policy section for discovery/fallback options)
mkdir -p report/inventory

# ------------------------------
# Priority inventory: compute instances + exact shape (tenancy-wide)
# ------------------------------
# prerequisite: report/compartment_ids.txt from the policy section
echo "" > report/inventory/compute_instances.jsonl
while read -r cid; do
  cpath="$(grep -m1 "^${cid}"$'\t' report/compartment_ids.txt | cut -f2-)"
  echo "Getting instances in ${cid} ${cpath}..."
  oci compute instance list --compartment-id "$cid" --all \
    | jq -c --arg cid "$cid" --arg cpath "$cpath" '
      .data[] | {
        compartmentId: $cid,
        compartmentPath: $cpath,
        region: .region,
        instanceId: .id,
        instanceName: ."display-name",
        shape: .shape,
        ocpus: ."shape-config".ocpus,
        memoryInGBs: ."shape-config"."memory-in-gbs",
        baselineOcpuUtilization: ."shape-config"."baseline-ocpu-utilization",
        lifecycleState: ."lifecycle-state",
        availabilityDomain: ."availability-domain",
        faultDomain: ."fault-domain",
        imageId: ."image-id",
        launchMode: ."launch-mode",
        sourceType: ."source-details"."source-type",
        capacityReservationId: ."capacity-reservation-id",
        dedicatedVmHostId: ."dedicated-vm-host-id",
        preemptibleActionType: ."preemptible-instance-config"."preemption-action"."type",
        availabilityRecoveryAction: ."availability-config"."recovery-action",
        legacyImdsEndpointsDisabled: ."instance-options"."are-legacy-imds-endpoints-disabled",
        networkType: ."launch-options"."network-type",
        consistentVolumeNamingEnabled: ."launch-options"."is-consistent-volume-naming-enabled",
        monitoringDisabled: ."agent-config"."is-monitoring-disabled",
        managementDisabled: ."agent-config"."is-management-disabled",
        liveMigrationPreferred: ."is-live-migration-preferred",
        pvEncryptionInTransitEnabled: ."is-pv-encryption-in-transit-enabled",
        metadataKeyCount: ((.metadata // {}) | keys | length),
        freeformTagCount: ((."freeform-tags" // {}) | keys | length),
        definedTagNamespaceCount: ((."defined-tags" // {}) | keys | length),
        timeCreated: ."time-created"
      }' >> report/inventory/compute_instances.jsonl
done < <(cut -f1 report/compartment_ids.txt)

jq -s '.' report/inventory/compute_instances.jsonl > report/inventory/compute_instances.json

jq -r '
  ["compartment-path","region","instance-name","shape","ocpus","memory-in-gbs","baseline-ocpu-utilization","lifecycle-state","availability-domain","fault-domain","image-id","launch-mode","source-type","capacity-reservation-id","dedicated-vm-host-id","preemptible-action-type","availability-recovery-action","legacy-imds-endpoints-disabled","network-type","consistent-volume-naming-enabled","monitoring-disabled","management-disabled","live-migration-preferred","pv-encryption-in-transit-enabled","metadata-key-count","freeform-tag-count","defined-tag-namespace-count","time-created","instance-id"],
  (.[] | [.compartmentPath, .region, .instanceName, .shape, .ocpus, .memoryInGBs, .baselineOcpuUtilization, .lifecycleState, .availabilityDomain, .faultDomain, .imageId, .launchMode, .sourceType, .capacityReservationId, .dedicatedVmHostId, .preemptibleActionType, .availabilityRecoveryAction, .legacyImdsEndpointsDisabled, .networkType, .consistentVolumeNamingEnabled, .monitoringDisabled, .managementDisabled, .liveMigrationPreferred, .pvEncryptionInTransitEnabled, .metadataKeyCount, .freeformTagCount, .definedTagNamespaceCount, .timeCreated, .instanceId]) | @csv
' report/inventory/compute_instances.json > report/inventory/compute_instances.csv

jq -r '
  ["shape","count"],
  (group_by(.shape) | map([.[0].shape, (length|tostring)]) | sort_by(.[1] | tonumber) | reverse | .[]) | @csv
' report/inventory/compute_instances.json > report/inventory/compute_shapes_summary.csv
```

## 2. Availability & resiliency assessment
> (HA patterns, DR considerations, failure modes, backup/restore)

## 3. Architecture & scalability review
> (service choices, patterns, integration points, bottlenecks)

### Policy Statements

To review all policy statements tenancy-wide and format them as CSV, use the following.
This is especially useful to spot duplicate policies and ensure any leaf compartment is below 500 policy statements total.

```bash
# use tenancy OCID from current OCI CLI context by default (Cloud Shell friendly)
TENANCY_OCID="${TENANCY_OCID:-$(
  oci iam compartment list \
    --include-root \
    --compartment-id-in-subtree true \
    --access-level ANY \
    --all \
    --query 'data[?starts_with(id, `ocid1.tenancy.`)].id | [0]' \
    --raw-output
)}"

# fallback: read tenancy OCID from ~/.oci/config (uses OCI_CLI_PROFILE or DEFAULT)
OCI_PROFILE="${OCI_CLI_PROFILE:-DEFAULT}"
TENANCY_OCID="${TENANCY_OCID:-$(
  awk -v profile="$OCI_PROFILE" '
    $0=="[" profile "]" {in_profile=1; next}
    /^\[/ {in_profile=0}
    in_profile && $1 ~ /^tenancy[[:space:]]*=/ {
      sub(/^[^=]*=[[:space:]]*/, "", $0); print $0; exit
    }
  ' ~/.oci/config
)}"

# optional manual override
# cat ~/.oci/config
# TENANCY_OCID="ocid1.tenancy.oc1...."

echo "Current tenancy ocid: ${TENANCY_OCID}"

# output folder (relative to current working directory)
mkdir -p report

# collect all compartments as: OCID<TAB>full.path (root + subtree)
oci iam compartment list \
  --compartment-id "$TENANCY_OCID" \
  --compartment-id-in-subtree true \
  --access-level ANY \
  --include-root \
  --all > report/compartments.json

jq -r --arg tenancy "$TENANCY_OCID" '
  .data as $d
  | ($d | map({key: .id, value: .}) | from_entries) as $m
  | def full_path($id):
      if $id == $tenancy then
        ""
      else
        (full_path($m[$id]."compartment-id")) as $p
        | if $p == "" then $m[$id].name else ($p + "." + $m[$id].name) end
      end;
    [ $d[] | {id: .id, path: (if .id == $tenancy then "root" else full_path(.id) end)} ]
  | sort_by(if .path == "root" then "" else .path end)
  | .[]
  | [.id, .path]
  | @tsv
' report/compartments.json > report/compartment_ids.txt

# pull policies per compartment into a single JSON file
echo "" > report/policies_all_compartments.jsonl
while read -r cid; do
  cpath="$(grep -m1 "^${cid}"$'\t' report/compartment_ids.txt | cut -f2-)"
  echo "Getting policies in ${cid} ${cpath}..."
  oci iam policy list -c "$cid" --all \
    | jq -c --arg cid "$cid" --arg cpath "$cpath" \
      '.data[] | {compartmentId:$cid, compartmentPath:$cpath, name:.name, id:.id, timeCreated:."time-created", definedTags:."defined-tags", statements:.statements}' \
    >> report/policies_all_compartments.jsonl
done < <(cut -f1 report/compartment_ids.txt)

jq -s '.' report/policies_all_compartments.jsonl > report/policies_all_compartments.json

# to csv, flattened by policy statement
jq -r '
  ["compartment-id","compartment-name","policy-name","created-by","time-created","the actual statement","id"],
  (.[] as $p | ($p.statements // [])[] |
    [$p.compartmentId, $p.compartmentPath, $p.name, ($p.definedTags["Oracle-Tags"]["CreatedBy"] // ""), $p.timeCreated, ., $p.id]
  ) | @csv
' report/policies_all_compartments.json > report/policy_statements.csv
```

## 4. Readout + actionable plan 

> (findings, prioritized recommendations, quick wins vs. longer-term items)
