# DNGRZ - Game Design Spec

**Engine:** Godot 4.5 (Forward Plus)
**Genre:** Competitive arcade baseball with Phenom-based team building
**Platform:** PC (initial), with online-first architecture
**Monetization:** Free-to-play, cosmetic-only
**Target match length:** 10-20 minutes per game

## Overview

DNGRZ is a competitive arcade baseball game that combines the accessible, ability-driven gameplay of Mario Superstar Baseball with the strategic depth of deckbuilding games like Magic: The Gathering. Players build rosters of fantasy characters called **Phenoms**, each with unique abilities and faction synergies, then compete in online matches with ranked ladders, drafting, and sideboarding.

The game is designed for esports from the ground up -- with matchmaking, bo3/bo5 series formats, and spectator-friendly information asymmetry -- while remaining easy to pick up for casual players.

**Core inspirations:**
- Mario Superstar Baseball (arcade baseball with character abilities)
- Magic: The Gathering (constructed/draft formats, sideboarding, faction synergies)
- Banana Ball (rule modifications that cut slow parts and amplify exciting parts)
- Rocket League (easy to learn, massive skill ceiling)

## 1. Core Game Loop: Phase-Based Rhythm

The game alternates between **tactical phases** (strategic decisions) and **action phases** (arcade baseball execution). This creates a rhythm similar to a fighting game's neutral-vs-combo flow or football's play-call-before-the-snap structure.

### Phase Flow

1. **Inning Setup** (Tactical Phase, ~10-15s)
   - Top of each half-inning
   - Defensive player: positions fielders, activates zone abilities, sets defensive strategy
   - Offensive player: can observe fielder positions (but not hidden zones) and plan approach
   - Longer timer since there's more to set up

2. **Pre-Pitch** (Tactical Phase, ~5-8s)
   - Before each pitch
   - Both players make micro-adjustments simultaneously
   - Defensive: shift fielders, queue ability activations
   - Offensive: adjust batter stance, queue baserunner commands, activate offensive zones
   - Timed to keep pace up -- this is the "play call before the snap"

3. **The Pitch** (Action Phase)
   - Real-time arcade execution
   - Pitcher selects pitch type, location, and executes with timing/input mechanics
   - Batter reads pitch, tracks location, times swing
   - Pure skill-based duel -- the heartbeat of the game

4. **The Play** (Action Phase)
   - Ball in play: fielding, throwing, baserunning in real time
   - Zone effects trigger when interacted with (ball passes through, runner crosses)
   - Crowd momentum shifts based on outcomes

5. **Resolution**
   - Outcome resolves (out, hit, run scored, etc.)
   - Cooldowns tick, resources update
   - Crowd momentum meter adjusts
   - Loop back to Pre-Pitch, or Inning Setup if 3 outs

### Design Principle: Layered Skill Expression

New players can completely ignore tactical phases. The game auto-positions fielders and uses default setups, letting beginners just play baseball. Depth reveals itself as players improve:

1. **Mechanical execution** -- can you throw/hit accurately (accessible floor)
2. **Pitch-vs-bat reads** -- can you outthink your opponent in the duel (mid-level play)
3. **Zone/tactical play** -- are you leveraging field setup to maximize advantages (competitive ceiling)

### Match Structure

- **5 innings per game** (~12-18 minutes target)
- Modified baseball rules in the spirit of Banana Ball -- cut the slow parts, amplify the exciting parts (specific rule modifications TBD during prototyping)
- Bo3 series for ranked constructed (Bo5 at higher tiers and tournaments)
- Single games for draft mode ranked

## 2. Pitch vs. Bat: The Core Duel

The pitch-versus-bat exchange is the foundation everything else builds on. It needs to be genuinely skill-based with its own depth, independent of the zone/tactical layer.

### Pitching

