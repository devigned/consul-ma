#!make

include .env
export $(shell sed 's/=.*//' .env)

image:
	packer build -var 'azure_location=$(location)' consul.json

pkg:
	zip app.zip createUiDefinition.json mainTemplate.json