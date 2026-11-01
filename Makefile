# A tap has no build artifact: build checks that every formula and cask parses.
RUBY_FILES := $(wildcard Formula/*.rb Casks/*.rb)
SHELL_FILES := scripts/update.sh tests/update_test.sh

.PHONY: build test lint check install redeploy

build:
	@$(foreach f,$(RUBY_FILES),ruby -c $(f) >/dev/null &&) true
	@echo "parsed $(words $(RUBY_FILES)) tap file(s)"

test:
	tests/update_test.sh

lint:
	shellcheck $(SHELL_FILES)
	$(if $(RUBY_FILES),brew style $(RUBY_FILES))

check: build test lint

install redeploy:
	@echo "nothing to $@: a tap is installed with brew tap aeryx-ai/tap"
