#!/bin/bash

set -e

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
cd $DIR

###

API_MODEL=$1
if [[ -z "${API_MODEL:-}" ]]; then echo "Usage: $0 <api-model>"; exit 1; fi

if [[ -z "${SUBSCRIPTION_ID:-}" ]]; then echo "Must specify SUBSCRIPTION_ID"; exit 1; fi
if [[ -z "${TENANT_ID:-}" ]]; then echo "Must specify TENANT_ID"; exit 1; fi

if [[ -z "${SERVICE_PRINCIPAL_ID:-}" ]]; then echo "Must specify SERVICE_PRINCIPAL_ID"; exit 1; fi
if [[ -z "${SERVICE_PRINCIPAL_PASSWORD:-}" ]]; then echo "Must specify SERVICE_PRINCIPAL_PASSWORD"; exit 1; fi

LOCATION=eastus

az login --service-principal -u ${SERVICE_PRINCIPAL_ID} -p ${SERVICE_PRINCIPAL_PASSWORD} --tenant ${TENANT_ID}
az account set --subscription ${SUBSCRIPTION_ID}

SSH_PUB_KEY=$(az keyvault secret show --vault-name oe-ci-test-kv --name id-rsa-oe-test-pub | jq -r .value | base64 -d)
sed -i "/\"keyData\":/c \"keyData\": \"${SSH_PUB_KEY}\"" ${API_MODEL}

ADMIN_PASSWORD=$(az keyvault secret show --vault-name oe-ci-test-kv --name windows-pwd | jq -r .value)
sed -i "/\"adminPassword\":/c \"adminPassword\": \"${ADMIN_PASSWORD}\"" ${API_MODEL}

ID=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 6)

../bin/oe-engine generate --api-model ${API_MODEL} --output-directory "_output/$ID"

RGNAME="oe-engine-pr-${BUILD_NUMBER}-$ID"
az group create --name $RGNAME --location $LOCATION
trap 'az group delete --name $RGNAME --yes --no-wait' EXIT
az group deployment create -n $ID -g $RGNAME --template-file _output/$ID/azuredeploy.json --parameters _output/$ID/azuredeploy.parameters.json
