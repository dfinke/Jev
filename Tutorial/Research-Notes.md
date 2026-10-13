# Research notes for the PowerShell Jev tutorial

These links informed the tutorial's teaching approach and examples. The aim is
to show Jev as a typed decision step that fits ordinary PowerShell pipelines,
then keep thresholds, routing, policy, and side effects in PowerShell.

## Closest Jev and ThinkThen references

- [ThinkThen tutorial](https://thinkthen.dev/learn/tutorial/) — a guided
  introduction to decision primitives such as `decide`, `filter`, `find`, and
  annotation. It helped shape the tutorial's progression from one decision to
  composable pipeline operations.
- [Introducing ThinkThen](https://thinkthen.dev/blog/introducing-thinkthen/)
  — explains the shell-first interaction style and small, composable commands.
- [ThinkThen demos](https://github.com/botassembly/thinkthen/tree/main/demos)
  — source examples ported into some of the PowerShell demo material.
- [ThinkThen demo index](https://github.com/botassembly/thinkthen/blob/main/demos/README.md)
  — useful model for organizing a catalog of short, runnable demonstrations.
- [ThinkThen: competitors and the field](https://thinkthen.dev/learn/beatles-bench/competitors/)
  — broader context on adjacent tools and approaches.
- [Jev cookbook](https://github.com/chr-kelly/jev-cookbook) — community recipes
  and evaluation examples.
- [Awesome Jev](https://github.com/kydlikebtc/awesome-jev/wiki) — community
  index of Jev-related material.

## Step-by-step tutorials and integrations

- [DataCamp: Jev API tutorial](https://www.datacamp.com/tutorial/jev-api-tutorial)
  — support-ticket routing, question types, and practical limitations.
- [OpenRouter: Jev tutorial](https://openrouter.ai/docs/guides/community/jev-tutorial)
  — an alternate provider path and quick-start structure.
- [Vercel Academy: Make decisions with Jev](https://vercel.com/academy/make-decisions-with-jev/run-the-template.md)
  — a small contact-routing walkthrough.
- [Vercel AI Gateway decision quickstart](https://vercel.com/docs/ai-gateway/getting-started/decision)
  — a concise decision-model getting-started example.
- [A Hands-On Guide to Jev](https://levelup.gitconnected.com/a-hands-on-guide-to-jev-69771edd027a)
  — beginner-oriented framing around choosing a decision with a clear outcome.
- [Dan Vega: Jev Spring Boot starter](https://www.danvega.dev/blog/jev-spring-boot-starter)
  — a Java ecosystem example of integrating Jev into an application.
- [DSPy: Decision-making with Jev types](https://dspy.ai/current/tutorials/jev_decisions/)
  — shows `Noul`, `Score`, and `Choice` inside a programming framework, including
  confidence and boundary calibration.

## Local and alternative runtimes

- [Ollama: Jev-style decision models](https://ollama.com/blog/ollama-now-supports-jev-style-decision-models)
  — local inference using decision-shaped outputs.
- [Pydantic AI: System One API](https://pydantic.dev/docs/ai/models/system-one/)
  — an integration example for structured decisions in a Python framework.
- [Ollaya walkthrough](https://www.scriptbyai.com/ollaya-jev-model-local/)
  — community walkthrough of a local runtime for decision models.

## Related semantic data operations

These are adjacent patterns rather than Jev-specific tutorials. They show how
semantic classification, filtering, and ranking can be presented as familiar
data operations.

- [llm-classify](https://pypi.org/project/llm-classify/) — shell-oriented
  semantic classification and filtering.
- [LOTUS semantic operators](https://lotus-ai.readthedocs.io/en/latest/core_concepts.html)
  — dataframe-style semantic filtering and top-k selection.
- [BigQuery AI.CLASSIFY](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/bigqueryml-syntax-ai-classify)
  — classification exposed through SQL.
- [BigQuery AI functions for SQL](https://cloud.google.com/blog/products/data-analytics/sql-reimagined-for-the-ai-era-with-bigquery-ai-functions)
  — examples of natural-language classification, scoring, and filtering in
  analytics workflows.

## Teaching takeaways

1. Start with one piece of state, one yes-or-no question, and a Boolean result.
2. Grow the same idea into streams, filtering, finding, ranking, annotation,
   scoring, and overlapping tags.
3. Keep a clear boundary: Jev interprets meaning; PowerShell applies thresholds,
   routing, approvals, and actions.
4. Prefer short, runnable examples with visible input and output. Save larger
   multi-file scenarios for workshops or deeper lessons.
5. Show where confidence matters and where human review or local policy should
   take over; a typed answer is useful structure, not a guarantee of correctness.

Links and product documentation can change; revisit them before using this
research as a live presentation reference.
