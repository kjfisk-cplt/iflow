---
name: Terraform Module Creation
about: Request creation of a new Terraform infrastructure module for iflow
title: "[IaC] Create <module_name> Terraform Module"
labels: infrastructure, terraform, enhancement, copilot
assignees: ''
---

<!--
🤖 CLOUD AGENT ASSIGNMENT
To assign this issue to the GitHub Copilot cloud agent:
1. Open the issue after creation
2. In the Assignees panel, click the gear icon
3. Select "Copilot" from the list
4. Copilot will automatically create a branch and open a PR

Or use the workflow: Actions → "Create & Assign Issue to Copilot"
-->

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
