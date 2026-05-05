APP := Autoclicker.app
BIN := .build/release/Autoclicker

.PHONY: build app run dev clean

build:
	swift build -c release

app: build
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	mkdir -p $(APP)/Contents/Resources
	cp $(BIN) $(APP)/Contents/MacOS/Autoclicker
	cp Info.plist $(APP)/Contents/Info.plist
	codesign --force --deep --sign - $(APP)
	@echo "Built $(APP)"

run: app
	open $(APP)

dev:
	swift run

clean:
	rm -rf .build $(APP)
