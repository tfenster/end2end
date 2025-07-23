---
layout: post
title: "What are FoDs or how to run IIS in a Windows Server 2025 Nano Server container"
permalink: what-are-fods-or-how-to-run-iis-in-a-windows-server-2025-nano-server-container
date: 2025-06-22 17:43:40
comments: false
description: "What are FoDs or how to run IIS in a Windows Server 2025 Nano Server container"
keywords: ""
image: /images/iis.png
categories:

tags:

---

Windows containers are often considered too heavy and resource-hungry for the highly dynamic worlds of microservices and edge computing. And, to be honest, there is some truth to that. However, Microsoft has made significant progress with Nano Server container images and has reduced the size and footprint of these images through multiple iterations. We have seen extracted images of less than 300 MB, and while this figure has increased again with Windows Server 2025, the images are still less than 500 MB. This is not tiny by any means in the Linux world, but compared to a Server Core container image, which was ~5 GB extracted and is now ~7.5 GB with the latest updates, it is quite small. The main disadvantage of Nano Server was that it often didn't provide exactly what you needed, so in some worst-case scenarios, a simple service or feature could force you to switch to Server Core. Fortunately, this has changed with FoDs ('Features on Demand'), which allow you to install specific features on demand - as the name suggests. Microsoft's [announcement][announcement] provides some details and an example, but I would like to give you another one below.

## The TL;DR

To see how it works locally, do the following:

- Clone my sample repo at [https://github.com/tfenster/FoDs](https://github.com/tfenster/FoDs)
- Make sure you have [Docker Desktop][dd] installed and configured for Windows containers
- Execute the following command in the directory where you cloned the repo: `docker build -t nanoserver-iis .`. This will build an image that uses the IIS FoD to enable [IIS][iis] in Nano Server.
- Run a container with that image and expose the default IIS port 80 on port 8080 of your localhost by using the following command: `docker run -p 8080:80 -ti nanoserver-iis`.
- You can then access your IIS running in a Nano Server container at [http://localhost:8080](http://localhost:8080)

While this runs only locally, it is a crucial first step to bringing a better overall experience to e.g. Azure Kubernetes Service when running Windows workloads. Once Windows Server 2025 is supported there, I'll follow up again.

## The details: The Dockerfile

The [Dockerfile][df] to make this happen looks like this

{% highlight Dockerfile linenos %}
FROM mcr.microsoft.com/windows/nanoserver:ltsc2025
WORKDIR /install
COPY install_iis.cmd .
USER ContainerAdministrator
RUN install_iis.cmd
USER ContainerUser
WORKDIR /inetpub
{% endhighlight %}

We start from Windows Server 2025 Nano Server (line 1) which is the first to support FoDs. We then copy the install script in and run it (lines 2-5). Note that we run it as `ContainerAdministrator` (line 4) because elevated permissions are required. Then, we switch back to the non-privileged `ContainerUser` and go to the `inetpub` folder (lines 6 and 7), which contains the IIs files.

## The details: The install script

The [install script][install] is even shorter and looks like this

{% highlight cmd linenos %}
DISM /Online /Add-Capability /CapabilityName:Microsoft.NanoServer.IIS /NoRestart
if errorlevel 3010 (
    echo The specified optional feature requested a reboot which was suppressed.
    exit /b 0
)
{% endhighlight %}

The first line installs the FoD and uses the `/NoRestart` parameter to ensure that no restart occurs. As this would cause an error, lines 2–5 are needed to handle it properly.

There are no additional details, but the above-mentioned announcement provides some more background information. This may not seem like a big deal, but once Microsoft adds more FoDs for us to choose from, it has the potential to unlock many scenarios in Nano Server and lead to much smaller container images.

[announcement]: https://techcommunity.microsoft.com/blog/containers/discover-the-new-era-of-windows-server-2025-nano-server-containers/4413060
[dd]: https://www.docker.com/products/docker-desktop/
[iis]: https://learn.microsoft.com/en-us/iis/get-started/introduction-to-iis/iis-web-server-overview
[df]: https://github.com/tfenster/FoDs/blob/main/Dockerfile
[install]: https://github.com/tfenster/FoDs/blob/main/install_iis.cmd