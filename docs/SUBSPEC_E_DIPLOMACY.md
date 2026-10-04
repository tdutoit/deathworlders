# DEATHWORLDERS — Sub-spec E: Diplomacy, AI Personalities & Victory

*Version 0.1. Companion to the main Game Design Spec v1.1 (sections 9, 10, 14) and Sub-specs A–D. Integer conventions per Sub-spec A0. Starting values at Standard pace.*

---

# PART 1: RELATIONS

## E1. Two Numbers per Relationship

Every pair of empires has two independent values (per direction; A's view of B can differ from B's view of A):

| Value | Range | Meaning | Moves |
|---|---|---|---|
| **Opinion** | −100 … +100 | How they *feel* about you | Fast; driven by events, borders, deals |
| **Trust** | 0 … 100 | Whether they believe you'll *keep your word* | Slow; built by honoured treaties, destroyed by betrayal |

Higher treaties need both. This keeps "bribe them to love you, then backstab" from working twice.

## E2. Opinion Modifiers

Opinion = species base affinity + sum of active modifiers (clamped). Each modifier has a value and a decay rate toward 0.

| Source | Value | Decay |
|---|---|---|
| Shared border | −10 | none while true |
| Overlapping claims | −20 | none while true |
| Common enemy (at war with same empire) | +20 | none while true |
| Trade agreement | +10 | none while active |
| Research pact / intel sharing | +10 each | none while active |
| Defence pact | +15 | none while active |
| Alliance | +25 | none while active |
| Protectorate (protected → guardian) | +30 | none while active |
| Gift | +1 per 25 credit-value, max +25 | −1/month |
| Fought together (shared battle win) | +5 per battle, max +25 | −1/2 months |
| Rescued them (you defended their system) | +20 | −1/3 months |
| Denied request / insult | −15 | −1/month |
| Espionage caught | −30 | −1/month |
| Treaty broken (by you, any empire) | −50 to the victim, −15 to everyone else | −1/month |
| At war with them | set to ≤ −50 | on peace: rises from −50 |
| Humiliated in peace deal | −40 | −1/2 months |
| Flying their salvaged ships (D13) | −10 | none while in service |
| Legend (Humans only) | + Respect/40, − Fear/40 (E14) | tracks Legend |

### Species base affinity

| From ↓ / to → | Human | Vess'kar | Krothi | Ohlan | Thessari |
|---|---|---|---|---|---|
| **Human** | +10 | 0 | −10 | 0 | +10 |
| **Vess'kar** | −20 ("primitives") | +20 | −30 | +5 | +10 |
| **Krothi** | 0 | −30 | +10 | −10 | −10 |
| **Ohlan** | +5 | +10 | −5 | +10 | 0 |
| **Thessari** | 0 (wary) | +15 | −25 | 0 | +20 |

The Vess'kar starting at −20 toward humans is the HFY arc in one number.

## E3. Trust

- Starts at **20** (first contact) for most pairs; **10** for species with base affinity ≤ −20.
- **+1 per month per active treaty** honoured, max **+3/month**.
- +5 when you fulfil an obligation (answer an alliance call, defend a protectorate in time).
- **Breaking a treaty:** victim's trust → 0; all other empires −20 trust toward you. The pair's other treaties end
  cleanly (owner decision 2026-10-03), so trust rebuilds from 0 by slow recovery until a pact is possible again.
- **Slow recovery at peace** (owner decision 2026-10-03): +1 every 18 months, up to 20.
- **Ignoring an alliance call-to-arms:** −30 trust with that ally.
- Trust never decays on its own; it moves by deeds and the slow recovery above.

## E4. Treaties

