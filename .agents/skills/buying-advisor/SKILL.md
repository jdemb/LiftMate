---
name: buying-advisor
description: >
  Research and recommend a specific model of a purchasable item named by the
  user by combining a short buyer interview, current web research, a scored
  comparison, and anti-bias checks before giving a purchase recommendation. Use
  when the user invokes buying-advisor with an item or asks what product,
  device, appliance, tool, accessory, component, gift, or other thing to buy and
  wants help choosing a concrete model instead of generic shopping advice.
  Trigger phrases: "co kupić", "jaki model wybrać", "doradź zakup", "wybierz
  model", "what should I buy", "which model should I choose", "recommend a
  product", "buying advice", "purchase recommendation".
---

# Product Research: Conscious Purchase Decision

This skill produces a **conscious purchase decision**: not a recommendation from
vibes, but one grounded in the item category, the buyer's constraints, current
market data, source-backed model comparisons, and an explicit check for reasons
the top pick might be wrong.

The output is a purchase recommendation in chat: one primary model/configuration
to buy, two alternatives, the tradeoffs, and the exact details to verify before
checkout. No file is written unless the user explicitly asks for a saved report.

Always answer in the user's language.

## When to use, when to skip

**Use when**: the user names something they may buy and wants help selecting a
specific model, version, SKU, or configuration. The skill works for consumer
electronics, appliances, tools, furniture, sports/outdoor gear, components,
accessories, gifts, and similar purchasable things.

**Skip when**: the user already chose a model and only needs setup,
troubleshooting, repair instructions, legal/medical advice, or a non-purchase
explanation of a category. If the request is only price tracking or deal
monitoring, use an automation instead of this skill.

## Non-goals

This skill does **not**:

- Buy the product or place an order.
- Track prices over time unless the user asks for an automation.
- Optimize for affiliate rankings or sponsored roundups.
- Replace professional advice for regulated, medical, legal, safety-critical,
  or installation-sensitive purchases.

## Required inputs

1. The item/category the user wants to buy, supplied in the skill invocation or
   in conversation.
2. `references/question-framework.md` - category-specific interview prompts.
3. `references/source-quality.md` - source hierarchy, freshness rules, and
   confidence labels.

## Initial Response

When this skill is invoked:

1. Extract the item/category from the user request. Examples:
   - `buying-advisor laptop do programowania`
   - `buying-advisor ekspres do kawy`
   - `Use buying-advisor for a robot vacuum`
2. If no item was provided, ask exactly:

```text
What item do you want to buy?
```

3. If an item was provided, do not recommend a model yet. First run a quick
   category scan using web search to identify current model classes, price
   bands, important specs, compatibility constraints, and common failure points.
4. Load `references/question-framework.md` and ask the smallest set of buyer
   questions needed to avoid guessing.

## Workflow

### Step 0 - Setup & category scan

Use current web search. Research the named item/category in the user's likely
market. If the user's market is unknown, infer from conversation/environment
only as a starting assumption and ask the user to confirm it.

Extract:

- Product category and relevant subtypes.
- Current price bands and what changes between them.
- Specs that materially affect the recommendation.
- Compatibility, sizing, installation, maintenance, or safety constraints.
- Common defects, gotchas, subscription traps, or regional variant issues.
- Whether professional reviews, owner reports, or manufacturer specs are likely
  to be decisive for this category.

Echo only the useful context, not a full research dump:

```text
I found that this category mostly splits into <2-4 model classes>. Before I
recommend anything, I need to pin down a few purchase constraints.
```

### Step 1 - Buyer interview

Ask 4-7 questions total for normal purchases. Ask more only for expensive,
technical, personal-fit, safety-sensitive, compatibility-heavy, or regulated
products.

Always cover these decision areas unless already known:

- Market: country/region and preferred stores.
- Budget: target budget, absolute ceiling, currency, new vs used/refurbished.
- Primary use: what the item must do, usage frequency, environment.
- Hard constraints: size, compatibility, platform/ecosystem, installation,
  power, standards, safety, delivery deadline.
- Priorities: the 2-3 tradeoffs that matter most in this category.
- Dealbreakers: brands, subscriptions, noise, weight, materials, maintenance,
  warranty, privacy, return policy, service availability.

Ask the user for all answers before moving to model research. If the user wants
to proceed without answering, continue with explicit assumptions and lower the
confidence rating.

### Step 2 - Product research

After the user answers, restate the buyer brief in 3-6 bullets and research
current models.

Build a candidate pool of 5-8 plausible models when the market has enough
options. For narrow categories, use all credible candidates. Search across
different evidence types:

- Manufacturer pages for exact specs, variants, dimensions, warranty, and
  certifications.
- Retailer pages in the user's market for current price, availability, SKU,
  return policy, and regional variants.
- Independent professional reviews with measurements or repeatable testing.
- Owner reports, specialist forums, and long-term reviews for reliability and
  recurring problems.

