# Decoding Decision Signals in Anti-Spot Skincare
### A Consumer Insights Analysis of 653,867 Sephora Reviews

---

## TL;DR

When consumers buy anti-spot skincare, what do they actually say drove their decision? I filtered 1.09M Sephora reviews down to 653,867 anti-spot reviews, built a 5-category signal taxonomy (ingredient, authority, price, result, brand), and extracted signals using keyword + regex pattern matching. The most actionable finding: price-motivated buyers have the lowest recommendation rate (78%) while authority-influenced buyers have the highest (93%) — meaning brands that compete on price in this category are likely attracting the wrong customer.

---

## Why This Question

The anti-spot and brightening category is one of the fastest-growing segments in skincare, driven by consumer demand for ingredients like niacinamide, vitamin C, and tranexamic acid. But "what makes someone buy" is rarely captured cleanly in structured data.

Review text is messy, informal, and underused. Most analyses stop at star ratings and sentiment polarity. This project goes one level deeper: instead of asking *how satisfied* consumers were, it asks *why they bought in the first place* — and whether that purchase motivation predicts satisfaction.

For a beauty brand's consumer insights or product team, that's the difference between knowing a product underperformed and knowing *which customer segment* bought it for the wrong reasons.

---

## Data

**Source:** [Sephora Product and Skincare Reviews](https://www.kaggle.com/datasets/nadyinky/sephora-products-and-skincare-reviews) (Kaggle)

| | Raw Dataset | Anti-Spot Subset |
|---|---|---|
| Products | 8,494 | 1,979 |
| Reviews | 1,094,411 | 653,867 |

**Filter logic (two-layer):**

Products were included if they matched *either* condition:
1. `tertiary_category` IN: Face Serums, Anti-Aging, Facial Peels, Blemish & Acne Treatments, Exfoliators, Toners, Eye Creams & Treatments, Face Masks, Face Oils, Face Sunscreen, and related categories
2. `ingredients` field contains any of: niacinamide, vitamin c, tranexamic acid, arbutin, kojic acid, azelaic acid, hydroquinone, retinol, ferulic acid, glycolic acid, lactic acid

The two-layer approach avoids both false negatives (anti-spot serums miscategorized as generic "Treatments") and false positives (relying on category alone without ingredient validation).

---

## Method

**5 Decision Signal Categories**

| Signal | What it captures | Example keywords |
|---|---|---|
| Ingredient | Mentions a specific active ingredient | niacinamide, retinol, vitamin c, glycolic acid |
| Authority | Influenced by expert or social media | dermatologist, instagram, tiktok, sponsored, gifted |
| Price | Price was a factor in the decision | affordable, dupe, worth the price, budget |
| Result | Outcome-focused purchase rationale | saw results, spots faded, actually works |
| Brand | Brand loyalty or trust | love this brand, never disappoints, loyal to |

Each review was tagged with binary flags (0/1) for all five signals. A single review can trigger multiple signals.

**Why keyword matching, not deep NLP:**

Dependency parsing (e.g., spaCy) to extract "I bought this because [reason]" sounds cleaner in theory. In practice, review language is too informal — incomplete sentences, run-ons, and mixed motivations make dependency parsing accuracy drop below 60% on this type of text. Keyword matching runs in minutes on 650K rows and is explainable end-to-end. The tradeoff is acknowledged in the limitations section below.

---

## Key Findings

**1. Anti-spot is an ingredient-driven category — brand loyalty barely registers**

Ingredient signal had the highest mention rate (7.4%), while brand signal was the lowest (0.3%). Consumers in this category research what's *in* the product, not who makes it. For brands, this means ingredient transparency and formulation credibility matter more than brand equity alone.

**2. How you buy predicts how satisfied you'll be**

| Primary Driver | Avg Rating | Recommend Rate | Review Count |
|---|---|---|---|
| authority_influenced | 4.59 | 93% | 34,600 |
| result_focused | 4.53 | 91% | 17,598 |
| brand_driven | 4.46 | 87% | 1,777 |
| ingredient_driven | 4.40 | 87% | 42,461 |
| mixed_or_none | 4.26 | 84% | 523,548 |
| price_motivated | 4.15 | 78% | 33,883 |

Price-motivated buyers are 15 percentage points less likely to recommend the product than authority-influenced buyers. This is the clearest signal for brands: discounting and dupe-positioning in anti-spot may generate sales but erodes satisfaction and word-of-mouth.

**3. Dry skin users lean on authority; oily skin users lean on ingredients**

Dry skin users had the highest authority signal rate (2.52%) while oily skin users had the highest ingredient signal rate (7.95%). This suggests dry skin consumers are more uncertain about what works for their skin type and rely more on external validation, while oily skin consumers tend to arrive with more product knowledge.

**4. Retinol and niacinamide lead on satisfaction; vitamin C has a reputation gap**

| Ingredient | Avg Rating | Recommend Rate | Mention Count |
|---|---|---|---|
| retinol | 4.49 | 90% | 15,363 |
| niacinamide | 4.48 | 90% | 5,267 |
| glycolic_acid | 4.40 | 87% | 3,281 |
| vitamin_c | 4.37 | 86% | 13,213 |
| tranexamic_acid | 4.21 | 86% | 92 |

Vitamin C has the second-highest mention count but ranks fourth on satisfaction — suggesting high consumer interest paired with inconsistent results, likely due to formulation sensitivity (oxidation, pH instability) rather than the ingredient itself.

---

## Dashboard

**[View Interactive Dashboard on Tableau Public](https://public.tableau.com/views/Sephora_Satisfaction_Signall/Dashboard12)**

Four views:
- **Driver Satisfaction** — Recommend rate by primary purchase driver
- **Ingredient Satisfaction** — Avg rating and mention count by key ingredient
- **Signal by Skin Type** — Heatmap of 5 signals × 4 skin types
- **Signal Overall** — Overall mention rate across all 5 signals

---

## Implications for Beauty Brands

1. **Lead with ingredients in anti-spot marketing.** Consumers in this category are doing ingredient research before they buy. Brands that clearly communicate formulation rationale convert better-informed buyers — who also tend to be more satisfied.

2. **Price promotions carry a satisfaction risk.** The data shows price-motivated buyers are the least satisfied segment. Competing on price in anti-spot may hurt brand perception long-term.

3. **Dry skin is an underserved education opportunity.** This segment relies on authority signals more than others, suggesting they're less confident in ingredient navigation. Educational content, dermatologist partnerships, and clearer product guidance could increase both conversion and satisfaction.

4. **Vitamin C needs expectation management.** High mention count with lower-than-expected satisfaction points to a gap between marketing promise and consumer experience. Brands should address formulation stability and application guidance more explicitly.

---

## Limitations & Honesty

**Keyword matching has a ceiling.** 82% of reviews were classified as "mixed or none" — not because they had no purchase driver, but because consumers don't always use explicit signal language. A review saying "my skin finally cleared up" captures result motivation, but won't trigger the keyword. A sentence embedding or fine-tuned classifier would catch these cases; keyword matching doesn't.

**This is post-purchase narrative, not pre-purchase decision tracking.** Reviews are written after the fact, often weeks or months later. What consumers say drove their decision may be influenced by whether the product worked, introducing recall bias.

**Authority signal expanded mid-analysis.** Instagram and sponsored/gifted language were added after the initial extraction when the authority count appeared understated. This is documented honestly — the final signal counts reflect the updated keyword list.

**Tranexamic acid sample is too small to trust.** 92 mentions is not a reliable basis for ranking. Treat that row as directional at best.

**No demographic controls.** Age, geography, and income are not in this dataset. Purchase driver patterns by skin type may be confounded by demographics we can't observe.

---

## Tech Stack

- **PostgreSQL** — Data ingestion (COPY), working table creation (CREATE TABLE AS SELECT), cross-tab aggregation (GROUP BY, CTE, window functions)
- **Python / pandas** — Data cleaning, keyword + regex signal extraction, signal validation
- **Tableau Public** — 4-view interactive dashboard
- **SQL highlights** — `RANK() OVER`, `CASE WHEN`, `LEFT JOIN`, `AVG()` on binary columns, `ILIKE` pattern matching

---

## File Structure

```
skincare-sentiment-analysis/
├── data/
│   ├── raw/                  # Original Kaggle CSVs (not committed, too large)
│   ├── clean/                # Pandas-cleaned review CSVs
│   └── output/               # Aggregated CSVs for Tableau
│       ├── signal_overall.csv
│       ├── signal_by_skintype.csv
│       ├── ingredient_satisfaction.csv
│       └── driver_satisfaction.csv
├── notebooks/
│   └── 02_decision_signals.ipynb   # Signal extraction pipeline
├── sql/                      # Core SQL queries (coming soon)
└── README.md
```

---

## Data Note

Raw CSV files are not committed due to file size. The cleaned and aggregated outputs in `data/output/` are sufficient to reproduce the Tableau dashboard. Full pipeline documented in `notebooks/02_decision_signals.ipynb`.
