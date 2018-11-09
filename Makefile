
image: export ARM_TENANT_ID=$(PKR_AZ_TENANT_ID)
image: export ARM_SUBSCRIPTION_ID=$(PKR_AZ_SUBSCRIPTION_ID)
image: export ARM_CLIENT_ID=$(PKR_AZ_CLIENT_ID)
image: export ARM_CLIENT_SECRET=$(PKR_AZ_CLIENT_SECRET)
image:
	packer build -var 'azure_location=$(location)' consul.json