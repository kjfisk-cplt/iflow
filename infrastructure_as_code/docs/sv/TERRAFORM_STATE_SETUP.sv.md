# Terraform State Backend – Konfigurationsguide

Denna guide beskriver hur IFlow-plattformens Terraform state hanteras säkert i Azure Storage med Microsoft Entra ID-autentisering (OIDC). Dokumentet täcker arkitektur, lokal utveckling, bootstrap-procedurer och felsökning.

---

## Innehållsförteckning

- [Översikt](#översikt)
- [Arkitektur och design](#arkitektur-och-design)
- [Förutsättningar](#förutsättningar)
- [Lokal utvecklarworkflow](#lokal-utvecklarworkflow)
- [Bootstrap-procedur](#bootstrap-procedur)
- [Backend-konfiguration](#backend-konfiguration)
- [State locking-mekanism](#state-locking-mekanism)
- [Disaster recovery](#disaster-recovery)
- [Felsökning](#felsökning)
- [Migration från lokal till remote state](#migration-från-lokal-till-remote-state)
- [Säkerhetspraxis](#säkerhetspraxis)

---

## Översikt

IFlow använder **Azure Storage** som remote backend för Terraform state-filer. Detta möjliggör:

- **Teamsamarbete** – Flera utvecklare kan arbeta på samma infrastruktur utan konflikter
- **State locking** – Förhindrar samtidiga ändringar via Azure Storage blob lease-mekanism
- **Versionering** – Fullständig historik av state-ändringar med möjlighet att återställa
- **Säkerhet** – Ingen state lagras lokalt; all autentisering via Microsoft Entra ID (RBAC)
- **Miljöisolering** – Separata storage accounts per miljö (dev/test/prod)

**Nyckelprincip:** Ingen storage account key används någonsin – all åtkomst via `use_azuread_auth = true`.

---

## Arkitektur och design

### Designbeslut

| Aspekt | Beslut | Motivering |
| --- | --- | --- |
| **Storage isolation** | En storage account per miljö | Fullständig separation; inget cross-environment risk |
| **Autentisering** | OIDC (keyless) + RBAC | Zero Trust; inga hemligheter i kod eller GitHub Secrets |
| **State layout** | En state-fil per modul | Oberoende deployment; parallellisering möjlig |
| **Versioning** | Aktiverad (oändlig retention) | Möjliggör rollback vid corruption |
| **Soft delete** | 30 dagar | Skydd mot oavsiktlig radering |
| **Replication** | LRS (dev/test), GRS (prod) | Kostnad vs. resiliency trade-off |
| **Locking** | Azure Storage native (60s lease) | Automatisk via Terraform; ingen extern tjänst krävs |

### Storage accounts per miljö

```text
Dev:  rg-tfstate-iflow-dev   → stotfstateiflowdev   (Standard_LRS)
Test: rg-tfstate-iflow-test  → stotfstateiflowtest  (Standard_LRS)
Prod: rg-tfstate-iflow-prod  → stotfstateiflowprod  (Standard_GRS)
```

Alla storage accounts har:

- **Container:** `tfstate`
- **Blob versioning:** Aktiverad
- **Soft delete:** 30 dagar
- **Public access:** Disabled

### State-fil namnkonvention

```text
Container: tfstate
State-filer:
  - int_network.tfstate
  - int_keyvault.tfstate
  - int_monitoring.tfstate
  - int_common.tfstate
  - int_messaging.tfstate
  - int_storage.tfstate
  - int_database.tfstate
  - int_apim.tfstate
  - int_common_functions.tfstate
  - int_common_logic.tfstate
```

Varje modul (`int_network`, `int_keyvault`, etc.) har sin egen state-fil för oberoende deployment.

---

## Förutsättningar

### För lokal utveckling

1. **Azure CLI**

   ```powershell
   winget install Microsoft.AzureCLI
   ```

2. **Terraform >= 1.9.0**

   ```powershell
   winget install Hashicorp.Terraform
   ```

3. **Azure-inloggning**

   ```powershell
   az login
   az account set --subscription <subscription-id>
   ```

4. **RBAC-behörigheter**

   Din Azure-användare behöver följande roller på storage account:

   - `Storage Blob Data Contributor` (skriva state)
   - `Reader` (läsa storage account metadata)

   Begär från plattformsteamet om du saknar åtkomst.

### För CI/CD (GitHub Actions)

Se [CICD_PREREQUISITES.md](../CICD_PREREQUISITES.md) för komplett guide om:

- Service Principal med OIDC federation
- GitHub Secrets konfiguration
- Federated credentials per branch/environment
- Workflow-filer

---

## Lokal utvecklarworkflow

### Steg 1: Initiera backend

Navigera till modulen du vill arbeta med:

```powershell
cd infrastructure_as_code/environments/dev/int_network
```

Initiera med backend-konfiguration:

```powershell
terraform init `
  -backend-config="../backend.conf" `
  -backend-config="key=int_network.tfstate"
```

Terraform kommer att:

1. Läsa backend-parametrar från `backend.conf`
2. Använda `az login`-autentisering för att komma åt storage account
3. Skapa state-filen om den inte finns
4. Ladda ned remote state lokalt för jämförelse

**Viktigt:** Parametern `key=int_network.tfstate` **måste matcha modulnamnet** för korrekt state-separering.

### Steg 2: Planera ändringar

```powershell
terraform plan -var-file="terraform.tfvars"
```

Terraform kommer att:

- Läsa remote state från Azure Storage
- Jämföra med aktuell konfiguration
- Visa föreslagna ändringar

Granska planen noggrant innan apply.

### Steg 3: Applicera ändringar

```powershell
terraform apply -var-file="terraform.tfvars"
```

Terraform kommer att:

1. Förvärva ett **blob lease lock** (60 sekunder) på state-filen
2. Applicera ändringar mot Azure
3. Uppdatera remote state
4. Skapa en ny blob version (versionering aktiverad)
5. Släppa låset

Om en annan användare försöker köra `apply` samtidigt, får de ett felmeddelande om att state är låst.

### Steg 4: Verifiera resultatet

```powershell
# Lista outputs från modulen
terraform output

# Visa aktuellt state (remote)
terraform show

# Lista alla resurser i state
terraform state list
```

---

## Bootstrap-procedur

**Viktigt:** Bootstrap behöver **endast köras en gång per miljö** av en plattformsadministratör med Contributor-behörighet på subscription.

### Skapa Dev-miljö

```powershell
# Sätt subscription context
az account set --subscription <subscription-id>

# Definiera variabler
$env = "dev"
$location = "swedencentral"
$workload = "iflow"

# Skapa resource group
az group create `
  --name "rg-tfstate-$workload-$env" `
  --location $location `
  --tags Environment=$env Workload=Terraform-State ManagedBy=IaC

# Skapa storage account (namn max 24 tecken, lowercase endast)
az storage account create `
  --name "stotfstate$workload$env" `
  --resource-group "rg-tfstate-$workload-$env" `
  --location $location `
  --sku Standard_LRS `
  --kind StorageV2 `
  --allow-blob-public-access false `
  --min-tls-version TLS1_2 `
  --https-only true `
  --tags Environment=$env Workload=Terraform-State ManagedBy=IaC

# Aktivera versioning
az storage account blob-service-properties update `
  --account-name "stotfstate$workload$env" `
  --resource-group "rg-tfstate-$workload-$env" `
  --enable-versioning true

# Aktivera soft delete (30 dagar)
az storage account blob-service-properties update `
  --account-name "stotfstate$workload$env" `
  --resource-group "rg-tfstate-$workload-$env" `
  --enable-delete-retention true `
  --delete-retention-days 30

# Skapa container
az storage container create `
  --name tfstate `
  --account-name "stotfstate$workload$env" `
  --auth-mode login
```

### Skapa Test-miljö

Upprepa ovanstående med `$env = "test"` och `stotfstateiflowtest`.

### Skapa Prod-miljö

För produktion, använd **Standard_GRS** för geo-redundans:

```powershell
$env = "prod"

az group create `
  --name "rg-tfstate-$workload-$env" `
  --location $location `
  --tags Environment=$env Workload=Terraform-State ManagedBy=IaC Criticality=High

az storage account create `
  --name "stotfstate$workload$env" `
  --resource-group "rg-tfstate-$workload-$env" `
  --location $location `
  --sku Standard_GRS `
  --kind StorageV2 `
  --allow-blob-public-access false `
  --min-tls-version TLS1_2 `
  --https-only true `
  --tags Environment=$env Workload=Terraform-State ManagedBy=IaC Criticality=High

# Versioning och soft delete
az storage account blob-service-properties update `
  --account-name "stotfstate$workload$env" `
  --resource-group "rg-tfstate-$workload-$env" `
  --enable-versioning true

az storage account blob-service-properties update `
  --account-name "stotfstate$workload$env" `
  --resource-group "rg-tfstate-$workload-$env" `
  --enable-delete-retention true `
  --delete-retention-days 30

az storage container create `
  --name tfstate `
  --account-name "stotfstate$workload$env" `
  --auth-mode login
```

### Tilldela RBAC-rättigheter

Ge utvecklare och service principal åtkomst:

```powershell
# För användare
az role assignment create `
  --assignee user@domain.com `
  --role "Storage Blob Data Contributor" `
  --scope "/subscriptions/<subscription-id>/resourceGroups/rg-tfstate-$workload-$env/providers/Microsoft.Storage/storageAccounts/stotfstate$workload$env"

# För GitHub Actions service principal (se CICD_PREREQUISITES.md för client-id)
az role assignment create `
  --assignee <service-principal-client-id> `
  --role "Storage Blob Data Contributor" `
  --scope "/subscriptions/<subscription-id>/resourceGroups/rg-tfstate-$workload-$env/providers/Microsoft.Storage/storageAccounts/stotfstate$workload$env"
```

---

## Backend-konfiguration

### Fil: `backend.conf` (per miljö)

Varje miljö har sin egen `backend.conf` i `infrastructure_as_code/environments/{env}/`:

**Dev:** `infrastructure_as_code/environments/dev/backend.conf`

```hcl
resource_group_name  = "rg-tfstate-iflow-dev"
storage_account_name = "stotfstateiflowdev"
container_name       = "tfstate"
use_azuread_auth     = true
```

**Test:** `infrastructure_as_code/environments/test/backend.conf`

```hcl
resource_group_name  = "rg-tfstate-iflow-test"
storage_account_name = "stotfstateiflowtest"
container_name       = "tfstate"
use_azuread_auth     = true
```

**Prod:** `infrastructure_as_code/environments/prod/backend.conf`

```hcl
resource_group_name  = "rg-tfstate-iflow-prod"
storage_account_name = "stotfstateiflowprod"
container_name       = "tfstate"
use_azuread_auth     = true
```

### Modul: `providers.tf`

Varje modul har en standardiserad `providers.tf` med backend-block:

```hcl
terraform {
  required_version = ">= 1.9.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  
  backend "azurerm" {
    # Konfigureras vid init:
    # terraform init -backend-config="../backend.conf" -backend-config="key=<modul>.tfstate"
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
```

**Kommentar i provider.tf påminner alltid om korrekt init-kommando.**

---

## State locking-mekanism

Terraform använder Azure Storage **blob lease** för att förhindra samtidiga apply-operationer.

### Så fungerar det

1. **Lock acquisition:**
   - När `terraform apply` körs, försöker Terraform förvärva ett 60-sekunders lease på state-blob
   - Om lyckat: Terraform får exklusiv åtkomst
   - Om misslyckad: Annan användare håller låset; operation blockeras med felmeddelande

2. **Lock renewal:**
   - Under apply förnyar Terraform låset automatiskt var 15:e sekund
   - Om apply tar >60s, förnyas låset tills operationen är klar

3. **Lock release:**
   - När apply/destroy är klar släpper Terraform låset automatiskt
   - Om processen crashar, förfaller låset efter 60 sekunder (auto-expiry)

### Visa aktiva lås

```powershell
# Visa blob properties (inklusive lease status)
az storage blob show `
  --account-name stotfstateiflowdev `
  --container-name tfstate `
  --name int_network.tfstate `
  --auth-mode login `
  --query "{LeaseState: properties.lease.state, LeaseStatus: properties.lease.status}"
```

### Forcera upplåsning (nödsituation)

**Varning:** Använd endast om du är säker på att ingen aktiv apply körs!

```powershell
terraform force-unlock <lock-id>
```

Lock-ID finns i felmeddelandet vid lock-konflikt.

Alternativ metod via Azure CLI (bryt lease):

```powershell
az storage blob lease break `
  --account-name stotfstateiflowdev `
  --container-name tfstate `
  --blob-name int_network.tfstate `
  --auth-mode login
```

Se [STATE_RECOVERY.md](../runbooks/STATE_RECOVERY.md) för detaljerad troubleshooting.

---

## Disaster recovery

### Blob versioning

Varje gång Terraform skriver till state skapas en **ny blob version**. Detta ger komplett historik.

**Visa version-historik:**

```text
az storage blob list `
  --account-name stotfstateiflowdev `
  --container-name tfstate `
  --prefix "int_network.tfstate" `
  --include v `
  --auth-mode login
```

**Återställ från tidigare version:**

```powershell
# 1. Lista versioner med timestamps
az storage blob list `
  --account-name stotfstateiflowdev `
  --container-name tfstate `
  --prefix "int_network.tfstate" `
  --include v `
  --auth-mode login `
  --query "[].{Name:name, VersionId:versionId, LastModified:properties.lastModified}" `
  --output table

# 2. Ladda ned specifik version
az storage blob download `
  --account-name stotfstateiflowdev `
  --container-name tfstate `
  --name int_network.tfstate `
  --version-id <version-id> `
  --file int_network.tfstate.backup `
  --auth-mode login

# 3. Granska backup-filen
terraform show int_network.tfstate.backup

# 4. Ersätt aktuell state (upload som ny version)
az storage blob upload `
  --account-name stotfstateiflowdev `
  --container-name tfstate `
  --name int_network.tfstate `
  --file int_network.tfstate.backup `
  --overwrite `
  --auth-mode login
```

### Soft delete recovery

Om en state-fil raderas av misstag, kan den återställas inom 30 dagar:

```text
# 1. Lista soft-deleted blobs
az storage blob list `
  --account-name stotfstateiflowdev `
  --container-name tfstate `
  --include d `
  --auth-mode login

# 2. Undelete blob
az storage blob undelete `
  --account-name stotfstateiflowdev `
  --container-name tfstate `
  --name int_network.tfstate `
  --auth-mode login
```

### Geo-redundans (prod)

Prod-miljön använder **Standard_GRS** (geo-redundant storage) med automatisk replikering till sekundär region.

**Viktigt:** Sekundär region är **read-only**. Vid disaster i primär region kan Microsoft initiera failover, men detta är sällsynt och kräver eskalering.

För detaljerad DR-procedur, se [STATE_RECOVERY.md – Scenario 4: Regional Disaster](../runbooks/STATE_RECOVERY.md#scenario-4-regional-disaster-geo-replication-failover).

---

## Felsökning

### Problem 1: "Error acquiring the state lock"

**Symptom:**

```text
Error: Error acquiring the state lock
Lock Info:
  ID: <uuid>
  Who: user@hostname
  When: 2024-05-15T10:30:00Z
```

**Orsak:**  
En annan användare/process har ett aktivt lock, eller tidigare operation crashade utan att släppa lock.

**Lösning:**

1. **Vänta 60 sekunder** – Lock förfaller automatiskt om processen är död
2. **Kontakta användaren** – Fråga i Teams om apply fortfarande körs
3. **Force unlock** (om säker):

   ```powershell
   terraform force-unlock <lock-id>
   ```

### Problem 2: "Failed to authorize with Azure CLI"

**Symptom:**

```text
Error: unable to list storage account keys: autorest/azure: Service returned an error. Status=<nil> Code="AuthorizationFailed"
```

**Orsak:**  
Din användare saknar RBAC-rättigheter på storage account.

**Lösning:**

1. Verifiera inloggning:

   ```powershell
   az account show
   ```

2. Begär `Storage Blob Data Contributor` från plattformsteam:

   ```powershell
   az role assignment create `
     --assignee user@domain.com `
     --role "Storage Blob Data Contributor" `
     --scope "/subscriptions/<subscription-id>/resourceGroups/rg-tfstate-iflow-dev"
   ```

3. Logga ut och in igen:

   ```powershell
   az logout
   az login
   ```

### Problem 3: "Backend configuration changed"

**Symptom:**

```text
Error: Backend configuration changed

Backend configuration has changed since initialization.
Run `terraform init -reconfigure`
```

**Orsak:**  
Du har bytt miljö (dev→test) eller ändrat `backend.conf`.

**Lösning:**

```powershell
terraform init -reconfigure `
  -backend-config="../backend.conf" `
  -backend-config="key=int_network.tfstate"
```

Detta återinitierar backend utan att radera lokal state cache.

### Problem 4: State drift detected

**Symptom:**
`terraform plan` visar att resurser kommer att ändras trots att ingen kod är modifierad.

**Orsak:**  
Manuella ändringar i Azure Portal har gjorts utanför Terraform.

**Lösning:**

1. **Granska drift:**

   ```powershell
   terraform plan -detailed-exitcode
   ```

2. **Importera resurser om nya skapats manuellt:**

   ```powershell
   terraform import azurerm_resource_group.example /subscriptions/.../resourceGroups/rg-name
   ```

3. **Refresh state:**

   ```powershell
   terraform apply -refresh-only
   ```

4. **Återställ manuella ändringar:**

   ```powershell
   terraform apply
   ```

Se [STATE_RECOVERY.md – Scenario 5: Drift Reconciliation](../runbooks/STATE_RECOVERY.md#scenario-5-manual-drift-reconciliation) för fullständig guide.

### Problem 5: Corrupted state

**Symptom:**

```text
Error: state data in S3 does not have the expected content.
```

**Orsak:**  
State-filen är korrupt eller ofullständig.

**Lösning:**

Återställ från tidigare version (se [Blob versioning](#blob-versioning) ovan).

---

## Migration från lokal till remote state

Om du redan har lokal state (`.terraform/terraform.tfstate`) och vill migrera till Azure Storage:

### Steg 1: Säkerhetskopiera lokal state

```powershell
Copy-Item terraform.tfstate terraform.tfstate.backup
```

### Steg 2: Konfigurera backend i providers.tf

Se [Backend-konfiguration](#backend-konfiguration) ovan.

### Steg 3: Initiera med migration

```powershell
terraform init `
  -backend-config="../backend.conf" `
  -backend-config="key=int_network.tfstate" `
  -migrate-state
```

Terraform frågar:

```text
Do you want to copy existing state to the new backend? (yes/no)
```

Svara **yes**.

### Steg 4: Verifiera migration

```powershell
# Bekräfta att remote state används
terraform state list

# Ta bort lokal state (valfritt, efter verifiering)
Remove-Item terraform.tfstate
Remove-Item terraform.tfstate.backup
```

---

## Säkerhetspraxis

### ✅ Best practices

1. **Aldrig använd storage account keys**
   - Alla operations via `use_azuread_auth = true`
   - Keys kan roteras utan att bryta Terraform

2. **Tilldela minsta nödvändiga behörighet**
   - Utvecklare: `Storage Blob Data Contributor` på storage account scope
   - Service Principal: Samma roll, begränsat till environment

3. **Aktivera diagnostik och audit logging**

   ```powershell
   az monitor diagnostic-settings create `
     --name tfstate-audit `
     --resource /subscriptions/.../resourceGroups/rg-tfstate-iflow-dev/providers/Microsoft.Storage/storageAccounts/stotfstateiflowdev `
     --logs '[{"category":"StorageWrite","enabled":true}]' `
     --workspace /subscriptions/.../resourceGroups/rg-monitoring/providers/Microsoft.OperationalInsights/workspaces/law-iflow
   ```

4. **Använd branch protection rules**
   - Kräv code review innan merge till main
   - Terraform apply körs endast från main (CI/CD)
   - PR-baserade `terraform plan` ger visibility

5. **Implementera change management**
   - Använd environment protection rules i GitHub Actions (prod)
   - Kräv manuell approval för prod-deployments
   - Dokumentera ändringar i commit messages

### ❌ Undvik

- ❌ Lagra state-filer i Git
- ❌ Dela storage account keys via Slack/Teams
- ❌ Köra `terraform apply` direkt på prod utan code review
- ❌ Force-unlock utan att verifiera att ingen apply körs
- ❌ Stänga av versioning eller soft delete
- ❌ Manuella ändringar i Azure Portal (undvik drift)

---

## Referensdokumentation

- [CICD_PREREQUISITES.md](../CICD_PREREQUISITES.md) – GitHub Actions och OIDC setup
- [STATE_RECOVERY.md](../runbooks/STATE_RECOVERY.md) – Disaster recovery runbook
- [ARCHITECTURE.md](../../../docs/ARCHITECTURE.md) – Fullständig plattformsarkitektur
- [Terraform azurerm backend docs](https://developer.hashicorp.com/terraform/language/settings/backends/azurerm)
- [Azure Storage versioning](https://learn.microsoft.com/azure/storage/blobs/versioning-overview)

---

**Dokumentversion:** 1.0  
**Senast uppdaterad:** 2024-05-15  
**Ägare:** IFlow Platform Team
