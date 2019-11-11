---
layout: page
title: "10 Business Central Script Overwrite"
description: ""
keywords: ""
permalink: "td19-10-bc-script-overwrite"
slug: "td19-10-bc-script-overwrite"
---
{::options parse_block_html="true" /}
Table of content
- [Activate the API in AdditionalSetup.ps1 using a c:\run\my bind mount](#activate-the-api-in-additionalsetupps1-using-a-crunmy-bind-mount)

&nbsp;<br />

### Activate the API in AdditionalSetup.ps1 using a c:\run\my bind mount
In order to activate the external API in a BC OnPrem 13 instance, we need to enable a NST setting and also run Codeunit 5465. This can easily be automated with a script like the one [here](https://raw.githubusercontent.com/tfenster/nav-docker-samples/initialize-api/AdditionalSetup.ps1). In order to use it, just download it into e.g. c:\temp and bind mount that to c:\run\my when starting the container
```bash
wget -UseBasicParsing -Uri https://raw.githubusercontent.com/tfenster/nav-docker-samples/initialize-api/AdditionalSetup.ps1 -OutFile c:\temp\AdditionalSetup.ps1
docker run --name api -e accept_eula=y -e usessl=n -v c:\temp:c:\run\my -e customNavSettings="ApiServicesEnabled=true" mcr.microsoft.com/businesscentral/onprem:1810-ltsc2019
```

<details><summary markdown="span">Full output of details</summary>
```bash
PS C:\temp> wget -UseBasicParsing -Uri https://raw.githubusercontent.com/tfenster/nav-docker-samples/initialize-api/AdditionalSetup.ps1 -OutFile c:\temp\AdditionalSetup.ps1
PS C:\temp> docker run --name api -e accept_eula=y -e usessl=n -v c:\temp:c:\run\my -e customNavSettings="ApiServicesEnabled=true" mcr.microsoft.com/businesscentral/onprem:1810-ltsc2019
Initializing...
Starting Container
Hostname is e0e56f93914b
PublicDnsName is e0e56f93914b
Using NavUserPassword Authentication
Starting Local SQL Server
Starting Internet Information Server
Creating Self Signed Certificate
Self Signed Certificate Thumbprint 48BE7678AFFBA64C22F106808BDB8D315EDCF380
Modifying Service Tier Config File with Instance Specific Settings
Modifying Service Tier Config File with settings from environment variable
Setting ApiServicesEnabled to true
Starting Service Tier
Registering event sources
Creating DotNetCore Web Server Instance
Creating http download site
Setting SA Password and enabling SA
Creating admin as SQL User and add to sysadmin
Creating SUPER user
initialize API Services
Container IP Address: 172.27.3.139
Container Hostname  : e0e56f93914b
Container Dns Name  : e0e56f93914b
Web Client          : http://e0e56f93914b/NAV/
Admin Username      : admin
Admin Password      : Howo4880
Dev. Server         : http://e0e56f93914b
Dev. ServerInstance : NAV

Files:
http://e0e56f93914b:8080/al-2.1.191507.vsix

Initialization took 74 seconds
Ready for connections!
Starting EventLog Monitor
Monitoring EventSources from EventLog[Application]:
- MicrosoftDynamicsNAVClientClientService
- MicrosoftDynamicsNAVClientWebClient
- MicrosoftDynamicsNavServer$NAV
- MSSQL$SQLEXPRESS
```
</details>
&nbsp;<br />

During startup you will see the line `initialize API Services` appear, coming from out script. After the contaier is ready, open e.g. http://&lt;ip&gt;:7048/NAV/api/beta/companyInformation in your browser. It should ask you to provide username and password and the you will get a JSON response from the API.
{::options parse_block_html="true" /}
