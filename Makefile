# Makefile for Android OTA Patcher
#
# This Makefile provides convenient targets for building and running
# the Android OTA Patcher container.
#

# Configuration
CONTAINER_NAME ?= android-ota-patcher
CONTAINER_TAG ?= latest
DATA_DIR ?= ./data
KEYS_DIR ?= ./keys
RUNTIME ?= podman

# Detect container runtime if not specified
ifeq ($(RUNTIME),auto)
	ifeq ($(shell which podman 2>/dev/null),)
		ifeq ($(shell which docker 2>/dev/null),)
			$(error Neither podman nor docker found)
		else
			RUNTIME := docker
		endif
	else
		RUNTIME := podman
	endif
endif

# Environment variables for passphrases (if set)
ENV_VARS := 
ifdef PASSPHRASE_OTA
	ENV_VARS += -e PASSPHRASE_OTA="$(PASSPHRASE_OTA)"
endif
ifdef PASSPHRASE_AVB
	ENV_VARS += -e PASSPHRASE_AVB="$(PASSPHRASE_AVB)"
endif

# Common run flags
RUN_FLAGS := --rm --privileged --shm-size=2g $(ENV_VARS) -v $(DATA_DIR):/data:Z -v $(KEYS_DIR):/workspace/keys:Z
RUN_INTERACTIVE := --rm -it --privileged --shm-size=2g $(ENV_VARS) -v $(DATA_DIR):/data:Z -v $(KEYS_DIR):/workspace/keys:Z
RUN_PRIVILEGED := --rm --privileged --shm-size=2g $(ENV_VARS) -v $(DATA_DIR):/data:Z -v $(KEYS_DIR):/workspace/keys:Z -v /dev/bus/usb:/dev/bus/usb

.PHONY: help build run shell clean scrape download patch ci sideload devices setup examples

# Default target
help: ## Show this help message
	@echo "Android OTA Patcher Container"
	@echo "=============================="
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "Configuration:"
	@echo "  RUNTIME      = $(RUNTIME)"
	@echo "  CONTAINER    = $(CONTAINER_NAME):$(CONTAINER_TAG)"
	@echo "  DATA_DIR     = $(DATA_DIR)"
	@echo "  KEYS_DIR     = $(KEYS_DIR)"
	@echo ""
	@echo "Environment Variables:"
	@echo "  PASSPHRASE_OTA     - Passphrase for OTA signing key (if encrypted)"
	@echo "  PASSPHRASE_AVB     - Passphrase for AVB signing key (if encrypted)"
	@echo ""
	@echo "Examples:"
	@echo "  # Basic usage"
	@echo "  make ci"
	@echo "  # With encrypted keys"
	@echo "  PASSPHRASE_OTA='mypass' PASSPHRASE_AVB='mypass' make ci"

build: ## Build the container image
	@echo "🔨 Building container..."
	$(RUNTIME) build -t $(CONTAINER_NAME):$(CONTAINER_TAG) -f Containerfile .

run: ## Show container help
	@echo "📋 Showing container help..."
	$(RUNTIME) run $(RUN_FLAGS) $(CONTAINER_NAME):$(CONTAINER_TAG)

shell: setup ## Start interactive shell in container
	@echo "🐚 Starting interactive shell..."
	$(RUNTIME) run $(RUN_INTERACTIVE) $(CONTAINER_NAME):$(CONTAINER_TAG) shell

clean: ## Remove container image and clean data
	@echo "🧹 Cleaning up..."
	$(RUNTIME) rmi $(CONTAINER_NAME):$(CONTAINER_TAG) 2>/dev/null || true
	@echo "Note: Data directory $(DATA_DIR) preserved"

setup: ## Create necessary directories
	@echo "📁 Setting up directories..."
	@mkdir -p $(DATA_DIR) $(KEYS_DIR)
	@chmod 755 $(DATA_DIR) $(KEYS_DIR)
	@echo "✅ Created $(DATA_DIR) and $(KEYS_DIR)"
	@echo "📝 Copy your signing keys to $(KEYS_DIR)/"
	@echo "💾 Downloads and patched files will be saved to $(DATA_DIR)/devices/<codename>/"

fix-permissions: ## Fix permissions for data directory (run if you get permission errors)
	@echo "🔧 Fixing permissions for data directory..."
	@sudo chown -R $$USER:$$USER $(DATA_DIR) $(KEYS_DIR) || true
	@chmod -R 755 $(DATA_DIR) $(KEYS_DIR) || true
	@echo "✅ Permissions fixed"

scrape: setup ## Scrape latest OTA URL (device=cheetah)
	@echo "🔍 Scraping OTA for device: $(or $(device),cheetah)"
	$(RUNTIME) run $(RUN_FLAGS) $(CONTAINER_NAME):$(CONTAINER_TAG) scrape --device $(or $(device),cheetah)

