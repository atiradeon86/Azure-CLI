#!/bin/bash

#Example
# wget https://raw.githubusercontent.com/atiradeon86/Azure-CLI/main/vm-create.sh
# chmod +x vm-create.sh && bash vm-create.sh

#Azure CLI install
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

#Upload your SSH Key

#Data setup

VM_Name="bryan-httpd";
RG="RG-user06";
Admin="bryan";
Vnet_Name="Bryan-vnet";
Subnet="httpd";
Public_Ip_Name="az-cli-vm-httpd-public"
Nsg="bryan-httpdNSG";
SSH_Key_Name="Bryan-SSH";

#Azure Login

az login

#VM Create

az vm create --name $VM_Name \
--priority Spot \
--max-price -1 \
--eviction-policy Deallocate \
--resource-group $RG \
--image Canonical:0001-com-ubuntu-server-focal:20_04-lts:latest \
--size Standard_D2as_v4 \
--authentication-type ssh \
--admin-username $Admin \
--ssh-key-name $SSH_Key_Name \
--nsg-rule SSH \
--storage-sku StandardSSD_LRS \
--vnet-name $Vnet_Name \
--subnet $Subnet \
--public-ip-address $Public_Ip_Name \
--nsg $Nsg \
--public-ip-sku Basic \
--public-ip-address-allocation dynamic \
--nic-delete-option Delete \
--os-disk-delete-option Delete

#HTTP Port Open
az vm open-port -g $RG --name $VM_Name --port 80

#Install nginx
az vm run-command invoke \
   -g $RG \
   -n $VM_Name \
   --command-id RunShellScript \
   --scripts "sudo apt-get update && sudo apt-get install -y nginx"

#Get VM public ip
Ip=$(az vm show -d -g $RG -n $VM_Name --query publicIps -o tsv)

#SSH Connect string
echo ssh -i $SSH_Key_Name "$Admin@$Ip"
