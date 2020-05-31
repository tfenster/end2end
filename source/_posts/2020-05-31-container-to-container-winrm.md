---
layout: post
title: "Container to container WinRM"
permalink: container-to-container-winrm
date: 2020-05-31 16:27:12
comments: false
description: "Container-to-container WinRM"
keywords: ""
categories:
image: /images/container-to-container.png

tags:

---

I have shared the basics of a Docker Swarm based setup to host containers on an Azure VM scale set on multiple occasions and we are right now in the pilot / beta phase with it[^1]. One of the obstacles that came up was the need to get container-to-container communication using Windows Remote Management (WinRM) and after some initial struggles I found a good solution.

## The TL;DR
WinRM has a couple of very sensible security mechanisms in place, but if you run containers on a network without incoming connectivity from the internet on VMs also on a network without incoming connectivity from the internet, you might be willing to sacrifice some of that. But please don't do the following if your containers are reachable from the outside, as that would be a serious security flaw. That being said, if you don't mind this, you can easily do the following:

1. Create a Dockerfile (as so often, heavily inspired by a [Dockerfile][Dockerfile] created by Stefan Scherer) with the following content
{% highlight dockerfile linenos %}
#escape=`
ARG TAG=ltsc2019
FROM mcr.microsoft.com/windows/servercore:$TAG
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

RUN $cert = New-SelfSignedCertificate -DnsName "dontcare" -CertStoreLocation Cert:\LocalMachine\My; `
    winrm create winrm/config/Listener?Address=*+Transport=HTTPS ('@{Hostname=\"dontcare\"; CertificateThumbprint=\"' + $cert.Thumbprint + '\"}'); `
    winrm set winrm/config/service/Auth '@{Basic=\"true\"}'

