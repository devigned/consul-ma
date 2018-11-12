#!make

include .env
export $(shell sed 's/=.*//' .env)

VERSION ?= $(shell git describe --tags --always --dirty --match=v* 2> /dev/null || \
			cat $(CURDIR)/.version 2> /dev/null || echo v0)
V 		= 0
Q 		= $(if $(filter 1,$V),,@)
M 		= $(shell printf "\033[34;1m▶\033[0m")

.PHONY: image
image: ; $(info $(M) building VM image using packer...)
	$(Q) packer build -var 'azure_location=$(location)' consul.json

.PHONY: pkg
pkg: ; $(info $(M) zipping up managed app package…)
	$(shell mkdir -p ./output)
	$(Q) zip -q ./output/consul-app-$(VERSION).zip createUiDefinition.json mainTemplate.json

.PHONY: publish
publish: pkg ; $(info $(M) publishing…)
	$(info $(M)$(M) fetching location and authorization details…)
	$(eval USER_ID := $(shell az ad user show --upn-or-object-id $(MA_UPN) --query objectId --output tsv))
	$(eval ROLE_ID := $(shell az role definition list --name Owner --query [].name --output tsv))
	$(eval RG_LOCATION := $(shell az group show -n consul-managed-app --query 'location' -o tsv))

	$(info $(M)$(M) ensure the storage container is created…)
	$(Q) az storage container create --account-name $(MA_STORAGE_ACCOUNT) -n $(MA_STORAGE_CONTAINER) > /dev/null

	$(info $(M)$(M) upload the blob named consul-app-$(VERSION).zip…)
	$(Q) az storage blob upload --account-name $(MA_STORAGE_ACCOUNT) -c $(MA_STORAGE_CONTAINER) -f ./output/consul-app-$(VERSION).zip -n consul-app-$(VERSION).zip > /dev/null 2>&1
	$(eval EXPIRY := $(shell gdate -u -d "+30 minutes" '+%Y-%m-%dT%H:%MZ'))
	$(eval SAS_TOKEN := $(shell az storage blob generate-sas --account-name $(MA_STORAGE_ACCOUNT) -c $(MA_STORAGE_CONTAINER) -n consul-app-$(VERSION).zip --permissions r --expiry $(EXPIRY) --https-only -o tsv))
	$(eval BLOB_URL := $(shell az storage blob url --account-name $(MA_STORAGE_ACCOUNT) -c $(MA_STORAGE_CONTAINER) -n consul-app-$(VERSION).zip -o tsv))
	$(info $(M)$(M) blob uploaded to $(BLOB_URL))

	$(info $(M)$(M) creating the managed application definition)
	$(Q) az managedapp definition create --name "managed-consul" \
		--location $(RG_LOCATION) \
		--resource-group $(MA_RESOURCE_GROUP) \
		--lock-level ReadOnly \
		--display-name "Managed Hashicorp Consul" \
		--description "Managed Hashicorp Consul on Azure supported by Hashicorp" \
		--authorizations $(USER_ID):$(ROLE_ID) \
		--package-file-uri $(BLOB_URL)?"$(SAS_TOKEN)"

.PHONY: clean
clean: ; $(info $(M) removing build artifacts…)
	$(Q) rm -r ./output

.PHONY: version
version:
	@echo $(VERSION)