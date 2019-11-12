---
layout: page
title: "12 Business Central custom Docker images"
description: ""
keywords: ""
permalink: "td19-12-bc-images"
slug: "td19-12-bc-images"
---
{::options parse_block_html="true" /}
Table of content
- [Activate the API in AdditionalSetup.ps1 using a custom image](#activate-the-api-in-additionalsetupps1-using-a-custom-image)

&nbsp;<br />

### Activate the API in AdditionalSetup.ps1 using a custom image
We have already seen two approaches to activating the API in AdditionalSetup.ps1, but what if you want to publish this e.g. to customers and make sure that it is as easy to consume as possible and very stable after delivery? You can easily create a custom image. We will reuse our AdditionalSetup.ps1 file in c:\temp and just put it into the image. The Dockerfile is available under c:\sources\presentation-src-techdays-19\bc-image, so we just copy it over to c:\temp and run `docker build` from there
```bash
cd c:\temp
copy c:\sources\presentation-src-techdays-19\bc-image\Dockerfile .
docker build -t mcr.microsoft.com/businesscentral/onprem:1810-ltsc2019-activateapi .
```

<details><summary markdown="span">Full output of copy and build</summary>
```bash
PS C:\> cd c:\temp
PS C:\temp> copy c:\sources\presentation-src-techdays-19\bc-image\Dockerfile .
PS C:\temp> docker build -t mcr.microsoft.com/businesscentral/onprem:1810-ltsc2019-activateapi .
Sending build context to Docker daemon  4.608kB
Step 1/3 : FROM mcr.microsoft.com/businesscentral/onprem:1810-ltsc2019
 ---> 0bf96c1268ea
Step 2/3 : RUN mkdir c:/run/my
 ---> Running in 7570ca3efd39

    Directory: C:\run

Mode                LastWriteTime         Length Name
----                -------------         ------ ----
d-----       11/11/2019   7:43 PM                my

Removing intermediate container 7570ca3efd39
 ---> 5153666d84b9
Step 3/3 : COPY AdditionalSetup.ps1 c:/run/my
 ---> e13575a90ba9
Successfully built e13575a90ba9
Successfully tagged mcr.microsoft.com/businesscentral/onprem:1810-ltsc2019-activateapi
```
</details>
&nbsp;<br />

With that in place, we now have an image with the API activation "baked in", so during startup we only need to reference the right image and don't need to provide anything else for the API activation. We could have also always activated the `ApiServicesEnabled` setting, but that would have made if difficult to switch off again. But if you want to do that, you could just add one line to `AdditionalSetup.ps1` which sets that config element.

```bash
docker run --name apiimage -e accept_eula=y -e usessl=n -e customNavSettings="ApiServicesEnabled=true" mcr.microsoft.com/businesscentral/onprem:1810-ltsc2019-activateapi
```

<details><summary markdown="span">Full output of docker run</summary>
```bash
PS C:\temp> docker run --name apiimage -e accept_eula=y -e usessl=n -e customNavSettings="ApiServicesEnabled=true" mcr.microsoft.com/businesscentral/onprem:1810-ltsc2019-activateapi
Initializing...
Starting Container
Hostname is f9375527c63e
PublicDnsName is f9375527c63e
Using NavUserPassword Authentication
Starting Local SQL Server
Starting Internet Information Server
Creating Self Signed Certificate
Self Signed Certificate Thumbprint 5F82A002FCDED7605565F8E0BE5FC2D3FBC4638E
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
Container IP Address: 172.27.10.200
Container Hostname  : f9375527c63e
Container Dns Name  : f9375527c63e
Web Client          : http://f9375527c63e/NAV/
Admin Username      : admin
Admin Password      : Xije9274
Dev. Server         : http://f9375527c63e
Dev. ServerInstance : NAV

Files:
http://f9375527c63e:8080/al-2.1.191507.vsix

Initialization took 76 seconds
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

Once again, open http://&lt;ip&gt;:7048/NAV/api/beta/companyInformation in your browser when the container is ready to validate the API access.
{::options parse_block_html="true" /}