- Pitcher selects **pitch type** (fastball, breaking ball, changeup, plus Phenom-specific fantasy pitches)
- Chooses **location** within/around the strike zone
- Timing/input mechanics affect **accuracy and movement** -- execution matters
- Pitch sequencing creates mind games: setting up a fastball with two changeups, like frame traps in a fighter
- Great pitchers hit their spots, mix speeds, and exploit batter tendencies

### Batting

- Batter reads pitch type out of the hand
- Tracks location and times the swing
- Swing timing and cursor placement determine **contact quality and launch angle**
- Discipline matters -- laying off bad pitches, recognizing breaking balls
- Great batters download pitcher tendencies over a series

### Mind Game Layer

- Pitchers have tendencies batters can read ("always goes offspeed on 0-2")
- Batters have tendencies pitchers can exploit ("can't lay off the low breaker")
- Count leverage creates pressure situations (full count, bases loaded, crowd roaring)
- Zones add another dimension: pitcher induces contact toward defensive zones, batter aims toward their own zones or away from discovered enemy zones
- But none of this matters if you can't execute the pitch or make contact -- fundamentals first

## 3. Phenoms: Roster Architecture

**Phenoms** are the playable characters. Each Phenom has:

### Core Attributes

- **Position proficiency** -- which baseball positions they can play and how well (e.g., elite at shortstop, decent at second base, weak in outfield)
- **Stats** -- batting power, contact, speed, arm strength, fielding, pitching repertoire (if they can pitch)
- **Passive ability** -- always active, defines their identity (e.g., "gains momentum from stolen bases," "zone effects last one extra pitch")
- **Tactical ability** -- activated during tactical phases, costs a resource or has a cooldown (e.g., "place a wind zone in the outfield," "buff adjacent baserunners' speed")
- **Signature play** -- high-impact ability requiring full crowd momentum to activate (star pitch, star swing -- the highlight reel moment)

### Variants

Alternate versions of the same Phenom with different stat distributions and ability kits. Same character identity, same faction, same passive -- different competitive role.

Example: A fire mage Phenom's base version might be an aggressive power hitter. Their variant could be a control-oriented pitcher. This allows deep roster customization and creates meaningful progression without power creep.

Every Phenom's **base version is free on day one**. Variants are earned through gameplay progression (packs). Variants are sidegrades, never upgrades.

## 4. Factions & Synergies

Phenoms belong to **factions** -- thematic groupings that create synergy bonuses when you stack multiple members.

### Synergy Tiers

- **2-piece bonus** -- small, flexible perk (e.g., +1s to your tactical phase timer)
- **4-piece bonus** -- significant tactical advantage (e.g., "zone effects cover 20% more area")
- **Full faction (6+)** -- powerful identity-defining bonus, but locks you into narrow sideboarding

### Deckbuilding Tension

The core roster-building decision: go deep into one faction for the big payoff, or spread across two factions for flexibility and better sideboarding options. This mirrors the deckbuilding tension in MTG between mono-color and multi-color strategies.

### Tempo Archetypes (via Faction Design)

Factions are designed to support distinct competitive archetypes:

- **Aggro factions** -- Phenoms that generate crowd momentum fast, reward short tactical phases, want to keep pressure on and deny the opponent setup time
- **Control factions** -- Phenoms that slow momentum swings, extend tactical phases, get extra value from zone setup, and compound advantages over time
- **Midrange factions** -- Flexible Phenoms that perform consistently regardless of tempo, adapt to the opponent's pace
- **Combo** -- Specific multi-Phenom synergies that require setup across tactical phases but pay off huge (e.g., a 3-Phenom trigger creating a massive zone effect)

## 5. Crowd Momentum System

Momentum is the **tempo control mechanic**, thematically represented as the crowd's energy. It determines who controls the pace of the game.

### How Momentum Works

- Shared tug-of-war meter that shifts based on in-game events
- Getting hits, stealing bases, making highlight defensive plays, and activating signature plays generate momentum
- The crowd visually and audibly shifts toward the side with momentum -- colors change, noise shifts, banners wave

