# Practicum CLI — What Each Vertical Would Actually Require

Companion to `PRACTICUM_CANDIDATE_VERTICALS.md`. That file asks which markets are worth entering. This one asks what it would cost to enter each, mapped against what the platform can do today.

## What exists now

The current model is a single shell session. Labs verify by inspecting the filesystem, the process table, command output, and exit codes. Content is plain text lessons plus `.sh` verification scripts. Everything runs on the learner's own machine, so there is no hosted sandbox and no per-learner infrastructure cost.

That last point is the platform's quiet advantage and also its main constraint. It scales to any number of learners for free, but it can only verify things that exist on the learner's machine.

## The four capability gaps that keep appearing

Most verticals below need one or more of the same four things, so build decisions should be made against this list rather than per course.

**Service containers.** A lab that needs a running database, message broker, or web service. Requires Docker as a prerequisite and verification that can reach into a container. This single capability unlocks the most verticals of any item here.

**Seeded state.** Labs where the learner is handed a broken or populated system rather than an empty one — a corrupted table, a filled log file, a repository with a messy history. Needs a fixture format and a reset command.

**Multi-step scenario state.** Incident-style labs where step three depends on what the learner did in step two, and where the environment changes underneath them. Today's model is one-shot verification.

**Output-artifact checking.** Verifying that a produced file is *correct*, not just present — row counts, schema, checksums, expected values. Cheaper than it sounds and reusable across data, genomics, and DBA work.

---

# Tier 1

## Data engineering

**What the learner does.** Builds a transformation that lands correct rows, debugs a failed pipeline run, writes a test that catches bad data, manages environments and secrets, recovers from a broken migration.

**Verification needed.** Output-artifact checking is the core requirement: assert row counts, schema shape, null rates, and expected values in a produced table or file. Service containers for a real database. Seeded state for "here is a pipeline that fails, fix it."

**Infrastructure.** Docker plus a local Postgres or DuckDB. DuckDB is worth serious consideration as the default, since it is a single file with no server, which keeps the zero-infrastructure property intact for most labs.

**Content and expertise.** This is the one vertical you can author yourself. RealityDB generates the fixtures, SafeSQL supplies query-risk material as lesson content, and your analytics background covers the correctness reasoning.

**Buyer.** Analytics teams onboarding juniors; bootcamps needing a verified practical component.

**Build shape.** The lightest lift on the list. Output-artifact checking plus DuckDB fixtures gets a meaningful catalog with no new domain expertise and no hosted infrastructure.

## Bioinformatics and computational genomics

**What the learner does.** Submits and monitors SLURM jobs, resolves a conda environment, runs a Nextflow or Snakemake pipeline, moves large files sensibly, interprets a pipeline failure.

**Verification needed.** Output-artifact checking on genomics file formats — FASTQ, BAM, VCF — asserting record counts and headers rather than byte equality. A SLURM simulation, since learners won't have a cluster. Seeded state for partially failed pipeline runs.

**Infrastructure.** The hard part. Either a containerized mini-SLURM so learners can practice job submission locally, or scope the course to pipeline and environment work and treat scheduler material as read-only. Real genomics data is far too large, so subsampled reference datasets are mandatory.

**Content and expertise.** A co-author who has run production jobs on an HPC cluster. Not optional, and not something desk research substitutes for. The failure mode is a curriculum that looks plausible to you and obviously thin to a postdoc.

**Buyer.** Core facilities, graduate programs, research computing centers. Institutional budgets, slow cycles, strong word of mouth once established.

**Build shape.** Highest ceiling, highest cost. The SLURM simulation alone is a sprint. This is the clearest argument for authoring tools instead of writing it yourself.

---

# Tier 2

## Defensive security for teams without a SOC

**What the learner does.** Reads authentication and web logs to find an intrusion, triages a suspicious process, checks persistence mechanisms, writes a detection rule, documents a timeline.

**Verification needed.** Seeded state is the whole game here — realistic log files with an attack buried in them. Multi-step scenario state for investigations that unfold. Answer-submission verification, since the learner's finding is a conclusion, not a file.

**Infrastructure.** Generated log corpora with known planted incidents. No hosted sandbox needed if the scenario ships as files, which keeps this cheaper than it first appears.

**Content and expertise.** A practitioner co-author is strongly advisable. Security learners are unforgiving about realism, and an unconvincing scenario damages credibility fast.

