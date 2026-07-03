# Makefile — DeToca
#
# Source of truth for building on the target: Mac OS X 10.6.8, Xcode 3.2.6.
# Programmatic UI, no XIB/NIB, no Xcode project required.
#
#   make            build DeToca.app
#   make run        build and launch DeToca.app
#   make test       build and run the OCUnit (SenTestingKit) parser tests
#   make spikeb     build the Spike B command-line fetch tool
#   make clean      remove build products
#
# Override on the command line if needed, e.g.:
#   make ARCH=x86_64 CC=llvm-gcc

SDK      ?= /Developer/SDKs/MacOSX10.6.sdk
ARCH     ?= i386
CC       ?= gcc
MINVER    = -mmacosx-version-min=10.6

# SenTestingKit lives under /Developer on 10.6 (not /System).
DEVFRAMEWORKS = /Developer/Library/Frameworks

COMMON = -arch $(ARCH) -isysroot $(SDK) $(MINVER) -Wall -fblocks -Isrc

APP        = DeToca.app
APP_BINARY = $(APP)/Contents/MacOS/DeToca
FONT       = Resources/CascadiaCode-Regular.ttf
LICENSE    = Resources/OFL.txt
ICON       = Resources/DeToca.icns

# --- Source groups -----------------------------------------------------------

# Pure Foundation, no AppKit. Unit-tested.
PARSER_SRC = \
	src/GopherItem.m \
	src/GopherMenuParser.m \
	src/GopherResource.m \
	src/ANSIPalette.m \
	src/ANSISpan.m \
	src/ANSIParser.m

# Networking (Foundation + libdispatch).
NET_SRC = \
	src/DTDispatch.m \
	src/GopherRequest.m

# Player model (pure Foundation, no AppKit/QTKit). Unit-tested.
MODEL_SRC = \
	src/StreamRouting.m \
	src/PlayQueueItem.m \
	src/PlayQueue.m \
	src/PLSParser.m \
	src/SpotSelectors.m \
	src/DTServerPrefs.m \
	src/DTMediaKeyRouter.m \
	src/DTNowSnapshot.m \
	src/DTSnapshotGuard.m \
	src/DTTrackItem.m \
	src/DTPlaylistItem.m \
	src/DTCoverCache.m

# Audio (Foundation + AudioToolbox; no AppKit). fio-5 live streaming.
AUDIO_SRC = \
	src/DTAudioStreamer.m

# AppKit UI (incl. the fio-2 QTKit player and fio-5 radinho v2).
# DTSpotAPI is app-only glue (NET + MODEL); it lives here so the lean spikeb/test
# builds don't have to link it.
UI_SRC = \
	src/DTTheme.m \
	src/DTSpotAPI.m \
	src/DTTrackCell.m \
	src/DTPlayerWindowController.m \
	src/DTPlaylistWindowController.m \
	src/DTFontManager.m \
	src/AttributedStringRenderer.m \
	src/BookmarkStore.m \
	src/DTInputSheet.m \
	src/GopherTableView.m \
	src/GopherMenuView.m \
	src/DTMediaKeyTap.m \
	src/PreferencesController.m \
	src/StreamPlayerController.m \
	src/GopherWindowController.m \
	src/AppDelegate.m \
	src/main.m

APP_SRC  = $(PARSER_SRC) $(NET_SRC) $(MODEL_SRC) $(AUDIO_SRC) $(UI_SRC)
APP_LIBS = -framework Cocoa -framework ApplicationServices -framework QTKit \
           -framework AudioToolbox

# DTCoverCache funnels its async work through DTDispatch (from NET_SRC), so the
# test bundle links that one extra file even though the rest of NET_SRC is UI-only.
TEST_SRC = $(PARSER_SRC) $(MODEL_SRC) src/DTDispatch.m \
           tests/ParserTests.m tests/PlayerTests.m \
           tests/PrefsTests.m tests/SpotAPITests.m

# --- Default target ----------------------------------------------------------

all: $(APP)

# --- Application bundle -------------------------------------------------------

$(APP): $(APP_SRC) Info.plist $(FONT) $(ICON)
	@echo "  Assembling $(APP)"
	@mkdir -p $(APP)/Contents/MacOS
	@mkdir -p $(APP)/Contents/Resources
	$(CC) $(COMMON) $(APP_SRC) $(APP_LIBS) -o $(APP_BINARY)
	@cp Info.plist $(APP)/Contents/Info.plist
	@printf 'APPLToca' > $(APP)/Contents/PkgInfo
	@cp $(FONT) $(APP)/Contents/Resources/
	@cp $(ICON) $(APP)/Contents/Resources/
	@if [ -f $(LICENSE) ]; then cp $(LICENSE) $(APP)/Contents/Resources/; fi
	@echo "  Built $(APP)"

run: $(APP)
	open $(APP)

# --- Spike B tool ------------------------------------------------------------

spikeb: $(PARSER_SRC) $(NET_SRC) tools/spikeb.m
	$(CC) $(COMMON) $(PARSER_SRC) $(NET_SRC) tools/spikeb.m \
		-framework Foundation -o spikeb
	@echo "  Built spikeb"

# --- OCUnit tests ------------------------------------------------------------

TEST_BUNDLE = Tests.octest

test: $(TEST_SRC) tests/Tests-Info.plist
	@echo "  Building $(TEST_BUNDLE)"
	@mkdir -p $(TEST_BUNDLE)/Contents/MacOS
	$(CC) $(COMMON) -bundle \
		-F$(DEVFRAMEWORKS) \
		-framework Foundation -framework SenTestingKit \
		$(TEST_SRC) -o $(TEST_BUNDLE)/Contents/MacOS/Tests
	@cp tests/Tests-Info.plist $(TEST_BUNDLE)/Contents/Info.plist
	@echo "  Running otest ($(ARCH))"
	OBJC_DISABLE_GC=YES DYLD_FRAMEWORK_PATH=$(DEVFRAMEWORKS) \
		arch -arch $(ARCH) /Developer/Tools/otest $(TEST_BUNDLE)

# --- Housekeeping ------------------------------------------------------------

clean:
	rm -rf $(APP) $(TEST_BUNDLE) spikeb

.PHONY: all run spikeb test clean
