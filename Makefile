.PHONY: clean package test

SHELL := /bin/bash

MANIFEST := \
	background.js \
	common.js \
	deluminate-*.png \
	deluminate.css \
	deluminate.js \
	manifest.json \
	migrate.html \
	migrate.js \
	options.html \
	options.js \
	popup.html \
	popup.js \
	url_selector.css \
	url_selector.js \
	utils.js \
	*.svg

BUILD_DIR := build
CHROME_BUILD_DIR := $(BUILD_DIR)/chrome
FIREFOX_BUILD_DIR := $(BUILD_DIR)/firefox
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

BASE_VERSION := $(shell < manifest.json jq -r .version)
LAST_VERSION_COMMIT := $(shell git blame manifest.json | grep \\bversion \
	| cut -d' ' -f1)
ifeq ($(LAST_VERSION_COMMIT), 00000000)
LAST_VERSION_COMMIT := HEAD
endif
BUILD_NUM := $(shell git log $(LAST_VERSION_COMMIT)..HEAD --oneline \
	| wc -l | tr -d ' ')
PKG_SUFFIX := $(shell git symbolic-ref --short HEAD \
	| sed '/^master$$/d;s/^/-/')
ifeq ($(strip $(PKG_SUFFIX)),)
VERSION := $(BASE_VERSION)
else
VERSION := $(BASE_VERSION).$(BUILD_NUM)
endif


package: deluminate$(PKG_SUFFIX).zip

package_firefox: web-ext-artifacts/deluminate$(PKG_SUFFIX)-$(VERSION).zip
web-ext-artifacts/deluminate$(PKG_SUFFIX)-$(VERSION).zip: $(MANIFEST) | $(FIREFOX_BUILD_DIR)
	echo "$@"
	rm -f $(FIREFOX_BUILD_DIR)/*
	cp $(MANIFEST) $(FIREFOX_BUILD_DIR)/
	cp $(FIREFOX_BUILD_DIR)/manifest.json $(FIREFOX_BUILD_DIR)/manifest.json.orig
	jq < '$(FIREFOX_BUILD_DIR)/manifest.json.orig' '.name = "Deluminate$(PKG_SUFFIX)" | .version = "$(VERSION)" | .permissions = .permissions - ["offscreen"]' > $(FIREFOX_BUILD_DIR)/manifest.json
	rm '$(FIREFOX_BUILD_DIR)/manifest.json.orig'
	cd '$(FIREFOX_BUILD_DIR)' && npx web-ext build -a '$(MAKEFILE_DIR)/$(@D)' --overwrite-dest

deluminate.zip: $(MANIFEST)
	zip "$@" $(MANIFEST)

deluminate%.zip: $(MANIFEST) | $(CHROME_BUILD_DIR)
	rm -f $(CHROME_BUILD_DIR)/*
	cp $(MANIFEST) $(CHROME_BUILD_DIR)/
	cp $(CHROME_BUILD_DIR)/manifest.json $(CHROME_BUILD_DIR)/manifest.json.orig
	sed -e '/"version"/s/"[^"]*$$/.$(BUILD_NUM)&/' \
		-e 's/"Deluminate"/"Deluminate$(PKG_SUFFIX)"/' \
		"$(CHROME_BUILD_DIR)/manifest.json.orig" > "$(CHROME_BUILD_DIR)/manifest.json"
	cd $(CHROME_BUILD_DIR) && zip "../$@" $(MANIFEST)

$(BUILD_DIR) $(CHROME_BUILD_DIR) $(FIREFOX_BUILD_DIR):
	mkdir -p $@

clean:
	rm -f deluminate*.zip
	rm -rf "$(BUILD_DIR)"
	find spec -name 'junit*.xml' -exec rm -f {} +

test: node_modules
	npm test

node_modules: package.json
	npm install

deploy: deluminate.zip node_modules
	npm run deploy -- "$<"

deploy-dev: deluminate$(PKG_SUFFIX).zip node_modules
	npm run deploy-dev -- "$<"
