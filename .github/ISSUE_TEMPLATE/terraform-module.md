---
name: Terraform Module Creation
about: Request creation of a new Terraform infrastructure module
title: "[IaC] Create <module_name> Terraform Module"
labels: infrastructure, terraform, enhancement
assignees: ''
---

## Overview

<!-- Brief description of the module's purpose -->

**Module Name:** `<module_name>`  
**Target Path:** `infrastructure_as_code/environments/dev/<module_name>/`  
**Priority:** <!-- Low / Medium / High / Critical -->

---

## Resources to Create

| Resource | Type | Naming Convention |
|----------|------|-------------------|
| | | |

---

## Configuration

### SKU / Tier Settings

| Resource | Dev/Test | Prod |
|----------|----------|------|
| | | |

### Variables

```hcl
# Standard variables (from _shared pattern)
- subscription_id (sensitive)
- workload (default: "iflow")
- env (validation: dev, test, prod)
- location (default: "swedencentral")

# Module-specific variables
- 
```

### Outputs

```hcl
# Required outputs for downstream modules
- 
```

---

## Implementation Requirements

- [ ] Use Azure Verified Modules (AVM) where available
- [ ] Reference `module.naming` from `../_shared/naming`
- [ ] Use `local.tags` from naming module
- [ ] Set `enable_telemetry = false` on all AVM modules
- [ ] Follow existing patterns from reference module

**Reference Module:** `infrastructure_as_code/environments/dev/<reference_module>/`

### Provider Requirements

```hcl
terraform {
  required_version = ">= 1.9, < 2.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
  }
}
```

---

## Dependencies

**Depends on:**
- 

**Consumed by:**
- 

---

## Acceptance Criteria

- [ ] `terraform validate` passes
- [ ] `terraform plan` shows expected resources
- [ ] All resources use centralized naming via `module.naming`
- [ ] All resources tagged via `local.tags`
- [ ] Outputs expose IDs needed by downstream modules
- [ ] No hardcoded values (all configurable via variables)
- [ ] Code follows HashiCorp HCL style guide
- [ ] Works with existing `backend.conf` configuration

---

## Additional Context

<!-- Architecture references, diagrams, or related issues -->

**Architecture Reference:** [docs/ARCHITECTURE.md](../../docs/ARCHITECTURE.md)
