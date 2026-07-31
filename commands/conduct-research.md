---
description: Research a question across four independent models and save a sourced report
---

Research the question that follows this command, using four independent models,
and save a report.

## 1. Preflight — before anything else

```bash
__REPO__/bin/preflight.sh
```

Record which lanes are LIVE and which are DOWN. This determines what the report
is allowed to claim. Do not skip it, and do not assume yesterday's result.

## 1b. Source routing — check before you launch

Scan the question for sentiment signals: "what did people think", "reactions to",
"best / worst / favourite", "reviews of", "consensus on", or an event plus a
recent date.

**If a signal fires**, the four web-search lanes are the wrong instrument —
sentiment lives in communities, not articles. Keep three lanes and repoint the
fourth at community APIs. Reddit first, since it consistently carries more
substance than X on niche topics:

```bash
curl -s -A "four-model-research/1.0" \
  "https://www.reddit.com/r/<subreddit>/search.json?q=<query>&restrict_sr=1&sort=relevance&limit=25" \
  | jq -r '.data.children[].data | "\(.score)\t\(.permalink)\t\(.title)"'
```

Return verbatim quotes with thread URLs and scores. The grok lane's `x_search`
covers X; do not duplicate it here.

**If no signal fires**, launch the four lanes unchanged.

## 2. Launch all four lanes in parallel

First make a run directory:

```bash
RUN="${RESEARCH_DIR:-$HOME/research}/.lanes/$(date +%Y-%m-%d)_<topic-slug>"; mkdir -p "$RUN"; echo "$RUN"
```

One message, four agent calls: `claude-researcher`, `openai-researcher`,
`gemini-researcher`, `grok-researcher`. Give each the same question, verbatim,
and give each the run directory:

> Write your full report to `<RUN>/<lane>.md` and reply with the receipt only.

Each lane returns roughly seven lines. **Read the four files to merge.** Never
ask a lane to paste its findings into the reply — four raw lane reports in the
transcript is thousands of words the human has to read before your merge, and
they will read it all twice.

Launch a lane even if preflight marked it DOWN — a lane that reports its own
failure is more useful than one you silently dropped.

## 3. Merge — the rule that matters

A finding is **corroborated** only by lanes that returned `STATUS: OK` and
actually cited it. Never count a lane that failed, never count a lane that
returned nothing, and never infer that a silent lane would have agreed.

If fewer than four lanes returned, say so in the report header and state the
convergence basis as "N of 4". Do not describe partial results as
"cross-model consensus".

Contradictions are findings. When lanes disagree, report the disagreement and
who said what — do not average it into a smooth summary.

## 3b. Verify the URLs before you write

Lanes hallucinate plausible URLs. A dead link reads as evidence and is not.

```bash
__REPO__/bin/verify-urls.sh <file-or-stdin-with-the-merged-findings>
```

- `404`/`000` — remove from Findings. If a finding rested on it, move it to Gaps
  and say the source could not be verified.
- `401`/`403`/`429` — usually a paywall or bot-check, not a dead page. Keep it,
  mark it `access-restricted`, and say plainly that it was not read.

Do this before writing the report, not after.

## 4. Write the report

Path: `$RESEARCH_DIR/YYYY-MM/YYYY-MM-DD_topic-slug.md`
(`RESEARCH_DIR` defaults to `~/research` — see config.example.sh)

```markdown
# Research: <topic>

**Date:** YYYY-MM-DD
**Question:** <verbatim>

## Lane status

| Lane | Model | Status |
|---|---|---|
| claude | Claude (WebSearch) | OK |
| openai | GPT (codex CLI) | OK |
| gemini | Gemini 3.1 Pro | OK |
| grok | Grok 4.5 (+ x_search) | FAILED — <error> |

**Convergence basis: N of 4 lanes.**

## Findings

| Conf | Finding | Source | Confirmed by |
|---|---|---|---|
| HIGH | <claim> | <URL, date> | claude, gemini |

Confidence is per claim and separate from lane count. `HIGH` needs two
independent sources or one official primary source (registry, regulator,
statutory filing). `MED` is one credible source. `LOW` is inferred or
lane-flagged as uncertain. A claim confirmed by three lanes all citing the same
single article is `MED`, not `HIGH` — lane agreement is not source independence.

## Disagreements

- <claim> — claude says X [URL]; grok says Y [URL]. Unresolved.

## Single-lane findings

Reported by one lane only. Not corroborated — treat as leads.

- <finding> — grok only, via x_search [URL]

## Sources

<deduplicated, with the lanes that surfaced each>

## Gaps

<what no lane could answer>
```

## 5. Report back

Give the headline findings, the file path, and the lane status line. If any lane
failed, say so in your first two sentences — not in a footnote.

## Notes

- Findings without a URL do not go in the Findings table. They go in Gaps,
  marked unsourced.
- `grok` is the only lane that can see X. Its single-lane findings are often
  the most interesting thing in the report — surface them, flagged as
  uncorroborated.

---

## Company mode — when the question names a specific company

A named company needs one extra step before the lanes run, and one rule about
what the lanes are for.

### First: ground the entity

Two unrelated businesses often share a trading name across jurisdictions. Four
lanes researching the wrong one produce four confident wrong answers. Before launching, establish the **legal entity name and jurisdiction**:

```bash
__REPO__/bin/company-domains.sh <their-domain>
```

and check the registry for the jurisdiction — see `docs/company-registries.md`
(Hong Kong, mainland China, UK, US, and global identifiers, with what each
costs and what is blocked).

Put the confirmed legal name into the question you give the lanes.
"Northwind Foods (HK) Limited, CR 1234567, the Hong Kong bakery chain" beats
"Northwind" — and stops a lane drifting onto a same-named firm elsewhere.

### Then: ask the lanes the business question, not the record question

The registry answers *is this entity real, current, and structured how*. It
cannot answer how a company is doing. A Hong Kong private company files a
one-page annual return with no accounts; there is no trading performance in the
registry to find.

Send the lanes the questions the record cannot answer: trajectory and store
count over time, funding or backing, franchise versus owned expansion, press
and reviews, hiring patterns and staff turnover, what employees and customers
say, who the competitors are, and what has gone wrong publicly.

### Report

Same template, plus a short **Corporate record** section above Findings holding
the registry facts, with the source and date for each and an explicit note of
what was not checked because it costs money or was unreachable.

Keep the two separated in the report. Registry facts are single-sourced and
authoritative. Lane findings are corroborated by count. Do not blend them into
one confidence level.
