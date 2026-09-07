SCHEME        := OpenWhisper
DERIVED_DATA  := build/DerivedData
APP           := $(DERIVED_DATA)/Build/Products/Release/OpenWhisper.app
INSTALL_DIR   := /Applications

.PHONY: setup generate build run test install clean model

setup: ## Fetch the whisper and llama xcframeworks, write signing config, generate the Xcode project
	scripts/fetch-frameworks.sh
	scripts/write-local-xcconfig.sh
	$(MAKE) generate

generate: ## Regenerate OpenWhisper.xcodeproj from project.yml
	xcodegen generate

build: generate ## Release build into build/DerivedData
	xcodebuild -scheme $(SCHEME) -configuration Release -derivedDataPath $(DERIVED_DATA) build | tail -n 5

run: build ## Build and launch the app
	open "$(APP)"

test: generate ## Run unit tests (needs the tiny.en model, see `make model`)
	xcodebuild -scheme $(SCHEME) -destination 'platform=macOS' -derivedDataPath $(DERIVED_DATA) test | tail -n 40

install: build ## Sync the release build into /Applications (rsync, so App Management never has to delete the bundle)
	mkdir -p "$(INSTALL_DIR)/OpenWhisper.app"
	rsync -a --delete "$(APP)/" "$(INSTALL_DIR)/OpenWhisper.app/"
	@echo "Installed $(INSTALL_DIR)/OpenWhisper.app"

model: ## Download the models the tests use (tiny.en, Silero VAD, Qwen 3B)
	scripts/fetch-model.sh tiny.en
	scripts/fetch-model.sh vad
	scripts/fetch-model.sh qwen-3b

release: ## Build, sign (Developer ID), notarize, staple, and zip for distribution
	scripts/release.sh

clean:
	rm -rf build dist OpenWhisper.xcodeproj
