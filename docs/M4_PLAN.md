# DEATHWORLDERS — M4 Build Plan: AI, Diplomacy & Species

*Version 0.1 (2026-10-02). Turns main spec 9, 10 and 14 (M4 scope in section 19: "species definitions and
signature mechanics, AI empires, treaties, opinion, war declarations"), Sub-spec E (relations, treaties, deals,
war, Council, personalities, strategic AI, difficulty, Legend), D7 (war footing), D10 (strategic AI layer),
the species rows of A13 / B and Sub-spec F14 into an ordered build plan. Builds on M3 (docs/M3_PLAN.md); same
rules (CLAUDE.md), same tooling.*

**Change log**
- 2026-10-02: plan created. Scope decisions below agreed with the project owner.
- 2026-10-02 (WP1, owner decisions): traits as proposed (open question 4 settled): Vess'kar Ancient Science
  (energy damage +100‰, shield regen +100‰) and Long-Lived (growth −250‰, stability +5); Krothi Swarm
  Doctrine (corvettes/frigates and fighters +100 accuracy), Ravenous (growth +500‰, food upkeep +250‰) and
  Expendable (morale loss x0.8); Ohlan Merchant Princes (Clerk output +150‰) and Missile Doctrine (missile
  accuracy +100, ECM +50 per suite); Thessari Shield Masters (shields +150‰), Steadfast Defenders (defensive
  platforms +200‰ hull) and Reluctant Warriors (war exhaustion +50%, stability +5); humans as specced, plus
  Pack Bonding (ally opinion growth +50%, used from WP3). Species balance target and the hull and design
  changes that meet it: Sub-spec A change log. The designer's prediction now plays each side's species.
- 2026-10-02 (WP1, owner decisions): cost-aware AI fleets: a species' ship credit upkeep follows its cost
  premium (humans x1.2, Krothi x0.91 of B10), and the AI's minimum defence fleet is a battle value
  (`combat_rules.ai_min_fleet_value` 2300, about two base-cost destroyers) instead of a ship count, so a
  species with pricier ships keeps fewer of them. B20 stays species-neutral like A14: `economy_harness.gd`
  runs with traits switched off by default (mode `neutral`); mode `species` keeps traits on and requires each
  species to meet B20 in at least half its empires. A `first` argument runs long checks in chunks.
  Results (20 seeds, small, 4 AIs): neutral 60 of 80 (M3 accepted 65; M3's own runs ranged 60-66); species
  58 of 80 with humans 18, Krothi 16, Vess'kar 16 and Thessari 8 of 20 after widening Thessari habitability
  (ocean 800, desert 600; was 5 of 20). Thessari miss the species floor: most failing empires stop at exactly
  5 colonies, which points at the AI's expansion gates rather than the species data. Carried to WP10 (the
  strategic loop reworks expansion) and WP14 (economy targets), together with the neutral 60 vs 65.
