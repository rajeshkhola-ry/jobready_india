# DAI Flash — Poori Coding Ki Jaanch

**Kab:** 16 September 2026 · **Version:** 1.7.1
**Kaise:** Saari 30+ source file padhkar. Koi command nahi chalayi, koi paisa kharch nahi hua.

Har point ke saath `file:line` diya hai — jisse fix karte waqt seedha wahan ja sakein.

---

# HISSA 1 — YE KAAM HO SAKTE HAIN

## 1.1 Kaam karwana (job)

| Kaam | Haalat |
|---|---|
| Ek file me code likhwana / badalwana | ✅ Poori tarah |
| Ek message me kai file ka kaam | ✅ Apne aap alag-alag job me bat jata hai, aur Smart Pro/Flash me teeno **ek saath** (fan-out) chalte hain |
| Nayi file banwana | ✅ Par pehle aapse poocha jayega (`extension.ts:5104`) |
| Galat folder me kaam se bachna | ✅ Warning aur "us folder ko khol dun?" (`extension.ts:5013`) |
| Kaam ruka to wahin se shuru karna | ✅ Checkpoint + Resume banner (`extension.ts:5916`) |
| Balance khatam hone par job ko pause | ✅ Fail nahi karta, pause karta hai (`agentRunner.ts:3327`) |

## 1.2 Kaun sa AI chalega (10 agent, 3 plan)

`agentRunner.ts:350-366` me 10 agent hain. Teen plan (`:433-541`):

- **Smart Saver** — DeepSeek Flash/Pro se shuru → DeepSeek Pro → o4-mini
- **Smart Pro** (default) — DeepSeek Pro / o4-mini / GPT Terra → Sonnet
- **Smart Flash** — Sonnet → Opus → GPT Astra → Fable

Kaam na hone par apne aap upar wale agent par chadhta hai (`agentRunner.ts:1630`), aur agar poora plan haar jaye to aapko batata hai ki **agla plan lijiye** (`:613`).

Ek khaas cheez: sasta agent do baar fail ho jaye to **Sonnet use samjha kar dobara bhejta hai** — "team lead" wala tarika (`agentRunner.ts:3242`). Ye achha design hai.

## 1.3 Quality aur safety

