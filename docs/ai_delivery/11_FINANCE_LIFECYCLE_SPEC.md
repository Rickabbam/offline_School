# FINANCE LIFECYCLE SPEC

## States
- draft
- confirmed
- posted
- reversed

## Rules
- posted records are immutable
- corrections are reversals/adjustments, not overwrite edits
- receipt issuance is durable and auditable
- offline payment entry is allowed if queueing and reversal rules remain safe
- report calculations must be reproducible from ledger truth

## Required artifacts
- fee categories
- fee structures
- invoices
- payments
- receipts
- reversal entries
- arrears reporting
- finance reports

## Tests required
- post/reverse lifecycle
- offline payment recording
- replay safety
- no double-post
- no silent mutation of posted data
