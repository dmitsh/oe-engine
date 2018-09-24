#!/bin/bash

# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

# Install required packages.
#

source /opt/azure/acc/utils.sh

cd /opt/azure/acc/

OE_PKG_BASE="PACKAGE_BASE_URL"

# Check to see this is an openenclave supporting hardware environment
retrycmd_if_failure 10 10 120 curl -fsSL -o oesgx "$OE_PKG_BASE/oesgx"
chmod a+x ./oesgx

./oesgx | grep "does not support"
if [ $? -eq 0 ] ; then
    echo "This hardware does not support open enclave"
    exit -1
fi

# Setup repositories for clang-7
echo "deb http://apt.llvm.org/xenial/ llvm-toolchain-xenial main" >> /etc/apt/sources.list
echo "deb-src http://apt.llvm.org/xenial/ llvm-toolchain-xenial main" >> /etc/apt/sources.list
echo "deb http://apt.llvm.org/xenial/ llvm-toolchain-xenial-6.0 main" >> /etc/apt/sources.list
echo "deb-src http://apt.llvm.org/xenial/ llvm-toolchain-xenial-6.0 main" >> /etc/apt/sources.list
echo "deb http://apt.llvm.org/xenial/ llvm-toolchain-xenial-7 main" >> /etc/apt/sources.list
echo "deb-src http://apt.llvm.org/xenial/ llvm-toolchain-xenial-7 main" >> /etc/apt/sources.list
wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -

# Update pkg repository
retrycmd_if_failure 10 10 120 apt update
if [ $? -ne 0  ]; then
  exit 1
fi

# Install public packages:
PACKAGES="make gcc g++ libmbedtls10 libssl-dev dh-exec libcurl3 libprotobuf9v5"

retrycmd_if_failure 10 10 120 apt-get -y install $PACKAGES
if [ $? -ne 0  ]; then
  exit 1
fi

# Install clang-7 packages:
PACKAGES="clang-7 lldb-7 lld-7"

retrycmd_if_failure 10 10 120 apt-get -y install $PACKAGES
if [ $? -ne 0  ]; then
  exit 1
fi

# Install OE packages
OE_PACKAGES=(
  libsgx-enclave-common_2.3.100.46354-1_amd64.deb
  libsgx-enclave-common-dev_2.3.100.0-1_amd64.deb
  libsgx-dcap-ql_1.0.100.46460-1.0_amd64.deb
  libsgx-dcap-ql-dev_1.0.100.46460-1.0_amd64.deb
  azquotprov_0.3-1_amd64.deb
  open-enclave-0.2.0-Linux.deb
)

for pkg in ${OE_PACKAGES[@]}; do
  retry_get_install_deb 10 10 120 "$OE_PKG_BASE/$pkg"
  if [ $? -ne 0  ]; then
    exit 1
  fi
done

systemctl disable aesmd
systemctl stop aesmd

# Install SGX driver
retrycmd_if_failure 10 10 120 curl -fsSL -o sgx_linux_x64_driver_dcap_36594a7.bin "$OE_PKG_BASE/sgx_linux_x64_driver_dcap_36594a7.bin"
if [ $? -ne 0  ]; then
  exit 1
fi
chmod a+x ./sgx_linux_x64_driver_dcap_36594a7.bin
./sgx_linux_x64_driver_dcap_36594a7.bin
if [ $? -ne 0  ]; then
  exit 1
fi

# Indicate readiness
touch /opt/azure/acc/completed
