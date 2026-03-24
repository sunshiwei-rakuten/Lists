# ABOUTME: Makefile for ListKit development.
# ABOUTME: Run `make help` to see available commands.

.PHONY: help build test clean lint format install-hooks

# Colors
RESET  := \033[0m
BOLD   := \033[1m
DIM    := \033[2m
CYAN   := \033[36m
GREEN  := \033[32m
YELLOW := \033[33m
BLUE   := \033[34m

DESTINATION := platform=iOS Simulator,name=iPhone 17 Pro
DERIVED_DATA := DerivedData

# Default target
help:
	@echo ""
	@echo "$(BOLD)$(CYAN)  ┌──────────────────────────────────────────────────────────────┐$(RESET)"
	@echo "$(BOLD)$(CYAN)  │$(RESET)                       $(BOLD)ListKit$(RESET)                                $(BOLD)$(CYAN)│$(RESET)"
	@echo "$(BOLD)$(CYAN)  └──────────────────────────────────────────────────────────────┘$(RESET)"
	@echo ""
	@echo "  $(BOLD)$(BLUE)◆ Development$(RESET)"
	@echo "  $(DIM)──────────────────────────────────────────────────────────────$(RESET)"
	@printf "    $(CYAN)%-24s$(RESET) %s\n" "build" "Build ListKit framework"
	@printf "    $(CYAN)%-24s$(RESET) %s\n" "clean" "Clean build artifacts"
	@echo ""
	@echo "  $(BOLD)$(YELLOW)◆ Testing$(RESET)"
	@echo "  $(DIM)──────────────────────────────────────────────────────────────$(RESET)"
	@printf "    $(CYAN)%-24s$(RESET) %s\n" "test" "Run ListKit tests"
	@echo ""
	@echo "  $(BOLD)◆ Code Quality$(RESET)"
	@echo "  $(DIM)──────────────────────────────────────────────────────────────$(RESET)"
	@printf "    $(CYAN)%-24s$(RESET) %s\n" "lint" "Lint Sources/ and Tests/ with SwiftFormat"
	@printf "    $(CYAN)%-24s$(RESET) %s\n" "format" "Format code with SwiftFormat"
	@printf "    $(CYAN)%-24s$(RESET) %s\n" "install-hooks" "Install git pre-commit hook"
	@echo ""

# =============================================================================
# Development
# =============================================================================

build:
	xcodebuild build \
		-scheme ListKit \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA) \
		| xcpretty || xcodebuild build \
		-scheme ListKit \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA)

# =============================================================================
# Testing
# =============================================================================

test:
	xcodebuild test \
		-scheme ListKit \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA) \
		| xcpretty || xcodebuild test \
		-scheme ListKit \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA)

# =============================================================================
# Code Quality
# =============================================================================

lint:
	swiftformat --lint Sources/ Tests/

format:
	swiftformat Sources/ Tests/

# =============================================================================
# Maintenance
# =============================================================================

clean:
	@echo "Cleaning derived data..."
	rm -rf $(DERIVED_DATA)
	@rm -rf ~/Library/Developer/Xcode/DerivedData/ListKit-* 2>/dev/null || true
	@rm -rf ~/Library/Developer/Xcode/DerivedData/Lists-* 2>/dev/null || true
	@echo "$(GREEN)Clean complete.$(RESET)"

install-hooks:
	@if [ -d ".git" ]; then \
		cp scripts/pre-commit .git/hooks/pre-commit; \
		chmod +x .git/hooks/pre-commit; \
		echo "Git hooks installed."; \
	else \
		echo "$(DIM)Not a git repo — skipping hook install.$(RESET)"; \
	fi
