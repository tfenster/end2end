---
layout: page
title: "11 Business Central container file handling"
description: ""
keywords: ""
permalink: "cosmo-docker-11-bc-files"
slug: "cosmo-docker-11-bc-files"
---
{::options parse_block_html="true" /}
Table of content
- [Activate the API in AdditionalSetup.ps1 using the folders parameter](#activate-the-api-in-additionalsetupps1-using-the-folders-parameter)

&nbsp;<br />

### Activate the API in AdditionalSetup.ps1 using the folders parameter
When using the c:\run\my approach as seen before, you need to make sure that the script is the same on all container hosts. If you go with the folders-based download approach, you can put your scripts in a central place and every container start will just download it. The start command is the same as before, we just use the folders env param to download the script from Github instead of the bind mount to c:\run\my
```bash
docker run --name apifolders -e accept_eula=y -e usessl=n -e folders="c:\run\my=https://github.com/tfenster/nav-docker-samples/archive/initialize-api.zip\nav-docker-samples-initialize-api" -e customNavSettings="ApiServicesEnabled=true" mcr.microsoft.com/businesscentral/onprem:1810-ltsc2019
```

<details><summary markdown="span">Full output of docker run</summary>
```bash
PS C:\temp> docker run --name apifolders -e accept_eula=y -e usessl=n -e folders="c:\run\my=https://github.com/tfenster/nav-docker-samples/archive/initialize-api.zip\nav-docker-samples-initialize-api" -e customNavSettings="ApiServicesEnabled=true" mcr.microsoft.com/businesscentral/onprem:1810-ltsc2019
Setting up folders...
Downloading https://github.com/tfenster/nav-docker-samples/archive/initialize-api.zip to c:\run\my
Extracting file in temp folder
Moving nav-docker-samples-initialize-api to target folder c:\run\my
Setting up folders took 1 seconds
Initializing...
Starting Container
Hostname is 4cae07acf2e7
PublicDnsName is 4cae07acf2e7
Using NavUserPassword Authentication
Starting Local SQL Server
Starting Internet Information Server
Creating Self Signed Certificate
Self Signed Certificate Thumbprint 13C16B33D13DB10CBBC283049401003BA6795685
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
Container IP Address: 172.27.2.221
Container Hostname  : 4cae07acf2e7
Container Dns Name  : 4cae07acf2e7
Web Client          : http://4cae07acf2e7/NAV/
Admin Username      : admin
Admin Password      : Reje5801
Dev. Server         : http://4cae07acf2e7
Dev. ServerInstance : NAV

Files:
http://4cae07acf2e7:8080/al-2.1.191507.vsix

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
Directly after startup you see the log output of the download and extraction of our .zip file. At the end, you again see the "initializing API Service" entry from our script. As before, open http://&lt;ip&gt;:7048/NAV/api/beta/companyInformation in your browser when the container is ready to validate the API access.
{::options parse_block_html="true" /}
