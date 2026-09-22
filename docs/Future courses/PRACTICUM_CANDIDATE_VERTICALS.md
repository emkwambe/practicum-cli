# Practicum CLI — Candidate Verticals

A parking list for later exploration. Not a roadmap, not committed work. Revisit after 7E, once the Classroom tier has real buyers and you know whether institutions actually purchase.

## The filter used here

Three tests decide whether a vertical belongs on this list.

**Is the terminal the work environment, not just an occasional tool?** If practitioners live in a shell all day, the platform is native to how they already work. If they touch a command line twice a month, a terminal-native course is a gimmick.

**Can the harness verify the work?** Practicum's real asset is a verification layer that inspects actual shell state and confirms a learner did the thing. If correctness can't be checked from the filesystem, process table, or command output, the platform's advantage disappears.

**Does someone hold a training budget?** Individuals buy cheap and churn. Departments, labs, and employers buy the Classroom tier.

Steep-slope options are excluded: anything requiring hardware you can't reach, or a domain where thin content would be spotted immediately by the learners themselves.

---

## Tier 1 — strongest fit

### Data engineering
The closest adjacency to what already exists. Git, dbt, SQL, pipeline orchestration, and warehouse tooling are all terminal work, and the verification model transfers directly — check that a transformation produced the expected rows, that a DAG ran clean, that a migration is reversible.

The real advantage is that SafeSQL Pro and RealityDB can supply content and synthetic data that no competitor can replicate: query-risk analysis as lesson material, generated datasets as lab fixtures. That's a moat, not just a course.

Buyers are analytics teams and bootcamps. The risk is crowding at the intro level, so the wedge is the operational middle — the part about running pipelines in production that tutorials skip.

### Bioinformatics and computational genomics
The most underserved market on this list. Graduate students and core-facility staff are handed a cluster account, SLURM, conda, and a Nextflow or Snakemake pipeline and left to work it out. The terminal is non-negotiable, and the people struggling most are biologists who never took a CS course.

Verification fits perfectly: confirm the pipeline produced the expected output files, that a job was submitted correctly, that an environment resolves. Core facilities and departments hold genuine training budgets and buy institutionally.

The blocker is credibility. This is a domain you haven't lived in, and a thin curriculum would be obvious to the first postdoc who opened it. It needs a co-author who has actually run jobs on an HPC cluster — which makes it the best argument for instructor authoring tools rather than a course you write yourself.

---

## Tier 2 — worth exploring with a narrow wedge

### Defensive security for teams without a SOC
Log analysis, incident triage, and host forensics are terminal-native, budgets are large, and certification culture is well established. But TryHackMe and Hack The Box have years of content and community, so entering broadly would be a losing fight.

The wedge is the part they neglect: the small-team defender who has no security operations center, needs to read logs on a handful of servers, and wants a repeatable process rather than offensive exercises. Narrow enough to win, adjacent enough to your existing Linux content.

### Platform and SRE practice
A natural extension upward from the current DevOps catalog rather than a new vertical — incident response drills, observability, on-call readiness, debugging a system under load. Employers pay for onboarding that shortens time-to-first-oncall.

Verification works well here because failures can be injected and the learner's response observed. The reason it's Tier 2 rather than Tier 1 is that it competes with your own existing content for attention, so it makes sense only once the Classroom tier has proven itself.

### Research computing and HPC literacy
The generic version of the bioinformatics case: SLURM, module systems, job arrays, and shared filesystems, taught to whoever the university hands a cluster account. Broader applicability across physics, chemistry, economics, and engineering, but a weaker sale because the pain is more diffuse.

Note the competitive hazard: the Carpentries teach adjacent material free. The paid angle has to be institutional — cohort tracking, completion reporting, onboarding that a research computing center can point at — not the content itself.

---

## Tier 3 — plausible, not yet interesting

### Embedded and systems toolchains
Cross-compilation, build systems, and debugging with gdb are genuinely terminal work with almost no good training. But verification often needs hardware you can't reach from a sandbox, which breaks the core model. Only viable if scoped strictly to the toolchain and emulated targets.

### Database administration
Backup, restore, replication, and performance triage are shell-heavy, and the SafeSQL adjacency is real. Ranked lower because the audience is shrinking at the low end as managed services absorb the routine work.

### Quantitative and scientific workflow
Reproducible environments, notebooks under version control, and long-running job management. Real pain, weak willingness to pay, and heavy free competition.

---

## The pattern underneath the list

Every Tier 1 and Tier 2 option shares a shape: a domain expert exists who knows the content but can't build a platform, and an institution exists that would buy cohort seats. That suggests the highest-leverage product isn't another course at all — it's **instructor authoring tools**, letting a domain expert write labs against the Practicum harness on a revenue share.

That would make the verification engine the product and the catalog the network effect. It's a strategic decision, not a sprint, and it should wait until the Classroom tier has shown whether institutions buy.

---

## Before any of this

Two things have to be true first. The Classroom tier needs real paying customers, not just a working dashboard — a vertical built on an unproven distribution model compounds one bet with another. And the content pipeline needs to be cheaper than it is today: if writing a course is slow and manual, adding verticals multiplies the cost instead of the revenue.
