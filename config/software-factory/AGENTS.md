# Software Factory Project Instructions

These rules apply to all work in this software factory. The Main agent coordinates the user request; role responsibilities are detailed in each role's `SOUL.md`.

## Roles

- `hoe`: Head of Engineering; co-owns product requirements with the user and coordinates delivery.
- `techlead`: Technical Lead; owns technical planning and technical review.
- `engineer`: Software Engineer; implements the approved plan.
- `qa`: QA Engineer (Diana); authors an independent test plan focused on UX and end-to-end flows, then executes it against the completed implementation.

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

`DISCOVERY → REQUIREMENT → USER_APPROVAL → TECHNICAL_PLANNING → OWNER_PLAN_APPROVAL → [IMPLEMENTATION ∥ QA_TEST_PLANNING] → TECH_LEAD_REVIEW → QA_EXECUTION → USER_APPROVAL → READY_TO_MERGE`

Read `WORKFLOW.md` for the handoff and gate details.

## Required artifacts

- Requirement: `docs/requirements/<feature>.md`
- High-level design: `docs/architecture/<feature>.md`
- Implementation plan: `docs/implementation/<feature>.md`
- QA test plan: `docs/qa/<feature>-test-plan.md` (authored by QA, approved by Tech Lead)
- QA report: `docs/qa/<feature>.md`

## Rules

1. Product requirements are owned by Head of Engineering and the user.
2. Tech Lead may not silently alter product requirements.
3. Engineer may not start implementation, and QA may not start test-plan authoring, before technical planning is complete and explicitly approved by the user (OWNER_PLAN_APPROVAL). Every decision point must be resolved and approved by the user in that gate; a plan with open or unconfirmed decision points may not proceed.
4. QA validates against the original user-approved requirement using its own independently authored test plan (UX and end-to-end flows first), not by re-running the Engineer's test suite alone.
5. QA may author its test plan in parallel with implementation, but may execute it only after the Tech Lead has approved both the implementation and the test plan.
6. Failed technical review returns the work to Engineer (or the test plan to QA) with actionable findings.
7. Failed QA execution returns the work to Engineer with reproducible findings.
8. User approval is required at every approval gate in the workflow: the requirement, the technical plan, and the final result.
9. Production deployment requires explicit user authorization.
10. Never commit secrets or directly modify production state.
11. Prefer reviewable commits and pull requests. Preserve unrelated user changes.
12. When creating Kanban tasks, do not set a model or provider. The worker then uses the model configured for its profile; a model on the task overrides it.
13. Follow the review-fix rules in `WORKFLOW.md`: repro-first regression tests, a Tech Lead adversarial pass over fixes, and a per-fix summary comment on the pull request after every fix round.
14. Aim for user re-reviews with zero new comments: plans and test plans meet the thoroughness standard in `WORKFLOW.md`, and defects found late get a recorded root cause and a preventive check.
{% if (agent_git_name and agent_git_email) or agent_commit_trailers %}

## Commit conventions

{% if agent_git_name and agent_git_email %}
- Author every commit as `{{ agent_git_name }} <{{ agent_git_email }}>`. The Docker terminals already use this Git identity. In a host terminal, pass `--author '{{ agent_git_name }} <{{ agent_git_email }}>'` instead. Never change `user.name` or `user.email` in any Git config.
{% endif %}
{% if agent_commit_trailers %}
- End every commit message with a blank line followed by these trailer lines, exactly as written (for example with `git commit --trailer '<line>'`):

  ```text
{% for trailer in agent_commit_trailers %}
  {{ trailer }}
{% endfor %}
  ```
{% endif %}
{% endif %}

## Definition of Done

A task may reach `READY_TO_MERGE` only after implementation is complete, relevant automated checks pass, Tech Lead review passes, QA passes against the approved requirement, the second user approval is recorded, and unresolved risks are documented.