**Buyer.** Small IT teams, MSPs, compliance-driven training budgets.

**Build shape.** Moderate. The log-generation tooling is reusable across every scenario, so cost front-loads and then drops.

## Platform and SRE practice

**What the learner does.** Responds to a failing service, reads metrics and traces, performs a rollback, runs a postmortem, handles a degraded dependency.

**Verification needed.** Multi-step scenario state and fault injection: the environment must actively break while the learner works. This is the deepest platform change on the list, since it inverts the current model from static check to live scenario.

**Infrastructure.** Docker Compose with a small multi-service application plus a fault injector.

**Content and expertise.** Within your reach, given the existing DevOps catalog, though the scenario design is a genuinely different skill from lesson writing.

**Buyer.** Employers onboarding engineers to on-call. The clearest budget story on the list, since time-to-first-oncall is a metric managers already track.

**Build shape.** Heavy platform work, light content work. Effectively a new lab engine rather than a new course.

## Research computing and HPC literacy

**What the learner does.** The generic version of the genomics case, across physics, chemistry, economics: modules, job arrays, shared filesystems, batch etiquette.

**Verification needed.** Same SLURM simulation as genomics. Shares nearly all its infrastructure, which is the main argument for treating them as one investment.

**Content and expertise.** A research computing staff co-author. Easier to find than a genomics specialist, since most universities have such a team.

**Buyer.** University research computing centers, which buy institutionally and renew annually.

**Build shape.** Only sensible as a companion to genomics; alone, the pain is too diffuse to sell against the Carpentries' free material.

---

# Tier 3

## Database administration

**What the learner does.** Takes and restores backups, sets up replication, diagnoses a slow query, recovers from a corrupted or full disk, manages users and permissions.

**Verification needed.** Service containers are mandatory, since a real database must be running. Seeded state for a database that is already broken. Output-artifact checking to confirm a restore actually produced the right data.

**Infrastructure.** Docker with Postgres or MySQL. Destructive labs need a clean reset, which makes the reset command a hard requirement rather than a convenience.

**Content and expertise.** Partially covered by your SQL work, though operational DBA skills — replication topologies, recovery under pressure — are a distinct specialty from query and analytics work.

**Buyer.** Weakening. Managed services have absorbed most routine administration, so the audience is shrinking at exactly the entry level a course would target.

**Build shape.** Moderate cost, declining market. Reconsider only as an add-on once service containers exist for data engineering.

## Embedded and systems toolchains

**What the learner does.** Cross-compiles for a target architecture, debugs with gdb, reads a linker error, works a build system.

**Verification needed.** Output-artifact checking on compiled binaries — target architecture, symbols, size — which is straightforward. The problem is everything involving real hardware, which the sandbox can't reach.

**Infrastructure.** QEMU for emulated targets. Scope strictly to toolchain and emulation, and state plainly that hardware bring-up is out of scope.

**Content and expertise.** Specialist co-author required.

**Build shape.** Viable only in a narrow slice. The part learners most want is the part the model can't verify.

## Quantitative and scientific workflow

**What the learner does.** Pins a reproducible environment, puts notebooks under version control, manages long-running jobs, structures a project so results can be regenerated.

**Verification needed.** Reproducibility checking — run it twice, confirm identical output — which is elegant and largely within current capability.

**Content and expertise.** Authorable without a co-author.

**Buyer.** The weak point. Real pain, thin willingness to pay, and direct free competition from the Carpentries.

**Build shape.** Cheapest to build, hardest to sell. Better as free marketing content that feeds paid catalogs than as a product.

---

# What this maps to in build order

The capability that unlocks the most ground for the least work is **output-artifact checking**, which serves data engineering, genomics, DBA, and embedded alike. **Service containers** come second and open data engineering and DBA properly. **Seeded state** is the prerequisite for security and any "fix what's broken" lab, and is mostly a fixture format plus a reset command. **Fault injection and live scenario state** is the largest investment and serves only SRE, so it should wait for evidence that employers will pay for on-call onboarding.

Read as a sequence, that is one clear path: build output-artifact checking and service containers for data engineering, a vertical you can author alone with your own products supplying the content. Those same two capabilities then make every other candidate materially cheaper — which is the strongest reason to start there rather than with the biggest market.
