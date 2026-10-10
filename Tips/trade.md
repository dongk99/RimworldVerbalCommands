# Trading, and other people you can do something with

## Who (user)
Only one pawn of a caravan can be traded with. Quest givers work the same way: one particular pawn is the
one to go to. So ask broadly first, then act on the one the answer points at.

## The steps (mod)
1. `show interactable pawns.` lists everyone in view who is not your colonist (traders, visitors, quest
   givers, prisoners, enemies) with the right-click orders the game offers on each. The trader's line says
   `TRADER: <kind>`; a trader who also has a quest says so. Trade ships in orbit are named on the last lines.
   `show interactable pawns for Bob.` asks what the game offers Bob in particular.
2. `use option trade on NAME with PAWN.` sends that colonist to the trader. OPTION is a word or two of the
   option's text, so the same sentence gives any other order from the list (a quest giver's option, a
   visitor's). NAME is as the list prints it, or the cell: `use option trade on 120, 88 with Alice.` A trade
   ship is called from a powered comms console: `use option call on X, Z with PAWN.` with the console's cell.
3. `run 1 hours.` The game opens its trade window when the colonist arrives; the window pauses the game and
   ends the run (`show speed.` says so). Until then there is nothing to see: goods and prices are only
   known at the window, as for a human player.
4. `show trade.` : silver on both sides, each thing with how many you and they hold, the price to buy and
   to sell, and what is set in the deal. `show trade for components.` shows only matching lines.
5. `trade buy 20 components.` / `trade sell 300 steel.` set lines of the deal (each replaces what that line
   was set to). Nothing changes hands yet. The numbers have to be in your order.
6. `accept trade.` settles it (the game checks the silver and moves the things) and closes the window;
   `cancel trade.` closes it without trading. The game stays paused after either: send a run.

## Things to know
- Who talks matters: prices depend on the negotiator (unchecked: on their social skill). Send the best one.
- What you can sell depends on who you trade with (source: the game's code, files named):
  - **A caravan trader on the map:** items in the home area or in any storage, not under fog, that the
    trader can reach (`RimWorld\Pawn_TraderTracker.cs:96-98`).
  - **A trade ship in orbit:** only things on cells within 7.9 tiles of a powered orbital trade beacon, in
    the same room as the beacon without passing a door (`RimWorld\Building_OrbitalTradeBeacon.cs:10, 40-76`,
    `RimWorld\TradeUtility.cs:84-134`). Your silver counts the same way: silver that is not near a beacon
    can not pay a ship. No powered beacon = nothing to sell and nothing to pay with.

## The orbital trade beacon
- What it is for: it marks what a trade ship can take. Put a stockpile under it and keep the silver and the
  goods for sale there.
- Needs: power (an unpowered beacon counts for nothing), and a powered comms console somewhere to call the
  ship. Both need research first: `show research path to microelectronics.` shows what opens them
  (unchecked which project).
- Reach: 7.9 tiles, and it stops at doors. One beacon in the middle of a storeroom up to about 15 by 15
  covers it; a bigger store needs more beacons.
- What you buy from a ship comes down in drop pods at the game's trade drop spot
  (`RimWorld\TradeShip.cs:207`); it is not put into the stockpile for you.
- Through the mod: `build orbital trade beacon at X, Z.` (when it is on the `buildings` line),
  `zone stockpile in area 15 by 15 around X, Z.` for the store round it, `show building orbital trade
  beacon.` for its power, `show power.` for the net. The mod has no question that lists which things are in
  a beacon's reach: at the trade window, `show trade.` shows only what counts, so a thing missing there is
  out of reach.

## More things to know
- A trader leaves after a while (unchecked how long). A trader caravan does not pause a run: watch
  `show events.` for the arrival letter.
- Components early on: buy them, or mine compacted machinery, or take ship chunks apart.
- What sells: see `people.md` (human skin sells well if your people can stand it; cloth is worth little).
- A trader with a quest hands it over when the trade window closes: look at `show letters.` afterwards.
