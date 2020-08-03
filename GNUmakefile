BINDIR = ${HOME}/GOG-Games/Starbound/game/linux

# Be extremely careful if you put wildcards in this variable. It will be
# passed to `rm -f`.
ALL_PAKS = rl_fieldcontrol.pak

# This rule assumes that a pak file `foo.pak` will have a corresponding
# source directory `foo` and will depend on every file under `foo`.
%.pak: $(shell find $(@:.pak=))
	cd $(@:.pak=) && $(BINDIR)/asset_packer . ../$(@) && cd ..

all: $(ALL_PAKS)

clean:
	rm -f $(ALL_PAKS)

.PHONY: all clean
