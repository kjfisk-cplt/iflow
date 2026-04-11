# iflow — Workspace Guidelines

## Project Structure

| Folder | Purpose |
|--------|---------|
| `code/` | Application source code |
| `infrastructure_as_code/` | Terraform / Azure IaC (see [terraform conventions](../infrastructure_as_code/.github/instructions/terraform-azure.instructions.md)) |
| `plan/` | Architecture decisions and planning docs |
| `.github/instructions/` | Workspace-scoped file instructions |
| `.github/agents/` | Custom Copilot agents |
| `.github/skills/` | Custom Copilot skills |

## Architecture

_TODO: Describe major components, service boundaries, and the "why" behind structural decisions._

## Code Style

- Follow conventions in `.github/instructions/team-conventions.instructions.md`
- Infrastructure code follows `.github/instructions/terraform-azure.instructions.md` inside `infrastructure_as_code/`
- Run formatters before committing; do not submit code that fails lint

## Build and Test

_TODO: Add commands to install, build, and test. Agents will attempt to run these._

```bash
# Example — replace with actual commands
# cd code && npm install && npm test
```

## Conventions

- Minimal, surgical changes — only modify what is required to fulfil the task
- Verify facts with tools before answering; prefer current data over internal knowledge
- Declare intent before taking action (especially destructive operations)
- Do not commit secrets, passwords, or credentials to source control
- Infrastructure changes require a plan review before apply