| Kya | Kahan |
|---|---|
| Compile + lint + test apne aap chalna | `qualityGates.ts:87-109` |
| Build toot jaye to **error wapas agent ko dekar** dobara likhwana (3 baar tak) | `agentRunner.ts:3940` |
| `@ts-ignore` / `eslint-disable` daal kar dhokha dena — **pakad liya jata hai** | `agentRunner.ts:3740` |
| Do alag reviewer (ek asli diff padhta hai, doosra checklist) | `acceptanceReview.ts` + `orchestrator.ts` |
| Reviewer wahi agent nahi ho sakta jisne kaam kiya | `extension.ts:7638` |
| Reject hone par apne aap poora wapas | `agentRunner.ts:3846` (aur ab job-level bhi, #34 fix) |
| Har badlaav se pehle snapshot | `agentRunner.ts:3706` |
| Khaali / duplicate / markdown-fence wala jawab likhne se pehle rok | `agentRunner.ts:802` |
| 18 aam error ka **Hindi me matlab** | `errorDictionary.ts:49-212` |
| Workspace ke bahar kuch bhi nahi likh sakta | `fileOpsGuard.ts:102` |

## 1.4 Panel ke buttons

**Chalte hain:** Send, Stop (■), Chat ON/OFF, plan dropdown, Report, Estimate, Quote, Gear (⚙️), Undo (↩), Trash (🗑), Mic, Attach (+), queue me har item par ✏️ edit aur ✕ delete, job card par Keep/Undo, "📋 Copy Full Report", Recovery banner ka Resume/Start Fresh, "➡️ Send to Agent" (chat ke jawab se seedha job).

**Queue:** kaam chalte waqt naya message bhejiye to line me lag jata hai, aur pehla khatam hote hi **apne aap** agla chal padta hai (`extension.ts:8665`). Ye humne aaj test bhi kiya — sahi chala.

**Chat mode:** file ko haath nahi lagata, sirf baat karta hai (`chatAssistant.ts:5`). Jawab ke saath "Send to Agent" button de sakta hai.

**Voice:** bolkar likhwana — sirf Windows par (`extension.ts:4550`), OpenAI key chahiye.

## 1.5 Paisa aur report

- Har job ka poora kharcha, alag-alag (asli kaam / sudharne wale run / review) — `extension.ts:3025`
- Ab andaaza bhi **range** me, aur "range ke andar? HAAN/NAHI" — aaj ka fix
- Agent Scorecard: kaunsa agent pehli baar me kaam karta hai, kitna kharcha — `agentReport.ts:274`. **5 run se kam wale agent par ye raay dene se mana kar deta hai** (`:183`) — ye imaandaar design hai
- Client ke liye Project Quote (module-wise ghante + rate + profit + GST) — `projectQuoteEngine.ts`
- Admin P&L report + CSV/Excel export — `adminAnalytics.ts`
- Har job ki poori report ab file me save hoti hai (aaj ka feature)

## 1.6 Google Search Console

Connect, sitemap dobara submit (job ke baad apne aap bhi), aur performance report (28 din, top 25 page + query) — `searchConsoleClient.ts:67`, `extension.ts:6402`.

## 1.7 Bharosa jeetne wali cheezein

- Backup: 2+ file badlein ya 50+ line, ya har 3rd kaam par — apne aap (`backupManager.ts:66`). **Doosre project ka backup kabhi restore nahi hoga** (`:139`)
- Monthly budget cap (`budgetGuard.ts`)
- Agent kabhi bhi ye nahi kar sakta: `git push`, `git reset`, file delete, deploy (`vercel`/`netlify`/`firebase`), internet se kuch download (`curl`/`wget`), admin rights (`agentTools.ts:69-80`)
- Bahar ke folder (Drive/OneDrive) — **har baar** aapse poochta hai, chahe Auto-Approve on ho (`agentTools.ts:1005`)

---

# HISSA 2 — YE KAAM NAHI HO SAKTE

> Ye wo cheezein hain jo coding me **abhi hain hi nahi**, ya jaanbujhkar band hain. Test karne ki zaroorat nahi — code me saaf likha hai.

## 2.1 🔴 Sabse zaroori — jo dikhta hai par kaam nahi karta

**1. "Send Next - Manual" aur "Auto-Send Queue" — ye dono button kuch nahi karte.**
Ye ek doosri, alag queue se jude hain jo **kabhi bharti hi nahi** — us queue me daalne wala function (`submitPrompt`) poore project me kahin se bulaya hi nahi jata. Isliye aap "Send Next" dabayenge to log me "📭 Queue is empty" aayega, jabki uske bagal me "2 queued" likha hoga.
`extension.ts:4441`, `agentRunner.ts:2390`

**2. "🟢 Auto-Approve: ON" — iske peeche koi setting hai hi nahi.**
Ye sirf ek likha hua label hai, na uska koi button hai na koi setting. Kuch on/off nahi hota.
`extension.ts:1862`

**3. "Recent sessions" list pehli job ke baad gayab ho jati hai.**
Ye list sirf tab dikhti hai jab log box bilkul khaali ho. Ek baar koi job chal gayi, to list dobara kabhi nahi aayegi — window reload ya 🗑 Trash dabane tak. Iske saath "🔁 Re-check" button bhi chhup jata hai.
`extension.ts:3285`

**4. ~~`npm test` chal hi nahi sakta.~~ — YE POINT GALAT THA. (16 Sept 2026 ko theek kiya)**

Maine likha tha ki `package.json:335` me do aisi test file ka naam hai jo maujood hi nahi
(`acceptanceReview.test.js`, `agentReport.test.js`). **Ye galat tha — dono file maujood hain.**
Galti meri thi: audit ke waqt maine `src/test/` folder khola hi nahi tha, isliye file "nahi
mili".

Sach ye hai: `npm test` chalta hai. Chalane par usne ek **asli** fail hone wala test dhoonda
(`buildCompactDiff` ka truncation note) — wo v63 me theek kar diya gaya.

## 2.2 Ek job = ek file

Sabse badi structural limit. Ek job me **sirf ek file** badal sakti hai (`agentRunner.ts:3703`, `extension.ts:5070`).

Iska matlab: **agar kaam tabhi sahi hoga jab do file ek saath badlein, to wo kaam nahi ho sakta.** Jaise — kisi export ka naam badalna aur uske saare import bhi theek karna. Yahi wajah hai ki hamara test wala kaam #3 hamesha fail hota tha.

**Tool mode** me ye limit nahi hai (`agentRunner.ts:4053`) — lekin wo default me **band** hai (`package.json:261`) aur use on/off karne ka panel me koi button nahi hai.

## 2.3 Teen agent kabhi chal hi nahi sakte

| Agent | Kyun |
|---|---|
| **Claude Haiku** | Kisi bhi plan ki list me hai hi nahi. Sirf request padhne ke liye use hota hai, code likhne ke liye kabhi nahi (`agentRunner.ts:2934`) |
| **GPT-5.6 Luna** | Kisi plan me nahi. Sirf haath se id daal kar |
| **DeepSeek V4 Flash** | Smart Saver ki list me hai, **lekin** har persona ka minimum level `medium` ya `high` hai, aur ye `low` hai — isliye har baar chhant jata hai (`agentRunner.ts:1150`, `personas.ts:70-145`) |

Yaani Smart Saver ka sabse sasta agent kabhi nahi chalta.

## 2.4 Agent ko test file likhne ko kaha jata hai, par wo likh nahi sakta

Char persona kehte hain "test zaroori hai" (`personas.ts:70,83,97,145`), test file ka naam bhi 5 jagah calculate hota hai — **lekin us naam ko koi padhta hi nahi**, aur ek job ek hi file likh sakti hai. To ye maang poori ho hi nahi sakti.
`agentRunner.ts:1949, 1966, 1987, 1999, 3444, 3527`

## 2.5 Attach (+) se file daalna — bina kisi rok-tok ke

Ek 300-line ki file attach ki, to **300 job ek click me** chal jayengi. Aur unme:

- ❌ koi kharche ka andaaza nahi
- ❌ budget check nahi
- ❌ koi confirmation nahi
- ❌ aapke project ke rules (house rules) lagte hi nahi
- ❌ galat-folder check nahi, nayi-file confirmation nahi

`extension.ts:6699`, `batchProcessor.ts:241`

Aur agar us waqt aap koi aur message type kar dein, to wo **batch ke beech me hi chal padta hai** — do kaam ek saath.
`extension.ts:8665`

## 2.6 Panel me jin cheezon ka button hi nahi

API key, bahar ke folder, retry ki ginti, review mode, house rules file, Search Console, backup, budget cap, fan-out on/off, tool mode — **sab sirf Settings ya Command Palette se**. Panel me kuch nahi.

## 2.7 Live kharcha kahin nahi dikhta

Job chalte waqt kitna paisa lag raha hai — ye dikhane wala code hai, lekin jis jagah dikhana tha wo element HTML me hai hi nahi. Kharcha sirf job khatam hone ke baad card par dikhta hai.
`extension.ts:4227, 4231`

## 2.8 ~~Tax engines kisi kaam nahi aa rahe~~ — THEEK KAR DIYA (16 Sept 2026)

**Pehle maine jo likha tha, usme ek baat galat thi.** Maine kaha tha ki `globalTaxEngine.ts`
me Germany ka `case 'DE'` hai hi nahi. **Wo galat tha** — `case 'IN'` aur `case 'DE'` dono
file me maujood the, aur jis desh ka engine nahi hai wo saaf-saaf error deta tha. Maine file
dobara padh kar apni galti pakdi.

**Jo sach me galat tha, aur ab theek ho gaya hai:**

1. **Engine kahin se use nahi ho rahe the.** Project Quote sirf ek flat GST % multiply karta
   tha (`projectQuoteEngine.ts:304`). Ab quote `GlobalTaxEngine` se hokar jaata hai: rate ko
   us desh ke **notified** rates se check kiya jaata hai, aur check **AI call se pehle** hota
   hai — yaani galat rate par paisa kharch hi nahi hota.

2. **Sirf do desh the.** Ab aath hain — India, Germany, UK, UAE, Singapore, Australia,
   Saudi Arabia, New Zealand (`simpleTaxEngine.ts`).

3. **Purane GST slab.** 12% aur 28% ab India me hain hi nahi (GST 2.0), aur 40% demerit rate
   missing tha — yaani sahi 40% wala invoice engine **mana** kar deta tha. Dono theek.

**US aur Canada jaan-boojh kar nahi daale.** US me tax har state/county/city ka alag hai
(~13,000 jurisdiction), Canada me province ke hisaab se HST/PST badalta hai. Ek percentage
likhna matlab kisi na kisi client ko galat bill bhejna. Un dono ke liye `computeTax()` saaf
error deta hai — chup-chaap koi number nahi banata.

## 2.9 Do faltu file

`dr0723000196800000Dg0723000254Module.ts` aur `dr082300001015000Dg0723000256Module.ts` — ye dono **agent ki galti se bani hui file hain**. Kisi ne bank ki transaction line paste kar di thi, aur agent ne usi naam ka "module" bana diya. Kahin se use nahi hoti, aur ek to import hote hi crash kar degi. **Delete kar dena chahiye.**

## 2.10 Aur limits

- Ek job **file delete / rename / move** nahi kar sakta — aisa koi tool hai hi nahi
- Chat mode file ko haath nahi laga sakta
- Voice sirf Windows par, aur OpenAI key chahiye
- PDF attach nahi hoti; 25 MB se badi file nahi (par button par "5MB+ supported" likha hai — galat)
- Google me "Request Indexing" nahi ho sakta (Google ne API hi nahi di)
- Chat sirf pichhli 40 baat yaad rakhta hai
- Job report file save to hoti hai, par use **kholne ka koi button nahi** hai

---

# HISSA 3 — JIN PAR MUJHE DOUBT HAI

> Code padhkar lagta hai ye kaam hone chahiye, lekin kahin atak sakte hain. Neeche **jo sabse upar hai wo sabse jyada sambhav hai**.

## 3.1 🔴 Lagbhag pakka atkenge

**D1. Backup se restore karne par kharab file hi wapas aa sakti hai.**
Backup job **khatam hone ke baad** liya jata hai — yaani jo file agent ne kharab ki, backup usi kharab haalat ka hai. Crash ke baad restore karenge to kharab file hi wapas aayegi. Sahi purani file sirf memory me thi, jo reload par chali jati hai.
`extension.ts:8770`
**Ye sabse khatarnak wala hai** — backup ka matlab hi ye hai ki wo bachaye.

**D2. Sanity guard sudharne wale round me lagta hi nahi.**
Jo guard markdown-fence aur duplicate content rokta hai, wo sirf pehli baar lagta hai. Corrective round me file bina jaanche likh di jati hai — aur wahi round sabse jyada galti karta hai.
Guard: `agentRunner.ts:3710` · Bina guard wala write: `:3828`

**D3. Guard ne rok diya to kharcha $0 dikhta hai.**
Paisa lag chuka hota hai, report me 0 aata hai.
`agentRunner.ts:3716`

**D4. Kharche ka andaaza alag agent maan kar lagta hai.**
Andaaza `deepseek-flash` maan kar lagta hai, chalta `deepseek-pro` hai — teen guna farak. Aur budget cap isi andaaze par check hota hai.
`agentRunner.ts:1284` bनाम `:3598`

**D5. "Run Safe Command" Windows par shayad chalta hi nahi.**
`npm.cmd` ko bina shell ke chalane ki koshish karta hai — Windows par ye EINVAL error deta hai. Baaki do jagah (quality gate, agent ka command) ye theek kiya gaya hai, sirf yahan reh gaya.
`agentShell.ts:31, 88`

**D6. Chat galat agent ka naam dikhata hai.**
"💬 Sonnet is thinking..." hamesha likha aata hai, jabki asal me plan ka sabse sasta agent chalta hai.
`extension.ts:2379` बनाम `:5871`

## 3.2 🟡 Aksar atkenge

**D7. Badi file kat sakti hai aur pata bhi nahi chalega.**
Jawab 4096 token se bada hua to model beech me kaat deta hai — aur code **kabhi check nahi karta** ki jawab poora aaya ya nahi. Nayi file banate waqt ye check aur bhi kam hai. Bachav sirf build fail hone se hota hai — aur fan-out ke beech me build chalta hi nahi.
`agentRunner.ts:2956, 3949`

**D8. Fan-out ke waqt panel kuch nahi dikhata.**
Default (Smart Pro) me kai file ek saath chalti hain, aur us waqt na step bubble dikhta hai, na counter, na kharcha — sirf aapas me mili-juli log lines. Chalta kaam aur atka kaam ek jaisa dikhta hai.
`extension.ts:5670`

**D9. Fan-out wala kaam beech me ruk jaye to resume nahi hota.**
Checkpoint us se pehle hi return ho jata hai. Wahi kaam fan-out band karke chalaya jaye to resume ho jata hai.
`extension.ts:5084` बनाम `:5160`

**D10. Keep/Undo na dabaya to agla message purana kaam chupchap "keep" kar deta hai.**
Card padha, socha "baad me dekhta hoon", agla message type kiya — purana diff hamesha ke liye keep ho gaya.
`extension.ts:4889`

**D11. Estimate card ke paise gear settings ko nahi maante.**
Estimate card me GST 18% aur ₹87/$ **fixed likhe hain**, jabki gear panel me aapne jo GST/rate set kiya wo sirf Quote button use karta hai. Ek hi screen par do alag GST.
`extension.ts:3599, 3679, 4199`

**D12. Diff banane ka tarika line-set hai, asli diff nahi.**
Jis file me ek jaisi lines baar-baar hain (jaise `},` ya imports), usme line hatane/duplicate karne par reviewer ko **khaali diff** milta hai — aur wo bina kuch dekhe raay deta hai.
`acceptanceReview.ts:113`

**D13. Sitemap ka Google call file ke naam se chalta hai, content se nahi.**
`sitemapHelpers.test.ts` chhoone par bhi Google ko call chala jayega.
`extension.ts:6385`

## 3.3 🟢 Kabhi-kabhi

- **D14.** `{` `}` ki ginti string aur comment ke andar bhi ho jati hai — sahi file ko "toota hua" bata kar wapas kar sakta hai (`fileOpsGuard.ts:380`)
- **D15.** `src/` folder na ho (jaise sirf `app/` wala Next.js) to agent ko file list milti hi nahi — aur wo nayi file banane lagta hai (`fileOpsGuard.ts:187`)
- **D16.** Multi-root workspace me build galat folder me chal sakta hai (`batchProcessor.ts:235`)
- **D17.** Budget ka hisaab fan-out me kam gin sakta hai (ek saath likhne se) (`budgetGuard.ts:74`)
- **D18.** Reviewer ka word-match "test" ko "latest" me dhoondh leta hai — galat pass ho sakta hai (`orchestrator.ts:279`)
- **D19.** `npm install` allowed hai — ye internet se package laata hai aur uski script chalata hai, jabki usi file me likha hai "agent internet par kuch nahi bhejega" (`agentTools.ts:78` बनाम `:100`)
- **D20.** Job history kabhi saaf nahi hoti aur usme poore diff bhare rehte hain — mahino baad bhaari ho jayegi (`jobHistory.ts:50`)

---

# HISSA 4 — DOUBT KAISE TEST KAREIN

**Achhi khabar: 6 me se 5 doubt bina ek rupaya kharch kiye test ho sakte hain.**

| # | Kya test karna hai | Kaise | Kharcha |
|---|---|---|---|
| 1 | ~~`npm test` chalta hai ya nahi~~ — **chal gaya, theek hai** (dekhiye 2.1 #4) | — | ₹0 |
| 2 | "Send Next - Manual" dead hai | Do message queue karke button dabaiye | ₹0 |
| 3 | "Recent sessions" gayab | Ek job ke baad panel dekhiye | ₹0 |
| 4 | Run Safe Command Windows par tuta | Command Palette → "DAI Flash Admin: Run Safe Command" | ₹0 |
| 5 | Chat galat naam dikhata hai | Chat ON karke kuch poochiye | ~₹1 |
| 6 | Backup purani file wapas laata hai ya kharab | Isme asli crash chahiye — **abhi mat kijiye** | — |

Aap kahein to ye 4 muft wale test aap chala dijiye, main result padh lunga. **D1 (backup)** ka test khatarnak hai — use pehle theek karna behtar hai, test karna nahi.

---

# MERI SALAAH — KIS ORDER ME

**Pehle (sabse zaroori — aapka data bacha sakta hai):**
1. **D1** — backup pehle lena, baad me nahi
2. **D2** — sanity guard corrective round me bhi lagana
3. **2.5** — Attach (+) par confirmation aur budget check

**Uske baad (rozana dikhne wali gadbad):**
4. **2.1** ke teen — dead buttons, jhootha Auto-Approve label, gayab sessions list (`npm test` wala point galat tha, hata diya)
5. **D3, D4** — kharche ki sachai
6. **D5** — Windows wala command

**Phir (safai):**
7. **2.9** — do faltu file delete
8. **2.3** — teen agent ya to plan me daaliye ya list se hataiye
9. **2.4** — ya test likhne dijiye, ya persona se ye maang hataiye
10. **D11** — ek hi GST pura panel me

**Sochne wala (feature):**
11. **2.2** — "ek job = ek file" wali limit. Tool mode isse todta hai par band pada hai. Ye poora ek alag project hai
12. **2.8** — tax engines ya to jodiye ya alag package me le jaiye