| Treaty | Influence | Min Opinion | Min Trust | Key effects | Break penalty |
|---|---|---|---|---|---|
| Non-aggression | 10 | −20 | 10 | No war without 12-month notice | Trust 0 w/ victim |
| Trade agreement | 10 | 0 | 15 | Trade routes allowed, +10% trade value | −25 opinion |
| Research pact | 20 | +20 | 25 | +10% research for both in shared branches | −25 opinion |
| Intel sharing | 20 | +30 | 40 | Share sensor coverage (D12) + intel levels | −30 opinion, intel purge |
| Military access | 15 | +10 | 25 | Pass through, resupply in their space (B12) | −20 opinion |
| Defence pact | 30 | +40 (+30 until research and intel pacts exist, M4) | 50 | Automatic call-to-arms when attacked | Trust 0, −50 opinion |
| Alliance | 50 | +50 (+40 until research and intel pacts exist, M4) | 60 | Full call-to-arms, shared vision, joint fleets, shared war goals | Trust 0, −60 opinion |
| Protectorate | 30 | +20 (protected's view) | 20 | See E8 | Legend −Respect, trust 0 with all minors |
| Federation (late) | 100 | +70 | 80 | Shared Council bloc vote, shared tech trickle | Trust 0 w/ all members |

- Treaties have a **minimum duration of 5 years**; ending early counts as breaking.
- Influence cost is paid by the **proposer**; the receiver pays nothing.

---

# PART 2: AI DECISIONS IN DIPLOMACY

## E5. Acceptance Formula (shown to the player)

When you propose something, the AI computes an **acceptance score**; it accepts at ≥ 0. The breakdown is **always visible** in the diplomacy screen so players learn *why*.

```
acceptance =   opinion / 2
             + trust / 2
             − treaty_threshold          (per treaty, e.g. Alliance 40)
             + deal_balance              (E6, value they gain − value they give, scaled)
             + shared_threat             (+20 if a common enemy/crisis is near them)
             + fear                      (+ your power ratio bonus, max +25; Legend Fear)
             + personality_modifier      (E10)
             − recent_refusal_penalty    (−10 if you asked for the same thing < 1 year ago)
```
Every term is an integer; displayed as "+17 Opinion, +12 Trust, −40 Alliance threshold…".

## E6. Deal Valuation

Resources, credits, influence, systems, tech, and intel can be traded.

```
value(item) = base_value (B1) × amount × scarcity × personality_greed
scarcity    = clamp(1000 × target_stock / max(1, current_stock), 500, 2000) ‰
```
- **Physical goods must be delivered by convoy** (B15); the deal completes when they arrive. Raided deliveries → deal failure, opinion hit to whoever's convoy failed.
- **Tech:** value = RP cost × 0.5; AIs refuse to trade their top-tier techs to rivals.
- **Systems:** value = sum of planet output × 60 months + strategic bonus (chokepoint +50%).
- Recurring deals (e.g. 20 food/month for 5 years) are valued at 60% of their total (discounting risk).

## E7. War

### Casus belli (needed to declare war without a Legend Fear penalty)
| Casus belli | Source | War goals allowed |
|---|---|---|
| Claim | Claimed systems (influence 25 each) | Take claimed systems |
| Protectorate defence | Your protected was attacked | Liberate, reparations |
| Liberation | Your species' pops oppressed/occupied | Free occupied planets |
| Retaliation | They broke a treaty with you / raided you | Reparations, humiliation |
| Crisis mandate | Council appoints you | Any vs crisis collaborators |
| Containment | Target's Fear-power ratio vs you ≥ 2:1 | Disarmament (fleet cap) |

No casus belli → war allowed but −200 Respect, −20 opinion from everyone, and allies won't join.

### War score (−100 … +100 per side pair)
| Source | Score |
|---|---|
| Battle won | +1 per 200 cost of enemy ships destroyed (A12) |
| Occupied enemy planet | +5 (+10 capital, +8 war-goal planet) |
| Convoy raided | +1 per 400 cargo value destroyed/stolen |
| Blockade | +1/month per blockaded enemy system (max +10) |
| Salvage/derelict captured | +2 per capital hull recovered |

### War exhaustion (0–100 per empire)
- +1 per 5% of pre-war fleet cost lost; +2 per own planet occupied per year; +1/month at Total War (×0.35 humans, D7).
- At 50: stability −5 empire-wide; at 75: −15 and AI strongly seeks peace; at 100: **forced status quo peace** after 6 months.

### Peace terms
| Term | Cost in war score |
|---|---|
| White peace | 0 |
| Cede a claimed system | 10–25 (by value) |
| Reparations (resources via convoy over 5 years) | 5 per 1,000 credit-value |
| Release protectorate / liberate planet | 15 |
| Humiliation (−influence, −opinion) | 10 |
| Disarmament (fleet cap for 10 years) | 30 |
| Vassalisation (minor/defeated small empire) | 50 |

AI accepts a peace offer if `cost ≤ enemy war score + (their exhaustion − yours) / 2`.

## E8. Protectorates (Guardian Contracts)

- **Requests** appear when a minor species or weak empire (power < 40% of a hostile neighbour) is threatened. Requests go to empires with opinion ≥ +20 and presence within 6 lanes. Humans get requests first at equal standing (Legend Respect ≥ 300).
- **Terms offered:** monthly tribute (resources or credits), military access, research pact, and sometimes a unique tech or ship design.
- **Obligation:** if the protected is attacked, the guardian must have a fleet in the attacked system within **60 days**, or the contract fails.
- **Failure:** Respect −150, trust with all minors → 0, protected leaves.
- **Success milestones:** each defended attack gives Respect +50, opinion +20, trust +10.
- **Integration:** after 20 years with opinion ≥ +80 and trust ≥ 80, the protected may offer **peaceful integration** (its planets and pops join you, event-driven). HFY payoff: an alien species chooses humanity.

## E9. The Galactic Council

- **Founding members:** the Vess'kar plus any empire with a Council seat at start (settings). Other empires start **unrecognised**.
- **Recognition:** vote by members. Requires opinion ≥ 0 with a majority of members, or a Crisis Mandate. Humans start unrecognised (campaign and sandbox arc).
- **Votes:** `1 + floor(influence_income / 5) + protectorates + (Vess'kar Precedence: +2)`.
- **Sessions:** every 2 years (Standard pace); each member can propose one resolution per session (influence 30).
- **Resolutions (examples):**
  - *Trade Standards:* +10% trade for members, −10% for non-members.
  - *Sanctions on X:* members can't trade with X; X −20 opinion from members.
  - *Kinetic Bombardment Ban:* bombardment by members counts as treaty-breaking (aimed at humans).
  - *Pirate Suppression Mandate:* members' patrols +10 security in all member space.
  - *Crisis Mandate:* appoints a **Crisis Commander** (most votes among candidates): may command allied fleets, gets Casus belli vs collaborators.
  - *Recognition of X.*
- **Precedence (Vess'kar):** one veto per session.
- **Defiance:** members violating a passed resolution: −15 opinion from each member that voted for it, −10 trust.
- The AI votes by personality (E10) and opinion toward the proposer.

## E10. Non-State Actors

| Actor | Interaction |
|---|---|
| **Conglomerates** (Ohlan subsidiaries, independent megacorps) | Contracts: build ships for you (pay credits, they deliver), lease freighters, run trade stations in your space (credits split). They lobby Council votes for pay. |
| **Pirates** | Bribe (credits/month) to leave your convoys alone for 1 year; hire as deniable raiders (no casus belli needed, but discovery = −30 opinion, −20 trust). |
| **Minor species** | Protectorate requests (E8), uplift events, refugees. |

---

# PART 3: AI PERSONALITIES

## E11. Personality Weights

Each AI empire has weights 0–100 (from `SpeciesDef.ai_personality`, then randomised ±15 with the `ai` stream):

| Weight | Drives |
|---|---|
| **Aggression** | War declaration threshold, doctrine choices (Assault vs Methodical) |
| **Expansion** | Outpost/colony priority, claim frequency |
| **Honour** | Likelihood of keeping treaties, answering calls-to-arms |
| **Xenophilia** | Opinion bonus for treaties, refugee acceptance, protectorates |
| **Greed** | Trade value demands, contract use, bribe acceptance |
| **Caution** | Fleet reserve kept home, retreat thresholds, fort investment |
| **Ambition** | Council activity, pursuit of signature victory |

### Species defaults
| Species | Personality name | Aggr | Exp | Hon | Xeno | Greed | Caution | Amb |
|---|---|---|---|---|---|---|---|---|
| Humans (AI) | *Stubborn Wildcards* | 55 | 60 | 70 | 60 | 40 | 40 | 60 |
| Vess'kar | *Aloof Elders* | 30 | 40 | 80 | 30 | 40 | 75 | 85 |
| Krothi | *Hungry Tide* | 80 | 90 | 35 | 15 | 30 | 20 | 50 |
| Ohlan | *Merchant Princes* | 35 | 50 | 50 | 60 | 90 | 50 | 60 |
| Thessari | *Quiet Sanctuary* | 10 | 30 | 90 | 80 | 20 | 85 | 40 |

Personality effect on acceptance (E5): `+ (xenophilia − 50)/5 + (honour − 50)/10 for defensive treaties − (greed − 50)/5 for gifts/trade`.

## E12. Strategic AI Loop (monthly)

1. **Assess:** power ratios (by *known* information, D12), threats within 6 lanes, economy health, war exhaustion.
2. **Score candidate actions** with utility functions (all integer):
   - Expand to system X: `resource_value + strategic_value − distance×reach_penalty − risk`, × Expansion.
   - Declare war on Y: `(my_power − their_power×caution) + casus_belli_bonus + opportunity (Y at war elsewhere)`, × Aggression; requires a valid target and threshold.
   - Propose treaty: expected acceptance (E5) × value to AI.
   - Build military vs economy: by threat level and Caution.
   - Set war footing: by threat and war state.
   - Council proposal/vote: by Ambition and opinion.
3. **Act:** take the top N actions (N = 1–3 by difficulty) as Commands.
4. **Operational layer** (governors, logistics, templates) runs every tick as for players (D10).
5. **Memory:** grudges (betrayals, humiliations) stored as long-decay opinion modifiers; AIs remember who helped them.

## E13. Difficulty

All bonuses are **listed openly** in match setup.

| Difficulty | Output bonus | Intel | Actions/month | Fog |
|---|---|---|---|---|
| Cadet | −200‰ | Normal | 1 | Honest |
| Officer | 0 | Normal | 2 | Honest |
| Commander | +150‰ | Normal | 3 | Honest |
| Admiral | +300‰ | +1 intel level | 3 | Honest |
| Deathworld | +500‰ | Full vision | 3 | Cheats (full vision, labelled) |

---

# PART 4: LEGEND & VICTORY

## E14. Legend (Humans), numbers

Respect and Fear are each 0–1000, starting at 100.

| Event | Respect | Fear |
|---|---|---|
| Win a battle while outnumbered ≥ 1.5:1 | +30 | +20 |
| Defend a protectorate successfully | +50 | — |
| Fail a protectorate | −150 | — |
| Keep a treaty 10 years | +20 | — |
| Break a treaty | −100 | +30 |
| Orbital bombardment (per 30 days) | −20 | +25 |
| Destroy an empire's capital fleet | +20 | +50 |
| War without casus belli | −200 | +50 |
| Accept refugees (per 5 pops) | +15 | — |
| "They did WHAT?" events | varies | varies |
| Lead crisis defence (per stage won) | +75 | +25 |

Effects:
- **Respect ≥ 300:** first pick of protectorate requests. **≥ 600:** +10 opinion from all. **≥ 800:** Council recognition automatic.
- **Fear ≥ 300:** AIs with Caution ≥ 50 won't declare war on you unless allied. **≥ 600:** enemies accept peace 20 points cheaper. **≥ 800:** AIs may form a **containment coalition** against you.
- Other species have a plain **Reputation** (−500 … +500) from the same events at half values.

## E15. Victory Conditions (thresholds)

All toggleable in match settings. Thresholds scale with galaxy size where noted.

| Victory | Condition |
|---|---|
| **Domination** | Own ≥ 50% of all colonised planets' pops (Small/Medium) or ≥ 40% (Large/Huge), **and** no other empire above 15%, held for 5 years |
| **Coalition** | Your alliance/federation holds ≥ 60% of Council votes **and** you hold the Council chair, for 10 consecutive years |
| **Signature** | Species-specific (below), held for 10 years |
| **Crisis** | Crisis defeated; highest **crisis contribution** score wins (co-op: shared) |
| **Score** (optional end date) | Highest score at end date (Fast: year 150, Standard: 250, Epic: 400) |

### Signature victories
| Species | Condition |
|---|---|
| Humans (**Legend**) | Respect ≥ 900 **and** ≥ 4 active or integrated protectorates **and** no war declared without casus belli for 30 years |
| Vess'kar (**Precedence**) | Council chair for 3 consecutive sessions **and** ≥ 50% of Council votes aligned (opinion ≥ +50) |
| Krothi (**Brood Tide**) | Own ≥ 40% of galactic pops |
| Ohlan (**Contracts**) | ≥ 50% of all galactic trade/cargo volume passes through Ohlan hubs or contracts |
| Thessari (**Sanctuary**) | ≥ 5 empires/minors in protectorate or alliance with you, and none of them lost a planet for 20 years |

### Crisis contribution score
`damage dealt to crisis forces (cost) + 3 × systems defended/retaken + resources given to the defence (value/10) + 500 × Crisis Commander years`

### Score (for Score victory and end-of-game screen)
`pops × 5 + (fleet cost / 50) + techs × 10 + protectorates × 50 + Council votes × 20 + planet traits × 15 + (Respect + Fear)/10`

### Loss conditions
- Lose your capital **and** all Core planets.
- Stability collapse: average stability < 10 for 2 years.
- In co-op: shared loss.

## E16. Balance Targets

- AI declares an unprovoked war on a human neighbour **no earlier than year 10** on Officer.
- An honourable player can reach **Alliance** with at least one AI by year 30 in a Medium galaxy.
- Breaking one major treaty should cost ~15–25 years of trust rebuilding with the victim.
- Signature victories should take **150–220 in-game years** at Standard in a Medium galaxy (before the year-250 score date); Domination similar or slightly longer. Scales with the pace multiplier (Fast ×0.6, Epic ×1.6).
- Council resolutions pass ~40–60% of the time (not rubber-stamps, not dead letters).
