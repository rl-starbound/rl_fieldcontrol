# Starbound mod: Field Control Technology

The **Field Control Technology** mod allows players to control the gravity, shielding, atmosphere, and environmental protection within arbitrarily-shaped regions in worlds. Some applications include: protecting locked rooms in your base, protecting bases from meteor strikes, building bases in asteroid belts so that they have air and gravity, and so forth.

Manipulating the physical forces of the universe can be complicated, so please read the [user's guide](users-guide.md) for instructions on using these tools.

This mod provides a number of items for controlling the forces of the Starbound universe:
* Field Control Console
* Portable Field Tuner
* Field Tuner XL and Field Tuning Markers
* Ship Control Console
* enhanced Space Station Console\*

*As of v3.0.0*, field control technology recipes must be learned from two quests, available from the wandering human scientist at the Outpost near Terramart. Elliot's tech challenge quest line is a prerequisite for these quests.

### Field Control Console

Each **field control console** (`rl_fieldcontrolconsole`) manipulates the physical forces of one specific field frequency within a world. Gravity, atmosphere, shielding, and (optionally) environmental protection can be controlled at this console. Field control consoles can be password protected, and can be wired for remote control.

The field control console is crafted at the **wiring station**, in the **mechanics** tab.

### Portable Field Tuner

The **portable field tuner** (`rl_fieldtuner`) can be used by the player to tune arbitrarily-shaped regions within a world to a specific field frequency. Right clicking sets the tuner's field grid to the field frequency below the cursor, and left clicking tunes blocks under the field grid to the chosen field frequency.

The portable field tuner is crafted at the **agricultural station**, in the **survival** tab.

### Field Tuner XL and Field Tuning Markers

The **field tuner XL** (`rl_fieldtunerxl`) can be used to tune very large areas far more quickly than a portable field tuner. **Field tuning markers** (`rl_fieldmarker`) are wired to the field tuner XL to define the rectangular area to tune.

The field tuner XL and field tuning markers are crafted at the **wiring station**, in the **mechanics** tab.

### Ship Control Console

Player ships consist of multiple fields. The **ship control console** (`rl_playershipconsoleapex`, `rl_playershipconsoleavian`, *etc.*) operates like a field control console, but synchronizes its effects across the default fields in a player ship.

The ship control console can be crafted at the **wiring station**, in the **mechanics** tab. Each of the base game races has a ship control console styled according to their race's ship, but they all function identically.

### enhanced Space Station Console

Personal space stations consist of multiple fields. If [Field Control Technology - Station Control Console](https://community.playstarbound.com/resources/field-control-technology-station-control-console.6408/) is installed, the space station console found on all personal space stations will be upgraded to operate like a field control console, synchronizing its effects across the default fields in a personal space station.

If *Field Control Technology: Station Control Console* is not installed, the **station shield switch** (`rl_stationshieldswitch`) can be used to synchronize the shielding of the default fields in a personal space station. The station shield switch can be crafted at the **wiring station**, in the **mechanics** tab.

## Optional Functionality

If either [Belter Dungeons](https://community.playstarbound.com/resources/belter-dungeons.6357/) or [No Belter Dungeons](https://community.playstarbound.com/resources/no-belter-dungeons.6358/) v2.2.0 or newer is installed, the field control console will gain the ability to protect players from environmental hazards. If both [Mech Compatibility Core](https://steamcommunity.com/sharedfiles/filedetails/?id=3371002682) and [Mech Compatibility Loader](https://steamcommunity.com/sharedfiles/filedetails/?id=3371011064) are installed, this protection extends to mechs.

Field control consoles can only protect against known environmental hazards. Hazards added by mods will require extensions. Currently available extensions are:
* [Arcana Compatibility](https://community.playstarbound.com/resources/field-control-technology-arcana-compatibility.6405/)
* [Frackin' Universe Compatibility](https://community.playstarbound.com/resources/field-control-technology-frackin-universe-compatibility.6406/)

## Compatibility

This mod should be compatible with nearly all mods. It is known to be incompatible with [Password Protection Module for Field Control Technology](https://steamcommunity.com/sharedfiles/filedetails/?id=2885032247), but v3.0.0 or later of this mod fully replaces the functionality of that mod.

## Uninstallation

Due to how the Starbound core engine handles removed mod assets, some issues may occur. None of these issues are major, but you should be aware of them before removing this mod.
* **You are strongly advised to turn off ship and station shielding, turn on ship and station air, and deregister any field control consoles before removing this mod**. Any fields that you had tuned or manipulated in any world will remain as you last set them before removal of this mod, including shielding, air, and environmental protection. If you ignore this advice, you will have to use admin commands to alter these properties in affected regions.
* The first time you load a character after removing this mod, the game may crash. However, you should be able to load the character again, and normal play should resume with the character returned to their ship.
* The first time you beam to any world that contained a field control console, field tuner XL, field tuning marker, or ship control console, those objects will cease to exist and leave error messages in the game log. If any of those objects were stored in a container, they will turn into perfectly generic items, as will any portable field tuners. No other negative effects should occur.

## Credits

Thanks to Pilch's "Field Generators" for inspiring this mod and Meteora for the idea to password protect the console.

## Collaboration

If you have any questions, bug reports, or ideas for improvement, please contact me via [Chucklefish Forums](https://community.playstarbound.com/members/rl-starbound.885402/), [Github](https://github.com/rl-starbound), [Reddit](https://www.reddit.com/user/rl-starbound/), or the Starbound Discord (`rl.steam`). Steam users may want to subscribe to my [workshop profile](https://steamcommunity.com/profiles/76561198808510456/myworkshopfiles/) for updates on this and my other mods. Also please let me know if you plan to republish this mod elsewhere, so we can maintain open lines of communication to ensure timely updates.

## License

Permission to include this mod or parts thereof in derived works, to distribute copies of this mod verbatim, or to distribute modified copies of this mod, is granted unconditionally to Chucklefish LTD. Such permissions are also granted to other parties automatically, provided the following conditions are met:
* Credit is given to the author(s) specified in this mod's `_metadata` file;
* A link is provided to the [source repository](https://github.com/rl-starbound/rl_fieldcontrol) in the accompanying files or documentation of any derived work;
* The exact name "Field Control Technology" is not used as the metadata `friendlyName` of any derived work without explicit consent of the author(s); however, the names may be used in verbatim distribution of this mod. For the purposes of this clause, minimal changes to metadata files to allow distribution on Steam shall be considered a verbatim distribution so long as authorship attribution remains. In other words, if you distribute an altered version of this mod, you must make that clear in the name.