download: setup ## Download latest OTA (device=cheetah)
	@echo "📥 Downloading OTA for device: $(or $(device),cheetah)"
	$(RUNTIME) run $(RUN_FLAGS) $(CONTAINER_NAME):$(CONTAINER_TAG) download --device $(or $(device),cheetah)

patch: setup ## Patch OTA file (Usage: make patch ota=... mode=... [prepatched=...] [magisk_preinit=...])
	@echo "🔧 Patching OTA..."
	$(eval ARGS := $(if $(ota),--ota $(ota),) $(if $(mode),--mode $(mode),) $(if $(prepatched),--prepatched $(prepatched),) $(if $(magisk_preinit),--magisk-preinit-device $(magisk_preinit),) $(if $(workdir),--workdir $(workdir),))
	$(RUNTIME) run $(RUN_FLAGS) $(CONTAINER_NAME):$(CONTAINER_TAG) patch $(ARGS) $(PATCH_ARGS)

boot-patch: setup ## Patch boot image (Usage: make boot-patch ota=... kernel=... [workdir=...])
	@echo "🔧 Patching boot image..."
	$(if $(ota),,$(error "ota" argument is required (e.g., make boot-patch ota=/data/ota.zip ...)))
	$(if $(kernel),,$(error "kernel" argument is required (e.g., make boot-patch kernel=/data/kernel.zip ...)))
	$(RUNTIME) run $(RUN_FLAGS) $(CONTAINER_NAME):$(CONTAINER_TAG) boot-patch $(ota) $(kernel) $(or $(workdir),/data/workdir)

ci: setup ## Run CI pipeline (Usage: make ci [devices="cheetah:cheetah ..."])
	@echo "🚀 Running CI pipeline..."
	$(eval ARGS := $(if $(devices),--devices "$(devices)",))
	$(RUNTIME) run $(RUN_FLAGS) $(CONTAINER_NAME):$(CONTAINER_TAG) ci $(ARGS) $(CI_ARGS)

sideload: setup ## Sideload patched OTA to device (requires file= parameter)
	@echo "📱 Sideloading $(file)..."
	$(RUNTIME) run $(RUN_PRIVILEGED) $(CONTAINER_NAME):$(CONTAINER_TAG) sideload $(file)

sideload-compose: setup ## Sideload using Docker Compose (default: /data/ota.zip.patched)
	@echo "📱 Sideloading via Docker Compose..."
	docker-compose run --rm ota-sideload

devices: ## List configured devices
	@echo "📱 Listing devices..."
	$(RUNTIME) run $(RUN_FLAGS) $(CONTAINER_NAME):$(CONTAINER_TAG) devices

examples: build setup ## Run example commands
	@echo "🚀 Running examples..."
	./run-examples.sh

# Development targets
dev-build: ## Build container with development tags
	$(RUNTIME) build -t $(CONTAINER_NAME):dev -f Containerfile .

dev-shell: setup ## Start development shell
	$(RUNTIME) run $(RUN_INTERACTIVE) $(CONTAINER_NAME):dev shell

# Convenience targets for common operations
pixel7pro: ## Scrape OTA for Pixel 7 Pro (cheetah)
	@$(MAKE) scrape device=cheetah

pixel8: ## Scrape OTA for Pixel 8 (shiba)  
	@$(MAKE) scrape device=shiba

data-status: ## Show data directory structure and contents
	@echo "📊 Data Directory Status"
	@echo "========================"
	@echo "Data Directory: $(DATA_DIR)"
	@echo ""
	@if [ -d "$(DATA_DIR)" ]; then \
		echo "📂 Directory Structure:"; \
		find $(DATA_DIR) -type d -exec echo "  📁 {}" \; 2>/dev/null || true; \
		echo ""; \
		echo "📄 Files by Device:"; \
		for device_dir in $(DATA_DIR)/devices/*/; do \
			if [ -d "$$device_dir" ]; then \
				device=$$(basename "$$device_dir"); \
				echo "  📱 $$device:"; \
				ls -la "$$device_dir" 2>/dev/null | grep -E '\.(zip|img|txt)' | awk '{print "    " $$9 " (" $$5 " bytes, " $$6 " " $$7 " " $$8 ")"}' || true; \
			fi; \
		done; \
	else \
		echo "❌ Data directory $(DATA_DIR) does not exist"; \
		echo "   Run 'make setup' to create it"; \
	fi

# Example usage targets
example-scrape: ## Example: Scrape cheetah
	@$(MAKE) scrape device=cheetah

example-download: ## Example: Download cheetah OTA
	@$(MAKE) download device=cheetah

example-patch-rootless: ## Example: Patch in rootless mode
	@$(MAKE) patch PATCH_ARGS="--ota $(DATA_DIR)/ota.zip --mode rootless"

example-ci: ## Example: Run CI for cheetah
	@$(MAKE) ci CI_ARGS="--devices cheetah:cheetah"
