APP=batt-sail
BUILD=.build

.PHONY: release universal install uninstall

release:
	swift build -c release

universal:
	swift build -c release --arch arm64
	swift build -c release --arch x86_64
	mkdir -p dist
	lipo -create \
		$(BUILD)/arm64-apple-macosx/release/$(APP) \
		$(BUILD)/x86_64-apple-macosx/release/$(APP) \
		-output dist/$(APP)
	codesign --force --sign - dist/$(APP)

install: universal
	install -m 0755 dist/$(APP) /usr/local/bin/$(APP)

uninstall:
	@if [ -x /usr/local/bin/$(APP) ]; then \
		/usr/local/bin/$(APP) uninstall; \
	elif [ -x dist/$(APP) ]; then \
		dist/$(APP) uninstall; \
	else \
		echo "batt-sail is not installed."; \
	fi

