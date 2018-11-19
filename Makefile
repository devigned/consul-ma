#!make

include .env
export $(shell sed 's/=.*//' .env)

VERSION ?= $(shell git describe --tags --always --dirty --match=v* 2> /dev/null || \
			cat $(CURDIR)/.version 2> /dev/null || echo v0)
V 		= 0
Q 		= $(if $(filter 1,$V),,@)
M 		= $(shell printf "\033[34;1m▶\033[0m")
EVNSUBST= /usr/local/opt/gettext/bin/envsubst
REPLACE	= '$${MA_STORAGE_ACCOUNT},$${MA_STORAGE_ACCOUNT_KEY},$${IMAGE_ID},$${SSH_PUB_KEY}'


.PHONY: all
all: consul-start-script publish

.PHONY: deploy-container
deploy-container: ; $(info $(M) ensure deployment container is created...)
	$(Q) az storage container create --account-name $(MA_STORAGE_ACCOUNT) -n deployments > /dev/null

.PHONY: consul-start-script
consul-start-script: deploy-container ; $(info $(M) rendering and pushing Consul VM startup script...)
	$(eval TMPDIR := $(shell mktemp -d))
	$(Q) $(EVNSUBST) < provision-script-template.sh > $(TMPDIR)/provision.sh
	$(Q) az storage blob upload --account-name $(MA_STORAGE_ACCOUNT) -c deployments -f $(TMPDIR)/provision.sh -n provision.sh > /dev/null 2>&1
	$(Q) rm $(TMPDIR)/provision.sh

.PHONY: image
image: ; $(info $(M) building VM image using packer...)
	$(eval RG_LOCATION := $(shell az group show -n $(MA_RESOURCE_GROUP) --query 'location' -o tsv))
	$(Q) packer build -var 'azure_location=$(RG_LOCATION)' consul.json

.PHONY: pkg
pkg: ; $(info $(M) zipping up managed app package…)
	$(shell mkdir -p ./output)
	$(eval IMAGE_ID := $(shell az image list -g $(MA_RESOURCE_GROUP) --query "[].id" -o tsv | sort -r | head -n 1))
	$(eval SSH_PUB_KEY := "$(shell cat ~/.ssh/id_rsa.pub)")
	$(Q) SSH_PUB_KEY=$(SSH_PUB_KEY) IMAGE_ID=$(IMAGE_ID) $(EVNSUBST) $(REPLACE) < mainTemplate-template.json > mainTemplate.json
	$(Q) zip -q ./output/consul-app-$(VERSION).zip createUiDefinition.json mainTemplate.json
	$(Q) rm mainTemplate.json

.PHONY: publish
publish: deploy-container pkg ; $(info $(M) publishing…)
	$(info $(M)$(M) fetching location and authorization details…)
	$(eval ROLE_ID := $(shell az role definition list --name Owner --query [].name --output tsv))
	$(eval RG_LOCATION := $(shell az group show -n $(MA_RESOURCE_GROUP) --query 'location' -o tsv))

	$(info $(M)$(M) uploading the managed application to blob named consul-app-$(VERSION).zip…)
	$(Q) az storage blob upload --account-name $(MA_STORAGE_ACCOUNT) -c deployments -f ./output/consul-app-$(VERSION).zip -n consul-app-$(VERSION).zip > /dev/null 2>&1
	$(eval EXPIRY := $(shell gdate -u -d "+30 minutes" '+%Y-%m-%dT%H:%MZ'))
	$(eval SAS_TOKEN := $(shell az storage blob generate-sas --account-name $(MA_STORAGE_ACCOUNT) -c deployments -n consul-app-$(VERSION).zip --permissions r --expiry $(EXPIRY) --https-only -o tsv))
	$(eval BLOB_URL := $(shell az storage blob url --account-name $(MA_STORAGE_ACCOUNT) -c deployments -n consul-app-$(VERSION).zip -o tsv))
	$(info $(M)$(M) blob uploaded to $(BLOB_URL)?"$(SAS_TOKEN)")

	$(info $(M)$(M) creating the managed application definition)
	$(Q) az managedapp definition create --name "managed-consul" \
		--location $(RG_LOCATION) \
		--resource-group $(MA_RESOURCE_GROUP) \
		--lock-level ReadOnly \
		--display-name "Managed Hashicorp Consul" \
		--description "Managed Hashicorp Consul on Azure" \
		--authorizations $(ARM_CLIENT_ID):$(ROLE_ID) \
		--package-file-uri $(BLOB_URL)?"$(SAS_TOKEN)"

.PHONY: clean
clean: ; $(info $(M) removing build artifacts…)
	$(Q) rm -rf ./output

.PHONY: version
version:
	@echo $(VERSION)