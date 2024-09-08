---
layout: post
title: "My remote (SSH) development setup with VS Code, part II"
permalink: my-remote-ssh-development-setup-with-vs-code-part-ii
date: 2024-09-08 16:18:24
comments: false
description: "My remote (SSH) development setup with VS Code, part II"
keywords: ""
image: /images/remote-dev-shortcut.png
categories:

tags:

---

## The TL;DR

In the [first part][fp] for this topic, I have shared my little VS Code extension that allows one-click startup of and remote SSH VS Code connection to a configured SSH host. In this second part, I want to share how you can install it as I have by now published it and how you can set up a VM similar to mine:

- To install it, just search for "Remote dev shortcut" and you should find my extension. Install it and you are ready to use it as explained in the [first part][fp]
![remote-dev-shortcut-screenshot](/images/remote-dev-shortcut-screenshot.png)
{: .centered}
- To create an SSH host like I do (Windows 11), you can use the script outlined in the following detail section

## The details: Creating a preconfigured Windows 11 dev VM

As I also mentioned in the first part, Windows 11 is my main day-to-day OS. That wouldn't necessarily block me from using a Linux VM as dev machine, but there are a couple of reasons why I prefer a Windows VM:

- Not everything can be developed in devcontainers, and sometimes you need e.g. for Office add-in development Microsoft Office on the dev VM. Then it is a requirement to run on Windows.
- Most of my development is done in devcontainers and that is very well supported on Windows with [Docker Desktop][dd] with the [WSL2 backend][wsl2], so I am quite happy with that setup as well.
- On conference session, I typically demo from a dev VM as well and then I also like to show a Windows OS as that is still the most widely used environment (at least for the audiences I talk to).

If you have similar requirements or for other reasons want to use a Windows dev VM, you can use the following script, which I'll explain step by step

{% highlight bash linenos %}
loc="germanywestcentral"
rg="devtfe-24" # used as vm name s well
tenant="539f23a3-6819-367e-bd87-7835f4122217"
subsc="94670b10-08d0-4d06-bcfe-e01f701be9ff"
user="azuretfenster"
pwd=$(tr -dc 'A-Za-z0-9!?%=@' < /dev/urandom | head -c 16)
pub_sshkey="/mnt/c/Users/tfenster/.ssh/id_azure.pub"

# az vm image list --publisher MicrosoftWindowsServer --all --offer microsoftserveroperatingsystems-previews --output table
# az vm image list --publisher MicrosoftWindowsDesktop --all --offer Windows-11 --output table
# az vm image list --publisher MicrosoftWindowsServer --all --output table
image="MicrosoftWindowsDesktop:windows-11:win11-23h2-pro:latest"
#image="MicrosoftWindowsServer:microsoftserveroperatingsystems-previews:windows-server-2025-azure-edition-hotpatch:latest"

# https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/overview?tabs=breakdownseries%2Cgeneralsizelist%2Ccomputesizelist%2Cmemorysizelist%2Cstoragesizelist%2Cgpusizelist%2Cfpgasizelist%2Chpcsizelist#list-of-vm-size-families-by-type
# az vm list-sizes -l $loc --output table
size="Standard_D16ds_v5"

sku='Premium_LRS'
diskSize='1024'

key=`cat $pub_sshkey`

echo "Log in and create resource group"
az config set core.login_experience_v2=off 
az login --tenant $tenant
az account set --subscription $subsc
az group create --name $rg --location $loc

echo "Create VM"
# az vm image terms accept --urn $image
az vm create --resource-group $rg --name $rg --image $image --admin-username $user --admin-password $pwd --size $size --location $loc --public-ip-address-dns-name $rg

echo "Configure VM"
az vm extension set --resource-group $rg --vm-name $rg --name WindowsOpenSSH --publisher Microsoft.Azure.OpenSSH --version 3.0
az network nsg rule create -g $rg --nsg-name "${rg}NSG" -n allow-SSH --priority 1100 --destination-port-ranges 22 --protocol TCP
az vm run-command invoke -g $rg -n $rg --command-id RunPowerShellScript --scripts "Add-Content 'C:\ProgramData\ssh\administrators_authorized_keys' -Encoding UTF8 -Value '$key';icacls.exe 'C:\ProgramData\ssh\administrators_authorized_keys' /inheritance:r /grant 'Administrators:F' /grant 'SYSTEM:F'; New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell -Value 'C:\Program Files\PowerShell\7\pwsh.exe' -PropertyType String -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')); choco feature enable -n allowGlobalConfirmation; choco install --no-progress --limit-output vscode docker-desktop git pwsh; Add-LocalGroupMember -Group 'docker-users' -Member '$user'; Enable-WindowsOptionalFeature -Online -FeatureName \$('Microsoft-Hyper-V', 'Containers') -All -NoRestart;"
az vm auto-shutdown -g $rg -n $rg --time 0200
az vm deallocate -g $rg -n $rg
az vm show -n $rg -g $rg --query storageProfile.osDisk.managedDisk -o tsv | awk -v sku=$sku -v diskSize=$diskSize '{system("az disk update --sku "sku" --size-gb "diskSize" --ids "$2)}'
az vm start -g $rg -n $rg

