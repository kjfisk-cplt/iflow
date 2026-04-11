locals {
  # Storage account names cannot contain hyphens — strip them and lowercase.
  workload_sa = replace(lower(var.workload), "-", "")
  env_sa      = replace(lower(var.env), "-", "")
}
