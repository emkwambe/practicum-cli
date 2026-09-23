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

## Getting help

practicum@mpingo.ai
