locals {
  # Storage account names: max 24 chars, lowercase alphanumeric only
  workload_sa = replace(lower(var.workload), "-", "")
  domain_sa   = replace(lower(var.domain), "-", "")
  env_sa      = replace(lower(var.env), "-", "")

  # Common prefix for most resources
  base_prefix = "${var.workload}-${var.domain}"
}