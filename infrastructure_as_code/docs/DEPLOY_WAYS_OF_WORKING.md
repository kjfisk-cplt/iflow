# iFlow – Deploy Ways of Working (Dev)

> **Audience:** Platform engineers and contributors working with the iFlow Terraform infrastructure.  
> **Scope:** How to safely develop, review, and deploy Terraform changes to the `dev` environment using GitHub Actions.

---

## Table of Contents

1. [Why the Terraform Apply Workflow Failed](#1-why-the-terraform-apply-workflow-failed)
2. [The Intended Flow](#2-the-intended-flow)
3. [Branch and Commit Strategy](#3-branch-and-commit-strategy)
4. [Step-by-Step: Deploying a Change to Dev](#4-step-by-step-deploying-a-change-to-dev)
5. [Workflow Reference](#5-workflow-reference)
6. [terraform.tfvars – Local Secrets File](#6-terraformtfvars--local-secrets-file)
7. [Emergency Manual Deploy (Break-Glass)](#7-emergency-manual-deploy-break-glass)
8. [Troubleshooting](#8-troubleshooting)
9. [Rules of Engagement (Quick Reference)](#9-rules-of-engagement-quick-reference)

---

## 1. Why the Terraform Apply Workflow Failed

Two separate runs of the **Terraform Apply** workflow failed. Here is a precise analysis of each.

### Run #1 – "No Terraform module detected in changed files"

| Item | Detail |
|------|--------|
| Run | [#1 – 2026-04-12](https://github.com/kjfisk-cplt/iflow/actions/runs/24307450372) |
| Trigger | Push to `main` |
| Commit | Commit that changed `.github/instructions/` and `.github/issues/template/` files |
| Error | `No Terraform module detected in changed files` |

**Root cause:** The commit that was pushed to `main` changed only documentation/agent-instruction files inside `.github/`. It contained **no files** in `infrastructure_as_code/environments/`. The apply workflow's auto-detection script runs `git diff --name-only <before>..<sha>` and then searches for paths matching `infrastructure_as_code/environments/[^/]+/int_[^/]+`. Since no Terraform files were in that diff, the script correctly found nothing — and then failed with an error.

**Why it ran at all:** The path filter on the `push` trigger only limits the workflow to pushes that change `*.tf` or `*.tfvars` files inside `infrastructure_as_code/environments/`. This commit appeared to bypass or pre-date that filter, possibly because the workflow file itself was being added or modified in the same push (GitHub evaluates filters against the version of the workflow after the push).

**Consequence:** Every direct push to `main` that does not touch a Terraform module will fail the apply workflow. **This is why direct commits to `main` are dangerous.**

---

### Run #2 – "Invalid revision range"

| Item | Detail |
|------|--------|
| Run | [#2 – 2026-04-13](https://github.com/kjfisk-cplt/iflow/actions/runs/24363531695) |
| Trigger | Push to `main` ("Implement int_monitoring module") |
| Commit SHA | `081fb10d` |
| `event.before` SHA | `5ec3c4d4` |
| Error | `fatal: Invalid revision range 5ec3c4d4..081fb10d` |

**Root cause:** The checkout action was configured with `fetch-depth: 2`, which creates a **shallow clone** containing only the latest commit and its single direct parent. The apply script then runs:

```bash
CHANGED_FILES=$(git diff --name-only ${{ github.event.before }}..${{ github.sha }})
```

`github.event.before` is the SHA of the commit that was at the tip of `main` *before* the push. When several commits are pushed together in a single `git push` (common when working locally and then pushing after several commits), or when using a squash-merge, `event.before` may be **more than one commit back** from the new tip. A shallow clone with `depth=2` only fetches one ancestor, so `event.before` is not in the local repository, making the `git diff` command fail.

Compare with `terraform-plan.yml`, which already correctly uses `fetch-depth: 0` for its detect-changes job. The apply workflow was left behind with `fetch-depth: 2`.

**Fix applied:** Changed `fetch-depth: 2` → `fetch-depth: 0` in `.github/workflows/terraform-apply.yml` to ensure the full commit history is always available.

---

## 2. The Intended Flow

```
feature/your-branch   ──┬──▶ Pull Request ──▶ [Terraform Plan runs automatically]
                        │                         │ Plan output posted as PR comment
                        │                         ▼
                        └──────────── Review + Approve PR
                                                  │
                                                  ▼
                                       Merge to main
                                                  │
                                                  ▼
                                  [Terraform Apply runs automatically]
                                    Deploys changed module to dev
```

**Key principle:** Infrastructure changes are **never committed directly to `main`**. All changes go through a pull request so the Terraform plan can be reviewed before anything is deployed.

---

## 3. Branch and Commit Strategy

### Branch naming

| Purpose | Pattern | Example |
|---------|---------|---------|
| New feature / module | `feature/int-<module>` | `feature/int-monitoring` |
| Bug fix in Terraform | `fix/<short-description>` | `fix/nsg-rule-order` |
| Hotfix (urgent) | `hotfix/<short-description>` | `hotfix/missing-subnet` |
| Experiments | `spike/<short-description>` | `spike/private-endpoint-dns` |

### Commit messages

Follow the pattern: `<type>(<scope>): <short description>`

```
feat(int_monitoring): add Log Analytics workspace and Application Insights
fix(int_network): correct NSG priority ordering
chore(naming): fix typo in variables.tf
```

### What to commit vs. what to gitignore

| File | Commit? | Why |
|------|---------|-----|
| `*.tf` | ✅ Yes | All Terraform source |
| `terraform.tfvars.example` | ✅ Yes | Template so others know what values are needed |
| `terraform.tfvars` | ❌ No | Contains secrets; already in `.gitignore` |
| `*.tfstate` | ❌ No | Managed in Azure Storage backend |
| `.terraform/` | ❌ No | Local provider cache |
| `tfplan` | ❌ No | Binary plan file |

---

## 4. Step-by-Step: Deploying a Change to Dev

This is the full lifecycle for making a Terraform infrastructure change.

### Step 1 – Create a feature branch

```bash
# Ensure you are on an up-to-date main
git checkout main
git pull origin main

# Create your feature branch
git checkout -b feature/int-monitoring
```

### Step 2 – Make your Terraform changes

Work in the relevant module directory, for example:

```
infrastructure_as_code/environments/dev/int_monitoring/
├── providers.tf
├── variables.tf
├── locals.tf
├── main.tf
└── outputs.tf
```

Create a `terraform.tfvars` file for **local testing** (never commit this):

```hcl
# infrastructure_as_code/environments/dev/int_monitoring/terraform.tfvars
subscription_id = "<your-azure-subscription-id>"
workload        = "iflow"
env             = "dev"
location        = "swedencentral"
```

> **Note:** Copy from `terraform.tfvars.example` if one exists. Ask a colleague for the subscription ID if you do not have it.

### Step 3 – Validate locally before pushing

```bash
cd infrastructure_as_code/environments/dev/int_monitoring

# Format your code
terraform fmt -recursive

# Initialise (requires backend.conf — see TERRAFORM_STATE_SETUP.md)
terraform init \
  -backend-config="../backend.conf" \
  -backend-config="key=int_monitoring.tfstate"

# Validate syntax
terraform validate

# Preview what will be deployed
terraform plan -var-file="terraform.tfvars"
```

Verify the plan looks correct before proceeding.

### Step 4 – Commit and push your branch

```bash
# Stage only Terraform source files
git add infrastructure_as_code/environments/dev/int_monitoring/*.tf

# Commit with a descriptive message
git commit -m "feat(int_monitoring): add Log Analytics workspace and Application Insights"

# Push the branch
git push origin feature/int-monitoring
```

### Step 5 – Open a Pull Request targeting `main`

1. Go to the repository on GitHub.
2. Click **"Compare & pull request"** or create a new PR.
3. Set:
   - **Base branch:** `main`
   - **Compare:** `feature/int-monitoring`
4. Write a description explaining:
   - What Terraform resources are being added / changed
   - Why the change is needed
   - Any prerequisites (e.g., another module must be deployed first)

### Step 6 – Review the Terraform Plan in the PR

The **Terraform Plan** workflow runs automatically on the PR. It will:

1. Detect which Terraform modules changed.
2. Run `terraform init`, `terraform validate`, and `terraform plan` for each changed module.
3. Post the plan output as a **PR comment**.

Read the plan carefully:

```
Plan: 3 to add, 0 to change, 0 to destroy.
```

- Review all resources being created, modified, or destroyed.
- Check that no existing resources are accidentally deleted.
- Confirm the resource names follow the naming conventions.

### Step 7 – Get approval and merge

1. Request a review from a team member.
2. Reviewer checks the PR description, the code, and the plan output.
3. Once approved, **squash and merge** (or regular merge) into `main`.

> **Important:** Do **not** resolve conflicts by force-pushing to `main`. If there are conflicts, resolve them on your branch and update the PR.

### Step 8 – Watch the Apply workflow

After the merge, the **Terraform Apply** workflow triggers automatically:

1. Go to **Actions → Terraform Apply** in the GitHub repository.
2. Find the run triggered by your merge commit.
3. Monitor the job. The job name will be `Apply auto-detected to dev`.
4. If successful: a summary is posted to the workflow run page.
5. If it fails: see [Troubleshooting](#8-troubleshooting) below.

### Step 9 – Verify in Azure

After a successful apply, verify the deployed resources:

```bash
# List resources in the resource group
az resource list --resource-group rg-iflow-<module>-dev --output table

# Check state file exists
az storage blob list \
  --account-name stotfstateiflowdev \
  --container-name tfstate \
  --auth-mode login \
  --query "[?name=='int_monitoring.tfstate']" \
  --output table
```

---

## 5. Workflow Reference

### `terraform-plan.yml` – Runs on Pull Requests

| Trigger | PR opened/updated against `main`, touching `infrastructure_as_code/environments/**/*.tf` or `*.tfvars` |
|---------|-------|
| What it does | Detects changed modules, runs `terraform plan` for each, posts results as a PR comment |
| Required secrets | `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` |
| Failure means | The Terraform code has a syntax error, validation error, or the plan itself has an unexpected change |

### `terraform-apply.yml` – Runs on merge to main

| Trigger | Push to `main` touching `infrastructure_as_code/environments/**/*.tf` or `*.tfvars`, OR manual `workflow_dispatch` |
|---------|-------|
| What it does | Auto-detects the changed module from `git diff`, runs `terraform init → validate → plan → apply` |
| Required secrets | `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` |
| Environment gate | Runs inside the `dev` GitHub Environment — add required reviewers there for extra safety |
| Failure means | See [Troubleshooting](#8-troubleshooting) |

### Auto-detection logic (apply workflow)

On a push event, the workflow detects which module to deploy by diffing `event.before` with the current commit:

```bash
CHANGED_FILES=$(git diff --name-only ${{ github.event.before }}..${{ github.sha }})
MODULE_PATH=$(echo "$CHANGED_FILES" | grep -oP 'infrastructure_as_code/environments/[^/]+/int_[^/]+' | head -n 1)
```

> **Limitation:** This logic picks **only the first changed module** (`head -n 1`). If a single PR touches two modules, only the first-detected module will be deployed automatically. For multi-module deploys use the manual `workflow_dispatch` (see [Emergency Manual Deploy](#7-emergency-manual-deploy-break-glass)).

---

## 6. terraform.tfvars – Local Secrets File

`terraform.tfvars` is intentionally **gitignored**. It holds sensitive values (subscription ID, etc.) that must never be committed.

**Initial setup (per developer, per module):**

```bash
# Copy the example template
cp infrastructure_as_code/environments/dev/int_monitoring/terraform.tfvars.example \
   infrastructure_as_code/environments/dev/int_monitoring/terraform.tfvars

# Edit with real values
# subscription_id is the Azure subscription ID for the dev environment
```

The CI/CD pipeline does NOT use `terraform.tfvars`. Instead, it injects `subscription_id` directly via:

```yaml
-var="subscription_id=${{ secrets.AZURE_SUBSCRIPTION_ID }}"
```

All other variable values (workload, env, location) are either hardcoded in the workflow or have safe defaults.

---

## 7. Emergency Manual Deploy (Break-Glass)

If you need to deploy outside the normal PR flow (e.g., an urgent hotfix):

1. Go to **Actions → Terraform Apply** in GitHub.
2. Click **"Run workflow"**.
3. Fill in the inputs:
   - **Environment:** `dev`
   - **Module:** `int_network` (or whichever module to deploy)
4. Click **"Run workflow"**.
5. Monitor the job — approval rules for the `dev` environment still apply if configured.

> **Use sparingly.** All infrastructure changes should still be code-reviewed on a PR. Use the manual trigger only when waiting for a merge would cause a production issue.

---

## 8. Troubleshooting

### "No Terraform module detected in changed files"

**Cause:** The push to `main` did not include any `*.tf` or `*.tfvars` files inside `infrastructure_as_code/environments/`. This can happen when only documentation or workflow files were changed in the same push.

**Solutions:**
- Check that the path filter in `terraform-apply.yml` is correct:
  ```yaml
  paths:
    - 'infrastructure_as_code/environments/**/*.tf'
    - 'infrastructure_as_code/environments/**/*.tfvars'
  ```
- If you need to force-deploy without a Terraform file change, use **manual workflow dispatch** (see [Section 7](#7-emergency-manual-deploy-break-glass)).

---

### "Invalid revision range \<SHA\>..\<SHA\>"

**Cause:** The checkout was done with a shallow clone (`fetch-depth` too small), and `github.event.before` is not in the local git history.

**Fix (already applied):** The `terraform-apply.yml` checkout now uses `fetch-depth: 0`. If you see this error again, verify line 39 of `.github/workflows/terraform-apply.yml` reads `fetch-depth: 0`.

---

### "Module path does not exist"

**Cause:** The auto-detected module path does not exist as a directory. This can happen if a Terraform file was deleted or renamed, or if the path detection grabbed a partial match.

**Solutions:**
- Check that the module directory exists: `ls infrastructure_as_code/environments/dev/int_<module>`
- Use manual workflow dispatch and provide the exact module name.

---

### Terraform Init fails ("Backend configuration changed")

**Cause:** A new developer ran `terraform init` locally without a `backend.conf`, writing a local state backend. The next `terraform init -backend-config=...` fails.

**Fix:**
```bash
terraform init -migrate-state \
  -backend-config="../backend.conf" \
  -backend-config="key=int_<module>.tfstate"
```

See [TERRAFORM_STATE_SETUP.md](TERRAFORM_STATE_SETUP.md) for the full backend setup guide.

---

### Terraform Apply fails (OIDC / permission error)

**Cause:** The GitHub Actions OIDC trust policy is not configured correctly, or the service principal does not have sufficient permissions in Azure.

**Check:**
1. Verify repository secrets exist: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`.
2. Check the federated identity credential in Azure AD App Registration — the subject must match `repo:kjfisk-cplt/iflow:environment:dev`.
3. Verify the service principal has the `Contributor` role (or appropriate least-privilege role) on the subscription.

See [CICD_PREREQUISITES.md](CICD_PREREQUISITES.md) for full OIDC setup instructions.

---

## 9. Rules of Engagement (Quick Reference)

| Rule | Why |
|------|-----|
| ✅ Always work on a branch, never commit directly to `main` | Prevents untested changes from triggering an apply |
| ✅ Open a PR for every infrastructure change | Ensures the plan is reviewed before anything is deployed |
| ✅ Read the Terraform plan in the PR before approving | Protects against accidental resource deletion |
| ✅ Use `terraform fmt` and `terraform validate` before pushing | Prevents CI plan failures due to formatting or syntax errors |
| ✅ Never commit `terraform.tfvars` | Protects secrets |
| ✅ Never commit `*.tfstate` or `.terraform/` | State is managed in Azure Storage |
| ✅ Use squash-merge or regular merge to `main` | Keeps history clean and ensures the apply diff is accurate |
| ❌ Do not push multiple modules in one commit if possible | The auto-detection script only picks up the first changed module |
| ❌ Do not force-push to `main` | Can cause the apply diff to miss changes or fail |
| ❌ Do not `terraform apply` locally against dev | All applies go through CI to maintain an audit trail |
