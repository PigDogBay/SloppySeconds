SJASMPLUS ?= /Users/mark/work/Next/tools/sjasmplus-v21/build-arm64/sjasmplus
ZESARUX   ?= /Applications/zesarux.app/Contents/MacOS/zesarux

BUILD := build
NEX   := $(BUILD)/sloppy.nex

# Test keys (N = finish level, 2 = Joe quits) are built in by default;
# make RELEASE=1 leaves them out.
ASMFLAGS :=
ifdef RELEASE
ASMFLAGS += -DRELEASE
endif

.PHONY: all run clean FORCE

all: $(NEX)

# Always reassemble (it takes a moment, and RELEASE may have changed).
$(NEX): FORCE | $(BUILD)
	$(SJASMPLUS) --zxnext --fullpath --msg=war $(ASMFLAGS) \
		--lst=$(BUILD)/sloppy.lst --sld=$(BUILD)/sloppy.sld \
		src/main.asm

$(BUILD):
	mkdir -p $(BUILD)

run: $(NEX)
	$(ZESARUX) --machine TBBlue --realvideo --tbblue-fast-boot-mode \
		--snap $(abspath $(NEX))

clean:
	rm -rf $(BUILD)