echo "DNS name: $rg.$loc.cloudapp.azure.com"
echo " "
echo "SSH config:"
echo "Host $rg"
echo "  HostName $rg.$loc.cloudapp.azure.com"
echo "  User $user"
echo "  IdentityFile c:\\users\\tfenster\\.ssh\\id_azure"
echo " "
echo "Deny direct RDP access:"
echo "az network nsg rule update --access Deny -g $rg --nsg-name '${rg}NSG' -n rdp"
echo " "
echo "RDP access via SSH tunnel:"
echo "mstsc /v:localhost:33389 /f; ssh -L 33389:localhost:3389 $rg -N"
echo " "
echo "cleanup:"
echo "az group delete -n $rg --no-wait"
echo " "
echo "Log in once via RDP to go through initial Windows wizard, open Docker Desktop to finish installation, log in and go through settings and maybe set up OneDrive!"
echo "User is $user and Password is $pwd"
{% endhighlight %}

Let's take a look what happens as the script logs in, creates the required resources, configures them and shows the results:

- Lines 1 to 7 are setup: We define the Azure region where the resources are created in line 1. Line 2 defines the resource group name, which is also used for the VM. The tenant ID and subscription ID are set up in lines 3 and 4. Line 5 and 6 define the user for the VM and the password. Note that I create a new random one which will at the very end by printed out, so you can store it e.g. in your password manager. And line 7 references the public key for the SSH connection we'll use later
- Line 12 selects the image to be used. You can use the commands in lines 9-11 to figure out which one you want to use, either for Windows Server (if you want to use that as base VM) or Windows 11.
- Line 17 configures the VM size. To find out which one you want to use, you can use the link in line 15 or the command in line 16.
- Lines 19 and 20 set up the disk, first the SKU and then the size in GB
- Line 22 puts the public key content into a variable
- Lines 24-27 are used to log in and select the right subscription, followed by creating the resource group in line 28.
- Lines 30-32 create the VM. Depending on the image you selected, you might have to accept terms first, e.g. if it is a preview image, which can be done with the command in line 31. Line 32 creates the VM with probably the expected parameters with maybe one lesser known one: You can immediately set up a public IP address DNS name with the `--public-ip-address-dns-name`. Note that this is only the prefix, the rest (in my case `.germanywestcentral.cloudapp.azure.com`) is automatically defined by Azure.
- Line 35 configures [OpenSSH][ossh] easily through a predefined [Azure VM extension][ave]
- Line 36 opens the SSH port in the Azure Firewall
- Line 37 runs a PowerShell command on the VM which:
  - sets up PowerShell 7 as default when connection through SSH, installs [Chocolatey][choco], 
  - uses it to install [Visual Studio Code][vsc], [Docker Desktop][dd], [Git][git] and [PowerShell][pwsh]
  - adds the user to the `docker-users` group and enables the `Hyper-V` and `Containers` optional features to make Linux containers work
  This gives me a VM with my most-used tools. As development is typically happening in devcontainers for me, I don't need other SDKs or tech stacks.
- Line 38 sets up autostop for the VM at 2:00 AM in case I forget to stop it
- Line 39 deallocates the VM, which is required for the next step in line 40 where we get the ID of the disk and then update it to the right SKU and size
- In line 41 the VM is started again and the setup is finished
- Lines 43-61 are the only outputs: 
  - Lines 46-49 show the right SSH config, intended to be copied into your ~/.ssh/config file. 
  - The command shown in line 52 can be used to deactivate RDP connections and that in line 55 gives you a command to set up an SSH tunnel to connect over via RDP. This gives you a safer connection option for RDP. 
  - Line 58 gives you a command to remove everything if needed. 
  - Line 60 explains the manual steps you need to go through to finalize the installation which can't be automated (yet)
  - The final line 61 gives you the user name and password to use when connecting via RDP

## The details: How to connect via RDP and when it is needed

You might be wondering why all those RDP steps are in there if I only aim to create a remote SSH VS Code instance. The reason is that I use Docker Desktop and that can unfortunately at the moment only start in a user session. Therefore, I need to connect via RDP (over the SSH tunnel), which then triggers the autostart of Docker Desktop. I heard that there will be an easier way to achieve this in the future, but for now that is required. You do this with the command in line 55, which looks e.g. like this assuming that your VM is called `devvm`: `mstsc /v:localhost:33389 /f; ssh -L 33389:localhost:3389 devvm -N`. The `mstsc` call opens a remote desktop connection to `localhost:33389`. The following `ssh` call creates a tunnel listening on `localhost:33389` which connects to the standard RDP port `3389` on your dev VM.

I hope this helps you to get an idea of how my remote dev setup works and ideally take this directly or as inspiration for your setup.

[fp]: /my-remote-ssh-development-setup-with-vs-code-part-i
[ossh]: https://www.openssh.com/
[ave]: https://learn.microsoft.com/en-us/azure/virtual-machines/extensions/features-windows
[choco]: https://chocolatey.org/
[vsc]: https://code.visualstudio.com/
[dd]: https://www.docker.com/products/docker-desktop/
[git]: https://git-scm.com/
[pwsh]: https://learn.microsoft.com/en-us/powershell/scripting/overview