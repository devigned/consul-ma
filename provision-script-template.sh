#!/usr/bin/env bash

# This script is meant to be run in the Custom Data of each Azure Instance while it's booting. The script uses the
# run-consul script to configure and start Consul in server mode. Note that this script assumes it's running in an Image
# built from the Packer template in examples/consul-image/consul.json.

set -e

# Send the log output from this script to custom-data.log, syslog, and the console
exec > >(tee /var/log/custom-data.log|logger -t custom-data -s 2>/dev/console) 2>&1

# These variables are passed in via Terraform template interplation
/opt/consul/bin/run-consul --server --scale-set-name "consulScaleSet" --subscription-id "${ARM_SUBSCRIPTION_ID}" --tenant-id "${ARM_TENANT_ID}" --client-id "${ARM_CLIENT_ID}" --secret-access-key "${ARM_CLIENT_SECRET}"
