.PHONY: install-mac install-linux update publish test init

init:
	git config core.hooksPath .githooks

install-mac:
	./bootstrap/macos.sh
	stow $$(ls -d */ | grep -Ev '^(bootstrap|test|linux)/' | tr -d '/')
	./bootstrap/link-jetbrains.sh

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
	bats test/
	actionlint
