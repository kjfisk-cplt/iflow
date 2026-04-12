# Assigning Tasks to the GitHub Copilot Cloud Agent

This guide shows how to create a GitHub issue from a task file in this repository and assign it to the GitHub Copilot cloud agent so it implements the task autonomously.

---

## How It Works

1. A task description is written as a Markdown file in `.github/issues/`
2. A GitHub Actions workflow reads the file, creates the issue, and assigns `@copilot`
3. Copilot creates a branch and opens a PR with the implementation
4. You review and merge the PR

---

## Quick Start — Via GitHub Actions Workflow

**Fastest method.** No UI needed.

1. Go to **Actions → Create & Assign Issue to Copilot**
2. Click **Run workflow**
3. Fill in:
   - `issue_file`: filename from `.github/issues/` (e.g. `int_common-terraform-module.md`)
   - `labels`: leave default or customize
4. Click **Run workflow**
5. Copilot starts working automatically

---

## Quick Start — Via GitHub UI

1. Click **Issues → New issue**
2. Select the **Terraform Module Creation** template
3. Fill in the template fields
4. Under **Assignees**, click the gear icon and select **Copilot**
5. Submit the issue

---

## Quick Start — Via MCP (GitHub Copilot Chat)

Use the GitHub MCP server tools in VS Code Copilot Chat to create and assign issues programmatically:
```
@github Create a GitHub issue titled "[IaC] Create int_common Terraform Module"
with the body from .github/issues/int_common-terraform-module.md
and assign it to copilot with labels: infrastructure, terraform, enhancement, copilot
```

The MCP tools available via `@github` handle authentication automatically — no tokens needed.

---

## Writing a New Task File

Task files live in `.github/issues/`. Follow this structure:

```markdown
# [IaC] Create int_<module> Terraform Module

## Overview
...

## Resources to Create
...

## Acceptance Criteria
- [ ] terraform validate passes
- [ ] All resources use module.naming
...
```

**Rules for cloud-agent consumption:**

- Start with a single `# Title` — this becomes the issue title
- Use `- [ ]` checklists for acceptance criteria — Copilot tracks these
- Be explicit about file paths, naming conventions, and provider versions
- Reference the scaffold prompt: `.github/prompts/scaffold-terraform-module.prompt.md`

---

## Example: Creating the int_common Issue

The ready-to-use task file is at `.github/issues/int_common-terraform-module.md`.

**Run the workflow:**

```

Actions → Create & Assign Issue to Copilot
issue_file: int_common-terraform-module.md
```

**Or via CLI (if `gh` is authenticated):**

```bash

gh workflow run assign-to-copilot.yml \
  -f issue_file=int_common-terraform-module.md
```

---

## Repository Layout for Issues

```
.github/
├── issues/                          # Task description files (source of truth)
│   ├── int_common-terraform-module.md
│   └── template/
│       └── terraform-module.md      # GitHub issue template (UI creation)
└── workflows/
    └── assign-to-copilot.yml        # Workflow: create + assign to Copilot
```

---

## Tips

- The `copilot` label is added by default — use it to filter Copilot-managed issues
- Detailed acceptance criteria checklists give Copilot the clearest success signal
- Reference existing modules (e.g. `int_network`) in the issue body as implementation examples
- After Copilot opens its PR, review the plan comment it posts before it starts coding
