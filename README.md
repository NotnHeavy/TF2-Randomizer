# (TF2) Randomizer

Ever wanted to be randomly given a Rocket Launcher in your melee slot and then snipe players with a secondary Sniper Rifle while having the chance to reserve your primary slot for the Stickybomb Launcher, alongside a slap in the face in order to wake yourself up? May I present to you the best (or the worst, depending on how you see it) TF2 Randomizer plugin I believe there is currently out there.

This plugin has a similar concept to other Randomizer plugins - your loadout will be randomized upon respawn. However, **any** weapon can spawn in **any** slot (with the exception of the sapper/PDA slots for Spy because they can cause crashes, and sappers because they're broken currently).

## How to install
Just download the `.zip` archive and extract it to your SourceMod directory. In order to load the `Weapon Manager` config file without having it set in `weapon_manager.cfg`, you will need to type `weapon_load "NotnHeavy - Randomizer"` and then `weapon_write` to save to your `autosave.cfg` file.

In order to tweak weapons for other classes, it is recommended that you use this plugin alongside [Weapon Fixes](https://github.com/NotnHeavy/TF2-Weapon-Fixes).

## Dependencies
This plugin is compiled using SourceMod 1.12, but should work under SourceMod 1.11.

The following external dependencies are mandatory for this plugin to function:
- [NotnHeavy's Weapon Manager (and its dependencies)](https://github.com/NotnHeavy/TF2-Weapon-Manager)
- [nosoop's TF2 Econ Data](https://github.com/nosoop/SM-TFEconData)
