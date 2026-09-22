\# Sprint: Wire 17 recurring yearly Dodo products \+ 3-zone pricing restructure

&nbsp;

\#\# Context

\- Repo: github.com/emkwambe/practicum-cli

\- All 17 new recurring yearly Dodo products created by Sentra

\- Old one-time product IDs must be fully replaced everywhere

\- New 3-zone page structure built in this same sprint

\- Read /mnt/skills/public/frontend-design/SKILL.md before writing any HTML

&nbsp;

\---

&nbsp;

\#\# Product ID Reference — use these everywhere, no exceptions

&nbsp;

\#\#\# Individual courses

\`\`\`

Linux Foundations              pdt\_0No8cX1sZ1XCttHIl5fh3

Git & Version Control          pdt\_0No8cX1r3haaAnMDWlW8C

Shell Mastery                  pdt\_0No8cX1sZ1XCttHQ6FwOk

Data Forging                   pdt\_0No8cX1rolhdm8TbGSI91

Docker & Containers            pdt\_0No8cX1sZQTfyfYqre4BW

CI/CD Pipelines                pdt\_0No8cX1tLOc3LaVXpGBPw

Terraform & IaC                pdt\_0No8cX2J2EoRdkmAVkMCE

Kubernetes                     pdt\_0No8cX2OJhVBYHfq4V9cs

\`\`\`

&nbsp;

\#\#\# Individual tracks

\`\`\`

Data Engineering Track         pdt\_0No8cX2PpLQr3eZTRBjov

Platform Engineering Track     pdt\_0No8cX2P3PLJsBYdbVe29

Full Catalog                   pdt\_0No8cX2NZGEmwrUPoCegF

\`\`\`

&nbsp;

\#\#\# Team tracks

\`\`\`

Team Data Engineering 5 Seats  pdt\_0No8cX2WdUc6FfZmRq6no

Team Data Engineering 10 Seats pdt\_0No8cX2kDV38Olhehkf7o

Team Platform Eng 5 Seats      pdt\_0No8cX2zJK81FG3NaA0st

Team Platform Eng 10 Seats     pdt\_0No8cX2tGb8qRo7UOMUqr

Team Full Catalog 5 Seats      pdt\_0No8cX2zJK81FG3VFNdPD

Team Full Catalog 10 Seats     pdt\_0No8cX2xnVQggiN3WPjoA

\`\`\`

&nbsp;

\#\#\# Unchanged

\`\`\`

Classroom — 30 Seats           pdt\_0No8Kgf2Z4FOleEA96DEW  (recurring yearly — correct)

\`\`\`

&nbsp;

\---

&nbsp;

\#\# Task 1 — workers/practicum-api/src/index.ts

&nbsp;

\#\#\# 1a. Replace all old product IDs in PRODUCT\_ENTITLEMENTS

&nbsp;

Remove every old pdt\_0No7um\* entry. Replace with:

&nbsp;

\`\`\`typescript

const PRODUCT\_ENTITLEMENTS: Record\<string, string\[\]\> \= {

&nbsp;&nbsp;// Individual courses

&nbsp;&nbsp;"pdt\_0No8cX1sZ1XCttHIl5fh3": \["linux-foundations"\],

&nbsp;&nbsp;"pdt\_0No8cX1r3haaAnMDWlW8C": \["git-essentials"\],

&nbsp;&nbsp;"pdt\_0No8cX1sZ1XCttHQ6FwOk": \["shell-mastery"\],

&nbsp;&nbsp;"pdt\_0No8cX1rolhdm8TbGSI91": \["data-forging"\],

&nbsp;&nbsp;"pdt\_0No8cX1sZQTfyfYqre4BW": \["docker-essentials"\],

&nbsp;&nbsp;"pdt\_0No8cX1tLOc3LaVXpGBPw": \["cicd-pipelines"\],

&nbsp;&nbsp;"pdt\_0No8cX2J2EoRdkmAVkMCE": \["terraform-iac"\],

&nbsp;&nbsp;"pdt\_0No8cX2OJhVBYHfq4V9cs": \["kubernetes"\],

&nbsp;

&nbsp;&nbsp;// Individual tracks

&nbsp;&nbsp;"pdt\_0No8cX2PpLQr3eZTRBjov": \[

&nbsp;&nbsp;&nbsp;&nbsp;"linux-foundations", "shell-mastery", "data-forging"

&nbsp;&nbsp;\],

&nbsp;&nbsp;"pdt\_0No8cX2P3PLJsBYdbVe29": \[

&nbsp;&nbsp;&nbsp;&nbsp;"linux-foundations", "git-essentials", "docker-essentials",

&nbsp;&nbsp;&nbsp;&nbsp;"cicd-pipelines", "terraform-iac", "kubernetes"

&nbsp;&nbsp;\],

&nbsp;&nbsp;"pdt\_0No8cX2NZGEmwrUPoCegF": \[

&nbsp;&nbsp;&nbsp;&nbsp;"linux-foundations", "git-essentials", "shell-mastery",

&nbsp;&nbsp;&nbsp;&nbsp;"data-forging", "docker-essentials", "cicd-pipelines",

&nbsp;&nbsp;&nbsp;&nbsp;"terraform-iac", "kubernetes"

&nbsp;&nbsp;\],

&nbsp;

&nbsp;&nbsp;// Team Data Engineering

&nbsp;&nbsp;"pdt\_0No8cX2WdUc6FfZmRq6no": \[

&nbsp;&nbsp;&nbsp;&nbsp;"linux-foundations", "shell-mastery", "data-forging"

&nbsp;&nbsp;\],

&nbsp;&nbsp;"pdt\_0No8cX2kDV38Olhehkf7o": \[

&nbsp;&nbsp;&nbsp;&nbsp;"linux-foundations", "shell-mastery", "data-forging"

&nbsp;&nbsp;\],

&nbsp;

&nbsp;&nbsp;// Team Platform Engineering

&nbsp;&nbsp;"pdt\_0No8cX2zJK81FG3NaA0st": \[

&nbsp;&nbsp;&nbsp;&nbsp;"linux-foundations", "git-essentials", "docker-essentials",

&nbsp;&nbsp;&nbsp;&nbsp;"cicd-pipelines", "terraform-iac", "kubernetes"

&nbsp;&nbsp;\],

&nbsp;&nbsp;"pdt\_0No8cX2tGb8qRo7UOMUqr": \[

&nbsp;&nbsp;&nbsp;&nbsp;"linux-foundations", "git-essentials", "docker-essentials",

&nbsp;&nbsp;&nbsp;&nbsp;"cicd-pipelines", "terraform-iac", "kubernetes"

&nbsp;&nbsp;\],

&nbsp;

&nbsp;&nbsp;// Team Full Catalog

&nbsp;&nbsp;"pdt\_0No8cX2zJK81FG3VFNdPD": \[

&nbsp;&nbsp;&nbsp;&nbsp;"linux-foundations", "git-essentials", "shell-mastery",

&nbsp;&nbsp;&nbsp;&nbsp;"data-forging", "docker-essentials", "cicd-pipelines",

&nbsp;&nbsp;&nbsp;&nbsp;"terraform-iac", "kubernetes"

&nbsp;&nbsp;\],

&nbsp;&nbsp;"pdt\_0No8cX2xnVQggiN3WPjoA": \[

&nbsp;&nbsp;&nbsp;&nbsp;"linux-foundations", "git-essentials", "shell-mastery",

&nbsp;&nbsp;&nbsp;&nbsp;"data-forging", "docker-essentials", "cicd-pipelines",

&nbsp;&nbsp;&nbsp;&nbsp;"terraform-iac", "kubernetes"

&nbsp;&nbsp;\],

&nbsp;

&nbsp;&nbsp;// Classroom

&nbsp;&nbsp;"pdt\_0No8Kgf2Z4FOleEA96DEW": \[

&nbsp;&nbsp;&nbsp;&nbsp;"linux-foundations", "git-essentials", "shell-mastery",

&nbsp;&nbsp;&nbsp;&nbsp;"data-forging", "docker-essentials", "cicd-pipelines",

&nbsp;&nbsp;&nbsp;&nbsp;"terraform-iac", "kubernetes"

&nbsp;&nbsp;\],

};

\`\`\`

&nbsp;

\#\#\# 1b. Update PRODUCT\_SEATS

&nbsp;

\`\`\`typescript

const PRODUCT\_SEATS: Record\<string, number\> \= {

&nbsp;&nbsp;"pdt\_0No8cX2WdUc6FfZmRq6no": 5,   // Team Data Eng 5

&nbsp;&nbsp;"pdt\_0No8cX2kDV38Olhehkf7o": 10,  // Team Data Eng 10

&nbsp;&nbsp;"pdt\_0No8cX2zJK81FG3NaA0st": 5,   // Team Platform 5

&nbsp;&nbsp;"pdt\_0No8cX2tGb8qRo7UOMUqr": 10,  // Team Platform 10

&nbsp;&nbsp;"pdt\_0No8cX2zJK81FG3VFNdPD": 5,   // Team Full 5

&nbsp;&nbsp;"pdt\_0No8cX2xnVQggiN3WPjoA": 10,  // Team Full 10

&nbsp;&nbsp;"pdt\_0No8Kgf2Z4FOleEA96DEW": 30,  // Classroom

};

\`\`\`

&nbsp;

\#\#\# 1c. Update PRODUCT\_ROLE

&nbsp;

\`\`\`typescript

const PRODUCT\_ROLE: Record\<string, string\> \= {

&nbsp;&nbsp;"pdt\_0No8Kgf2Z4FOleEA96DEW": "instructor-admin",

&nbsp;&nbsp;// all others default to "learner"

};

\`\`\`

&nbsp;

\#\#\# 1d. Update Telegram email note

&nbsp;

In sendLicenseEmail, detect team products (seats \> 1\) and append:

&nbsp;

\`\`\`typescript

const isTeam \= (PRODUCT\_SEATS\[product\_id\] ?? 1\) \> 1;

const telegramNote \= isTeam ? \`

\---

Your private Telegram group will be set up within 24 hours of purchase.

You will receive a separate email at this address with the invite link.

As the team admin you can invite your engineers directly from the group.

\` : "";

\`\`\`

&nbsp;

Include telegramNote in the email body after the course list.

&nbsp;

\---

&nbsp;

\#\# Task 2 — lib/index.html — full pricing section replacement

&nbsp;

Replace everything between the pricing section opening tag and the

footer with the 3-zone structure below.

&nbsp;

\#\#\# Cancellation policy addition to license terms block

&nbsp;

Add after "There is no automatic renewal.":

&nbsp;

"If you cancel, access continues until your current license year ends.

No prorated refunds are issued for unused months."

&nbsp;

\#\#\# Zone 1 — Learn independently

&nbsp;

Section heading: "Learn independently"

Subheading: "Your license. Your pace. No autorenewal."

&nbsp;

5 tiles — 3+2 responsive grid:

&nbsp;

\*\*Free Preview — $0\*\*

Features:

\- CLI Immersion — all 4 days

\- Days 1–3 of every course

\- Quizzes and sandbox mode

\- No credit card required

CTA: Start Free → \#install

&nbsp;

\*\*Single Course — $49/yr\*\*

Descriptor: One complete course, annual access

Features:

\- Full course access

\- All quizzes and assessments

\- Completion certificate

\- All course updates during your license year

Dropdown \+ dynamic buy button.

Course → Product ID map:

&nbsp;&nbsp;Linux Foundations      pdt\_0No8cX1sZ1XCttHIl5fh3

&nbsp;&nbsp;Git & Version Control  pdt\_0No8cX1r3haaAnMDWlW8C

&nbsp;&nbsp;Shell Mastery          pdt\_0No8cX1sZ1XCttHQ6FwOk

&nbsp;&nbsp;Data Forging           pdt\_0No8cX1rolhdm8TbGSI91

&nbsp;&nbsp;Docker & Containers    pdt\_0No8cX1sZQTfyfYqre4BW

&nbsp;&nbsp;CI/CD Pipelines        pdt\_0No8cX1tLOc3LaVXpGBPw

&nbsp;&nbsp;Terraform & IaC        pdt\_0No8cX2J2EoRdkmAVkMCE

&nbsp;&nbsp;Kubernetes             pdt\_0No8cX2OJhVBYHfq4V9cs

CTA: Buy Course — $49

&nbsp;

\*\*Data Engineering — $99/yr\*\*

Descriptor: The complete data engineering foundation.

Features:

\- ✓ Linux Foundations

\- ✓ Shell Mastery

\- ✓ Data Forging

\- Track projects and associated labs

\- Completion certificate

\- All track additions during your license year

CTA: Start Data Engineering

href: https://checkout.dodopayments.com/buy/pdt\_0No8cX2PpLQr3eZTRBjov

&nbsp;

\*\*Platform Engineering — $129/yr\*\* \[MOST POPULAR\]

Descriptor: The full technical foundation for modern platform work.

Features:

\- ✓ Linux Foundations

\- ✓ Git & Version Control

\- ✓ Docker & Containers

\- ✓ CI/CD Pipelines

\- ✓ Terraform & IaC

\- ✓ Kubernetes

\- CKA \+ TF Associate 004 \+ DCA aligned

\- Completion certificate

CTA: Start Platform Engineering

href: https://checkout.dodopayments.com/buy/pdt\_0No8cX2P3PLJsBYdbVe29

&nbsp;

\*\*Full Catalog — $199/yr\*\*

Descriptor: Every course. Every lab. The only tier with Capstone

and Certification.

Features:

\- ✓ Linux Foundations

\- ✓ Git & Version Control

\- ✓ Shell Mastery

\- ✓ Data Forging

\- ✓ Docker & Containers

\- ✓ CI/CD Pipelines

\- ✓ Terraform & IaC

\- ✓ Kubernetes

\- ✓ All Practicum Labs

\- ✓ Capstone \+ Certification

\- 5 certification alignments

\- Every catalog addition during your license year

CTA: Get Full Access

href: https://checkout.dodopayments.com/buy/pdt\_0No8cX2NZGEmwrUPoCegF

&nbsp;

\---

&nbsp;

\#\#\# License terms policy block

&nbsp;

Place between Zone 1 and Zone 2\. Keep existing bordered callout

style with green left rule.

&nbsp;

Full updated text:

"Your license is valid for 12 months from purchase. There is no

automatic renewal. New courses, lessons, labs, and features added

to your subscribed plan during that period are included at no

additional cost. If you cancel, access continues until your current

license year ends. No prorated refunds are issued for unused months.

When your year ends, you choose whether to renew at the price

published at that time."

&nbsp;

\---

&nbsp;

\#\#\# Zone 2 — Develop your team

&nbsp;

Section heading: "Develop your team"

Subheading: "Same curriculum your engineers would buy individually —

with team visibility, a shared dashboard, and a private Telegram group."

&nbsp;

Explicit disclaimer below subheading:

"Team licenses are available for full tracks and the complete catalog

only. Individual course selection is not available for team purchases."

&nbsp;

3 team cards. Each card has a seat selector (5 seats / 10 seats)

that updates the displayed price and CTA href on selection.

Default selection: 5 seats.

&nbsp;

\*\*Team Data Engineering\*\*

Descriptor: Your data engineers get the same three courses —

with team visibility.

Features:

\- ✓ Linux Foundations

\- ✓ Shell Mastery

\- ✓ Data Forging

\- Track projects and associated labs

\- Team dashboard \+ completion tracking

\- 1 admin seat

\- ✓ Private Telegram group for your team

Seat selector:

&nbsp;&nbsp;5 seats — $349/yr  pdt\_0No8cX2WdUc6FfZmRq6no

&nbsp;&nbsp;10 seats — $599/yr pdt\_0No8cX2kDV38Olhehkf7o

CTA: Equip Your Team

&nbsp;

\*\*Team Platform Engineering\*\*

Descriptor: Six courses. The whole platform foundation —

for your whole team.

Features:

\- ✓ Linux Foundations

\- ✓ Git & Version Control

\- ✓ Docker & Containers

\- ✓ CI/CD Pipelines

\- ✓ Terraform & IaC

\- ✓ Kubernetes

\- Team dashboard \+ completion tracking

\- 1 admin seat

\- ✓ Private Telegram group for your team

Seat selector:

&nbsp;&nbsp;5 seats — $499/yr  pdt\_0No8cX2zJK81FG3NaA0st

&nbsp;&nbsp;10 seats — $899/yr pdt\_0No8cX2tGb8qRo7UOMUqr

CTA: Equip Your Team

&nbsp;

\*\*Team Full Catalog\*\*

Descriptor: Every course, every lab, Capstone and Certification —

for your entire engineering team.

Features:

\- ✓ All 8 courses

\- ✓ All Practicum Labs

\- ✓ Capstone \+ Certification

\- Team dashboard \+ completion tracking

\- CSV export

\- 1–2 admin seats

\- ✓ Private Telegram group for your team

Seat selector:

&nbsp;&nbsp;5 seats — $899/yr   pdt\_0No8cX2zJK81FG3VFNdPD

&nbsp;&nbsp;10 seats — $1,599/yr pdt\_0No8cX2xnVQggiN3WPjoA

CTA: Equip Your Team

&nbsp;

\---

&nbsp;

\#\#\# Zone 3 — Run a cohort

&nbsp;

Section heading: "Run a cohort"

Subheading: "Structured delivery with instructor controls,

assignments, and completion evidence."

&nbsp;

2 cards side by side:

&nbsp;

\*\*Classroom — $3,499/yr\*\*

Features:

\- ✓ All 8 courses

\- ✓ All Practicum Labs

\- ✓ Capstone \+ Certification

\- Up to 30 learner seats

\- 2 instructor seats

\- Instructor dashboard \+ assignments

\- Cohort progress \+ completion reporting

\- CSV export

\- ✓ Private Telegram group managed by instructor

CTA: Join the Waitlist

href: mailto:practicum@mpingo.ai?subject=Classroom%20License%20

%E2%80%94%20Waitlist\&body=Institution%20name%3A%0A

Number%20of%20learners%3A%0AExpected%20start%20date%3A

&nbsp;

\*\*Enterprise\*\*

Features:

\- ✓ Full catalog \+ all labs

\- Unlimited seats

\- SSO integration

\- Department management

\- Skill dashboards

\- Custom exercises

\- Dedicated support

CTA: Talk to Us

href: mailto:practicum@mpingo.ai

&nbsp;

\---

&nbsp;

\#\# Task 3 — Verify no old product IDs remain

&nbsp;

\`\`\`powershell

grep \-r "pdt\_0No7um" lib/ workers/

\# Must return 0 matches

\`\`\`

&nbsp;

\---

&nbsp;

\#\# Task 4 — Deploy

&nbsp;

\`\`\`powershell

wrangler deploy \--cwd C:\\Users\\HP\\Documents\\practicum-cli\\workers\\practicum-api

wrangler deploy \--cwd C:\\Users\\HP\\Documents\\practicum-cli

\`\`\`

&nbsp;

Smoke tests:

\`\`\`powershell

\# Three zones live

curl \-s https://practicum-cli.dev | grep \-c "Learn independently"

curl \-s https://practicum-cli.dev | grep \-c "Develop your team"

curl \-s https://practicum-cli.dev | grep \-c "Run a cohort"

&nbsp;

\# New product IDs present

curl \-s https://practicum-cli.dev | grep \-c "pdt\_0No8cX"

&nbsp;

\# No old product IDs

curl \-s https://practicum-cli.dev | grep \-c "pdt\_0No7um"

\# Must return 0

&nbsp;

\# Cancellation policy present

curl \-s https://practicum-cli.dev | grep \-c "prorated"

&nbsp;

\# Team disclaimer present

curl \-s https://practicum-cli.dev | grep \-c "Individual course selection"

&nbsp;

\# No forbidden copy

curl \-s https://practicum-cli.dev | grep \-c "lifetime\\|buy it once\\|sales@mpingo"

\# Must return 0

\`\`\`

&nbsp;

\---

&nbsp;

\#\# Task 5 — Update docs/gating-audit.md

&nbsp;

\- All old pdt\_0No7um product IDs replaced with recurring yearly IDs

\- 6 new team track products added to entitlement map

\- Telegram Phase 1 noted: manual provisioning within 24h of team purchase

\- Cancellation policy documented: access to license year end, no prorated refund

\- Team disclaimer noted: individual course selection unavailable for teams

&nbsp;

\---

&nbsp;

\#\# Task 6 — Commit

&nbsp;

\`\`\`powershell

git add lib/index.html workers/practicum-api/src/index.ts docs/gating-audit.md

git commit \-m "feat: 17 recurring yearly products, 3-zone pricing, team tracks, Telegram"

git push origin main

\`\`\`

&nbsp;

\---

&nbsp;

\#\# Definition of Done

\- \[ \] All 17 new product IDs in PRODUCT\_ENTITLEMENTS

\- \[ \] All old pdt\_0No7um IDs removed — grep returns 0

\- \[ \] PRODUCT\_SEATS updated for all 6 team track products

\- \[ \] Telegram email note added for seats \> 1

\- \[ \] Zone 1 — 5 individual tiles with full course lists

\- \[ \] Zone 2 — 3 team cards with seat selector and Telegram line

\- \[ \] Zone 3 — Classroom waitlist \+ Enterprise contact

\- \[ \] License terms block includes cancellation policy

\- \[ \] Team disclaimer explicitly present

\- \[ \] Seat selector JS updates price and href on selection

\- \[ \] No old product IDs anywhere in repo

\- \[ \] All smoke tests pass

\- \[ \] gating-audit.md updated

\- \[ \] Committed and pushed to main

&nbsp;