# Changelog

## 1.0.0 beta

The first release: the [TBCrushCalc app](https://github.com/kcham01/TBCrushCalc), one for one, inside the game on the TBC Anniversary realms. Type `/tbcc`.

- **Character pane** with every equipment slot, quality colours, gem and enchant markers and the game's own item tooltips. If the character is the race you're playing, it shows in 3D wearing the planned gear. Stat panels for base stats, defenses, melee, ranged and spells.
- **Every TBC item** a warrior, paladin or druid can wear (14,000+), with filters for phase, level and armor type, search, and sorting by avoidance.
- **Gems and enchants** for every socket and slot. Ones that can't go on an item stay in the list with the reason.
- **Talents** laid out like the game's talent frame, with the tree paintings, prerequisite arrows and rank badges.
- **Buffs**: every flask, elixir, food, scroll and potion; raid buffs, boss debuffs and world buffs; stances, cooldowns and on-use trinkets.
- **66 TBC raid bosses** with their level, swing speed, attacks and abilities.
- **Caps**: crush cap (gear only, with your block cooldown, with procs), the attack table, damage taken, crit cap, Holy Shield and Shield Block charge coverage, Illidan's Shear, what closes the gap, and where every number comes from.
- **Load the character you're playing**: gear, gems, enchants and talents read from the game, including items the Anniversary realms reissued under new ids.
- **Alts and share codes**, the same codes as the phone app, both ways.

Fixed during testing in game:

- The item data didn't load (the game loaded it before the main addon). It now loads either way, and if it ever can't, the chat message says why.
- Search boxes only kept one letter.
- Talent tree paintings were hidden behind the panel's background.
- Race portraits used icons the Anniversary client doesn't have.
