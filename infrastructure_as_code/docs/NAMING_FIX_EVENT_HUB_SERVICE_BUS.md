# Naming Fix: Event Hub and Service Bus Global Uniqueness

## Issue

The Terraform apply workflow for `int_messaging` module failed with the following errors:

```
Error: creating Namespace (Subscription: "***"
Resource Group Name: "rg-iflow-messaging-dev"
Namespace Name: "evh-iflow-messaging-dev"): performing CreateOrUpdate: unexpected status 400 (400 Bad Request) with error: NamespaceUnavailable: Namespace name 'evh-iflow-messaging-dev' is not available. Reason: NameInUse. Message: Name already in use
```

Similar errors occurred for:
- `sb-iflow-logging-dev` (Service Bus logging namespace)
- `sb-iflow-messagebroker-dev` (Service Bus messagebroker namespace)

## Root Cause

Event Hub and Service Bus namespace names must be **globally unique across all of Azure**, not just within a subscription or resource group. This is similar to Key Vault and Storage Account naming requirements.

The original naming module generated simple concatenated names without a uniqueness suffix:
- `evh-iflow-messaging-dev`
- `sb-iflow-logging-dev`
- `sb-iflow-messagebroker-dev`

These names were already in use elsewhere in Azure, causing the deployment to fail.

## Solution

Updated the `_shared/naming` module to append a 4-character random suffix to Event Hub and Service Bus namespace names, following the same pattern used for Key Vault names.

### Changes Made

#### 1. Naming Module (`infrastructure_as_code/environments/dev/_shared/naming/outputs.tf`)

**Before:**
```hcl
output "evh_messaging_name" {
  description = "Event Hub namespace name."
  value       = "evh-${var.workload}-messaging-${var.env}"
}

output "sb_logging_name" {
  description = "Service Bus namespace name for logging."
  value       = "sb-${var.workload}-logging-${var.env}"
}

output "sb_messagebroker_name" {
  description = "Service Bus namespace name for message brokering."
  value       = "sb-${var.workload}-messagebroker-${var.env}"
}
```

**After:**
```hcl
# Event Hub and Service Bus namespaces require globally unique names across Azure.
# A 4-character random suffix is appended to ensure uniqueness.

output "evh_messaging_name" {
  description = "Event Hub namespace name with unique suffix for global uniqueness."
  value       = "evh-${var.workload}-messaging-${var.env}-${random_string.unique_suffix.result}"
}

output "sb_logging_name" {
  description = "Service Bus namespace name for logging with unique suffix for global uniqueness."
  value       = "sb-${var.workload}-logging-${var.env}-${random_string.unique_suffix.result}"
}

output "sb_messagebroker_name" {
  description = "Service Bus namespace name for message brokering with unique suffix for global uniqueness."
  value       = "sb-${var.workload}-messagebroker-${var.env}-${random_string.unique_suffix.result}"
}
```

#### 2. Documentation Updates

- **`.github/copilot-instructions.md`**: Updated naming patterns and globally unique resources section
- **`.github/instructions/terraform-azure.instructions.md`**: Added Event Hub and Service Bus to naming patterns with global uniqueness requirements

## Result

The naming module now generates globally unique names like:
- `evh-iflow-messaging-dev-83zg`
- `sb-iflow-logging-dev-83zg`
- `sb-iflow-messagebroker-dev-83zg`

### Key Characteristics

- **Deterministic**: The suffix is based on workload and environment using Terraform's `random_string` with `keepers`
- **Reproducible**: Same workload+environment combination always produces the same suffix
- **Globally Unique**: Prevents name collisions across all of Azure
- **Consistent**: Follows the same pattern as Key Vault naming

## Verification

To verify the fix works:

1. Navigate to the `int_messaging` module:
   ```bash
   cd infrastructure_as_code/environments/dev/int_messaging
   ```

2. Run Terraform plan:
   ```bash
   terraform init -backend-config="../backend.conf" -backend-config="key=int_messaging.tfstate"
   terraform plan -var-file="terraform.tfvars"
   ```

3. Check the plan output shows names with the suffix:
   ```
   + name = "evh-iflow-messaging-dev-83zg"
   + name = "sb-iflow-logging-dev-83zg"
   + name = "sb-iflow-messagebroker-dev-83zg"
   ```

## Related Resources

- Azure Event Hubs naming rules: https://learn.microsoft.com/en-us/azure/event-hubs/event-hubs-quotas
- Azure Service Bus naming rules: https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-quotas
- GitHub Issue: Workflow terraform apply for module int-messaging failed due name issues

## Future Considerations

When adding new Azure services that require globally unique names, always check the Azure documentation and consider adding the random suffix to the naming module outputs.

Common services requiring globally unique names:
- ✅ Key Vault
- ✅ Event Hub namespaces
- ✅ Service Bus namespaces
- ✅ Storage Accounts (handled with special lowercase alphanumeric naming)
- Container Registries
- App Configuration stores
- Azure AI Search services
- Cognitive Services accounts
