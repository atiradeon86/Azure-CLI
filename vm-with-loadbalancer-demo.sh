#!/bin/bash
backendpool=("")

#Base Settings
RG="RG-user06";
Admin="bryan";

#Set default ResourceGroup
az configure --defaults group=$RG

Vnet_Name="bryan-vnet";
Subnet="bryan-subnet";

Nsg="bryan-NSG";

SSH_Key_Name="bryan-ssh";

#LoadBalancer
LB_Name="bryan-cli-loadbalancer"
LB_Frontend_IP_Name="bryan-lb-frontend-ip"
LB_Public_IP_Name="bryan-lb-publicip"
LB_Public_IP_DNS_Name="bryan-cli-loadbalancer"

#Healtprobe
LB_Healtprobe="bryan-healtprobe"
LB_Loadbalance_rule="bryan-loadbalance-rule"


#Create load-balancer
az network lb create --name $LB_Name \
--sku Standard \
--frontend-ip-name $LB_Frontend_IP_Name \
--public-ip-address $LB_Public_IP_Name \
--public-ip-dns-name $LB_Public_IP_DNS_Name

#VM Create

for i in 1 2
do

echo "VM Createing $i ..."

VM_Name="bryan-testing-$i"
Public_Ip_Name="pm-testing$i"

#Check
az config get

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
--os-disk-delete-option Delete \


#Get VM public ip
Ip=$(az vm show -d -g $RG -n $VM_Name --query publicIps -o tsv)

#Get VM private ip
Ip_Private=$(az vm show -d -g $RG -n $VM_Name --query privateIps -o tsv)


#Debug -> SSH Connect string -<
echo ssh -i $SSH_Key_Name "$Admin@$Ip"

#Get default address-pool name
ap=$(az network lb address-pool list --lb-name $LB_Name | grep name | cut -d "\"" -f4)

if [ -z "$backendpool" ]; then
        backendpool+=$Ip_Private
        webserver="nginx"
else
backendpool+=","$Ip_Private
webserver="apache2"
fi

#Add Debug
echo "Show Debug"

echo $backendpool
echo $webserver

#HTTP Port Open
az vm open-port -g $RG --name $VM_Name --port 80

#Install Webserver
echo "Install Webserver"

az vm run-command invoke \
   -g $RG \
   -n $VM_Name \
   --command-id RunShellScript \
   --scripts "sudo apt-get update && sudo apt-get install -y $webserver"

done

#Add backend pool
echo "Create backend pool"

cmd="az network lb address-pool update --name $ap --lb-name $LB_Name --vnet $Vnet_Name "
    counter=0
    IFS=,
    for i in $backendpool
    do
    counter=$((counter+1))
    cmd+=" --backend-address name=addr$counter ip-address=$i"
    done

eval $cmd

#Add Healtprobe
echo "Create Healtprobe"

az network lb probe create --name $LB_Healtprobe \
--lb-name $LB_Name \
--port 80 \
--protocol Tcp \
--interval 7 \
--threshold 3

# Add Load balance rule
echo "Create Load balance rule"

az network lb rule create --name $LB_Loadbalance_rule \
--lb-name $LB_Name \
--frontend-port 80 \
--backend-port 80 \
--protocol Tcp \
--backend-pool-name $ap \
--frontend-ip-name $LB_Frontend_IP_Name \
--probe-name $LB_Healtprobe
