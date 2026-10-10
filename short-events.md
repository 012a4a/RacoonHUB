# Pull A Sword short events

Checked against the current game's replicated command definitions and client modules (place version 1179). These describe supported mechanics, not a record of what actually spawned in previous shows.

| Event | What it does | Reward / useful script feature |
|---|---|---|
| SwordDrop | Spawns a random sword and size in a random mob zone. The carrier can be knocked out outside safe zones; the command describes a five-second pull. | Sword-name/rarity ESP, missing-index filtering, auto-pull, optional return after pulling. |
| CrateDrop | Spawns glove crates in mob zones. The command describes first-touch collection and a glove roll. | Crate name/location alert; no automatic collection added. |
| VaultKeys | Spawns keys in mob zones, up to one per zone. The command describes a 1.5-second hold from six studs. | Vault-key location alert; no automatic collection added. |
| Frenzy | Grants temporary one-hit NPC kills, with a rainbow outline. Admin variants target one player or everyone. | Nearby auto-hit benefits while the server buff is active. |
| Gigantomax | A giant sword contest at the Gigantomax spot: one-minute king-of-the-hill, with players shoving for points. | Most points wins; configured tiers include Valhalla, Galaxy, SciFi, Midas and Unique. A countdown/score alert could help. |
| Troopers | Spawns zone-scaled troopers. The command supports here/all/a chosen zone, up to three per area and excludes Zone 1. | Kills advance Bennet's bar; these NPCs have NoDrop=true. Troopers-only targeting uses ordinary attacks and optional walking approach. |
| TitanMob | Listed in the seven-entry server-event registry. Its implementation was not found in the exposed scripts. | Exact spawn behavior and rewards remain unverified. |

The server-event command describes a random event every 30 minutes. Admins can force events locally or globally; those forced events do not move the random-event clock.

Bennet's bar reaches 100% for the next reward. The shared reward table includes Laserblades, Void Saber and Halosplitters; Void Halosplitter has a configured 0.4% weight. The script's optional auto-claim works only within ten studs of Bennet. It opens his normal talk prompt, waits for a server-offered reward answer and the visible answer UI, then sends that answer. It does not travel to him. A real 100% claim still needs live verification; unknown dialogue wording is deliberately left unanswered.

Historical admin-show logs are exposed as admin-only commands. Their definitions do not provide this account with the past spawn log, so a list of swords that actually appeared in an earlier show cannot be confirmed from the available client data.

