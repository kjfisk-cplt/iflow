# ── Random Suffix for Globally Unique Resources ──────────────────────────────
# Generates a deterministic 4-character suffix based on workload and environment.
# Used for Azure resources requiring global uniqueness (Key Vault, Storage, etc.)
#
# The suffix uses the 'keepers' parameter to ensure:
# - Same suffix across all deployments in the same workload+environment
# - Different suffix if workload or environment changes
# - Reproducible and predictable within the same context

resource "random_string" "unique_suffix" {
  length  = 4
  special = false
  upper   = false
  numeric = true

  # Keepers ensure the suffix remains stable for the same workload+env combination
  keepers = {
    workload = var.workload
    env      = var.env
  }
}
