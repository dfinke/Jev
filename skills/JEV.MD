---
name: jev
license: MIT
description: >
  Build AI-powered software with Jev (TypeSafe's System One model). Jev turns
  natural language + application state into typed decisions (Choice, Score, Noul)
  and calibrated probabilities your code consumes directly — no text parsing.
  Use when a feature needs semantic routing, ranking, extraction, verification,
  moderation, or any judgment where an LLM prompt-and-parse step could become a
  structured, typed decision. Code owns the workflow; Jev fills the semantic
  judgment slots. Always read live docs and the closest cookbook before building.
---

# Build with Jev (TypeSafe System One)

## What Jev Is

**Jev** is TypeSafe's System One model. It accepts text input (string, JSON
object, or array) and returns typed decisions + calibrated probability
distributions — not generated text. ~100 ms per request. Code owns control
flow; Jev fills narrow semantic judgment slots where code needs language
understanding.

| | LLM | Jev |
|---|---|---|
| Output | Free-form text | Typed: choice / score / float |
| Control | Prompt → text → parse | Code owns flow; model fills slots |
| Uncertainty | Overconfident | Calibrated (RLCD training) |
| Speed | 500 ms–s | ~100 ms |
| Use | Generate, reason, explain | Classify, rank, verify, route |

**Architecture rule:** AI-powered software (code controls flow, Jev does atomic
semantic judgments) — not LLM agents (model controls flow).

---

## Live Docs — Read Before Building

**The live docs are the source of truth.** This skill gives direction; docs
carry current API contracts, SDK versions, model limits, and worked examples.

Fetch the index first, then targeted pages:
```
https://docs.typesafe.ai/llms.txt          ← start here
```
Mintlify serves Markdown at `<page-url>.md`. Resolve relative links against
`https://docs.typesafe.ai`.

