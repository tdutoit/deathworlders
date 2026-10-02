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
