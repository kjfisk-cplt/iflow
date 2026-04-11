# Rename to terraform.tfvars (never commit files with secrets to source control).
# Run: terraform init -backend-config="backend.conf" -reconfigure
# Then: terraform plan -var-file="terraform.tfvars"

subscription_id = "00000000-0000-0000-0000-000000000000"
workload        = "iflow"
env             = "dev"
location        = "swedencentral"

vnet_address_space = ["10.0.0.0/16"]

# Override subnets if your environment requires different CIDR blocks or delegations.
subnets = {
  "snet-private-endpoints" = {
    address_prefixes                  = ["10.0.0.0/24"]
    private_endpoint_network_policies = "Disabled"
  }
  "snet-integration" = {
    address_prefixes = ["10.0.1.0/24"]
    delegations = [{
      name = "delegation-webfarm"
      service_delegation = {
        name = "Microsoft.Web/serverFarms"
      }
    }]
  }
  "snet-apim" = {
    address_prefixes = ["10.0.2.0/24"]
  }
}

pep_monitoring_subnet_key = "snet-private-endpoints"

# Terraform state backend — must match your backend.conf
tfstate_resource_group_name  = "rg-tfstate"
tfstate_storage_account_name = "stoterraformstate"
tfstate_container_name       = "tfstate"
