---
layout: post
title: "Building a BC container image with BuildKit"
permalink: building-a-bc-container-image-with-buildkit
date: 2024-05-27 20:08:10
comments: false
description: "Building a BC container image with BuildKit"
keywords: ""
image: /images/buildkit-bc.png
categories:

tags:

---

In my [last blog post][last], I shared how you can use BuildKit on Windows to create a very simple Hello World container image. Now I want to show you how you can create a Dynamics 365 Business Central (BC) container image, which is way more complex.

## The TL;DR

Creating a BC container image is easiest by using the [BcContainerHelper][bcch] PowerShell module and I created a little fork to make a couple small changes for BuildKit support, based on input by [Markus Lippert][ml]. Therefore, you first need to get those changes:

1. Get the code from my fork, checkout the right branch and import that version of BcContainerHelper
   ```
   git clone https://github.com/tfenster/navcontainerhelper
   cd .\navcontainerhelper\
   git checkout add-buildkit-support
   .\import-BcContainerHelper.ps1
   ```
2. Use the scripts provided in my previous blog post to set up BuildKit. You only need steps one and two, so it would be 
   ```
   Set-ExecutionPolicy Bypass -Scope Process -Force;
   Invoke-Expression ((New-Object System.Net.WebClient).
     DownloadString('https://github.com/tfenster/buildkit-windows/raw/main/SetupFolderStructure.ps1'))
   
   Invoke-Expression ((New-Object System.Net.WebClient).
     DownloadString('https://github.com/tfenster/buildkit-windows/raw/main/SetupContainerd.ps1'))
   ```
   in a first admin terminal and 
   ```
   Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-Expression ((New-Object System.Net.WebClient).
     DownloadString('https://github.com/tfenster/buildkit-windows/raw/main/SetupBuildkit.ps1'))
   ```
   in a second one.
3. With that in place, you can use the regular `New-BCImage` cmdlet to create the BC container image
   ```
   New-BcImage -artifactUrl (Get-BCArtifactUrl -type OnPrem -country de -version 23.5) -imageName buildkit-bc
   ```
