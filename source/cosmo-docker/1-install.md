---
layout: page
title: "1 Install Docker"
description: ""
keywords: ""
permalink: "cosmo-docker-1-install"
slug: "cosmo-docker-1-install"
---
{::options parse_block_html="true" /}

Table of content
- [Install module and package](#install-module-and-package)
- [Restart](#restart)
- [Check if everything works](#check-if-everything-works)
- [One more preparation step](#one-more-preparation-step)

&nbsp;<br />
### Install module and package
Open the RDP connection to the first, bigger machine. In the future, I'll refer to it as host as it will be our container host<br />
Start PowerShell as admin (not ISE, as it doesn't work well with Docker)  
```bash
Install-Module -Name DockerMsftProvider -Repository PSGallery -Force
```
--> accept with "Y"

```bash
Install-Package -Name docker -ProviderName DockerMsftProvider
```  
--> accept with "A"

<details><summary markdown="span">Full output of the install commands</summary>
```bash
PS C:\Users\CosmoAdmin> Install-Module -Name DockerMsftProvider -Repository PSGallery -Force

NuGet provider is required to continue
PowerShellGet requires NuGet provider version '2.8.5.201' or newer to interact with NuGet-based repositories. The NuGet
 provider must be available in 'C:\Program Files\PackageManagement\ProviderAssemblies' or
'C:\Users\CosmoAdmin\AppData\Local\PackageManagement\ProviderAssemblies'. You can also install the NuGet provider by
 running 'Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force'. Do you want PowerShellGet to install
and import the NuGet provider now?
[Y] Yes  [N] No  [S] Suspend  [?] Help (default is "Y"): Y
PS C:\Users\CosmoAdmin> Install-Package -Name docker -ProviderName DockerMsftProvider

The package(s) come(s) from a package source that is not marked as trusted.
Are you sure you want to install software from 'DockerDefault'?
[Y] Yes  [A] Yes to All  [N] No  [L] No to All  [S] Suspend  [?] Help (default is "N"): A
WARNING: A restart is required to enable the containers feature. Please restart your machine.

Name                           Version          Source           Summary
----                           -------          ------           -------
Docker                         19.03.4          DockerDefault    Contains Docker EE for use with Windows Server.
```
</details>

&nbsp;<br />

### Restart
Restart the computer to make everything work
```bash
Restart-Computer -Force
```  

&nbsp;<br />

### Check if everything works
After the restart has finished: Start PowerShell as admin and check if the install was successful
```bash
docker version
```

<details><summary markdown="span">Full output of the version command</summary>
```bash
PS C:\Users\CosmoAdmin> docker version
Client: Docker Engine - Enterprise
 Version:           19.03.4
 API version:       1.40
 Go version:        go1.12.10
 Git commit:        9e27c76fe0
 Built:             10/17/2019 23:42:50
 OS/Arch:           windows/amd64
 Experimental:      false

Server: Docker Engine - Enterprise
 Engine:
  Version:          19.03.4
  API version:      1.40 (minimum version 1.24)
  Go version:       go1.12.10
  Git commit:       9e27c76fe0
  Built:            10/17/2019 23:41:23
  OS/Arch:          windows/amd64
  Experimental:     false
```
</details>
&nbsp;<br />
Now we run a sample container to make sure everything works. This will pull and run the image
```bash
docker run hello-world:nanoserver
```
<details><summary markdown="span">Full output of the sample command</summary>
```bash
PS C:\Users\CosmoAdmin> docker run hello-world:nanoserver
Unable to find image 'hello-world:nanoserver' locally
nanoserver: Pulling from library/hello-world
9ff41eda0887: Pull complete
e34b597d4d9c: Pull complete
d2708320a311: Pull complete
Digest: sha256:6923ba909bd4b9b8ee22e434a8353a77ceafb6a5dfa24cde98ec8e5371e25588
Status: Downloaded newer image for hello-world:nanoserver

Hello from Docker!
This message shows that your installation appears to be working correctly.

To generate this message, Docker took the following steps:
 1. The Docker client contacted the Docker daemon.
 2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
    (windows-amd64, nanoserver-1809)
 3. The Docker daemon created a new container from that image which runs the
    executable that produces the output you are currently reading.
 4. The Docker daemon streamed that output to the Docker client, which sent it
    to your terminal.

To try something more ambitious, you can run a Windows Server container with:
 PS C:\> docker run -it mcr.microsoft.com/windows/servercore powershell

Share images, automate workflows, and more with a free Docker ID:
 https://hub.docker.com/

For more examples and ideas, visit:
 https://docs.docker.com/get-started/
```
</details>
&nbsp;<br />
### One more preparation step
To be quicker for the next samples, please run the script C:\sources\presentation-src-cosmo-docker\cosmo-pullall.bat as this will pull all necessary images and we don't need to wait for the downloads later on!

{::options parse_block_html="false" /}