### Momentum Effects

- **High offensive momentum** -- batter's side gets more time in tactical phases or extra tactical actions. Defense feels rushed.
- **High defensive momentum** -- pitcher's side can compress tactical windows (quick-pitch, shortened pre-pitch). Batter has less time to read and adjust.
- **Neutral** -- standard timers for both sides.

### Signature Plays

Full crowd momentum unlocks **signature plays** -- each Phenom's ultimate ability. These are the highlight-reel moments: a devastating star pitch, an impossible star swing, a game-changing fielding play. They require building and maintaining momentum to access, creating natural climactic moments.

### Phenom Tempo Tools

Some Phenoms have abilities that interact directly with momentum:
- "Call Time" -- spend a resource to force an extended tactical phase (batter slowing things down)
- "Quick Pitch" -- spend momentum to skip/shorten the next tactical phase (pitcher pushing pace)
- Passives that generate momentum from specific actions (a speedster from stolen bases, a power hitter from extra-base hits)

### Esports & Spectator Value

The crowd system creates natural broadcast moments. Casters don't need to explain an abstract meter -- "listen to that crowd, the offense has FULL momentum" is instantly understood. Momentum swings are visible and audible, making the game exciting to watch at any level.

## 6. Field Zones & Information Asymmetry

The field is a tactical space where both players place invisible ability zones during tactical phases.

### Zone Mechanics

- Zones are placed during tactical phases using Phenom abilities
- **Zones are invisible to the opponent** -- fog of war on the field
- Zones only reveal when something interacts with them (batted ball passes through, runner crosses)
- **Spectators see all zones from both sides** -- full information broadcast view
- Discovered zones stay revealed for the rest of that half-inning
- Between innings, defense can reposition zones, resetting the fog of war

### Zone Types (Examples)

**Defensive zones:**
- Frost zone -- reduces ball speed passing through (kills line drives)
- Blaze zone -- increases fielder error rate in the area
- Gravity zone -- pulls batted balls downward (turns fly balls into grounders)

**Offensive zones:**
- Tailwind zone -- increases ball carry (turns warning-track flies into homers)
- Spark zone -- increases baserunner speed through the area
- Shield zone -- nullifies one defensive zone it overlaps with

### Information Economy

- Early at-bats are partly about **scouting** -- probing the field to discover what's out there
- Players may sacrifice an at-bat to intentionally hit to certain areas for information
- Late in an inning, the batter has more info and can exploit discovered zones
- Defense balances optimal zone placement vs. being predictable across innings
- Some Phenoms have **scout abilities** that reveal zones passively, adding roster value beyond raw stats

### Strategic Depth

**Defensive mind games:**
- Place zones where you predict hits will go
- Bait hitters into zones with fielder positioning
- Move zones between innings to stay unpredictable

**Offensive scouting:**
- Sacrifice early at-bats to probe the field
- Place offensive zones to counter discovered defensive setups
- Phenoms with scout abilities become high-value draft picks

## 7. Competitive Modes

### Constructed Mode -- "Bring Your Deck"

Pre-built roster, queue into ranked or casual:

| Slot | Count | Purpose |
|------|-------|---------|
| Starters | 9 | Batting lineup + fielding positions |
| Bench | 4 | Mid-game substitutions (pinch hitters, relief pitchers, defensive replacements) |
| Sideboard | 3 | Swaps between games in a Bo3/Bo5 series |
| **Total** | **16** | |

- Faction synergy bonuses calculated from 9 starters
- Bench subs can shift synergy mid-game (subbing in a 4th faction member to hit the 4-piece bonus)
- Sideboarding between games: swap any sideboard Phenom for any bench or starter
- Enables adjusting faction balance, swapping variants, or bringing in counter-picks based on game 1 scouting

### Draft Mode -- "Adapt and Overcome"

