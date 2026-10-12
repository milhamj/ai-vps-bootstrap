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
   Write `docs/architecture/<feature>.md` and `docs/implementation/<feature>.md`. Cover affected repositories, interfaces, design choices, migration and failure risks, test approach, and rollout considerations. Return product questions to the user rather than redefining scope.
   List every decision point as a numbered item (D1, D2, …) with the options, a recommendation, and the requirement it serves; do not settle one silently with a default. Before submitting the plan, run the pre-approval self-review in [Review-cycle minimization](#review-cycle-minimization).

5. **OWNER_PLAN_APPROVAL — user**
   The user reviews and explicitly approves the architecture and implementation plan before any execution starts. Every decision point must be resolved and approved here; a plan with open, default-assumed, or unconfirmed decision points may not proceed. The user may override, amend, or reject any part of the plan; requested changes return to TECHNICAL_PLANNING and need approval again. Later plan amendments that change a decision or the scope also need user approval. Implementation and QA test-plan authoring both start only after this gate.

6. **IMPLEMENTATION ∥ QA_TEST_PLANNING — Engineer and QA Engineer, in parallel**
   - **Engineer:** work in the assigned repositories and worktrees. Follow the approved requirement and plan, preserve unrelated changes, run relevant checks (self-tests and the project's verification commands), and report exact changes and evidence. Raise any requirement conflict before expanding scope.
   - **QA (test-plan authoring):** write `docs/qa/<feature>-test-plan.md` from the requirement and design: an independent, black-box plan with QA's own test cases, focused first on UX and end-to-end user journeys (for example sign-up → sign-in → core task → sign-out), then on integration and failure paths. Cover error, recovery, and edge paths with executable fault injection, not only happy paths, and meet the test-plan standard in [Review-cycle minimization](#review-cycle-minimization). Commit it with the feature's branch so it stays with the change. Do not reuse the Engineer's test suite as the plan.

7. **TECH_LEAD_REVIEW — Tech Lead**
   Review both deliverables before QA executes anything: (a) the implementation and the Engineer's self-tests against the plan and requirement, for correctness, maintainability, security, and scope; (b) the QA test plan, for coverage of the acceptance criteria, correctness, and feasibility. Approve or amend each. Record actionable findings; if changes are needed, return to IMPLEMENTATION or QA_TEST_PLANNING and review again after fixes.

8. **QA_EXECUTION — QA Engineer (Diana)**
   Execute the Tech-Lead-approved test plan against the completed implementation, and re-run the project's standing verification checks as supporting evidence. UX and end-to-end findings are defects, not suggestions. Record environment, checks, results, evidence, and defects in `docs/qa/<feature>.md`. A failed check returns to IMPLEMENTATION; QA retests the fix. Do not infer success from a build alone.

9. **USER_APPROVAL — user**
   Present the implementation summary, review outcome, QA report, and remaining risks. Obtain explicit approval before marking the task ready to merge. Requested changes return to the appropriate earlier phase.

10. **READY_TO_MERGE — Main agent / Head of Engineering**
   Confirm all required artifacts and gates are present and link them on the task. This means ready for a merge decision; it does not authorize merging, deployment, or production changes by itself.

## Kanban task structure

After the user approves the plan (OWNER_PLAN_APPROVAL, recorded on the planning card), the Tech Lead creates these cards, with dependencies so each starts only when its inputs are done:

1. **Implementation** (assignee `engineer`), parent: the planning card.
2. **QA test plan** (assignee `qa`), parent: the planning card.
3. **Tech Lead review** of both (assignee `techlead`), parents: cards 1 and 2.
4. **QA execution** (assignee `qa`), parent: card 3.

Keep each card small enough to finish in one run; split large implementations into several implementation cards and make the review card depend on all of them. Do not set a model or provider on any card.

## Review-fix rounds

These rules apply whenever a review (by the user or the Tech Lead) returns findings to be fixed:

1. **Adversarial pass:** before handing fixes back, the Tech Lead reviews each fix diff adversarially, explicitly covering interactions between fixes and the boundary states QA probes.
2. **Repro first:** every fix ships with a regression test that was verified to fail at the pre-fix commit.
3. **All implementations:** when the project has several implementations of the same interface (for example storage backends or platforms), verify each fix on all of them, not only a test stub or in-memory fake.
4. **Docs are gated too:** tables and diagrams in plans and ledgers must render, and the project's documentation formatting and lint checks must pass.
5. **Fix summary on the PR:** after each fix round, the Engineer or Tech Lead posts one comment on the pull request summarizing every fix: the finding it addresses, what changed, files, commit SHAs, tests added, and check results.
6. **Escalation:** if a pull request reaches a third user review round, the Tech Lead re-plans before another fix round.

## Review-cycle minimization

Goal: a user re-review should need zero additional comments. A delivery or fix round in which the user finds new defects is a process defect: analyze and prevent it, don't only fix it.

1. **Planning thoroughness (Tech Lead):** before submitting a plan for OWNER_PLAN_APPROVAL, review it adversarially: cross-component interactions, lifecycle and protocol completeness (every key, field, and identity an operation touches), and the failure and edge cases that past reviews targeted. Every decision point states its requirement basis. A gap found later is a planning defect.
2. **Test-plan thoroughness (QA):** test plans cover error, recovery, and edge paths with executable fault injection, not only happy paths; trace every acceptance criterion to cases; and give each case explicit columns for the implementation or backend it runs against and the evidence it produces. Before submitting the plan for review, QA audits it against the architecture and implementation docs and maps every row.
3. **Retrospective:** when a user review finds something an earlier stage should have caught, the Tech Lead records the root cause in the plan or fix doc and adds a preventive check to the process.

## Handoff record

Every role handoff includes the task ID, project, repository and branch/worktree, requirement revision, acceptance criteria, artifacts changed, checks run and results, known risks or blockers, and the requested next action. Keep secrets out of task descriptions, comments, docs, logs, and commits.

## Multi-repository work

A single project may contain multiple repositories, such as frontend, backend, and infrastructure. Track them under the same project/task; list each repo, branch/worktree, owner, dependency, and interface change in the plan. Do not split them into unrelated projects solely because they use separate repositories.

## Exceptions

- If acceptance criteria conflict with the approved requirement, pause affected work and request a user decision.
- If a required check cannot run, mark it blocked or not run; never mark it passed.
- If unrelated user changes appear, preserve them and flag them in the handoff.
- Never merge, deploy, publish, force-push, delete data, or contact people without the user's explicit authorization.
