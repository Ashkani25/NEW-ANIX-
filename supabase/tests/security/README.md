Rolled-back security probes. Each file is a `do $$ ... raise exception 'HARNESS_RESULT %', json $$` block: run it inside
`begin; <optional migration>; <probe>;` and read the JSON from the error; nothing is ever committed.