Live pick-phase against your opponent:

- **Ban phase** -- each player bans 2-3 Phenoms
- **Snake draft** -- alternating picks (A, BB, AA, BB...) building a 9-Phenom roster from a shared pool
- No sideboard -- single game format
- Faction synergies still matter, creating tension between best-available picks and synergy building
- Tests adaptability, valuation, and opponent reads rather than pre-built optimization

### Ranked Ladder

- **Separate ranks** for Constructed and Draft
- Constructed ranked: Bo3 with sideboarding (Bo5 at higher tiers)
- Draft ranked: single games
- Seasonal resets with cosmetic rewards
- MMR-based matchmaking with visible rank tiers

### Casual / Unranked

- Quick play queue for both modes (single games, no series)
- For testing rosters, warming up, or playing with friends

### Tournament Support

- Built-in bracket system for community-organized events
- Bo5 with full sideboard for tournament constructed
- Draft tournaments with Swiss or elimination formats

## 8. Progression & Monetization

### Progression Currency: Hype

Earned through gameplay, spent on Phenom variant packs:

- **Match completion** -- win or lose, winners earn more
- **Daily/weekly challenges** -- "Strike out 10 batters," "Win a draft game with 3+ factions"
- **Ranked milestones** -- first time hitting a new tier each season
- **Highlight plays** -- signature plays, clutch moments recognized by the game

### Phenom Variant Packs

- Purchased with Hype (earned currency only)
- Contain alternate Phenom variants (sidegrades with different stat spreads and ability kits)
- **Every base Phenom is free from day one** -- packs expand options, never gate competitive access

### Cosmetic Monetization (Real Money)

- **Phenom skins** -- alternate visual designs, effects, animations
- **Stadium themes** -- custom field aesthetics, crowd visuals, atmosphere
- **Signature play effects** -- cosmetic flair on highlight moments (home run celebrations, strikeout animations)
- **Crowd packs** -- themed crowd visuals and audio
- **Season pass** -- cosmetic reward track with free and premium tiers

**No gameplay advantage is purchasable.** A stock Phenom with no skins plays identically to a fully cosmetic-equipped one.

### Seasonal Content

- New Phenoms added each season (base version free for all players)
- New variants for existing Phenoms added to the pack pool
- Seasonal ranked rewards (cosmetics)
- Limited-time event modes (home run derby, all-star draft, modified-rule games)

## 9. Setting & Tone

- **Original fantasy universe** -- not tied to any existing IP
- Phenoms are unique fantasy characters with distinct personalities, visual designs, and lore
- Factions represent thematic groupings (elemental, mechanical, nature, shadow, etc. -- specific factions TBD)
- Tone is **accessible and fun but with competitive edge** -- not grimdark, not childish. Think Rocket League or Splatoon energy.
- The sport itself is called **Dingerz** in-universe, and Phenoms are the athletes who play it
- World-building supports the game without requiring lore engagement -- you can ignore it entirely and just compete

## 10. Open Design Questions

Items to resolve during prototyping and further design iteration:

- **Specific baseball rule modifications** -- which traditional rules to cut/modify for pace and fun (innings length, extra innings format, stealing rules, etc.)
- **Faction definitions** -- how many factions, their thematic identities, and specific synergy bonuses
- **Starting roster size** -- how many base Phenoms ship in the initial release
- **Zone ability budget** -- how many zones can each player place per inning, resource costs
- **Momentum meter tuning** -- how fast it swings, thresholds for tactical phase timer modifications
- **Pitching/batting input mechanics** -- specific control schemes for pitch selection, swing timing, fielding
- **Camera system details** -- default view, wide tactical view toggle, transitions between phases
- **Netcode architecture** -- rollback vs. lockstep, server authority model for competitive integrity
- **Anti-cheat considerations** -- fog of war requires server-side zone state, clients should never receive opponent zone data until triggered
