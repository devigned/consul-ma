# Consul Managed Application Demo
Hashicorp Consul managed application demo to illustrate the functionality of Azure managed apps.

## Basics
-	`make consul-start-script` injects service principal credentials into the vmss provisioning script run when the vm 
    is provisioned. This is the script that starts Consul.
-	`make image` will build the base VM image for the VMSS used in the managed app using Hashicorp Packer. This installs 
    Consul 1.4.0, supervisord, Azure CLI and a handful of other software that we wouldn’t want to install during the 
    provisioning phase of the vmss.
-	`make pkg` will zip up the managed application, which consists of the UI definition file and the deployment 
    template. It does a transform of the deployment package to inject the storage account name and key before zip.
-	`make publish` uploads the manage app package and creates the manged app definition with az cli.

## Overall solution
The Consul managed application shows a proof of concept of creating a managed application, UI components and deployment 
template to give a bare bones installation of Hashicorp Consul featuring a VNET, Network Security Group and Subnet.

