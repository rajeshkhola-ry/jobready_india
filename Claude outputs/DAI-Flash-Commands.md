# DAI Flash — Command Cheat Sheet
**Format:** `[FILE PATH] में [क्या] [कैसे]।`  
**Rule:** जितना छोटा command → उतना कम खर्च → उतना बेहतर result

---

## ━━━ PROJECT 1 — DAI Flash Extension ━━━
📁 `C:\Druta Extension\src\`

### 🔧 Code Fix
```
src/extension.ts में _pickAcceptanceReviewer() function में bug fix करो।
Error: [यहाँ exact error paste करो]
```

```
src/agentRunner.ts में MAX_TOOL_ITERATIONS की value 24 से 30 करो।
```

```
src/agentTools.ts में NEVER_ALLOWED list में नया pattern जोड़ो:
pattern: /^docker\b/i
why: 'container ops are irreversible'
```

### ➕ नई Feature
```
src/agentTools.ts में नया export function बनाओ:
`estimateTokens(text: string): number`
Returns: Math.ceil(text.length / 4)
```

```
src/agentReport.ts में buildAgentReport() के end में एक नई line जोड़ो:
"अगली review: [date + 15 दिन]"
```

### 🧪 Tests
```
npm test चलाओ और result बताओ।
```

```
src/test/agentTools.test.ts में failing tests fix करो।
```

```
src/test/agentReport.test.ts में नया test case जोड़ो:
"50 runs वाला agent 'solid' confidence दिखाए"
```

### 📦 Build & Package
```
npm run build करो। errors हों तो fix करो।
```

```
npm run package करो और .vsix file का नाम बताओ।
```

### ⚙️ Settings
```
.vscode/settings.json में daiFlash.monthlyBudgetUsd की value [NUMBER] करो।
```

---

## ━━━ PROJECT 2 — The Clip Editor ━━━
📁 `[your clip editor folder]\`  
🌐 theclipeditor.com | Deploy: `git push` → Vercel auto-deploy

### 🎨 UI Changes
```
src/components/PricingCard.tsx में Pro Plus (₹999) card पर
"Studio Voice Clean" feature की badge जोड़ो - color: gold।
```

```
src/app/pricing/page.tsx में heading बदलो:
"Old heading" → "New heading"
```

### 💰 Plan / Pricing Logic
```
src/lib/plans.ts में check करो कि 'studio-voice-clean' feature
सिर्फ 'pro-plus' plan में है, 'pro' plan में नहीं। अगर नहीं है तो fix करो।
```

```
src/app/api/checkout/route.ts में नया paid feature जोड़ो:
Feature ID: '[feature-id]'
Plan: 'pro-plus' only
Free tier: false (zero cost to user)
```

### 🧾 GST / Tax
```
src/lib/tax/indiaGst.ts में invoice के लिए GST breakdown add करो।
Customer state: Delhi → CGST + SGST
Customer state: other → IGST
Export customer → 0% (zero-rated)
```

```
src/components/InvoicePreview.tsx में GST line items दिखाओ।
Format: CGST @9% ₹XX | SGST @9% ₹XX
```

### 💳 Razorpay
```
src/app/api/razorpay/webhook/route.ts में payment.failed event handle करो।
Action: Supabase में subscription status 'failed' करो।
```

### 🗄️ Supabase
```
supabase/migrations/ में नया migration बनाओ:
Table: user_invoices
Columns: id, user_id, amount, gst_amount, created_at
```

### 🚀 Deploy
```
git add src/[changed file] && git commit -m "fix: [क्या fix किया]" && git push
```

---

## ━━━ PROJECT 3 — GetReadyJob ━━━
📁 `[your getreadyjob folder]\`  
🌐 getreadyjob.com | Legal: Druta Systems | GST: Delhi registered

### 🤖 Android / Flutter
```
android/app/src/main/java/.../MainActivity.kt में [क्या बदलना है] करो।
```

```
lib/screens/home_screen.dart में [क्या बदलना है] करो।
```

### 🌐 Next.js (Web)
```
pages/api/jobs/[id].ts में नया field जोड़ो:
Field: 'postedAt' - ISO date string
```

```
components/JobCard.tsx में apply button का color
'blue-600' से 'green-500' करो।
```

### 🧾 GST (Delhi Registered)
```
lib/tax/checkout.ts में GST split logic check करो:
Delhi customer → CGST 9% + SGST 9%
Other state → IGST 18%
Export → 0%
Legal entity: Druta Systems
Support email: support@drutasystems.com
```

### 🔍 Bug Fix
```
pages/api/auth/[...nextauth].ts में error आ रहा है:
[exact error यहाँ paste करो]
Fix करो।
```

---

## ━━━ UNIVERSAL COMMANDS (सभी projects) ━━━

### Git
```
git status बताओ।
```
```
git log --oneline -10 बताओ।
```
```
सब staged changes commit करो। Message: "fix: [description]"
```
```
last commit का diff दिखाओ।
```

### Debug
```
[FILE]:[ LINE NUMBER] पर यह error आ रही है:
[ERROR TEXT]
Fix करो।
```

### Review
```
[FILE PATH] को review करो:
1. कोई security issue?
2. कोई missing null check?
3. कोई performance problem?
```

---

## ━━━ TOKEN SAVING RULES ━━━

| ❌ महंगा | ✅ सस्ता |
|---------|---------|
| "भाई देखो मेरे site पर..." | `src/Header.tsx` में color `blue` → `green` |
| "मुझे नहीं पता क्या हुआ पर..." | `line 47: TypeError: Cannot read 'id'` fix करो |
| "कुछ नया feature add करना है" | `src/lib/features.ts` में `voiceClean: proPlus only` जोड़ो |
| "test चला कर देखो" | `npm test चलाओ` |

**Golden Rule:** File path + क्या change + कैसे = perfect command  
**Cost estimate:** 20-30 tokens per command (vs 150-200 tokens conversational)

---
*Last updated: Sep 2026 | Rajesh Kumar Yadav | Druta Systems*
