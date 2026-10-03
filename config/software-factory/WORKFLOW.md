# Software factory workflow

Use the following lifecycle for feature work. A state transition is a real gate: record the decision and handoff on the Kanban task before the next role proceeds.

## Lifecycle and ownership

1. **DISCOVERY — Main agent / Head of Engineering**
   Clarify the user outcome, constraints, affected project and repositories, and acceptance criteria. Record unknowns and dependencies. Do not invent a product decision to fill a gap.

2. **REQUIREMENT — Head of Engineering with the user**
   Write `docs/requirements/<feature>.md` with the problem, user outcome, scope, non-goals, acceptance criteria, and open questions. The Tech Lead may advise but cannot silently change product requirements.

3. **USER_APPROVAL — user**
   Obtain explicit approval of the requirement before technical planning. Record the approval and the requirement revision on the task. If the user requests changes, return to REQUIREMENT.

4. **TECHNICAL_PLANNING — Tech Lead**
   Write `docs/architecture/<feature>.md` and `docs/implementation/<feature>.md`. Cover affected repositories, interfaces, design choices, migration and failure risks, test approach, and rollout considerations. Return product questions to the user rather than redefining scope. Implementation starts only after this plan is reviewed and accepted.

5. **IMPLEMENTATION — Engineer**
   Work in the assigned repositories and worktrees. Follow the approved requirement and plan, preserve unrelated changes, run relevant checks, and report exact changes and evidence. Raise any requirement conflict before expanding scope.

6. **TECH_LEAD_REVIEW — Tech Lead**
   Review the implementation against the plan and requirement for correctness, maintainability, security, and scope. Record actionable findings. If changes are needed, return to IMPLEMENTATION and review again after fixes.

7. **QA — QA Engineer (Diana)**
   Verify acceptance criteria independently against the original approved requirement. Record environment, checks, results, evidence, and defects in `docs/qa/<feature>.md`. A failed check returns to IMPLEMENTATION; QA retests the fix. Do not infer success from a build alone.

8. **USER_APPROVAL — user**
   Present the implementation summary, review outcome, QA report, and remaining risks. Obtain explicit approval before marking the task ready to merge. Requested changes return to the appropriate earlier phase.

9. **READY_TO_MERGE — Main agent / Head of Engineering**
   Confirm all required artifacts and gates are present and link them on the task. This means ready for a merge decision; it does not authorize merging, deployment, or production changes by itself.

## Handoff record

Every role handoff includes the task ID, project, repository and branch/worktree, requirement revision, acceptance criteria, artifacts changed, checks run and results, known risks or blockers, and the requested next action. Keep secrets out of task descriptions, comments, docs, logs, and commits.

## Multi-repository work

A single project may contain multiple repositories, such as frontend, backend, and infrastructure. Track them under the same project/task; list each repo, branch/worktree, owner, dependency, and interface change in the plan. Do not split them into unrelated projects solely because they use separate repositories.

## Exceptions

- If acceptance criteria conflict with the approved requirement, pause affected work and request a user decision.
- If a required check cannot run, mark it blocked or not run; never mark it passed.
- If unrelated user changes appear, preserve them and flag them in the handoff.
- Never merge, deploy, publish, force-push, delete data, or contact people without the user's explicit authorization.
