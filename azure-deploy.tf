variable "location" {
  description = "Azure datacenter to deploy to."
  default = "westus2"
}

variable "resource_group_name" {
  description = "Resource group to provision test infrastructure in."
  default = "consul-managed-app1"
}

variable "service_principal_password" {
  description = "Password for the service principal that will managed the Managed Application"
}

# Data resources used to get SubID and Tennant Info
data "azurerm_client_config" "current" {}

resource "random_string" "name" {
  keepers = {
    # Generate a new id each time we switch to a new resource group
    group_name = "${var.resource_group_name}"
  }

  length  = 8
  upper   = false
  special = false
  number  = false
}

resource "azurerm_resource_group" "managed_app" {
  name = "${var.resource_group_name}"
  location = "${var.location}"
}

// Application for Packer to use to generate the managed application VMSS image
resource "azurerm_azuread_application" "managed_app" {
  name                       = "Managed Application Packer Builder"
  homepage                   = "https://managedapplication-${random_string.name.result}"
  identifier_uris            = ["https://managedapplication-${random_string.name.result}"]
  reply_urls                 = ["https://managedapplication-${random_string.name.result}"]
  available_to_other_tenants = false
  oauth2_allow_implicit_flow = true
}

resource "azurerm_azuread_service_principal" "managed_app" {
  application_id = "${azurerm_azuread_application.managed_app.application_id}"
}

resource "azurerm_azuread_service_principal_password" "managed_app" {
  service_principal_id = "${azurerm_azuread_service_principal.managed_app.id}"
  value                = "${var.service_principal_password}"
  end_date             = "2020-01-01T01:02:03Z"
}

# This role provides access for packer to generate the managed image within the subscription
resource "azurerm_role_assignment" "managed_app" {
  scope                = "subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Owner"
  principal_id         = "${azurerm_azuread_service_principal.managed_app.id}"
}

# This provides permissions to the Managed Application resource provider, so that it can read the
# packer image within the managed application definition group when deploying an instance of the
# managed application.
resource "azurerm_role_assignment" "appliance_resource_provider" {
  scope                = "subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${azurerm_resource_group.managed_app.name}"
  role_definition_name = "Reader"
  principal_id         = "8b967430-badb-45ba-8d11-bca192994047"
}

resource "azurerm_storage_account" "managed_app" {
  name                     = "consulma${random_string.name.result}"
  resource_group_name      = "${azurerm_resource_group.managed_app.name}"
  location                 = "${var.location}"
  account_kind             = "BlobStorage"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

output "ARM_SUBSCRIPTION_ID" {
  value = "${data.azurerm_client_config.current.subscription_id}"
}

output "ARM_TENANT_ID" {
  value = "${data.azurerm_client_config.current.tenant_id}"
}

output "ARM_CLIENT_ID" {
  value = "${azurerm_azuread_application.managed_app.application_id}"
}

output "ARM_CLIENT_SECRET" {
  value = "${azurerm_azuread_service_principal_password.managed_app.value}"
}

output "MA_RESOURCE_GROUP" {
  value = "${var.resource_group_name}"
}

output "MA_STORAGE_ACCOUNT" {
  value = "${azurerm_storage_account.managed_app.name}"
}

output "MA_STORAGE_ACCOUNT_KEY" {
  value = "${azurerm_storage_account.managed_app.primary_access_key}"
}