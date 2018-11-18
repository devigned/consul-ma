# Consul Managed Application Demo
Hashicorp Consul managed application demo to illustrate the functionality of Azure managed apps.

## Overall solution
The Consul managed application shows a proof of concept of creating a managed application, UI components and deployment 
template to give a bare bones installation of Hashicorp Consul featuring a VNET, Network Security Group and Subnet.

## Getting Started
You will need to provision some base infrastructure in Azure to get started. This is handled via the azure-deploy.tf
template. Just run the following:
```bash
terraform init
# please replace the password in the next line
terraform plan -var 'service_principal_password=${your_super_secret_password}' -out ./plan.out
terraform apply
```
The outputs from the `terraform apply` should now be copy and pasted into a new `.env` file in the root of the project.
After the `.env` file has been created, run the following:
```bash
make image
make
```
Make should run the following steps:
-   Build the VM image required for the VMSS deployment
-   Copy `./provsion-script.sh`, the rendered version of `./provision-script-template.sh`, into the deployment storage 
    container, which will be used in the VMSS deployment
-   Package and publish the managed application

## Make Tasks
-   `make` build and publish everything except the VM image
-	`make consul-start-script` injects service principal credentials into the vmss provisioning script run when the vm 
    is provisioned. This is the script that starts Consul.
-	`make image` will build the base VM image for the VMSS used in the managed app using Hashicorp Packer. This installs 
    Consul 1.4.0, supervisord, Azure CLI and a handful of other software that we wouldn’t want to install during the 
    provisioning phase of the vmss.
-	`make pkg` will zip up the managed application, which consists of 
    [the UI definition file](./createUiDefinition.json) and [the deployment template](./mainTemplate-template.json). It 
    does a transform of the deployment package to inject the storage account name and key before zip.
-	`make publish` uploads the manage app package and creates the manged app definition with az cli.
-   `./sideload-createuidef.sh` will provide a URI to allow for quick UI debugging while building new UI components.

## Developing
When making changes to the managed application, one should simply need to call `make` to republish the managed 
application definition as well as all dependant resources.