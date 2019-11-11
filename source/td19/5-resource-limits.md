---
layout: page
title: "5 Resource limits"
description: ""
keywords: ""
permalink: "td19-5-resource-limits"
slug: "td19-5-resource-limits"
---
{::options parse_block_html="true" /}
Table of content
- [Run a large container without resource limits](#run-a-large-container-without-resource-limits)
- [Run the same container with resource limits](#run-the-same-container-with-resource-limits)

&nbsp;<br />
### Run a large container without resource limits
In order to watch the resource consumption, it might make sense to put the two powershell sessions side by side, so you can follow in parallel. Run `docker stats` in one session and create a BC container in the second session
```bash
# first session
docker stats
# second session
docker run -e accept_eula=y --name bc mcr.microsoft.com/businesscentral/sandbox:ltsc2019
```

<details><summary markdown="span">Full output of stats</summary>
```bash
CONTAINER ID        NAME                CPU %               PRIV WORKING SET    NET I/O             BLOCK I/O
034dc559f78e        iis                 0.00%               51.26MiB            983B / 2.71kB       21.9MB / 21MB
fb6ded834a19        bc                  0.00%               1.859GiB            81.7kB / 14.2kB     562MB / 261MB
```
</details>
<details><summary markdown="span">Full output of BC run</summary>
```bash
PS C:\Users\Verwalter> docker run -e accept_eula=y --name bc mcr.microsoft.com/businesscentral/sandbox:ltsc2019
Initializing...
Starting Container
Hostname is fb6ded834a19
PublicDnsName is fb6ded834a19
Using NavUserPassword Authentication
Starting Local SQL Server
Starting Internet Information Server
Creating Self Signed Certificate
Self Signed Certificate Thumbprint 8DA55D41D691CFD07E8925CED93AD4E5E7252837
Modifying Service Tier Config File with Instance Specific Settings
Starting Service Tier
Registering event sources
Creating DotNetCore Web Server Instance
Enabling Financials User Experience
Creating http download site
Setting SA Password and enabling SA
Creating admin as SQL User and add to sysadmin
Creating SUPER user
Container IP Address: 172.27.9.176
Container Hostname  : fb6ded834a19
Container Dns Name  : fb6ded834a19
Web Client          : https://fb6ded834a19/BC/
Admin Username      : admin
Admin Password      : Nejy5113
Dev. Server         : https://fb6ded834a19
Dev. ServerInstance : BC

Files:
http://fb6ded834a19:8080/al-4.0.192371.vsix
http://fb6ded834a19:8080/certificate.cer

Initialization took 50 seconds
Ready for connections!
```
</details>
&nbsp;<br />
### Run the same container with resource limits
Note how long it took the container to start, which is shown in the logs at the very end, in my case 50 seconds. Now we will remove the BC container and create it again, but this time limit the CPU percentage to 3%. The host is rather big, but you should have seen the CPU usage go above 3% a couple of times, so this should have an impact
```bash
docker rm -f bc
docker run -e accept_eula=y --name bc --cpu-percent 3 mcr.microsoft.com/businesscentral/sandbox:ltsc2019
```

<details><summary markdown="span">Full output of BC run with resource limit</summary>
```bash
PS C:\Users\Verwalter> docker rm -f 8
8
PS C:\Users\Verwalter> docker run -e accept_eula=y --name bc --cpu-percent 3 mcr.microsoft.com/businesscentral/sandbox:ltsc2019
Initializing...
Starting Container
Hostname is ab4b2b4481ed
PublicDnsName is ab4b2b4481ed
Using NavUserPassword Authentication
Starting Local SQL Server
Starting Internet Information Server
Creating Self Signed Certificate
Self Signed Certificate Thumbprint A6A6AEC651BA126F1DEE1BB2D976D98E37138B6C
Modifying Service Tier Config File with Instance Specific Settings
Starting Service Tier
Registering event sources
Creating DotNetCore Web Server Instance
Enabling Financials User Experience
Creating http download site
Setting SA Password and enabling SA
Creating admin as SQL User and add to sysadmin
Creating SUPER user
Container IP Address: 172.27.15.154
Container Hostname  : ab4b2b4481ed
Container Dns Name  : ab4b2b4481ed
Web Client          : https://ab4b2b4481ed/BC/
Admin Username      : admin
Admin Password      : Heca3495
Dev. Server         : https://ab4b2b4481ed
Dev. ServerInstance : BC

Files:
http://ab4b2b4481ed:8080/al-4.0.192371.vsix
http://ab4b2b4481ed:8080/certificate.cer

Initialization took 92 seconds
Ready for connections!
```
</details>
&nbsp;<br />
You should have seen in the stats window that the CPU percentage has only small spikes above 3% and then immediately goes down again. It never should have reached 4% or more. As a result, the startup should take a lot longer, in my case 92 seconds, so we can see the resource limits working.

Make sure you remove the container in the end with `docker rm -f bc`

{::options parse_block_html="true" /}