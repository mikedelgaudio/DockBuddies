.PHONY: build run app clean

# Build the Swift package
build:
	swift build

# Build and run
run: build
	swift run

# Build and package as DockBuddies.app (Accessibility permission persists across rebuilds)
app: build
	@echo "Packaging DockBuddies.app..."
	@rm -rf .build/DockBuddies.app
	@mkdir -p .build/DockBuddies.app/Contents/MacOS
	@mkdir -p .build/DockBuddies.app/Contents/Resources
	@cp .build/arm64-apple-macosx/debug/DockBuddies .build/DockBuddies.app/Contents/MacOS/
	@cp Resources/Info.plist .build/DockBuddies.app/Contents/
	@codesign -s - -f .build/DockBuddies.app 2>/dev/null || true
	@echo ""
	@echo "✅ Built .build/DockBuddies.app"
	@echo ""
	@echo "To run:  open .build/DockBuddies.app"
	@echo ""
	@echo "For Accessibility (tab switching), add DockBuddies.app to:"
	@echo "  System Settings → Privacy & Security → Accessibility"
	@echo "  (Permission persists across rebuilds)"

clean:
	swift package clean
	rm -rf .build/DockBuddies.app
