# New Website Build — Project Brief & Rate Card (Estimator Test File)

**Purpose of this file:** feed this into DAI Flash / Druta Extension's estimator
and check whether the amount it calculates matches the manual calculation at
the bottom. Edit the hours/rates/percentages below to match your real numbers
before testing.

## 1. Project Overview

- **Project type:** Business/company website — multi-page, with CMS (admin
  panel to edit content), contact form, blog section, and basic SEO setup.
- **Tech assumption:** Next.js/React frontend + a lightweight backend/CMS +
  database (adjust if your real stack differs).
- **Optional add-on included below:** online payment gateway integration
  (Razorpay/Stripe) — mark this in/out depending on whether the site needs
  e-commerce/payments.

## 2. Scope of Work — Task Breakdown

| # | Task | Phase | Est. Hours | Rate/hr (₹) | Task Cost (₹) |
|---|------|-------|-----------:|------------:|---------------:|
| 1 | Requirement gathering & planning | Planning | 4 | 600 | 2,400 |
| 2 | UI/UX wireframe & design | Design | 10 | 500 | 5,000 |
| 3 | Frontend development (responsive pages) | Development | 24 | 700 | 16,800 |
| 4 | Backend / CMS setup (admin panel, content mgmt) | Development | 16 | 800 | 12,800 |
| 5 | Database setup & integration | Development | 6 | 800 | 4,800 |
| 6 | Contact form + email notification integration | Integration | 4 | 700 | 2,800 |
| 7 | Payment gateway integration (Razorpay/Stripe) — *optional* | Integration | 8 | 800 | 6,400 |
| 8 | Basic SEO setup (meta tags, sitemap.xml, robots.txt) | SEO | 4 | 500 | 2,000 |
| 9 | Content upload & formatting | Content | 6 | 400 | 2,400 |
| 10 | Testing & QA (cross-browser, mobile responsive) | QA | 8 | 400 | 3,200 |
| 11 | Deployment, domain & hosting setup | Deployment | 3 | 600 | 1,800 |
| 12 | Client training & handover documentation | Handover | 2 | 500 | 1,000 |
| 13 | 1-month post-launch support / AMC | Support | 5 | 500 | 2,500 |

**Total task hours:** 100 hrs
**Actual Cost (sum of all tasks above, including the optional payment gateway task):** **₹63,900**
**Actual Cost (without the optional payment gateway task):** ₹57,500

## 3. Pricing Formula (what the estimator should reproduce)

```
Actual Cost          = sum of all task costs
Profit               = Actual Cost × Profit Margin %   (using 30% below)
Selling Price        = Actual Cost + Profit
Tax (GST)            = Selling Price × Tax %            (using 18% below)
Final Invoice Amount = Selling Price + Tax
```

## 4. Manual Calculation (compare the estimator's output against this)

**Scenario A — with payment gateway (all 13 tasks):**

| Step | Amount (₹) |
|---|---:|
| Actual Cost | 63,900 |
| Profit (30%) | 19,170 |
| Selling Price (before tax) | 83,070 |
| GST (18%) | 14,953 |
| **Final Client Invoice Amount** | **98,023** |

**Scenario B — without payment gateway (12 tasks):**

| Step | Amount (₹) |
|---|---:|
| Actual Cost | 57,500 |
| Profit (30%) | 17,250 |
| Selling Price (before tax) | 74,750 |
| GST (18%) | 13,455 |
| **Final Client Invoice Amount** | **88,205** |

## 5. How to use this test

1. Paste/upload this file into DAI Flash's estimate feature as the project input.
2. Ask it to compute the Actual Cost, Selling Price (with profit), and Final
   Invoice Amount (with GST) for Scenario A and Scenario B.
3. Compare its output line-by-line against Section 4 above.
4. If it's off, the likely gap is one of: it's using a different profit % or
   GST % than instructed, it's missing a task from the table, or it's applying
   GST before profit instead of after (order matters — see Section 3).

*Note: hours, rates, 30% profit margin and 18% GST are placeholder values —
replace them with the numbers you actually use before trusting the result.*
