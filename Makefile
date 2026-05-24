FPC ?= fpc
BUILD_DIR := build
UNIT_DIR := $(BUILD_DIR)/units
BIN := $(BUILD_DIR)/neo-opensuse-i3

.PHONY: all clean release

all: $(BIN)

$(BIN): $(wildcard src/*.pas) src/neo_opensuse_i3.lpr
	mkdir -p $(BUILD_DIR) $(UNIT_DIR)
	ln -sf /lib64/libc.so.6 $(BUILD_DIR)/libc.so
	ln -sf /lib64/libdl.so.2 $(BUILD_DIR)/libdl.so
	$(FPC) -Mobjfpc -Sh -Fl$(BUILD_DIR) -Fusrc -FU$(UNIT_DIR) -FE$(BUILD_DIR) -oneo-opensuse-i3 src/neo_opensuse_i3.lpr

release: $(BIN)
	rm -rf release
	mkdir -p release
	cp $(BIN) release/neo-opensuse-i3
	cp -a assets release/assets
	chmod 0755 release/neo-opensuse-i3 release/assets/bin/lbemenu release/assets/bin/lfuzzel
	(cd release && sha256sum neo-opensuse-i3 assets/i3/config assets/bin/lbemenu assets/sway/config assets/sway/themes/*.conf assets/bin/lfuzzel assets/fuzzel/themes/*.ini assets/kitty/kitty.conf assets/kitty/themes/*.conf assets/wallpapers/* > SHA256SUMS)
	printf '%s\n' 'neo-opensuse-i3 1.0.0' 'Ready-to-run openSUSE Tumbleweed i3/Sway installer bundle.' > release/RELEASE-NOTES.txt

clean:
	rm -rf $(BUILD_DIR) release