| Task | Read |
|---|---|
| Programming model | [system-one.md](https://docs.typesafe.ai/concepts/system-one.md) · [how-to-build.md](https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md) |
| What to build | [use-case-map.md](https://docs.typesafe.ai/concepts/use-case-map.md) → relevant cookbook |
| Primitives & state | [state.md](https://docs.typesafe.ai/concepts/state.md) · [primitives.md](https://docs.typesafe.ai/primitives.md) |
| Uncertainty handling | [confidence.md](https://docs.typesafe.ai/confidence.md) |
| Python SDK | [sdk/python.md](https://docs.typesafe.ai/sdk/python.md) |
| JavaScript SDK | [sdk/javascript.md](https://docs.typesafe.ai/sdk/javascript.md) |
| HTTP API | [api.md](https://docs.typesafe.ai/api.md) |
| Migration | [migrating-to-v1.md](https://docs.typesafe.ai/migrating-to-v1.md) |

If live access fails: use installed SDK types, state the limitation, do not
invent version-dependent details.

---

## State — The Input

**State** = the content Jev evaluates. Pass in the `state` field alongside
`questions`. All questions in one request see the **same state** and evaluate
**independently**.

| Format | When | Example |
|---|---|---|
| `string` | Single text passage | `"Card charged twice."` |
| `object` | Named fields, related records ← **preferred** | `{"message": "...", "policy": "..."}` |
| `array` | Sequence of messages/records | `["Hi", "Charged twice"]` |

**Rules:**
- Include only context relevant to current questions (avoid context rot)
- Supply current data from your own sources; never rely on model weights for facts
- Use JSON objects with descriptive field names for most requests

**Reference nested fields** in instructions with backtick dot-and-index paths:
```
"Does `ticket.messages[0].text` request a refund?"
"Does `refund_policy` support `ticket.messages[0].text`, given `order.charges`?"
```

Jev accepts text only. No images, audio, or video yet. Primary language:
English (other languages accepted, lower accuracy).

---

## The Three Primitives

Every question: **ID** (code key, never sent to model) + **type** +
**instructions** + **criteria** (required for Choice/Score; optional for Noul).

### Choosing the Right Primitive

```
Answer is one of a fixed unordered set?       → Choice
  (routing, classification, function selection)

Answer falls on a described spectrum?         → Score
  (severity, frustration, quality, skill level)

Yes/no where the probability IS the signal?   → Noul
  (contains PII, requests refund, is urgent)

Multiple conditions may apply simultaneously? → one Noul per condition
  (not Choice — Choice picks exactly one)
```

> **Critical:** Noul 0.5 = equal probability yes/no ≠ medium intensity.
> Use Score when you need to measure degree on a spectrum.

---

### Choice

Picks exactly one option. Returns: `choice` (string key) ·
`probabilities` (dict) · `confidence` (0–1).

```python
Choice(
    instructions="Which team should handle this ticket?",
    criteria={
        "billing":   "Payment, subscription, or invoice issues.",
        "technical": "Bugs, API errors, or integration problems.",
        "sales":     "Pricing, upgrades, or new account questions.",
        "other":     "None of the above.",   # always include a fallback
    },
)
# response.answers["dept"].choice        → "billing"
# response.answers["dept"].probabilities → {"billing": 0.87, "technical": 0.09, ...}
# response.answers["dept"].confidence    → 0.83
```

**Structured criteria** for contrastive disambiguation:
```python
criteria={
    "limits": {
        "what":     "Quantity, transaction, or merchant restrictions",
        "not_for":  "Purpose, eligibility, or setup",
        "examples": ["How many cards per day?", "Where can I use it?"],
    },
    "setup": {
        "what":     "Purpose, eligibility, or setup",
        "not_for":  "Quantity, transaction, or merchant restrictions",
        "examples": ["How do I get a card?", "What are disposable cards for?"],
    },
}
```

---

### Score

Rates content along ordered descriptive levels. Returns: `score` (float, can
fall between levels) · `legend` · `probabilities` (list) · `confidence` (0–1).

```python
Score(
    instructions="How frustrated does the customer appear in `message`?",
    criteria=[
        "Calm — stating facts, no emotional language.",      # level 0
        "Concerned but civil — some frustration, polite.",   # level 1
        "Very angry — strong language, demanding action.",   # level 2
    ],
)
# response.answers["frustration"].score → 1.4  (between levels 1 and 2)
```

**Level rule:** Each level must describe a concrete situation and stand on its
own. Vague labels ("low / medium / high") produce vague scores.

**Normalize to 0–1:** `normalized = answer.score / (num_levels - 1)`

---

### Noul

Returns the probability the statement is true — a single float 0–1. No
separate confidence field; the value itself carries uncertainty.

```python
Noul(instructions="Does `ticket.messages[0].text` request a refund?")
# Optional criteria to clarify yes/no:
Noul(
    instructions="Is this a critical production outage?",
    criteria={
        "yes": "Production is down or data is being lost right now.",
        "no":  "Performance is degraded but service is still running.",
    },
)
# response.answers["refund"].noul → 0.95 (strong yes)
# near 1.0 = strong yes | near 0.5 = uncertain | near 0.0 = strong no
```

**Multiple independent labels → one Noul each:**
```python
questions={
    "has_pii":         Noul(instructions="Does `text` contain personally identifiable information?"),
    "requests_refund": Noul(instructions="Does `text` request a refund?"),
    "is_urgent":       Noul(instructions="Does `text` express time-sensitive urgency?"),
}
# These are independent — using Choice would force exactly one to win
```

---

## Confidence (Choice & Score only)

Derived from probability distribution shape: concentrated on one option → high;
evenly spread → low. Approximate formula (N options):
`confidence ≈ (N × max_probability − 1) / (N − 1)`

**Three-tier behavioral model:**

| Range | Action |
|---|---|
| ≥ 0.8 (high) | Act automatically |
| 0.5–0.8 (medium) | Confirm / flag / gather more info |
| < 0.5 (low) | Route to human / do not act |

**Risk-scaled thresholds** — raise the bar proportional to consequences:
```python
action     = response.answers["action"]
confidence = action.confidence

if confidence < 0.5:
    route_to_human(message)               # genuinely unsure — don't guess

elif action.choice == "check_balance":
    show_balance()                        # low stakes: any conf ≥ 0.5 fine

elif action.choice == "approve_transfer":
    if confidence > 0.9:
        confirm_then_execute()            # high stakes + high confidence
    else:
        ask_user_to_confirm()             # high stakes + moderate confidence
```

**Confidence does NOT mean:** correctness guarantee · permission to act ·
that all low-confidence answers are wrong. Several acceptable alternatives
spread probability — low confidence ≠ wrong answer. Calibrate thresholds on
your own data and consequences, not cookbook examples.

---

## Question Design Rules

| # | Rule |
|---|---|
| 1 | **One narrow judgment per question.** Split independently useful dimensions. |
| 2 | **Write full meaning in `instructions`.** ID is never sent to the model. |
| 3 | **Give enough state.** Source text, identities, relationships, policies, facts. |
| 4 | **Define criteria precisely.** Concrete situations, not vague labels. |
| 5 | **Include a no-match option** in Choice when the list may be incomplete. |
| 6 | **Ask for fast judgments** — what a knowledgeable person decides in one second. "Analyze and determine best action" = slow reasoning; decompose it. |
| 7 | **Use structured instructions/criteria** when strings blur together or criteria need contrastive what/not-for/examples. |
| 8 | **Select, don't generate.** Find candidates in code, ask Jev to select the correct one, normalize in code. |
| 9 | **Keep policy in code.** Thresholds, weights, routing rules — not baked into questions. |
| 10 | **Check candidate coverage.** For selection tasks, the model cannot choose an option that isn't in `criteria`. |

**Decomposition example:**

```python
# ❌ Bad — one broad question hides multiple signals
{"is_spam": Noul(instructions="Is `message` spam?")}

# ✓ Good — each signal is independently inspectable and tunable
{
    "requests_credentials":    Noul(instructions="Does `message.body` ask the recipient for a password or login credential?"),
    "offers_unexpected_reward": Noul(instructions="Does `message.body` claim the recipient received an unexpected prize or payment?"),
    "creates_time_pressure":   Noul(instructions="Does `message.subject` or `message.body` pressure the recipient to act immediately?"),
    "sender_identity_mismatch": Noul(instructions="Does the organization named in `message.sender.display_name` conflict with the domain in `message.sender.email`?"),
    "link_domain_mismatch":    Noul(instructions="Does `message.links[0].url` conflict with the organization in `message.sender.display_name`?"),
}
```

---

## Building a Workflow

**Step-by-step:**
1. **Use code when you can.** Keep deterministic rules, calculations, and exact lookups in code. Avoid Jev where a formula or lookup suffices.
2. **Decompose state.** Include only relevant context. Use JSON objects with descriptive fields. Reference fields in questions via backtick paths.
3. **Decompose questions.** Ask the most explicit, narrow, atomic questions possible. One question = one property to evaluate.
4. **Use structure in questions.** Put code-sourced data into structured `instructions` fields rather than string-templating it.
5. **Ask many questions per request.** Questions run in parallel — adding more barely changes latency. Ask everything you might need plus speculative questions.
6. **Combine in code.** Compose answers with weighted sums, thresholds, and rules. Keep policy in code, not questions.
7. **Route on uncertainty.** Gate high-stakes actions on confidence. Escalate uncertain cases to a human or reasoning model.

**When to make a second request** (exception, not the rule):
- Need the first answer to **fetch new evidence** (e.g. retrieve top-3 documents, then judge them)
- Need the first answer to **construct new state** (e.g. merged text blocks that didn't exist before)
- The first answer **determines the next question's options** (e.g. hierarchical classification)
Otherwise: ask everything in one request and ignore unused answers in code.

---

## Composing Answers in Code

```python
answers = response.answers

# Weighted sum of Noul signals
spam_score = (
    0.30 * answers["requests_credentials"].noul
    + 0.30 * answers["offers_unexpected_reward"].noul
    + 0.20 * answers["creates_time_pressure"].noul
    + 0.20 * answers["sender_identity_mismatch"].noul
)

# Composite Score normalization (3 levels → divide by 2 for 0–1 range)
priority = (
    0.5 * answers["bug_severity"].score         / 2
    + 0.3 * answers["customer_frustration"].score / 2
    + 0.2 * answers["report_quality"].score       / 2
)

# Hard rule overrides weighted score
if answers["policy_violation"].noul > 0.9:
    block()
elif priority > 0.8:
    page_on_call()

# Use probabilities as ML features
features = {
    "severity_p2":  answers["bug_severity"].probabilities[2],
    "frustration":  answers["customer_frustration"].score / 2,
    "billing_noul": answers["billing"].noul,
}
# → feed into CatBoost / XGBoost / sklearn
```

**Access patterns:**

| Primitive | Field | Type |
|---|---|---|
| Noul | `.noul` | float 0–1 |
| Choice | `.choice` · `.probabilities` · `.confidence` | str · dict · float |
| Score | `.score` · `.probabilities` · `.confidence` | float · list · float |

Python shorthand: `response.nouls["q"].noul` · `response.choices["q"].choice` · `response.scores["q"].score`

---

## Architectural Patterns

### Speculative Fan-Out
Ask all questions you might need in one call. Let code decide which answers to
use. 13 questions in one call = **12.2× cheaper, 10× faster** than 13 separate
calls with identical answers.

```python
response = client.system_one(
    state=ticket,
    questions={
        "department":   Choice(instructions="Which team handles this?", criteria={...}),
        "is_urgent":    Noul(instructions="Does this convey urgency?"),
        # Speculative — only consumed if department == "technical"
        "bug_severity": Score(instructions="How severe is the bug?", criteria=[...]),
        # Speculative — only consumed if department == "billing"
        "charge_type":  Choice(instructions="What kind of charge issue?", criteria={...}),
    },
)
dept = response.answers["department"].choice
if dept == "technical":
    severity = response.answers["bug_severity"].score   # use it
elif dept == "billing":
    charge = response.answers["charge_type"].choice     # use it
```

State speculative premises explicitly in the question instructions.

### Confidence-Gated Routing
Use `confidence` as a second axis: the answer tells you *what*; confidence
tells you *whether to act*. Apply risk-scaled thresholds (see Confidence
section above).

### Composite Scoring
Break a complex judgment into atomic Score questions. Combine with weights in
code. Change weights — not questions — when priorities shift. Individual scores
are preserved for display and debugging. Use raw `probabilities` as ML
features.

### Intent Routing
Use a Choice question to classify user intent, then route to the optimal
handler (deterministic code, specialist LLM, or human). Combine with
Speculative Fan-Out to ask branch-specific questions in the same call.

---

## Use-Cases by Category

| Category | Use Case | Primitive |
|---|---|---|
| **Routing** | Ticket → department · Intent detection · Doc type | Choice |
| **Ranking** | RAG reranking · Ticket priority · Resume shortlisting | Score per item |
| **Extraction** | Value extraction · Date parts · Duplicate detection | Choice selects; code normalizes |
| **Verification** | Citation check · Tool-call trace · Policy compliance | Noul per claim |
| **Moderation** | LLM guardrails · Spam detection · Harm severity | Noul per hazard + Score |
| **ML** | Feature discovery · Entity alignment · Hierarchical classification | Score/Noul → probabilities as features |
| **Function calling** | Natural-language → typed function name + args | Choice for name; Choice/Noul for args |

---

## SDKs

### Python — `typesafe-sdk`
```sh
pip install typesafe-sdk    # or: uv add typesafe-sdk
```
Set `TYPESAFE_API_KEY` env var. Source: https://github.com/typesafe-ai/typesafe-sdk-python

```python
from typesafe_sdk import Choice, Noul, Score, TypeSafeClient

with TypeSafeClient() as client:
    response = client.system_one(
        state={"message": "Charged twice. Fix this ASAP."},
        questions={
            "billing": Noul(instructions="Is `message` about a billing issue?"),
            "tone":    Choice(instructions="What is the customer's tone in `message`?",
                              criteria={"calm": None, "frustrated": None, "angry": None}),
            "urgency": Score(instructions="How urgent is `message`?",
                             criteria=["can wait", "this week", "today"]),
        },
    )
response.nouls["billing"].noul          # float
response.choices["tone"].choice         # "calm" | "frustrated" | "angry"
response.scores["urgency"].score        # float
```

Async client: `AsyncTypeSafeClient` with `await client.system_one(...)`.
Override model per call: `client.system_one(..., model="jev-1.13")`.
Full reference: https://docs.typesafe.ai/sdk/python.md

### JavaScript/TypeScript — `@typesafe-ai/sdk`
```sh
npm install @typesafe-ai/sdk    # Node.js 20+; ESM + CJS + TypeScript declarations
```
Set `TYPESAFE_API_KEY` env var. Source: https://github.com/typesafe-ai/typesafe-sdk-js

```ts
import { choice, noul, score, TypeSafeClient } from "@typesafe-ai/sdk";

const client = new TypeSafeClient();
const response = await client.systemOne({
    state: { message: "Charged twice. Fix this ASAP." },
    questions: {
        billing: noul("Is `message` about a billing issue?"),
        tone:    choice("Customer's tone in `message`?", { calm: null, frustrated: null, angry: null }),
        urgency: score("How urgent is `message`?", ["can wait", "this week", "today"]),
    },
});
// Answer types inferred — no casting needed
response.answers.billing.noul      // number
response.answers.tone.choice       // "calm" | "frustrated" | "angry"
response.answers.urgency.score     // number
```

Full reference: https://docs.typesafe.ai/sdk/javascript/api.md

### HTTP API
```
POST https://api.typesafe.ai/v1/systemone
Authorization: Bearer $TYPESAFE_API_KEY
Content-Type: application/json
```
**Never expose API keys in client-side browser code.**

Request body:
```json
{
  "model": "jev-latest",
  "state": "<string | object | array>",
  "questions": {
    "<id>": {
      "type": "noul | choice | score",
      "instructions": "<string | object | array>",
      "criteria": "<object (choice) | array (score) | object optional (noul)>"
    }
  }
}
```
Response: `{ "answers": { "<id>": { "type": "...", "<noul|choice|score>": ..., "probabilities": ..., "confidence": ... } }, "usage": {...} }`

Full reference: https://docs.typesafe.ai/api.md · Models: https://docs.typesafe.ai/models.md

---

## Cookbooks — Read Before Building

| Cookbook | Demonstrates | Key Technique |
|---|---|---|
| [Parallel Questions](https://docs.typesafe.ai/cookbooks/parallel_questions.md) | 13 Qs in 1 call: 12.2× cheaper, 10× faster | Speculative Fan-Out |
| [Function Calling](https://docs.typesafe.ai/cookbooks/function_calling.md) | NL trading → typed function calls | Choice for name + args |
| [Value Extraction](https://docs.typesafe.ai/cookbooks/pre_parsed_value_extraction_cookbook.md) | Regex → Choice selects → code normalizes | Select-don't-generate |
| [Structure Recovery](https://docs.typesafe.ai/cookbooks/autoformat.md) | Reconstruct Markdown in 2 requests | Multi-step, new state from answers |
| [Reranking](https://docs.typesafe.ai/cookbooks/rerank_typesafe.md) | BM25 → Jev reranks → top-1 5%→18% | Score per candidate |
| [Semantic Search](https://docs.typesafe.ai/cookbooks/semantic_find.md) | Score 218 lines against query in 1 req | Choice + Noul |
| [Citation Check](https://docs.typesafe.ai/cookbooks/citation_check.md) | Verify quotes; flag uncertain | Choice + Confidence |
| [LLM Guardrails](https://docs.typesafe.ai/cookbooks/llm_guardrails.md) | Screen I/O for hazards; block/review | Noul + Score per hazard |
| [RAG Passage Classifier](https://docs.typesafe.ai/cookbooks/classifying_rag_passages.md) | Filter contradictions/injections | Score per passage |
| [SDE Cascade](https://docs.typesafe.ai/cookbooks/sde_cascade.md) | Mini → verify → reasoning fallback | Multi-stage cascade |
| [Date Extraction](https://docs.typesafe.ai/cookbooks/date_extraction_cookbook.md) | Extract + resolve dates in code | Choice for parts |
| [Self-Consistency Noul](https://docs.typesafe.ai/cookbooks/consistency_noul_cookbook.md) | Route uncertain to human review | Noul + thresholds |
| [Self-Consistency Choice](https://docs.typesafe.ai/cookbooks/consistency_choice_cookbook.md) | Label agreement vs automatic rate | Choice + agreement |
| [Hierarchical Classification](https://docs.typesafe.ai/cookbooks/hierarchical_classification.md) | Deep taxonomies via beam search | Sequential Choice |
| [Skill Suggestion](https://docs.typesafe.ai/cookbooks/skill_suggestion.md) | Rank 182 skills → fetch top 3 → judge | Two-request pattern |
| [Entity Alignment](https://docs.typesafe.ai/cookbooks/entity_alignment.md) | 450 pairs: merge/leave/review | Score with action levels |
| [AutoResearch Features](https://docs.typesafe.ai/cookbooks/autoresearch_feature_discovery.md) | Propose Qs → text → CatBoost | Score/Noul as ML features |
| [Classification via Confidence](https://docs.typesafe.ai/cookbooks/classification_using_confidence.md) | 75 groups; confidence → broader fallback | Choice + Confidence hierarchy |

---

## Testing & Debugging

- Test representative cases and resulting **application behavior** (not just model answers)
- For failures, inspect: exact state → questions → candidates → answers → composition → observed outcome
- Separate: missing evidence / model errors / code errors / service failures
- Cookbook thresholds and demo results are **examples to evaluate**, not universal rules or permanent model limits
- Typed output guarantees the interface contract, not truth — validate model performance in your target domain
- Keep API credentials server-side; never expose in web client code