# Create a test account
RUN net user /add ContAdmin Passw0rd ; `
    net localgroup Administrators ContAdmin /add
{% endhighlight %}
{:start="2"}
2. Run `docker build -t winrm-demo .` to create a Docker image using the Dockerfile above
1. Run `docker run --name target --rm -d winrm-demo ping -t localhost`. This creates a container from the image just created and endlessly pings localhost, so it never stops. This container will be the target of our connection.
1. Run `docker run -ti --name source --rm mcr.microsoft.com/windows/servercore:1809 powershell`. This creates a container from the standard Windows Server Core image and gives us a PowerShell session in that container. We will use it as the source of our connection. Note that after running this command, our session is now inside the container named `source`
1. Run `$cred = New-Object pscredential 'ContAdmin', (ConvertTo-SecureString -String 'Passw0rd' -AsPlainText -Force)` to create a credential object and then `Enter-PSSession -Credential $cred -ComputerName target -Authentication Basic -UseSSL -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck)`. The result should be something like `[target]: PS C:\Users\ContAdmin\Documents>` which shows that we have successfully created a WinRM connection from one container to another.

## The details: Why -ContainerId sounds promising but doesn't work (in this case)
Before explaining a bit more about the actual solution, I also want to explain why the probably most obvious way to try to achieve container-to-container WinRM doesn't work, so that you don't have to spend time to figure that one out: `Enter-PSSession` has a parameter `-ContainerId`, which seems very promising and indeed works very well on the container host. To give you an example, the following just works, assuming that you have a container called `target` up and running.

{% highlight powershell linenos %}
PS C:\Users\tfenster8982> Enter-PSSession -ContainerId (docker ps --no-trunc -qf "name=target")
[38c66532136f...]: PS C:\Users\ContainerUser\Documents>
{% endhighlight %}

However, if you try this in a container, you will get

{% highlight powershell linenos %}
*** Exception creating session: Unable to load DLL 'vmcompute.dll': The specified module could not be found. (Exception from HRESULT: 0x8007007E)
{% endhighlight %}

You can then spend endless hours down the rabbit hole called "internet research", but won't find a solution. Thanks to an idea by Stefan Scherer I tried to copy `vmcompute.dll` from the host into the container and it took me one step further, but unfortunately just to the next error message:

{% highlight powershell linenos %}
PS C:\> Enter-PSSession -ContainerId (docker ps --no-trunc -qf "name=target")
Enter-PSSession : The input ContainerId 38c66532136f9709ead86cf3e24f42b7da06df0e502eb592fd74df9e3d923029 does not exist, or the corresponding container is not running.
{% endhighlight %}

That seems like a good error message, but unfortunately the container with that ID exists and is running... I the created an [issue][issue] on the PowerShell Github repository and got very quick [feedback][feedback]:

*When you use "Enter-PSSession -ContainerId", you use "Host Compute Service" (via vmcompute.dll) which is only available on the host*

After that very clear statement, I decided to accept that this path obviously was not the right one :) 

## The details: What needs to be set up
In order to get a connection between two containers, we need a) a network connection, b) something that is accepting a connection on the target side and c) a way to authenticate. While a) is already a given in our scenario, b) and c) need some work. As outlined above, after being on the wrong track for some time, I then found out that I needed to use WinRM for b). Fortunately that is available and already set up in the Windows Server Core standard images, but c) was still an issue. WinRM can use Basic, Digest, Negotiate, Kerberos and client certificates as auth mechanism as explained [here][here], so almost everything doesn't work in my scenario. Client certificates could be an option, but because of the effort to set it up, I decided against even trying, so I was left with Basic auth. Not the favorite from a security standpoint, which is why it is disabled by default, and we need to enable it in our Docker image. Connecting with Basic auth however is only possible if you use an encrypted channel for communication, which means SSL needs to be set up[^2]. To do that, a certificate is needed and I just went with a self-signed one, which means that the source doesn't have a good option to make sure it really is talking to the intended target. But as explained in the beginning, I still find it a reasonable approach, given the scenario. The following three lines from the Dockerfile above do exactly that:

{% highlight powershell linenos %}
$cert = New-SelfSignedCertificate -DnsName "dontcare" -CertStoreLocation Cert:\LocalMachine\My
winrm create winrm/config/Listener?Address=*+Transport=HTTPS ('@{Hostname="dontcare"; CertificateThumbprint="' + $cert.Thumbprint + '"}')
winrm set winrm/config/service/Auth '@{Basic="true"}'
{% endhighlight %}

The first line creates and store a self-signed certificate, the second line creates a WinRM listener endpoint using that certificate and HTTPS as transport and the third line enables basic auth. With that, the only thing we still need is a username and password to use when connecting. While containers have predefined users, the passwords are not available. To solve that, the next lines from the Dockerfile create a new account with a default password and make it an administrator:

{% highlight powershell linenos %}
net user /add ContAdmin Passw0rd 
net localgroup Administrators ContAdmin /add
{% endhighlight %}

With that, everything is set up on the target side and we only need to figure out the right command on the source side to connect. As mentioned in the TL;DR, the following commands can be used:

{% highlight powershell linenos %}
cred = New-Object pscredential 'ContAdmin', (ConvertTo-SecureString -String 'Passw0rd' -AsPlainText -Force)
Enter-PSSession -Credential $cred -ComputerName target -Authentication Basic -UseSSL -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck)
{% endhighlight %}

The first line creates a credential object with the information that we used in the Dockerfile for the image of the target container. The second line uses those credentials to connect to the target container with basic authentication and therefore SSL. As we used a self-signed certificate, the certificate authority and common name of the certificate can't be checked, so `-SkipCACheck` and `-SkipCNCheck` need to be used.

Not terribly complicated, but some hoops to jump through and the `-ContainerId` param of `Enter-PSSession` might lead you down the wrong path, so I am hoping this is useful for some who face the same challenge.

[^1]: Still a lot of work to do as pilot users expectedly find issues we didn't see during development. But also lots of very good feedback!
[^2]: I could also have configured WinRM to allow unencrypted traffic, but didn't want to disable all security mechanisms.
[Dockerfile]: https://github.com/StefanScherer/dockerfiles-windows/blob/master/winrm/Dockerfile
[issue]: https://github.com/PowerShell/PowerShell/issues/12570
[feedback]: https://github.com/PowerShell/PowerShell/issues/12570#issuecomment-623600216
[here]: https://docs.microsoft.com/en-us/windows/win32/winrm/authentication-for-remote-connections
