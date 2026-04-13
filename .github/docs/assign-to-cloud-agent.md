# Assigning Tasks to the GitHub Copilot Cloud Agent

This guide shows how to create a GitHub issue and assign it to the GitHub Copilot cloud agent so it implements the task autonomously.

---

## How It Works

1. A task description is written as a Markdown file anywhere in the repository
2. A GitHub Actions workflow reads the file, creates the issue, and assigns `@copilot`
3. Copilot creates a branch and opens a PR with the implementation
4. You review and merge the PR

---

## Quick Start — Via GitHub UI (Issue Template)

**Easiest method.**

1. Click **Issues → New issue**
2. Select the **Terraform Module Creation** template
3. Fill in the template fields
4. Under **Assignees**, click the gear icon and select **Copilot**
5. Submit the issue

---

## Quick Start — Via GitHub Actions Workflow

Use this method when you have a task file already written in the repository.

1. Go to **Actions → Create & Assign Issue to Copilot**
2. Click **Run workflow**
3. Fill in:
   - `issue_file`: path to the task file in the repo (e.g. `docs/tasks/my-module.md`)
   - `labels`: leave default or customize
4. Click **Run workflow**
5. Copilot starts working automatically

---

## Quick Start — Via MCP (GitHub Copilot Chat)

Use the GitHub MCP server tools in VS Code Copilot Chat to create and assign issues programmatically:

```
@github Create a GitHub issue titled "[IaC] Create int_keyvault Terraform Module"
with body describing the module requirements
and assign it to copilot with labels: infrastructure, terraform, enhancement, copilot
```

The MCP tools available via `@github` handle authentication automatically — no tokens needed.

---

## Writing a Task File

Create a Markdown file anywhere in the repository with the following structure:

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

## Using the Workflow with a Task File

Once you've written a task file, run the workflow:

**Via GitHub Actions UI:**

```
Actions → Create & Assign Issue to Copilot
issue_file: path/to/your-task.md
```

**Or via CLI (if `gh` is authenticated):**

```bash
gh workflow run assign-to-copilot.yml \
  -f issue_file=path/to/your-task.md
```

---

## Repository Layout (issue-related files)

```
.github/
├── ISSUE_TEMPLATE/              # GitHub-discoverable issue templates (UI creation)
│   └── terraform-module.md
├── docs/
│   └── assign-to-cloud-agent.md
└── workflows/
    └── assign-to-copilot.yml    # Workflow: create + assign to Copilot
```

> Task files used with the workflow can live anywhere in the repository — the workflow accepts any repository-relative path.

---

## Tips

- The `copilot` label is added by default — use it to filter Copilot-managed issues
- Detailed acceptance criteria checklists give Copilot the clearest success signal
- Reference existing modules (e.g. `int_network`) in the issue body as implementation examples
- After Copilot opens its PR, review the plan comment it posts before it starts coding
