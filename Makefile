.PHONY: install-mac install-linux update publish test test-linux doctor init install-hooks

init: install-hooks

install-hooks:
	git config core.hooksPath .githooks

install-mac:
	./bootstrap/macos.sh
	stow $$(ls -d */ | grep -Ev '^(bootstrap|test|linux)/' | tr -d '/')
	./bootstrap/link-jetbrains.sh
	launchctl load ~/Library/LaunchAgents/com.dotfiles.doctor.plist 2>/dev/null || true

install-linux:
	./bootstrap/linux.sh
	stow $$(ls -d */ | grep -Ev '^(bootstrap|test|macos)/' | tr -d '/')
	./bootstrap/link-jetbrains.sh

update:
	git pull && stow -R $$(ls -d */ | grep -Ev '^(bootstrap|test)/' | tr -d '/')

publish:
	@bash publish.sh

test:
	@command -v bats       >/dev/null || { echo "bats not found - brew install bats-core"; exit 1; }
	@command -v shellcheck >/dev/null || { echo "shellcheck not found - brew install shellcheck"; exit 1; }
	@command -v actionlint >/dev/null || { echo "actionlint not found - brew install actionlint"; exit 1; }
	bats $(filter-out test/langs.bats,$(wildcard test/*.bats))
	actionlint

doctor:
	@bash bootstrap/doctor.sh

test-linux:
	docker build -t dotfiles-test-linux -f Dockerfile.test .
	docker run --rm -v "$(PWD):/dotfiles" dotfiles-test-linux make test