4. Once that has finished, you can verify it by doing a `docker run` with that image like this:
   ```
   docker run -e accept_eula=y -e username=admin -e passwordSuper5ecret! -e auth=NavUserPassword `
   -e usessl=n --isolation process -p 8080:80 buildkit-bc:onprem-23.5.16502.16757-de
   ```
   Once it has finished, you can go to [http://localhost:8080/BC](http://localhost:8080/BC) and enjoy BC using an image that has been created with BuildKit!

## The details: What does a full run look like?
Starting from step 3, a full run looks like this:

{% highlight powershell linenos %}
PS C:\Users\vmadmin\buildkit-bc\navcontainerhelper> new-BcImage -artifactUrl (Get-BCArtifactUrl -type OnPrem -country de -version 23.5) -imageName buildkit-bc
buildkit-bc:onprem-23.5.16502.16757-de
Building image buildkit-bc:onprem-23.5.16502.16757-de based on mcr.microsoft.com/businesscentral:ltsc2022-dev with https://bcartifacts-exdbf9fwegejdqak.b02.azurefd.net/onprem/23.5.16502.16757/de
Pulling latest image mcr.microsoft.com/businesscentral:ltsc2022-dev
ltsc2022-dev: Pulling from businesscentral
Digest: sha256:72096da67bab12afba0e478fa0424a80004389ee3f9f1360d74f55ec3b66392b
Status: Image is up to date for mcr.microsoft.com/businesscentral:ltsc2022-dev
mcr.microsoft.com/businesscentral:ltsc2022-dev
Generic Tag: 1.0.2.23
Container OS Version: 10.0.20348.2461 (ltsc2022)
Host OS Version: 10.0.22000.2538 (21H2)
WARNING: Container and host OS build is 20348 or above, defaulting to process isolation. If you encounter issues, you could try to install HyperV.
Using process isolation
Files in c:\bcartifacts.cache\je0th2no.vsk\my:
Copying Platform Artifacts
c:\bcartifacts.cache\onprem\23.5.16502.16757\platform
Copying Database
Copying Licensefile
Copying ConfigurationPackages
C:\bcartifacts.cache\onprem\23.5.16502.16757\de\ConfigurationPackages
Copying Applications
C:\bcartifacts.cache\onprem\23.5.16502.16757\de\Applications
c:\bcartifacts.cache\je0th2no.vsk
Building image took 1624 seconds
PS C:\Users\vmadmin\buildkit-bc\navcontainerhelper> docker run -e accept_eula=y -e username=admin -e passwordSuper5ecret! -e auth=NavUserPassword -e usessl=n --isolation process -p 8080:80 buildkit-bc:onprem-23.5.16502.16757-de
Initializing...
Starting Container
Hostname is a86563df8e15
PublicDnsName is a86563df8e15
Using NavUserPassword Authentication
Starting Local SQL Server
Starting Internet Information Server
Creating Self Signed Certificate
Self Signed Certificate Thumbprint 754675240D76035392EF02F592911289394F8DA2
DNS identity a86563df8e15
Modifying Service Tier Config File with Instance Specific Settings
Starting Service Tier
Registering event sources
Creating DotNetCore Web Server Instance
Using application pool name: BC
Using default container name: NavWebApplicationContainer
Copy files to WWW root C:\inetpub\wwwroot\BC
Create the application pool BC
Create website: NavWebApplicationContainer without SSL
Update configuration: navsettings.json
Done Configuring Web Client
Creating http download site
Setting SA Password and enabling SA
Creating admin as SQL User and add to sysadmin
Creating SUPER user
Container IP Address: 172.22.215.139
Container Hostname  : a86563df8e15
Container Dns Name  : a86563df8e15
Web Client          : http://a86563df8e15/BC/
Admin Username      : admin
Admin Password      : Rowu6522
Dev. Server         : http://a86563df8e15
Dev. ServerInstance : BC

Files:
http://a86563df8e15:8080/ALLanguage.vsix

Container Total Physical Memory is 8.0Gb
Container Free Physical Memory is 1.2Gb

Initialization took 44 seconds
Ready for connections!
Starting EventLog Monitor
Monitoring EventSources from EventLog[Application]:
- MicrosoftDynamicsNAVClientClientService
- MicrosoftDynamicsNAVClientWebClient
- MicrosoftDynamicsNavServer$BC
- MSSQL$SQLEXPRESS
{% endhighlight %}

Now that we are using BuildKit, we also get support for the builds view in Docker Desktop, which is a very convenient way to keep track of your (local) builds:

![Docker Desktop builds view](/images/build-success.png)
{: .centered}

## The details: What needed to be changed?
The changes were actually quite simple. As mentioned above, Markus Lippert already found out that we need to work around an [issue in BuildKit for Windows][issue]. [Anthony Nandaa][an] provided a [workaround][wa] which I just had to bring to the right place in BcContainerHelper. Looking at the [comparison][comp] on GitHub, you can see that I had to add the workaround in line 688 of `New-NavImage.ps1` where the `Dockerfile` is dynamically generated and by repeating the `CMD` from the base image in line 707, make sure that it also applies when running the container:

{% highlight Dockerfile linenos %}
...
SHELL ["C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell", "-Command", "`$ErrorActionPreference = 'Stop'; `$ProgressPreference = 'SilentlyContinue';"]
...
CMD .\Run\start.ps1
...
{% endhighlight %}

In line 716, I called a new command `buildx build` instead of the previous `build` and added the `--load` parameter, which makes sure that the BuildKit-create image is also available for `docker run`.

{% highlight powershell linenos %}
...
if (!(DockerDo -command "buildx build" -parameters @("--load", "--isolation=$isolation", "--memory $memory", "--no-cache", "--tag $imageName") -imageName $buildFolder)) {
...
{% endhighlight %}

Allowing this to work in the `DockerDo` function in `HelperFunctions.ps1` was as simple as adding it to the `ValidateSet`:

{% highlight powershell linenos %}
[ValidateSet('run', 'start', 'pull', 'restart', 'stop', 'rmi', 'build', 'buildx build')]
{% endhighlight %}

## The details: Why isn't this already a PR to BcContainerHelper?
"If it is that easy, why isn't this already a PR to BcContainerHelper?", you might ask. And indeed, I would love to see it there, but unfortunately builds for images with BC 24 or 25 break with a weird error 

{% highlight powershell linenos %}
PS C:\Users\vmadmin\buildkit-bc\navcontainerhelper> new-BcImage -artifactUrl (Get-BCArtifactUrl -type Sandbox -country de -select NextMajor -accept_insiderEula) -imageName buildkit-bc
Downloading artifact /sandbox/25.0.20065.0/de
Downloading C:\Users\vmadmin\AppData\Local\Temp\60d2a61e-1b96-43a0-9cca-053214af08f0.zip
Unpacking artifact to tmp folder using Expand-Archive
Downloading platform artifact /sandbox/25.0.20065.0/platform
Downloading C:\Users\vmadmin\AppData\Local\Temp\35eb91a2-01ea-4394-8974-e2780ce2b90e.zip
Unpacking artifact to tmp folder using Expand-Archive
Downloading Prerequisite Components
Downloading c:\bcartifacts.cache\sandbox\25.0.20065.0\platform\Prerequisite Components\IIS URL Rewrite Module\rewrite_2.0_rtw_x64.msi
Downloading c:\bcartifacts.cache\sandbox\25.0.20065.0\platform\Prerequisite Components\DotNetCore\DotNetCore.1.0.4_1.1.1-WindowsHosting.exe
buildkit-bc:sandbox-25.0.20065.0-de-mt
Building multitenant image buildkit-bc:sandbox-25.0.20065.0-de-mt based on mcr.microsoft.com/businesscentral:ltsc2022-dev with https://bcinsider-fvh2ekdjecfjd6gk.b02.azurefd.net/sandbox/25.0.20065.0/de
Pulling latest image mcr.microsoft.com/businesscentral:ltsc2022-dev
ltsc2022-dev: Pulling from businesscentral
Digest: sha256:72096da67bab12afba0e478fa0424a80004389ee3f9f1360d74f55ec3b66392b
Status: Image is up to date for mcr.microsoft.com/businesscentral:ltsc2022-dev
mcr.microsoft.com/businesscentral:ltsc2022-dev
Generic Tag: 1.0.2.23
Container OS Version: 10.0.20348.2461 (ltsc2022)
Host OS Version: 10.0.22000.2538 (21H2)
WARNING: Container and host OS build is 20348 or above, defaulting to process isolation. If you encounter issues, you could try to install HyperV.
Using process isolation
Files in c:\bcartifacts.cache\o2pwjaui.1uc\my:
Copying Platform Artifacts
c:\bcartifacts.cache\sandbox\25.0.20065.0\platform
Copying Database
Copying Licensefile
Copying ConfigurationPackages
C:\bcartifacts.cache\sandbox\25.0.20065.0\de\ConfigurationPackages
Copying Extensions
C:\bcartifacts.cache\sandbox\25.0.20065.0\de\Extensions
Copying Applications.DE
C:\bcartifacts.cache\sandbox\25.0.20065.0\de\Applications.DE
c:\bcartifacts.cache\o2pwjaui.1uc
new-BcImage Telemetry Correlation Id: 8dad3e73-9936-4702-a1cb-3d04337e3eba
Write-Error: C:\Users\vmadmin\buildkit-bc\navcontainerhelper\ContainerHandling\New-NavImage.ps1:716
Line |
 716 |  …       if (!(DockerDo -command "buildx build" -parameters @("--load",  …
     |                ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | WARNING: isolation flag is deprecated with BuildKit. #0 building with "buildkit-exp" instance using remote driver  #1 [internal] load build
     | definition from Dockerfile #1 transferring dockerfile: 800B done #1 DONE 0.1s  #2 [internal] load metadata for
     | mcr.microsoft.com/businesscentral:ltsc2022-dev #2 DONE 0.1s  #3 [internal] load .dockerignore #3 transferring context: 2B done #3 DONE 0.1s  #4
     | [internal] load build context #4 DONE 0.0s  #5 [1/4] FROM
     | mcr.microsoft.com/businesscentral:ltsc2022-dev@sha256:72096da67bab12afba0e478fa0424a80004389ee3f9f1360d74f55ec3b66392b #5 resolve
     | mcr.microsoft.com/businesscentral:ltsc2022-dev@sha256:72096da67bab12afba0e478fa0424a80004389ee3f9f1360d74f55ec3b66392b #5 resolve
     | mcr.microsoft.com/businesscentral:ltsc2022-dev@sha256:72096da67bab12afba0e478fa0424a80004389ee3f9f1360d74f55ec3b66392b 0.1s done #5 CACHED  #4
     | [internal] load build context #4 transferring context: 286.78MB 5.0s #4 transferring context: 654.80MB 10.2s #4 transferring context: 1.02GB 15.2s
     | #4 transferring context: 1.44GB 20.3s #4 transferring context: 1.73GB 25.4s #4 transferring context: 2.02GB 30.4s #4 transferring context: 2.21GB
     | 35.4s #4 transferring context: 2.22GB 40.5s #4 transferring context: 2.25GB 45.6s #4 transferring context: 2.27GB 50.7s #4 transferring context:
     | 2.33GB 55.8s #4 transferring context: 2.73GB 60.9s #4 transferring context: 2.77GB 63.1s done #4 DONE 63.2s  #6 [2/4] COPY my /run/ #6 DONE 0.4s
     | #7 [3/4] COPY NAVDVD /NAVDVD/ #7 DONE 71.8s  #8 [4/4] RUN Runstart.ps1 -installOnly -multitenant #8 207.7 c:\run\my folder doesn't exist, creating
     | it #8 208.0 Using DVD installer from C:\Run\240 #8 208.2 Installing Business Central: multitenant=True, installOnly=True, filesOnly=False,
     | includeTestToolkit=False, includeTestLibrariesOnly=False, includeTestFrameworkOnly=False, includePerformanceToolkit=False, appArtifactPath=,
     | platformArtifactPath=, databasePath=, licenseFilePath=, rebootContainer=False #8 208.2 Installing from DVD #8 208.3 Starting Local SQL Server #8
     | 211.0 Starting Internet Information Server #8 211.4 Copying Service Tier Files #8 211.4 C:\NAVDVD\ServiceTier\Program Files #8 217.7
     | C:\NAVDVD\ServiceTier\System64Folder #8 218.7 Copying Web Client Files #8 218.7 C:\NAVDVD\WebClient\Microsoft Dynamics NAV #8 224.8 Copying
     | ModernDev Files #8 224.8 C:\NAVDVD #8 224.8 C:\NAVDVD\ModernDev\program files\Microsoft Dynamics NAV #8 229.4 Copying additional files #8 229.5
     | Copying ConfigurationPackages #8 229.5 C:\NAVDVD\ConfigurationPackages #8 229.7 Copying Test Assemblies #8 229.7 C:\NAVDVD\Test Assemblies #8
     | 229.8 Copying Extensions #8 229.8 C:\NAVDVD\Extensions #8 231.9 Copying Applications #8 231.9 C:\NAVDVD\Applications #8 238.2 Copying
     | Applications.DE #8 238.2 C:\NAVDVD\Applications.DE #8 239.2 Copying dependencies #8 239.3 Importing PowerShell Modules #8 242.9 Restoring CRONUS
     | Demo Database #8 243.3 The system cannot find the file specified #8 243.3 Installation failed #8 243.3 At C:\Run\start.ps1:399 char:9 #8 243.3 +
     | throw "Installation failed" #8 243.3 +         ~~~~~~~~~~~~~~~~~~~~~~~~~~~ #8 243.3     + CategoryInfo          : OperationStopped: (Installation
     | failed:String) [  #8 243.3    ], RuntimeException #8 243.3   #8 243.3     + FullyQualifiedErrorId : Installation failed #8 ERROR: process
     | "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell -Command $ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';
     | \\Run\\start.ps1 -installOnly -multitenant" did not complete successfully: exit code: 1 ------  > [4/4] RUN Runstart.ps1 -installOnly
     | -multitenant:   243.3 Installation failed 243.3 At C:\Run\start.ps1:399 char:9 243.3 +         throw "Installation failed" 243.3 +
     | ~~~~~~~~~~~~~~~~~~~~~~~~~~~ 243.3     + CategoryInfo          : OperationStopped: (Installation failed:String) [  243.3    ], RuntimeException
     | 243.3   243.3     + FullyQualifiedErrorId : Installation failed ------ Dockerfile:11 --------------------    9 |        10 |        11 | >>> RUN
     | \Run\start.ps1 -installOnly -multitenant   12 |        13 |     LABEL legal="http://go.microsoft.com/fwlink/?LinkId=837447" \ --------------------
     | ERROR: failed to solve: process "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell -Command $ErrorActionPreference = 'Stop';
     | $ProgressPreference = 'SilentlyContinue'; \\Run\\start.ps1 -installOnly -multitenant" did not complete successfully: exit code: 1  View build
     | details: docker-desktop://dashboard/build/buildkit-exp/buildkit-exp0/nj6ve15yyk8rfckkxvnzgszfi ExitCode: 1 Commandline: docker buildx build --load
     | --isolation=process --memory 8G --no-cache --tag buildkit-bc:sandbox-25.0.20065.0-de-mt c:\bcartifacts.cache\o2pwjaui.1uc
{% endhighlight %}

Somewhere in here you can see the root cause: `The system cannot find the file specified`. Again, the Docker Desktop build view makes it easier to read:

![Docker Desktop build view showing the build error](/images/build-failure.png)

I tried a couple of things to debug and potentially come up with a solution, but no luck so far. As it works with BC 23 and fails with BC 24, which happens to be the first version to use PowerShell 7, my guess is that this is less a BuildKit and more a BC / PowerShell core issue... If you have any ideas, please let me know.

[last]: /test-buildkit-support-for-windows
[bcch]: https://github.com/microsoft/navcontainerhelper
[fork]: https://github.com/tfenster/navcontainerhelper
[ml]: https://lippertmarkus.com
[issue]: https://github.com/moby/buildkit/issues/4901
[an]: https://nandaa.dev/
[wa]: https://github.com/moby/buildkit/issues/4901#issuecomment-2106651324
[comp]: https://github.com/microsoft/navcontainerhelper/compare/master...tfenster:navcontainerhelper:add-buildkit-support?diff=split&w=