.PHONY: build run app dist dmg release clean help

# Default: show the help.
help:
	@echo "DockBuddies — make targets"
	@echo ""
	@echo "  make run      Build (debug) and run via swift run"
	@echo "  make app      Build a debug .app into .build/ (fast dev loop)"
	@echo "  make dist     Build a release universal .app into dist/"
	@echo "  make dmg      Build dist/, then package as dist/DockBuddies.dmg"
	@echo "  make release  Alias for 'make dmg' — what CI runs"
	@echo "  make clean    Remove .build/ and dist/"

# --- Development ------------------------------------------------------------

build:
	swift build

run: build
	swift run

# Build a debug .app under .build/ — kept because Accessibility permission
# tracks by bundle ID and survives rebuilds at this path.
app: build
	@echo "Packaging .build/DockBuddies.app (debug)..."
	@rm -rf .build/DockBuddies.app
	@mkdir -p .build/DockBuddies.app/Contents/MacOS
	@mkdir -p .build/DockBuddies.app/Contents/Resources
	@cp .build/arm64-apple-macosx/debug/DockBuddies .build/DockBuddies.app/Contents/MacOS/
	@cp Resources/Info.plist .build/DockBuddies.app/Contents/
	@codesign -s - -f .build/DockBuddies.app 2>/dev/null || true
	@echo ""
	@echo "✅ Built .build/DockBuddies.app"
	@echo "   open .build/DockBuddies.app"

# --- Release ---------------------------------------------------------------

# Release-mode universal binary into dist/.
dist:
	@./scripts/build-app.sh

# Release .app + .dmg in dist/.
dmg: dist
	@./scripts/build-dmg.sh

release: dmg

# --- Cleanup ---------------------------------------------------------------

clean:
	swift package clean
	rm -rf .build/DockBuddies.app
	rm -rf dist