- 2026-10-02 (WP2): `SignatureMechanic` (sim/species) with deterministic hooks: `init_state` (match start),
  `month_tick` (new month phase 5, after the AI), `battle_resolved`, `command_applied` (player commands and
  the AI's), `treaty_event` (from WP4) and `meter` for the UI. `SignatureMechanics` maps
  `SpeciesDef.signature_mechanic` to a script; core registers legend, precedence, brood_surge, contracts and
  sanctuary (stubs until WP9); `register` adds more (mods later, tests now). Per-empire state is
  `Empire.mechanic` (ints and strings; saved, in the checksum). An unknown mechanic name fails validation.
- 2026-10-02 (WP3, owner decision on open question 1): first contact when an own system is within
  `contact_lanes` (3) of the other's territory or any own unit is in a system the other owns; mutual; checked
  monthly (month phase 5, before the signature mechanics). `Relation` per directed pair (`MatchState.relations`,
  `diplomacy` checksum part): trust (E3 start 20, or 10 when the affinity is -20 or lower; moved only by deeds),
  standing modifiers recomputed monthly while true (shared border = an own system one lane from theirs, -10;
  common enemy, +20; treaties from WP4) and event modifiers (one accumulating value per type, capped, decaying
  one point every N months: gift, fought together, rescued, denied, espionage, treaty broken (victim and
  others), humiliated, war memory). Opinion = species affinity + standing + events, clamped to +-100, at
  most -50 while at war. `Empire.reputation` (-500..500, E14) for every empire. All numbers in the new
  `diplomacy_rules` Def. Pack Bonding's faster ally opinion applies once alliances exist (WP4).
- 2026-10-02 (WP4 part 1, owner decisions on open questions 7 and 8): six `treaty` Defs (E4 numbers;
  E5 thresholds placeholders: non-aggression 0, trade 5, access 10, protectorate 20, defence pact 30,
  alliance 40). `propose_treaty`: an AI answers at once (E4 opinion/trust gates, then E5 score >= 0: opinion/2
  + trust/2 - threshold + shared threat 20 + fear (power ratio above 1:1, 2:1 = +25) + personality (E11 note,
  species weights until WP10) - recent refusal 10; deal balance from WP5); a player answers within 30 days
  (`answer_proposal`; declining is "denied", -15). The proposer pays the influence. `cancel_treaty`: after 5
  years it ends cleanly (non-aggression: 12 months' notice, war blocked until then); earlier it is broken:
  the victim's opinion (the treaty's break value) and trust (to 0 for non-aggression, defence pact, alliance
  and protectorate, per E4's column), everyone else in contact -15 opinion and -20 trust, Reputation -50.
  Treaty opinion (trade +10, defence pact +15, alliance +25, protectorate +30 for the protected) is standing;
  trust +1 a month per treaty, at most +3 per pair. Declaring war breaks the declarer's treaties with the
  target and calls the target's defence pact, alliance and protectorate partners (`answer_call`: join = war
  and +5 trust; refuse or 30 days = -30 trust; AI partners answer by an Honour roll until WP10). Military
  access lets a fleet resupply from the granting empire's stockpiles. Protectorate (E8 adapted): the protected
  proposes when under 40% of a hostile neighbour's power, the guardian within 6 lanes; tribute 10% of the
  protected's credit net; when the protected is attacked, a guardian warship in one of its systems within 60
  days earns "rescued" +20, trust +10, Reputation +25, otherwise the protectorate fails (trust 0, Reputation
  -75). Pack Bonding scales allies' positive opinion events toward humans by 1.5.
- 2026-10-02 (WP4 part 2, coalition battles): a battle's sides are coalitions (`Battle.sides`; `owners` keeps
  each side's lead). An owner arriving in a battle joins the side whose enemies it is hostile to while hostile
  to nobody on that side (allies and co-belligerents); otherwise it waits, as a third party did in M3.
  Formations carry their own owner (doctrine, morale traits, Last Stand and retreat home per owner); a boarded
  ship goes to the boarding ship's owner; the battle ends as a truce once no owner on one side is hostile to
  any on the other. Salvage goes to each winning-side empire by its share of the hull damage the side dealt
  (Improvisers on its own share). Reports keep `sides`; the UI names coalition sides "A + B".
- 2026-10-02 (WP5): deals (`propose_deal`: items each way, optionally with a treaty; an AI answers by E5 with
  a deal-balance term, a plain deal using threshold 0 and the trade personality term, gifts always accepted;
  a player answers the proposal). Items: credits and influence (moved at once), resources (the giver's idle
  freighters carry them to the receiver's capital; goods need a trade agreement, which may be signed in the
  same proposal), claimed systems (not the capital; the giver's colonies there, pops keeping their species,
  and stations change hands; routes and demands touching them are removed). Recurring items pay monthly for
  N months. E6 value from the valuer's side: base value x amount x scarcity (target stock = 6 months of last
  month's use; clamp 500-2000 permille), greed (500 + 10 x greed permille) on what it gives up, recurring at
  60%, systems at 60 months of their colonies' output (at least 500). Placeholders: influence worth 5
  credits; deal balance 1 point per 50 credits of value, capped at +-50. A gift adds +1 opinion per 25 value
  (E2). A failed deal (unpaid, or a deal freighter lost to raiders) costs the at-fault side -20 opinion
  ("failed a deal", -1 a month).
- 2026-10-02 (WP6, owner decisions): `claim_system` (25 influence; claims cost -20 opinion both ways while
  they stand). Casus belli: claim (take claimed systems), retaliation (they broke a treaty or failed a deal
  with you, while that memory lasts), protectorate (they are at war with your protected), containment (they
  are at least twice your power: disarmament); liberation and crisis mandate wait for M6/M7.
  `declare_war {empire, casus_belli}`: without one, Reputation -100 (half of E14's Respect -200), everyone
  else's opinion -20 ("warmonger") and no calls to arms. A `War` record per pair (`war_info`; joining allies
  fight their own pair wars): war score from battles (+1 per 200 battle value of the enemy's ships destroyed or
  captured, weighted by each empire's share of its side's damage), convoy raids by its fleets (+1 per 400 cargo
  value) and blockades (own stationary warships in an enemy system with none of theirs, +1 a month each, at
  most +10). War exhaustion (0-100): +1 per 5% of the pre-war fleet value lost (Reluctant Warriors +50%),
  -2 a month at peace (placeholder); stability -5 at 50 and -15 at 75; at 100 for 6 months a status quo
  peace. Peace: `offer_peace {empire, loser, terms}` and `answer_peace`: white (0), cede a claimed system
  (10-25 by value, 1 per 2000 of value above 10), reparations (5 per 1000 credit-value, paid as credits
  monthly for 60 months), humiliation (10: -50 influence and "humiliated" -40), disarmament (30: for 10 years
  the loser's warship value stays at most half of what it had; the shipyard check enforces it). The attacker
  may demand its casus belli's goals; either side reparations and humiliation. An AI loser accepts when the
  cost is at most the demander's score + half the exhaustion gap; an AI winner accepts terms worth at least
  that. Peace adds "war memory" -50 both ways (-1 a month). `make_peace` stays as the dev white peace.
- 2026-10-02 (WP7): war footing as `war_footing` Defs (Peace, Mobilised, Total War, D7's table: job output
  per resource for alloys, munitions, credits and research; stability -5 / -15). `set_war_footing`; a change
  runs at half effect for 60 days; Total War back to Peace costs -5 stability for 6 months. E7 and D7 read
  together: at Total War, exhaustion from losses grows x0.5 and +1 a month is added while at war; humans
  (Stubborn, `empire.total_war_exhaustion` 350) use x0.35 for both. The AI sets Peace at peace, Mobilised at
  war, Total War against a stronger enemy (placeholder until WP10).
- 2026-10-02 (WP8, owner decisions on open question 3 and the Council details): `MatchState.council`; founders
  are every Vess'kar empire, else the empire with the highest species Ambition (ties: lowest ID). Sessions every
  24 months; a member makes one proposal a session (`council_propose`, 30 influence; the proposer votes for
  it), members vote (`council_vote`; AI members by opinion of the proposer / 2 plus a stance: Trade Standards
  greed - 50, Sanctions minus their opinion of the target (-100 if it is them, -50 more if allied to it),
  Pirate Suppression caution - 40, Recognition their opinion of the target + xenophilia - 50; repeals flip
  the stance). Votes: 1 + influence income / 5 + protectorates held + mechanic bonuses (Precedence, WP9).
  Passes on more weighted yes than no; in force until a later session repeals it (`repeal`). Resolutions (as
  `resolution` Defs): Trade Standards (members' Clerk credits +10%, others -10%), Sanctions on X (members'
  opinion of X -20 while in force; a member signing a treaty or deal with X defies it: -15 opinion and -10
  trust from each member that voted for it), Pirate Suppression Mandate (+10 security in member space),
  Recognition of X (admits X). Kinetic Bombardment Ban and Crisis Mandate wait for M6/M7.
- 2026-10-02 (WP9, owner decisions on open question 2): the five mechanics, numbers in a new
  `signature_rules` Def. New mechanic hooks: day_tick, opinion_from, acceptance_bonus, peace_discount,
  output_permille, containment_target, auto_recognition, council_votes, council_veto; events through
  treaty_event (treaty signed/broken/ended, protectorate defended/failed, war declared, war won, resolution
  passed, goods delivered).
  Legend (humans, E14): Respect and Fear start 100 (0-1000): outnumbered victory (enemy start cost >= 1.5x)
  +30/+20, protectorate defended +50 / failed -150, a treaty kept 10 years +20, a treaty broken -100/+30,
  an empire's capital fleet (half its navy lost in one battle) +20/+50, war without casus belli -200/+50.
  Every other empire's opinion + Respect/40 - Fear/40, +10 at Respect 600; Respect 800 = Council member;
  Fear 600 = peace terms 20 cheaper; Fear 800 = anyone has a containment casus belli. (Respect 300's first
  pick and Fear 300's deterrence are AI rules, WP10.) Other species keep Reputation (WP3).
  Precedence (Vess'kar): +2 Council votes; one veto a session (AI: a passed resolution it scores at -20 or
  less; player: `precedence_veto`); stagnation +1 a year without signing a treaty, passing its own resolution
  or winning a war, -2% job output per point beyond 5 (to -20%).
  Brood Surge (Krothi): `brood_surge {colony}`: 6+ pops, 2 pops and half a corvette's components become a
  Krothi corvette after 15 days; a colony once per 6 months.
  Contracts (Ohlan): `hire_mercenaries`: 300 credits + 30 a month, 3 Ohlan destroyers for 12 months (they
  leave when time or money runs out); +5% of the value of goods its freighters deliver in deals; +3 credits a
  month per trade agreement.
  Sanctuary (Thessari): colonies with 5+ pops keep planetary defences (`core:station/planetary_defence`, a
  defensive platform, free, not buildable; one per 10 pops, at least one), which fight in battles in the
  system; others' opinion +10; defence pacts, alliances and protectorates proposed to them +10 acceptance.
  Stations gain `buildable` (false for planetary defences).
- 2026-10-02 (WP10): `StrategicAI` (month phase 5, after the Council). E11: each empire's weights are its
  species' defaults +-15 on the `ai` stream at match start (`Empire.personality`; every personality term now
  reads them). E12: each month an AI scores candidates and takes the best `actions_per_month` (2; difficulty
  sets `Empire.ai_actions`, WP12): treaties it would get (E5 >= 0; weight by Caution for non-aggression,
  Greed for trade, Aggression/2 for access, Xenophilia for pacts and alliances, +15 x5 when a stronger hostile
  neighbour exists), war (from year 10 only, E16; a target within 6 lanes, power at least 1 + Caution/100
  times its own, a casus belli unless Aggression >= 80; cautious AIs leave humans with Fear 300 alone),
  peace (losing at -20 or exhausted at 75: white peace; winning at +10 with exhaustion 37.5 or score 30:
  its war goals, then reparations, within what the score buys), claims (Aggression >= 50: a disliked
  neighbour's border system, one a month), Council proposals (Ambition >= 50: sanctions on an empire it
  likes at -40 or less, recognition of a liked non-member, Trade Standards at Greed 60, Pirate Suppression at
  Caution 60 with raiders about) and protectorate requests when threatened (humans with Respect 300 first).
  Numbers in a new `ai_rules` Def. Economy harness sanity (neutral, seeds 1-4): 11 of 16 (13 before); the
  full economy and expansion pass (Thessari floor) stays with WP14.
- 2026-10-03 (WP11): the military autopilot goes to war. Threats in allied and protected systems count like
  its own (calls to arms, guardian duty within E8's 60 days). Fleets under 50% hull head for the nearest own
  shipyard system. At war, idle fleets beyond a home reserve (fleet value x Caution x 0.5%) attack: systems
  where enemy warships sit, when they bring at least `ai_attack_ratio` (1.5x) of their battle value, else enemy
  colony systems with no enemy warships (blockades score war points; their armed stations count), nearest
  first, one fleet a target. Retreat in battle stays with fleet doctrine (A10). Numbers in ai_rules.
- 2026-10-03 (WP12): `difficulty` Defs (E13): Cadet (AI job output -20%, 1 strategic action a month), Officer
  (0, 2), Commander (+15%, 3), Admiral (+30%, 3), per AI slot in match setup (default Officer), applied at match
  start (`Empire.ai_output`, `ai_actions`); Admiral's +1 intel level and Deathworld wait for intel (M5).
  Match setup also offers a founding Council seat per slot and shows the selected species' personality, traits
  and signature mechanic; the difficulty tooltip lists every bonus from the data.
- 2026-10-03 (WP13, owner decision: F5): the Diplomacy screen (near full screen) with Empires (their view of you
  with the opinion breakdown, trust, both fleets, treaties with age and notice, cancel/break, the proposal
  builder: a treaty and deal items you give / they give with amounts and months, the live E5 breakdown and
  verdict, claims, declaring war with or without a casus belli), War (each war's casus belli, score and
  exhaustion, a terms builder showing the cost against what they would accept, demand / white peace, the war
  footing), Council (members, next session, your votes, resolutions in force with repeal, the next session's
  proposals with your vote and the Precedence veto, proposing, the last session's results) and Inbox
  (proposals, peace offers and calls to arms with their answers). The header shows the signature meter,
  Reputation and exhaustion (and Hire mercenaries for the Ohlan); the planet panel offers Brood Surge. Alerts
  for proposals, peace offers and calls to arms. The M3 Empires tab is gone from the Fleets screen.
- 2026-10-04 (WP14, owner decisions 2026-10-03): balance and performance pass.
  Owner decisions: trust recovers +1 every 18 months at peace up to 20 (`trust_recovery_*`); battle reports keep
  the newest 100 (`combat_rules.report_keep`); breaking a treaty also ends the pair's other treaties cleanly
  (no penalty to the victim), so trust rebuilds from 0; until research and intel pacts exist the defence pact
  needs opinion 30 and the alliance 40 (E4, was 40/50; trust gates unchanged); a non-member with the goodwill
  of most Council members (opinion 0 or more) may apply for its own Recognition (30 influence), as AI empires
  do and players can from the Council tab. Player build controls (stations, shipyard queues) are WP15, after
  WP14: the sim had them since M2/M3 but no milestone gave the player the UI.
  Economy AI: freighters serve the largest deficit first, so warship builds took every alloy and farms, mining
  sites and outposts stalled for years; at peace and past half the minimum fleet the AI starts no warship while
  a civilian build has stalled over `combat_rules.ai_civilian_stall_days` (30; raided systems don't count),
  only starts one it can pay for in full, and never ahead of a civilian ship. Mining queues deposit miners
  first, and an empire short of rare earths (< 100) builds a rare earths mine on a deposit colony even while a
  mining station is unfinished (without rare earths Fabricators make no components and shipyards stall).
  Diplomacy AI: idle scouts fly to the nearest system of an empire not met yet (AI empires many lanes apart
  never met, so AI diplomacy never started); treaties and Council proposals keep a system claim's worth of
  influence while the empire expands (early treaties held first colonies back to month 15-32); an AI proposes
  only treaties its own E4 gates allow (no pact offered to a betrayer); no new war while its war exhaustion is
  above `ai_rules.war_max_exhaustion` (25; one AI declared and white-peaced the same neighbours monthly); a
  refused applicant waits `council_reapply_months` (72) before applying again.
  Performance: each AI empire's monthly turn (autopilot, military autopilot, strategic AI) runs in its own hour
  after the diplomacy hour (`Sim.AI_PHASE`, `EMPIRE_HOURS` 8) and each empire's daily auto-logistics in its own
  hour of the day; fleet supply builds each owner's supply points (with military access) once a day; freighters
  idle at home skip planning; colony production hoists empire-wide modifiers. Huge, 8 AIs, year 15 with a war:
  worst sim hour 121 -> 41 ms headless, 8x 61 fps average (60.8-61.6 over three runs; worst frame ~185 ms).
  `tools/perf_huge.gd` runs it and saves the match for the FPS check.
  Results: `tools/diplomacy_harness.gd` (all-AI, and a scripted honourable player that courts one AI with
  gifts of credits and surplus goods, proposes only what the AI would accept and breaks its first alliance
  once): medium, 6 empires, 30 years: no unprovoked AI war on a human-species neighbour (first AI war year
  15); Council resolutions 8 of 16 passed (50%); bot alliance in year 9, trust rebuilt in 15 years
  (small, 50 years: alliances in years 5 and 7, rebuilt in 16 and 18). Economy harness (20 seeds, small,
  4 AIs): neutral 69 of 80 (accepted 65), species 70 of 80 (humans 19, Vess'kar 18, Thessari 17, Krothi 16 of
  20). Remaining B20 misses are mostly the alloy band's top (strong economies over 140 a month). Combat harness
  unchanged at A14 and the species target.

---

## Goal of M4

A match where empires behave like rival civilisations:
- **five distinct species**: traits (A13, B), AI personalities (E11), base affinities (E2), species-flavoured
  standard designs, and their **signature mechanics**: Legend (humans), Precedence (Vess'kar), Brood Surge
  (Krothi), Contracts (Ohlan) and Sanctuary (Thessari),
- **relations**: opinion with decaying modifiers and slow-moving trust per directed pair (E1-E3), plus
  Reputation for every species and the full Legend meter for humans (E14),
- **treaties** with the acceptance formula shown to the player (E4, E5), minimum durations and break
  penalties, call-to-arms obligations,
- **deals** trading credits, influence, resources (delivered by convoy) and claimed systems (E6, B15),
- **war** with casus belli, war goals, war score, war exhaustion and negotiated peace, including ceded
  systems (E7), and **war footing** (D7),
- a **minimal Galactic Council**: membership and recognition, sessions, a handful of resolutions, AI voting
  and the Vess'kar veto (E9),
- **AI empires** running the E12 strategic loop on top of the shared automation: expansion, treaties,
  wars (including offensives), peace-seeking and Council votes, with **difficulty levels** (E13),
- the **Diplomacy screen** (F14) with the acceptance breakdown, deal builder, war and Council tabs,
- harnesses for the E16 balance targets, with determinism, economy, combat and performance still green.

No research tree, intel or fog of war (M5), ground war or occupation (M6), events, crises or minor species
(M7), victory screens or campaign (M8), or the general mod-script API (M9).

## Scope decisions (2026-10-02)

| Question | Decision |
|---|---|
| Signature mechanics | **All five + a minimal Council.** Legend (Respect/Fear) and Precedence come now with a minimal Galactic Council; Brood Surge, Contracts and Sanctuary too. Other species get the plain Reputation track (E14). |
| What a war can win | **Peace deals including systems.** War score from battles, convoy raids and blockades (E7); peace terms: white peace, reparations, humiliation and ceding claimed systems, colonies included (ownership and pops transfer). Occupation feeds war score from M6. |
| Trade and deals | **Deals with convoy delivery.** Credits, influence, resources (physically delivered, B15/E6) and claimed systems. A trade agreement lets deals and freighters cross borders and gives its opinion bonus; Trade Stations and passive trade income wait for a later economy pass. |
| Alien ship models | **Later.** Other species keep tinted human models; species ship sets are a dedicated asset task in a later milestone. |
| Treaties | **All but research and intel:** non-aggression, trade agreement, military access, defence pact, alliance and protectorate (between empires: a weak empire under a stronger guardian, E8). Federation, research pact and intel sharing later. |
| AI military | **Full war AI:** E12 loop picks war targets by personality and power, declares with a casus belli, masses fleets, attacks fleets, stations and convoys, blockades, answers calls to arms and sues for peace by war score and exhaustion. |
| War footing | **Yes:** D7 as specced (output shifts, 60-day transition, demobilisation dip, war-weariness scaling); the AI sets it by threat. |
| Difficulty | **Honest levels:** Cadet to Admiral (output bonus, AI actions per month, all listed in match setup). Deathworld's full-vision cheat waits for fog (M5). |

## Carried over from M3

- The M3 war/peace toggle is replaced by real war declarations and peace deals (WP6); a dev-only debug
  command keeps forcing war for tests and harnesses.
- AI production planning (owner, M2 and M3 sign-off: revisit in M4) is reviewed inside WP10, where the
  strategic loop decides military versus economy spending.
- Battle reports are never pruned (about 190 by year 15 in a huge galaxy, a quarter of the save): WP14
  decides a cap or archive rule.

---

## D1. Work Packages

### WP1: Species Content & Traits · M
**Spec:** main spec 10.1-10.3, C (SpeciesDef row), A13, B4, E2, E11
- `SpeciesDef` grows to the C schema: `traits[]`, `ai_personality{}`, `affinity{species: int}` (E2 table),
  `signature_mechanic`, design bias; new `TraitDef` category (modifiers plus named rule hooks).
- Content for the five species: traits (humans: Deathworlder, Stubborn, Pack Bonding, Improvisers,
  Persistence Hunters; the other species' traits from their archetypes, proposed at the WP), personality
  defaults (E11 table), affinities (E2), species standard designs re-done to each military bias (Vess'kar
  energy and shields, Krothi mass corvettes and fighters, Ohlan missiles and ECM, Thessari shields and PD).
- Trait effects wired: kinetic damage +100‰ and hull +100‰ (humans, A13), Stubborn morale resist 700 and
  Last Stand (A10), Persistence Hunters pursuit (A10), Improvisers salvage +50% (A12), Deathworlder
  habitability floor (B4). Combat harness re-run for the species matchups.

### WP2: Signature Mechanic Framework · S
**Spec:** C9 ("signature mechanics as modules"), C (`register_signature_mechanic`)
- A sim-side `SignatureMechanic` base (deterministic hooks: month tick, battle resolved, command applied,
  treaty events) registered per species from `SpeciesDef.signature_mechanic`, with per-empire mechanic
  state (ints and strings, saved, in the checksum). The general ModApi stays M9; this is its first slice and
  the five core mechanics are its examples.

### WP3: Relations · M
**Spec:** E1-E3, E14 (Reputation), main spec 9.2
- Per directed pair: opinion (base affinity + modifiers, each with value and decay), trust (deeds only).
- Contact: full visibility in M4, so first contact happens when two empires' territories come within a
  contact range (open question 1); before contact, no diplomacy.
- Modifier sources available in M4: shared border, overlapping claims, common enemy, treaties, gifts, fought
  together, rescued, denied request, treaty broken, at war, humiliated (salvaged ships and espionage wait
  for their systems).
- Reputation (−500…+500) for every empire from E14 events at half values; `diplomacy` checksum part.

### WP4: Treaties · L
**Spec:** E4, E5, E8, main spec 9.4
- `TreatyDef` data (influence, thresholds, minimum duration 5 years, break penalties, effects).
- Commands: propose (with an attached deal), accept, decline, cancel/break; the AI answers by E5 with the
  full breakdown recorded for the UI; recent-refusal penalty.
- Effects: non-aggression (12-month notice before war), trade agreement (cross-border deals and freighter
  passage), military access (passage and resupply in their space, B12), defence pact and alliance
  (call-to-arms; ignoring it costs trust), protectorate (guardian obligation: a fleet in an attacked system
  within 60 days; tribute; failure penalties).
- Coalition battles: allies on one side of a battle (battles become two coalitions, not two owners).

### WP5: Deals · M
**Spec:** E6, B15
- Deal model: items both ways (credits, influence, resources, claimed systems; one-off or recurring).
- E6 valuation (base value × amount × scarcity × greed; recurring at 60%), shown in the deal builder.
- Physical goods delivered by convoy: a delivery job on either side's freighters; the deal completes on
  arrival, raided deliveries fail it with the opinion hit (E6).
- System transfer: ownership of the system, its colonies (pops keep their species), stations and claims.

### WP6: War · L
**Spec:** E7, E14 (war without casus belli)
- Claims (influence 25 each) and casus belli: claim, retaliation, protectorate defence, containment
  (liberation and crisis mandate wait for M6/M7). War without one: Respect/Reputation −200, opinion −20 from
  everyone, allies won't join.
- Declaration names war goals; allies are called in (defence pact, alliance, protectorate).
- War score per side pair: battles won, convoys raided, blockades (occupation and derelicts later).
- War exhaustion: fleet losses, Total War months (humans ×0.35); effects at 50/75/100 (forced status quo).
- Peace: offers with terms (white peace, reparations by convoy, humiliation, cede claimed systems,
  disarmament), AI acceptance `cost ≤ war score + (their exhaustion − yours)/2`, treaty-like enforcement.
- Replaces the M3 toggle (kept as a debug command).

### WP7: War Footing · S
**Spec:** D7
- Empire war footing (Peace / Mobilised / Total War): output modifiers, 60-day transition at half effect,
  demobilisation stability dip, war-weariness gain scaling; command and AI rule.

### WP8: Galactic Council (minimal) · M
**Spec:** E9
- Founding members (Vess'kar plus settings), recognition votes, votes per member, sessions every 2 years,
  one proposal per member per session (influence 30).
- Resolutions as Defs (subset, open question 3): Trade Standards, Sanctions on X, Pirate Suppression
  Mandate, Recognition of X; defiance penalties; the AI votes by personality and opinion.

### WP9: Signature Mechanics · L
**Spec:** main spec 10.1, 10.4, E14, E9 (Precedence), owner placeholders for the rest
- **Legend** (humans): Respect and Fear 0-1000 from E14 events available in M4; thresholds (opinion bonus,
  protectorate first pick, Fear deterrence and cheaper peace, containment coalition at Fear 800).
- **Precedence** (Vess'kar): +2 Council votes, one veto per session, stagnation rule (open question 2).
- **Brood Surge** (Krothi), **Contracts** (Ohlan), **Sanctuary** (Thessari): mechanics proposed at the WP
  from main spec 10.1 (no numbers in the specs yet; open question 2).

### WP10: AI Personalities & Strategic Loop · L
**Spec:** E11, E12, D10
- Personality weights per AI empire (SpeciesDef defaults ±15 on the `ai` stream).
- Monthly loop: assess (power ratios, threats within 6 lanes, economy, exhaustion), score candidate actions
  (expansion, treaty proposals and answers, war declaration, peace offers, military vs economy, war footing,
  Council proposals and votes), take the top N actions (by difficulty) as Commands; grudges as long-decay
  modifiers. Absorbs the M2/M3 autopilot rules and revisits AI production planning.

### WP11: AI War Operations · L
**Spec:** E12, A (doctrine), M3 MilitaryAutopilot
- Offensive operations: choose targets (enemy fleets, stations, convoy routes, blockade points), mass
  fleets, set doctrine, attack, reinforce, retreat when beaten; defend allies and protectorates in time;
  keep a home reserve by Caution.

### WP12: Difficulty & Match Setup · S
**Spec:** E13, F15
- Difficulty per AI slot or match (Cadet, Officer, Commander, Admiral): output bonus and actions per month,
  listed openly; Council founding seats; species picker shows traits and signature mechanic.

### WP13: Diplomacy UI · L
**Spec:** F14, F12 (alerts), F2 (top bar)
- Diplomacy screen (full screen): empires list with opinion and trust, opinion breakdown, treaties with
  time left, propose with the live acceptance breakdown and tip, deal builder (you give / they give, delivery
  time and route risk), war tab (war goals, war score, exhaustion, peace offers), Council tab (session
  countdown, resolutions, expected votes).
- Incoming proposals, calls to arms and peace offers as alerts and a decision panel; Legend / signature
  meter in the top bar; war footing control. Replaces the M3 Empires tab.

### WP14: Diplomacy Balance & Performance Pass · M
**Spec:** E16, B20, A14, M3 DoD
- `tools/diplomacy_harness.gd`: all-AI matches reporting first war year, unprovoked wars on human-species
  neighbours, alliances formed, treaties broken, Council pass rate, wars and peace outcomes.
- E16 targets; economy and combat harnesses still at their accepted levels; huge-galaxy performance bars.
- Battle report retention rule.

### WP15: Player Build Controls · M
**Spec:** F4 (planet panel: buildings and orbitals), F12 ("Shipyard idle [Queue]"), main spec 5 (build stations,
shipyard queues). Added 2026-10-03 (owner decision): the sim has built stations and ships since M2/M3 and the AI
uses them, but no milestone gave the player the controls, so a human could only watch.
- Planet panel: queue any allowed building (not only the governor's suggestion); an Orbitals list with every
  station the planet's free slots allow (cost, build days, the reason when blocked) and upgrades.
- Shipyard panel: the queue with civilian hulls (freighter, colony ship, scout) and the empire's saved designs,
  reorder and cancel; "Build at..." from the Ship Designer; the "Shipyard idle" alert opens it.
- All through the existing Commands; keyboard-navigable; loc keys.

---

## D2. Dependency Order

| WP | Needs |
|---|---|
| WP2 | WP1 |
| WP3 | WP1 |
| WP4 | WP3 |
| WP5 | WP3 (WP4 for trade agreements) |
| WP6 | WP4, WP5 |
| WP7 | WP6 |
| WP8 | WP3 |
| WP9 | WP2, WP3, WP6, WP8 |
| WP10 | WP3-WP9 |
| WP11 | WP6, WP10 |
| WP12 | WP10 |
| WP13 | grows alongside: relations with WP3, treaties and deals with WP4/WP5, war with WP6, Council with WP8 |
| WP14 | everything |
| WP15 | WP13 (after WP14, owner decision) |

## D3. M4 Definition of Done

- [ ] All WP acceptance criteria met.
- [ ] `tools/run_tests.sh` green; determinism harness green (20 seeds × 4 sizes, with diplomacy checksums).
- [ ] Diplomacy harness meets the E16 targets: no unprovoked AI war on a human neighbour before year 10 on
      Officer; an honourable player can reach an alliance with at least one AI by year 30 in a Medium galaxy
      (scripted honourable-player bot); breaking a major treaty costs 15-25 years of trust; Council
      resolutions pass 40-60% of the time.
- [ ] Economy harness at least at the accepted level (65 of 80); combat harness at the A14 targets.
- [ ] Huge galaxy, 8 AI empires at year 15 with wars under way: 8× speed holds ≥ 60 fps; worst hour under
      50 ms headless.
- [ ] No Sub-spec E numbers in code (data only); content validation green.
- [ ] Sim lint green; every player-facing string uses a loc key; all M4 screens keyboard-navigable.
- [ ] Spec change logs updated with every decision made during the build.

## D4. Open Questions (to settle at the WP, recorded in the change logs)

The specs give no number or rule for these; the WP proposes a placeholder and asks before relying on it.
1. **First contact** (WP3): with full visibility, when two empires meet (territory within N lanes, a ship
   entering their space, or contact with everyone from the start).
2. **Signature numbers** (WP9): Brood Surge (pop-to-ship conversion rate, food burden), Contracts
   (mercenary fleet hire, trade-route ownership in others' space, convoy profit), Sanctuary (planetary
   defence strength, protector attraction), Precedence stagnation.
3. **Council resolutions** (WP8): which subset ships in M4 (Kinetic Bombardment Ban needs bombardment, M6).
4. **Non-human traits** (WP1): the trait lists and numbers for Vess'kar, Krothi, Ohlan and Thessari.
5. **Victory conditions** (E15): whether any victory check runs in M4 or all wait for M8's end-game screens.
6. **Non-state actors** (E10): pirate bribes and deniable raiders, conglomerate contracts (overlaps
   Contracts) in M4 or later.
7. **Protectorates without minor species** (WP4): which empires may request protection (power < 40% of a
   hostile neighbour, E8) and what tribute they offer.
8. **Coalition battles** (WP4/WP6): more than two owners per battle as two coalitions; how doctrine and
   salvage split.
