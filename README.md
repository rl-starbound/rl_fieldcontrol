# Starbound mod: Field Control Technology

This mod allows players to control the gravity, atmosphere, and shielding within arbitrarily-shaped regions in worlds. Some applications include: protecting keypad-locked rooms in your base, protecting bases from meteor strikes, building bases in asteroid belts so that they have air and gravity, and so forth.

Manipulating the physical forces of the universe can be complicated, so please read the [user's guide](users-guide.md) for detailed instruction on using these tools.

This mod provides a number of items for controlling the forces of the Starbound universe:

* Ship Shield Switch and Station Shield Switch
* Field Control Console
* Portable Field Tuner
* Field Tuner XL and Field Tuning Markers

### Ship Shield Switch

Player ships typically consist of multiple fields. The **Ship Shield Switch** (`rl_shipshieldswitchapex`, `rl_shipshieldswitchavian`, *etc.*) synchronizes the shielding of the default fields on a player ship.

The ship shield switch can be crafted at the wiring station, in the mechanics tab. Each of the base game races has a ship shield switch colored with their race's ship color scheme, but they all function identically.

### Station Shield Switch

Player space stations typically consist of multiple fields. The **Station Shield Switch** (`rl_stationshieldswitch`) synchronizes the shielding of the default fields on a player space station.

The station shield switch can be crafted at the wiring station, in the mechanics tab.

### Field Control Console

Each **Field Control Console** (`rl_fieldcontrolconsole`) manipulates the physical forces of one specific field frequency within a world. Gravity, atmosphere, and shielding can be controlled at this console.

The field control console is crafted at the wiring station, in the mechanics tab.

### Portable Field Tuner

The **Portable Field Tuner** (`rl_fieldtuner`) can be used by the player to tune arbitrarily-shaped regions within a world to a specific field frequency. Right clicking sets the tuner's field grid to the field frequency below the cursor, and left clicking tunes blocks under the field grid to the chosen field frequency.

The portable field tuner is crafted at the agricultural station, in the survival tab.

### Field Tuner XL and Field Tuning Markers

The **Field Tuner XL** (`rl_fieldtunerxl`) can be used to tune very large areas far more quickly than a portable field tuner. **Field Tuning Markers** (`rl_fieldmarker`) are wired to the field tuner XL to define the rectangular area to tune.

The field tuner XL and field tuning markers are crafted at the wiring station, in the mechanics tab.

## Optional Functionality

If [Belter Dungeons](https://community.playstarbound.com/resources/belter-dungeons.6357/) (or [No Belter Dungeons](https://community.playstarbound.com/resources/no-belter-dungeons.6358/)) v2.0.0 or later is installed, the field control console will gain the ability to protect players from environmental hazards, *i.e.*, deadly [radiation](https://starbounder.org/Deadly_Radiation), [cold](https://starbounder.org/Deadly_Chill), or [heat](https://starbounder.org/Deadly_Heat).

## Compatibility Notes

Care has been taken to use unique namespaces and make no changes to existing assets, so this mod should be widely compatible. The only point of interaction with the vanilla code is patching the recipes into the player and species config files.

## Uninstall Notes

Due to how the Starbound core engine handles removed mod assets, some issues may crop up. None of these issues are major, but you should be aware of them before removing this mod.

* Any fields that you had tuned or manipulated in any world will remain as you last set them before removal of this mod, including shielding. You can use `/admin` commands to deactivate shielding (also known as tile protection). **You are strongly advised to disable any ship or station shield switches and deregister any field control consoles before removing this mod**.
* The first time you load a character after removing this mod, the game may crash. However, you should be able to load the character again, and play should resume with the character returned to their ship.
* The first time you beam to any world that contained a field control console, field tuner XL, field tuning marker, or ship or station shield switch, those objects will cease to exist and leave error messages in the game log. If any of those objects were stored in a container, they will turn into perfectly generic items, as will any portable field tuners.

## Collaboration

If you have any questions, bug reports, or ideas for improvement, please contact me via [Chucklefish Forums](https://community.playstarbound.com/members/rl-starbound.885402/), [Github](https://github.com/rl-starbound), [Reddit](https://www.reddit.com/user/rl-starbound/), or Discord (`rl.steam`). Also please let me know if you plan to republish this mod elsewhere, so we can maintain open lines of communication to ensure timely updates.

## Credits

Thanks to Pilch's "Field Generators" for inspiring this mod.

## License

Permission to include this mod or parts thereof in derived works, to distribute copies of this mod verbatim, or to distribute modified copies of this mod, is granted unconditionally to Chucklefish LTD. Such permissions are also granted to other parties automatically, provided the following conditions are met:

* Credit is given to the author(s) specified in this mod's \_metadata file;
* A link is provided to the [Github repository](https://github.com/rl-starbound/rl_fieldcontrol) or [mod page](https://community.playstarbound.com/resources/field-control-technology.6028/) in the accompanying files or documentation of any derived work;
* The names "Field Control Technology" or "rl_fieldcontrol" are not used as the name of any derived work without explicit consent of the author(s); however, those names may be used in verbatim distribution of this mod. For the purposes of this clause, minimal changes to metadata files to allow distribution on Steam shall be considered a verbatim distribution so long as authorship attribution remains.
