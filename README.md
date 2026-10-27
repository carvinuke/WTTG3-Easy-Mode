# Hykeem's WTTG3 Easy Mode

An easy mode for **Welcome to the Game III**, for people who get scared easily or are new to horror games.

By Shrimp. Idea from Hykeem the Legend.

## What it does

**Killers**
- Warns you on screen when a killer shows up, and tells you how to survive that one.
- Briefly slows time when a killer spawns, so you have a moment to react.
- Shows killers through walls, with their distance.
- Skips kill jumpscares: the screen cuts to black and you go straight to game over.
- Makes killer sounds quieter. Footsteps stay normal, so you can still hear them coming.

**Money & gambling**
- More money and cheaper prices, adjustable from x1 to x5.
- Better slot machine odds (60% by default, up from the game's 25%), and no "lose everything" spin.

**Hacking & hiding**
- Easier hacking minigames: more time, plus fewer, slower and weaker enemies.
- Easier hiding from Lucas.

**Hints**
- Lists which websites hold the keys and how each key is hidden. You can also turn on showing the keys themselves.

Every feature can be switched on or off in game.

## Install

1. Download `HykeemsEasyMode-Install.zip` from [Releases](../../releases/latest).
2. In Steam, right-click **Welcome to the Game III** and choose **Manage → Browse local files**.
3. Extract everything from the zip into that folder. If Windows asks about merging folders or replacing files, say yes.
4. Start the game from Steam as usual.

The zip contains [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) (the mod loader) with this mod already set up.

> Some antivirus programs flag UE4SS's `dwmapi.dll`. It's how UE4SS loads itself into the game, and it's a common false positive.

### Already have UE4SS?

Copy the `HykeemsEasyMode` folder from this repo into `WTTGSD\Binaries\Win64\ue4ss\Mods\`. UE4SS needs to be a recent experimental build, since the game runs on Unreal Engine 5.6.

## Use

- **Title screen:** click **Settings**, then the **HYKEEM'S EASY MODE** button in the bottom-right corner.
- **In game:** press **Esc**, then click the same button.

| Key | Does |
|-----|------|
| F6 | Easy Mode on/off |
| F7 | Show killers through walls |
| F8 | Show where the keys are |

Your choices are saved to `Scripts\settings.lua`. Delete that file to go back to the defaults. The defaults, and a few extra knobs (hack timer, alert length, slow-mo length), are in `Scripts\config.lua`.

## Uninstall

Delete `dwmapi.dll` and the `ue4ss` folder from `WTTGSD\Binaries\Win64` inside the game folder.

If you only want to turn Easy Mode off, rename `ue4ss\Mods\HykeemsEasyMode\enabled.txt` to anything else.

## Notes

- Tested on the Steam version of the game. A game update could break the mod; if it does, uninstall it and the game runs normally.
- Changes are made in memory while the game runs. The mod never edits the game's files or your save.
- This is a fan-made mod. It isn't affiliated with or endorsed by Reflect Studios. Please buy the game.

## License

MIT. See [LICENSE](LICENSE). UE4SS is MIT licensed by its authors.
