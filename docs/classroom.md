# Practicum Classroom — instructor guide

A Classroom license gives you 30 learner seats and 2 instructor seats for a
12-month term, with the full catalog and all Practicum Labs for everyone on
the roster.

## Signing in

The dashboard is at **practicum-cli.dev/dashboard/**. There is no password:
enter the email address your Classroom license was issued to and we send a
sign-in link. The link works once and expires after 15 minutes, and it only
works for an instructor on an active classroom.

We deliberately don't sign you in with a license key. Keys get pasted into
terminals and shared screens, and this dashboard shows your learners' names,
email addresses and progress.

## Inviting learners

Invite one at a time from the roster, or import a CSV of up to 100 rows with
`email,display_name` (a header row is optional — download the template from the
dashboard). Each learner gets an email with their own license key and the
three steps to install Practicum, activate it, and start the course.

Rows are handled independently: a bad address in your CSV is reported on its
own row and never blocks the good ones. The results table tells you exactly
what happened to each: invited, already on the roster, not a valid email, or no
seats left.

If an invite email fails to send, **the seat is still yours** — the roster shows
an "Email failed" badge and you can use **Resend** to try again. We never lose a
seat because a mail server was briefly unhappy.

## Resending and revoking

**Resend** issues a brand-new key and emails it. The learner's previous key
stops working. Use it when someone deletes the email or the invite bounced.

**Revoke** removes a learner from the classroom and frees the seat for someone
else. Their key stops working.

### How quickly a revoked key stops working

Not instantly, but quickly: plan for **within about an hour**.

Two things are in the way:

1. **Propagation (seconds to about a minute).** License data is replicated
   around the world so the CLI is fast everywhere. A revocation takes a short
   while to reach every location.
2. **The learner's cached license (up to one hour).** The CLI remembers a valid
   license so learners can keep working on a train, on hotel wifi, or in a lab
   with no internet. Classroom seats re-check every hour; a personal licence
   bought directly is cached for a day, since nobody can revoke it out from
   under the owner.

So a learner who is working offline may keep opening lessons for up to an hour
after you revoke them. The seat is freed for re-use immediately — it is only
their existing copy that lags.

If you need access stopped sooner than that, revoke the seat and tell the
learner; running `practicum license` refreshes their license on the spot and
they will see that their seat was removed.

When it does take effect, the learner sees:

```
Your classroom seat was removed. Contact your instructor.
```

## What your learners type

Three commands cover everything a learner needs. All three are also in the menu
`./practicum start` opens, under **Your classroom**, so nobody has to remember
them:

| Command | Does |
|---|---|
| `./practicum start` | Open the course menu and work through lessons |
| `./practicum assignments` | What you set, each marked with their own status, overdue flagged |
| `./practicum community` | The class group link, if you have set one |
| `./practicum sharing` | Whether progress sharing is on, and turn it on or off |
| `./practicum license` | Their key's status and expiry |

The classroom entries only appear for a classroom license — someone who bought
a course themselves never sees them.

## What your learners see

Learners clone the repo, run `./practicum activate <key>` (or
`PRACTICUM_KEY=... ./practicum activate` on a shared machine), and get the full
catalog for the length of your license term.

The first time a classroom key is activated, the CLI tells the learner plainly
that their lesson and lab progress is shared with their instructor, and asks
them to acknowledge it before anything is sent. Nothing is reported before that
acknowledgement, and solo (non-classroom) licenses never report progress at all.

## Your Telegram group

If you set a Telegram invite link on the classroom, it is included in every
invite email, and learners can print it any time with `practicum community`.
You manage the group yourself — we only distribute the link, and only to people
who hold a seat.

## License term

Your license runs for 12 months from purchase and does not auto-renew. New
courses, lessons and labs added during that period are included. If you cancel,
access continues to the end of the term; there are no prorated refunds for
unused months.

## Reusing seats

> The three sections below take effect when the Classroom tier goes on sale.
> They are published now so that a privacy or procurement review can read them
> before you buy. Until the tier is live they describe intent, not behaviour
> that is already running.

A seat is not tied to one person for the whole year. Revoke a learner and the
seat is free for someone else immediately, so a 30-seat license can carry a
class in the autumn and a different class in the spring.

There is a limit, because a license for one classroom should not quietly become
a license for a whole institution. We count the number of **distinct people**
who have held a seat during your 12-month term, not the number of seats:

| Distinct people this term | What happens |
|---|---|
| Up to 44 | Nothing; invite as normal |
| 45 | The dashboard warns you that you are approaching the limit |
| 60 | Further invitations are blocked, with a message pointing you at support |

Two terms of a 30-seat class fit comfortably. Three full turnovers do not, and
at that point the honest answer is that you need a second license or a site
agreement — email practicum@mpingo.ai and we will sort it out rather than let
you hit a wall mid-term. Re-inviting someone who already held a seat does not
count twice; the count is of people, not invitations.

## When your license ends

If you let the term lapse or cancel, nothing is deleted on the last day.

**Your learners** lose access to the paid courses. Their keys stop unlocking
lessons and labs, and they see a message telling them their classroom license
has ended.

**You keep the dashboard for 90 days**, read-only. You can still see the roster
and the progress matrix, and you can still export CSV — so a term that ends in
June can still be reported on in September. You cannot invite, revoke, or set
assignments, because there is no live classroom to do it to.

Renewing within those 90 days restores everything exactly as it was.

## What we keep, and for how long

**For 90 days after your license ends**, your classroom stays as described
above: names, email addresses and progress all intact, so you can export what
you need.

**After 90 days we anonymize it.** Learner names and email addresses are
deleted. What remains is aggregate progress — how many people completed a
lesson or passed a lab — with nothing that identifies who they were. This is
what lets us understand how the courses are used without holding onto a class
list from years ago. It cannot be reversed, and it cannot be un-anonymized on
request afterwards, so export anything you need before the 90 days are up.

**Deletion on request is honoured within 30 days.** You, or a learner directly,
can ask us to delete their data at any time — during the term or after it —
and we will do it within 30 days and confirm when it is done. Write to
practicum@mpingo.ai. A learner does not need to go through you to ask.

If your institution needs a different retention window, a data processing
agreement, or answers for a privacy review, email practicum@mpingo.ai. We would
rather have that conversation before you buy than after.

## Getting help

practicum@mpingo.ai