For broad categories, split research mentally by source type rather than by
brand: specs/variants, prices/availability, review measurements, owner
reliability. Synthesize only after all source types have been checked.

### Step 3 - Score and shortlist

Apply hard filters first:

- Over budget ceiling.
- Not available in the user's market.
- Fails mandatory compatibility, dimensions, safety, certification, or
  installation requirements.
- Violates a user dealbreaker.
- Unclear seller, warranty, region, or variant for categories where that matters.

Then score surviving models against 5 buyer-specific criteria:

| Model | Requirement fit | Value | Reliability | Usability / ownership cost | Evidence quality | Total |
|---|---|---|---|---|---|---|
| <model> | | | | | | |

Adapt the criteria labels when the category needs it, but keep the same intent:
fit, price/value, durability/reliability, day-to-day ownership, and confidence
in the evidence.

Shortlist three options:

1. Best overall recommendation.
2. Best cheaper or simpler alternative.
3. Best premium, specialized, or risk-reducing alternative.

### Step 4 - Anti-bias cross-check

Before finalizing, stress-test the top recommendation yourself. Do not skip this
even if the top model seems obvious.

Apply three lenses:

**Devil's advocate** - list 3-5 concrete reasons this model may be the wrong
choice for this buyer.

**Pre-mortem** - write a short internal failure story: the user bought this
model and regretted it after weeks/months. Identify which assumptions failed.

**Unknown unknowns** - surface 3-5 non-obvious details the user may not know
before checkout, such as regional SKUs, subscriptions, accessory requirements,
return-policy traps, installation constraints, certification gaps, firmware/app
issues, or consumable costs.

If the cross-check reveals a better recommendation, switch to it and mention
why. If it reveals only manageable risks, keep the top model and include the
risks in "Check before checkout".

### Step 5 - Final recommendation

Use this output shape unless the user asked for a different format:

```text
Recommendation: <specific model/configuration/SKU>
Target price: <current realistic price/range in the user's market>
Confidence: <high | medium | low>

Why this model:
<short rationale tied directly to the user's answers and the scoring>

Compared shortlist:
| Model | Best for | Main tradeoff |
|---|---|---|
| <recommended model> | <fit> | <tradeoff> |
| <alternative 1> | <fit> | <tradeoff> |
| <alternative 2> | <fit> | <tradeoff> |

Buy this if:
- <fit condition>
- <fit condition>

Do not buy it if:
- <clear limitation>

Check before checkout:
- <exact variant/SKU/spec/connector/size/warranty/return-policy detail>
- <known risk or gotcha from anti-bias check>

Sources checked:
- <linked source label>
- <linked source label>
- <linked source label>
```

Keep the recommendation practical. Mention tradeoffs plainly instead of trying
to make every candidate sound good.

## Output

Default output is a chat recommendation with:

- One specific model/configuration/SKU to buy.
- A target price or current price range.
- Confidence level.
- Two alternatives with clear reasons to choose them instead.
- A checkout checklist for exact variant, compatibility, warranty, and return
  policy.
- Source links used for current research.

If the user asks for a file, write a concise Markdown report to the path they
request, or to `purchase-recommendation.md` in the current workspace if no path
is specified.

## References

- `references/question-framework.md` - category-specific buyer interview prompts.
- `references/source-quality.md` - source hierarchy, freshness rules, evidence
  capture, and confidence labels.

## Critical guardrails

1. **Research before recommending.** Never recommend a current product model
   based solely on training-data memory. Prices, stock, model generations, and
   defects change quickly.

2. **Questions before assumptions.** The skill exists to avoid guessing. Ask
   only questions that can change the recommendation, but ask them before
   scoring models.

3. **Exact model over brand family.** Recommend a concrete model, variant, SKU,
   configuration, or size when available. Do not stop at "buy a Bosch" or "get
   a ThinkPad" unless the market evidence only supports category-level advice.

4. **Three candidates, not one.** Always show two alternatives so the user can
   choose a cheaper, premium, safer, or more available option if the top pick is
   blocked.

5. **Anti-bias is mandatory.** Run the devil's advocate, pre-mortem, and unknown
   unknowns checks before finalizing. Include the useful risks in the checkout
   checklist.

6. **Do not invent volatile facts.** Never fabricate prices, stock status,
   warranty terms, release dates, recalls, review conclusions, seller
   reliability, or regional compatibility.

7. **Safety and fit outrank specs.** For safety-sensitive, regulated, medical,
   child, vehicle, electrical, protective, furniture, ergonomic, clothing,
   footwear, bike, mattress, and wearable purchases, prioritize certification,
   fit, measurements, trial/return policy, and professional guidance over
   spec-sheet scoring.

8. **Skill-internal labels stay internal.** When speaking to the user, do not
   mention step numbers or scoring mechanics unless useful. Say "this model is
   ruled out by your size limit" instead of "it failed the hard filter".
