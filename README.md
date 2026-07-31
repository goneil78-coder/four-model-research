# four-model-research

Ask one research question to four different models — Claude, GPT, Gemini and
Grok — in parallel, then merge their answers into a sourced report that is
honest about which models actually agreed.

Built for [Claude Code](https://claude.com/claude-code). Adds one command:
`/conduct-research <question>`. Lane agents run on Opus.

## Design principle: a lane that fails says so

Multi-model setups fail quietly. A model ID gets retired, a key expires, a CLI
changes its flags — and an agent wrapping that call will often paper over the
error and answer from its own knowledge instead. The report still looks normal.
It just isn't four models any more.

That is dangerous precisely because it is invisible in the output. Agreement
between lanes gets used as a confidence signal, so a silently substituted lane
inflates confidence in exactly the findings you should trust least.

So every lane here is built to fail loudly:

- `preflight.sh` tests all four lanes before a run and exits non-zero if any is down
- each agent is told that a missing lane is a correct result and a substituted lane is a corrupted one
- the report header states the convergence basis as "N of 4"
- no finding is marked corroborated by a lane that did not return

Lane independence is testable, so test it. On a sample question the three
external lanes returned nine sources with zero domain overlap.

## The four lanes

| Lane | Model | Mechanism | Needs |
|---|---|---|---|
| claude | Claude | native WebSearch | nothing |
| openai | GPT | `codex exec` with web search | `codex login` |
| gemini | Gemini 3.1 Pro | `gemini` CLI, Search grounding | `GEMINI_API_KEY` |
| grok | Grok 4.5 | xAI Agent Tools API | `XAI_API_KEY` |

The **openai lane runs on a ChatGPT subscription** via the codex CLI, so it
needs no API key. Set `OPENAI_API_KEY` only if you'd rather bill the API.

Grok's lane is the only one with `x_search`, so it's the only one that can see
X/Twitter — live practitioner reaction and dissent that hasn't reached articles
yet. Its single-lane findings get their own section in the report.

## Setup

```bash
git clone https://github.com/goneil78-coder/four-model-research.git && cd four-model-research

npm i -g @google/gemini-cli @openai/codex   # if you don't have them
codex login                                  # ChatGPT subscription auth

cp .env.example .env                         # add XAI_API_KEY, GEMINI_API_KEY
cp config.example.sh config.sh               # optional: models, RESEARCH_DIR

./bin/preflight.sh                           # confirm the lanes are live
./install.sh                                 # into ~/.claude
```

Then in Claude Code: `/conduct-research does spaced repetition work for adult learners?`

`jq`, `curl` and `bash` are assumed. Keys are read from the first of
`$FOUR_MODEL_ENV`, `./.env`, `~/.four-model-research.env`, `~/.claude/.env`.

## Using a lane on its own

Each lane is a standalone script — useful for scripting, or for checking one
model without spending the other three.

```bash
./bin/ask-grok.sh   "What are people on X saying about AI grading?"
./bin/ask-gemini.sh "Primary sources on the 2026 Oxfam inequality report"
./bin/ask-openai.sh "Peer-reviewed work on AI detector false positives"
```

Exit codes: `0` ok, `3` not configured, `4` API/CLI error, `5` empty response.
Findings go to stdout, diagnostics to stderr.

## Company research

`/conduct-research` has a company mode for questions about a specific named
business: ground the legal entity from the registry first, then put the business
question to the four lanes. See the Company mode section of
`commands/conduct-research.md` and `docs/company-registries.md` for
jurisdiction-by-jurisdiction sources (Hong Kong is covered in detail).

`bin/company-domains.sh <domain>` enumerates domains and subdomains via
certificate transparency, subfinder and assetfinder, probes them with httpx, and
reports which techniques ran versus were skipped. It needs Go 1.24+ tools on
PATH at `~/go/bin`; it degrades and says so if they are missing.

## Verifying what comes back

Research models hallucinate plausible URLs, and a dead link reads as evidence
when it isn't. Every lane checks its own citations before returning, and the
merge step re-checks the combined set:

```bash
./bin/verify-urls.sh report.md        # or pipe URLs on stdin
```

It resolves each URL in parallel and separates three cases: live, **blocked**
(401/403/429 — a paywall or bot-check, so the source may well be real but was
not read), and **dead** (404/000 — remove it). Run against a real report it
routinely finds one or two institutional pages that have moved since the lane
cited them.

Findings also carry a per-claim confidence tag, kept deliberately separate from
lane count:

- `HIGH` — two independent sources, or one official primary source
- `MED` — one credible source
- `LOW` — inferred, or the lane itself flagged it as uncertain

Three lanes citing the same single article is `MED`, not `HIGH`. Lane agreement
is not source independence.

## Sentiment questions get routed differently

For "what did people think of X" style questions, four web-search lanes are the
wrong instrument — that discussion lives in communities, not articles. The
command detects those and repoints one lane at the Reddit API, keeping the other
three. In practice Reddit carries more substance than X on niche topics, which
is a thing the grok lane reports honestly when its `x_search` comes back empty.

## Cost

The claude lane is included in Claude Code. The openai lane is covered by a
ChatGPT subscription. Gemini and Grok bill per call — a four-lane run on one
question is typically a few cents, mostly Grok. There is no fan-out beyond the
four lanes, so cost per question is bounded and predictable.

## Keeping it current

Model IDs age fast, and a stale ID is exactly the failure this repo exists to
prevent. When a lane starts failing, check `config.example.sh` first — every
model ID lives there. `preflight.sh` tells you which lane broke and why.

## Licence

MIT.
