# Software Factory Project Instructions

These rules apply to all work in this software factory. The Main agent coordinates the user request; role responsibilities are detailed in each role's `SOUL.md`.

## Roles

- `hoe`: Head of Engineering; co-owns product requirements with the user and coordinates delivery.
- `techlead`: Technical Lead; owns technical planning and technical review.
- `engineer`: Software Engineer; implements the approved plan.
- `qa`: QA Engineer (Diana); verifies the implementation against the original requirement.

## Workspace structure

- Factory root: `{{ factory_home }}/{{ factory_relative_path }}`.
- Each project lives under `projects/<project-name>/` and may contain multiple repositories.
- Keep project artifacts at `projects/<project-name>/docs/{requirements,architecture,implementation,qa}/`.
- Keep active repositories at `projects/<project-name>/repos/<repo-name>/`.
- All project-document tasks must use `workspace_kind: dir` and `workspace_path: {{ factory_home }}/{{ factory_relative_path }}`.
- Equivalent CLI argument: `--workspace dir:{{ factory_home }}/{{ factory_relative_path }}`.
- Do not put persistent project artifacts in a default scratch workspace.

## Workflow

Work follows this lifecycle:

`DISCOVERY → REQUIREMENT → USER_APPROVAL → TECHNICAL_PLANNING → IMPLEMENTATION → TECH_LEAD_REVIEW → QA → USER_APPROVAL → READY_TO_MERGE`

Read `WORKFLOW.md` for the handoff and gate details.

## Required artifacts

- Requirement: `docs/requirements/<feature>.md`
- High-level design: `docs/architecture/<feature>.md`
- Implementation plan: `docs/implementation/<feature>.md`
- QA report: `docs/qa/<feature>.md`

## Rules

1. Product requirements are owned by Head of Engineering and the user.
2. Tech Lead may not silently alter product requirements.
3. Engineer may not start implementation before technical planning is complete and approved.
4. QA validates against the original user-approved requirement.
5. Failed technical review returns the work to Engineer with actionable findings.
6. Failed QA returns the work to Engineer with reproducible findings.
7. User approval is required at both approval gates in the workflow.
8. Production deployment requires explicit user authorization.
9. Never commit secrets or directly modify production state.
10. Prefer reviewable commits and pull requests. Preserve unrelated user changes.

## Definition of Done

A task may reach `READY_TO_MERGE` only after implementation is complete, relevant automated checks pass, Tech Lead review passes, QA passes against the approved requirement, the second user approval is recorded, and unresolved risks are documented.
