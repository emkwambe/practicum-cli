-- Manual QA classroom support.
-- A test classroom normally sends nowhere real. qa_mail_to opts one specific
-- test classroom into delivering to a named human address, so invite and
-- sign-in mail can be read end to end without exposing real learners.
-- NULL keeps the existing behaviour: mail goes to the Resend sink.

ALTER TABLE classrooms ADD COLUMN qa_mail_to TEXT;
