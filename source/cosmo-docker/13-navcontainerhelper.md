---
layout: page
title: "13 Using navcontainerhelper"
description: ""
keywords: ""
permalink: "cosmo-docker-13-navcontainerhelper"
slug: "cosmo-docker-13-navcontainerhelper"
---
{::options parse_block_html="true" /}
Table of content
- [Preparation](#preparation)
- [Run your first container](#run-your-first-container)
- [Compile an extension in a container](#compile-an-extension-in-a-container)
- [Publish an extension to a container](#publish-an-extension-to-a-container)

&nbsp;<br />

### Preparation
The first step when using navcontainerhelper is of course to install it
```bash
install-module navcontainerhelper -force
```

### Run your first container
With that in place, we can now create our first container using navcontainerhelper. We also need to accept the EULA and tell it which image to use. Navcontainerhelper also has a mandatory parameter for the container name when creating a new one and it defaults to Windows authentication when nothing else is set, so it asks for your credentials. If you just put in your local Windows credentials, you get SSO. A very helpful parameter is `-updateHosts` which automatically creates the entry to your hosts file which we created manually to make sure you can reach the container by name. With that we have the following initial command:
```bash
New-BCContainer -accept_eula -imageName mcr.microsoft.com/businesscentral/onprem:ltsc2019 -containerName helper -updateHosts
```
It also does a couple of additional default settings like e.g. disabling the event log dump which the standard image does to avoid the corresponding CPU load or disabling the self-signed SSL certificates. It also adds some useful information to your output which is especially helpful when you ask questions or file bugs, so make sure to always add the full output in those case.
<details><summary markdown="span">Full output of New-BCContainer</summary>
```bash
PS C:\> New-BCContainer -accept_eula -imageName mcr.microsoft.com/businesscentral/onprem:ltsc2019 -containerName helper -updateHosts
NavContainerHelper is version 0.6.4.18
NavContainerHelper is running as administrator
Host is Microsoft Windows Server 2019 Datacenter - ltsc2019
Docker Client Version is 19.03.4
Docker Server Version is 19.03.4
Using image mcr.microsoft.com/businesscentral/onprem:ltsc2019
Creating Container helper
Version: 15.1.37793.0-W1
Style: onprem
Platform: 15.0.37769.0
Generic Tag: 0.0.9.96
Container OS Version: 10.0.17763.805 (ltsc2019)
Host OS Version: 10.0.17763.805 (ltsc2019)
Using locale en-US
Using process isolation
Disabling the standard eventlog dump to container log every 2 seconds (use -dumpEventLog to enable)
Files in C:\ProgramData\NavContainerHelper\Extensions\helper\my:
- AdditionalOutput.ps1
- MainLoop.ps1
- SetupVariables.ps1
- SetupWebClient.ps1
- updatehosts.ps1
Creating container helper from image mcr.microsoft.com/businesscentral/onprem:ltsc2019
b5e012ff2b1a48ffbede7c6ce023a0a993fadac0873b288f5c8c87c8a0d09f58
Waiting for container helper to be ready
Initializing...
Setting host.containerhelper.internal to 172.27.0.1 in container hosts file
Starting Container
Hostname is
PublicDnsName is helper
Using Windows Authentication
Starting Local SQL Server
Starting Internet Information Server
Modifying Service Tier Config File with Instance Specific Settings
Starting Service Tier
Registering event sources
Creating DotNetCore Web Server Instance
Creating http download site
Creating Windows user CosmoAdmin
Setting SA Password and enabling SA
Creating SUPER user
Container IP Address: 172.27.1.1
Container Hostname  :
Container Dns Name  : helper
Web Client          : http://helper/BC/
Dev. Server         : http://helper
Dev. ServerInstance : BC
Setting helper to 172.27.1.1 in host hosts file

Files:
http://helper:8080/al-4.0.194000.vsix

Initialization took 45 seconds
Ready for connections!
Reading CustomSettings.config from helper
Creating Desktop Shortcuts for helper
Container helper successfully created
```
</details>
&nbsp;<br />

When the container is available, you also get helpful shortcuts on your Desktop, which you can use to access the WebClient or get a PowerShell session into the container. You can either use those or enter http://helper/BC to get to the WebClient

### Compile an extension in a container
Navcontainerhelper brings a lot of additional helper functions for dealing with extensions. Whether you are bringing your C/AL code modifications to AL, working on an AL-native project or setting up your CI/CD environment, navcontainerhelper brings useful cmdlets. One such example is the ability to compile an extension in a container. For that, we first need to get the AL extension for VS Code: You can either install it through Visual Studio Code itself (go to the extensions view and search for "AL") or PowerShell (`code --install-extension ms-dynamics-smb.al`). While you are at it, you might want to install the Docker extension as well and play with it (search for "Docker" or run `code --install-extension ms-azuretools.vscode-docker`). When the AL extension install has finished, hit Ctrl+Alt+P and enter "AL: Go" to create the AL demo project. Use the default folder and select target platform 4.0. This will give you a small sample extension and the VS code window will refresh. Hit ESC when asked about your server as we will use navcontainerhelper for compiling our extension.

For the container to be able to access the sources, we need to set up a bind mount for that folder. Therefore, remove the first container, create a second one with a bind mount for our little project and then run the compile command. Note the usage of `-additionalParameters` which is the mechanism of navcontainerhelper to add any parameter to the the actual docker run command it generates.
```bash
Remove-BCContainer -containerName helper
New-BCContainer -accept_eula -imageName mcr.microsoft.com/businesscentral/onprem:ltsc2019 -containerName compile -updateHosts -additionalParameters @("-v c:\users\CosmoAdmin\Documents\AL\ALProject1\:c:\src")
Compile-AppInBCContainer -containerName compile -appProjectFolder c:\users\CosmoAdmin\Documents\AL\ALProject1\
```

<details><summary markdown="span">Full output of removing and creating the container and then compiling the extension</summary>
```bash
PS C:\> Remove-BCContainer -containerName helper
Removing container helper
Removing helper from host hosts file
Removing C:\ProgramData\NavContainerHelper\Extensions\helper
PS C:\> New-BCContainer -accept_eula -imageName mcr.microsoft.com/businesscentral/onprem:ltsc2019 -containerName compile -updateHosts -additionalParameters @("-v c:\users\CosmoAdmin\Documents\AL\ALProject1\:c:\src")
NavContainerHelper is version 0.6.4.18
NavContainerHelper is running as administrator
Host is Microsoft Windows Server 2019 Datacenter - ltsc2019
Docker Client Version is 19.03.4
Docker Server Version is 19.03.4
Using image mcr.microsoft.com/businesscentral/onprem:ltsc2019
Creating Container compile
Version: 15.1.37793.0-W1
Style: onprem
Platform: 15.0.37769.0
Generic Tag: 0.0.9.96
Container OS Version: 10.0.17763.805 (ltsc2019)
Host OS Version: 10.0.17763.805 (ltsc2019)
Using locale en-US
Using process isolation
Disabling the standard eventlog dump to container log every 2 seconds (use -dumpEventLog to enable)
Files in C:\ProgramData\NavContainerHelper\Extensions\compile\my:
- AdditionalOutput.ps1
- MainLoop.ps1
- SetupVariables.ps1
- SetupWebClient.ps1
- updatehosts.ps1
Creating container compile from image mcr.microsoft.com/businesscentral/onprem:ltsc2019
94da85725c4c80f25d8f7209afbdc92cf1a5c178f851df6103e8c774c18c18e9
Waiting for container compile to be ready
Initializing...
Setting host.containerhelper.internal to 172.27.0.1 in container hosts file
Starting Container
Hostname is
PublicDnsName is compile
Using Windows Authentication
Starting Local SQL Server
Starting Internet Information Server
Modifying Service Tier Config File with Instance Specific Settings
Starting Service Tier
Registering event sources
Creating DotNetCore Web Server Instance
Creating http download site
Creating Windows user CosmoAdmin
Setting SA Password and enabling SA
Creating SUPER user
Container IP Address: 172.27.4.17
Container Hostname  :
Container Dns Name  : compile
Web Client          : http://compile/BC/
Dev. Server         : http://compile
Dev. ServerInstance : BC
Setting compile to 172.27.4.17 in host hosts file

Files:
http://compile:8080/al-4.0.194000.vsix

Initialization took 46 seconds
Ready for connections!
Reading CustomSettings.config from compile
Creating Desktop Shortcuts for compile
Container compile successfully created
PS C:\> Compile-AppInBCContainer -containerName compile -appProjectFolder c:\users\CosmoAdmin\Documents\AL\ALProject1\
Using Symbols Folder: c:\users\CosmoAdmin\Documents\AL\ALProject1\.alpackages
Downloading symbols: Microsoft_System_15.0.37769.0.app
Url : http://172.27.4.17:7049/BC/dev/packages?publisher=Microsoft&appName=System&versionText=15.0.0.0&tenant=default
Downloading symbols: Microsoft_System Application_15.1.37793.0.app
Url : http://172.27.4.17:7049/BC/dev/packages?publisher=Microsoft&appName=System Application&versionText=1.0.0.0&tenant=default
Downloading symbols: Microsoft_Base Application_15.1.37793.0.app
Url : http://172.27.4.17:7049/BC/dev/packages?publisher=Microsoft&appName=Base Application&versionText=15.0.0.0&tenant=default
Compiling...
alc.exe /project:c:\src\ /packagecachepath:c:\src\.alpackages /out:c:\src\output\Default publisher_ALProject1_1.0.0.0.app /assemblyprobingpaths:"C:\Program Files (x86)\Microsoft Dynamics NAV\150\RoleTailored Client","C:\Program Files\Microsoft Dynamics NAV\150\Service","C:\Program Files (x86)\Open XML SDK\V2.5\lib","c:\windows\assembly","C:\Test Assemblies\Mock Assemblies"
Microsoft (R) AL Compiler version 4.0.2.62932
Copyright (C) Microsoft Corporation. All rights reserved

Compilation started for project 'ALProject1' containing '1' files at '23:18:47.867'.


Compilation ended at '23:18:54.276'.

c:\users\CosmoAdmin\Documents\AL\ALProject1\output\Default publisher_ALProject1_1.0.0.0.app successfully created in 29 seconds
c:\users\CosmoAdmin\Documents\AL\ALProject1\output\Default publisher_ALProject1_1.0.0.0.app
```
</details>
&nbsp;<br />

### Publish an extension to a container
Now the last step is to publish that extension to a container. To make sure we are starting form a clean slate, we remove the container again, create a new one and publish (and sync and install) the extension. Note that we no longer need to bind mount the source folder as the communication now works through the management APIs provided by the development service in the container. We need to add the `-skipVerification` parameter as we don't have code signing in place, but for development purposes, that is ok. 
```bash
Remove-BCContainer compile
New-BCContainer -accept_eula -imageName mcr.microsoft.com/businesscentral/onprem:ltsc2019 -containerName publish -updateHosts
Publish-NavContainerApp -containerName publish -appFile "C:\Users\CosmoAdmin\Documents\AL\ALProject1\output\Default publisher_ALProject1_1.0.0.0.app" -skipVerification -sync -install
```

<details><summary markdown="span">Full output of remove, create and publish</summary>
```bash
PS C:\> Remove-BCContainer compile
Removing container compile
Removing compile from host hosts file
Removing C:\ProgramData\NavContainerHelper\Extensions\compile
PS C:\> New-BCContainer -accept_eula -imageName mcr.microsoft.com/businesscentral/onprem:ltsc2019 -containerName publish -updateHosts
NavContainerHelper is version 0.6.4.18
NavContainerHelper is running as administrator
Host is Microsoft Windows Server 2019 Datacenter - ltsc2019
Docker Client Version is 19.03.4
Docker Server Version is 19.03.4
Using image mcr.microsoft.com/businesscentral/onprem:ltsc2019
Creating Container publish
Version: 15.1.37793.0-W1
Style: onprem
Platform: 15.0.37769.0
Generic Tag: 0.0.9.96
Container OS Version: 10.0.17763.805 (ltsc2019)
Host OS Version: 10.0.17763.805 (ltsc2019)
Using locale en-US
Using process isolation
Disabling the standard eventlog dump to container log every 2 seconds (use -dumpEventLog to enable)
Files in C:\ProgramData\NavContainerHelper\Extensions\publish\my:
- AdditionalOutput.ps1
- MainLoop.ps1
- SetupVariables.ps1
- SetupWebClient.ps1
- updatehosts.ps1
Creating container publish from image mcr.microsoft.com/businesscentral/onprem:ltsc2019
4253de61241b6cb4205f1d62d976fc5d254aa7fb53fb44a77fd3249b2e138b83
Waiting for container publish to be ready
Initializing...
Setting host.containerhelper.internal to 172.27.0.1 in container hosts file
Starting Container
Hostname is
PublicDnsName is publish
Using Windows Authentication
Starting Local SQL Server
Starting Internet Information Server
Modifying Service Tier Config File with Instance Specific Settings
Starting Service Tier
Registering event sources
Creating DotNetCore Web Server Instance
Creating http download site
Creating Windows user CosmoAdmin
Setting SA Password and enabling SA
Creating SUPER user
Container IP Address: 172.27.0.56
Container Hostname  :
Container Dns Name  : publish
Web Client          : http://publish/BC/
Dev. Server         : http://publish
Dev. ServerInstance : BC
Setting publish to 172.27.0.56 in host hosts file

Files:
http://publish:8080/al-4.0.194000.vsix

Initialization took 46 seconds
Ready for connections!
Reading CustomSettings.config from publish
Creating Desktop Shortcuts for publish
Container publish successfully created
PS C:\> Publish-NavContainerApp -containerName publish -appFile "C:\Users\CosmoAdmin\Documents\AL\ALProject1\output\Default publisher_ALProject1_1.0.0.0.app" -skipVerification -sync -install
Publishing C:\ProgramData\NavContainerHelper\Extensions\publish\_Default publisher_ALProject1_1.0.0.0.app
Synchronizing ALProject1 on tenant default
Installing ALProject1 on tenant default
App successfully published
```
</details>
&nbsp;<br />
To verify that you have successfully published the extension, go to http://publish/BC/ or use the shortcut on your desktop. In BC, go to customers and you will see the Hello World message. You will also find the app in extension management
{::options parse_block_html="true" /}
