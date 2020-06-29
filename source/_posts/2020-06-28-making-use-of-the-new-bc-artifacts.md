---
layout: post
title: "Making use of the new BC artifacts"
permalink: making-use-of-the-new-bc-artifacts
date: 2020-06-28 23:34:46
comments: false
description: "Making use of the new BC artifacts"
keywords: ""
categories:
image: /images/compile-bc-sdk.png

tags:

---

As you probably have seen ([1][1], [2][2], [3][3], [4][4] [^1]) if you are following what is happening with Business Central on Docker, Microsoft has overhauled the way all of this works. While it stays very similar to what we had before from an end user perspective[^2], the whole structure underneath has changed a lot. I personally feel like this is a bit of a mixed bag because I can see why Microsoft doesn't want to support all the needed images, but at the same time, if you take away the concept of an (immutable) image, the whole Docker story becomes a lot less appealing. So while I can see the benefits and again, the end user should probably not even notice anything has changed, I also see some drawbacks, especially around support in case of issues and how it works with container orchestrators like Kubernetes or Swarm.

But as always, let's look at the bright side of things and dig into what we can now do more conveniently which was a lot more complicated before. There are a couple of interesting scenarios but the first one I decided to tackle is this: Compiling a Business Central app in a container was very slow in the old way as the whole infrastructure like SQL and BC needed to start before you could start compiling. And if you ran this as part of a pipeline on a hosted machine where you didn't have control over the images, it got even slower, because the very big BC image had to be pulled. You could work around that and I have blogged about that a couple of years ago, but with the new artifacts, it gets a lot easier.

## The TL;DR
Building an "SDK" image for BC is a three-step process:
1. Create a navcontainerhelper image because the cmdlets to get artifacts are very handy
2. Create an artifact image with all the artifacts you might need, mainly the compiler and symbols
3. Create the SDK image with the compiler and applications symbols so that you can compile.

How quick is that? I can bring it to 5.5 seconds for the standard sample created with "AL: Go!" in VS Code:

![compile-bc-sdk](/images/compile-bc-sdk.png)
{: .centered}

Of course, this will be slower with real life projects but for the hosted CI/CD scenario, pulling the image alone takes a couple of minutes and even starting a container if the image is already there, takes between 40 and 60 seconds for the standard image, so this really is A LOT quicker! Pulling also would be quicker because my SDK image is based on the nanoserver Windows container, which means it has a grand total size of 587 MB if it runs on 1809:

![artifact-image-size](/images/artifact-image-size.png)
{: .centered}

On a side note, as you can see in the screenshot as well: If we go to 2004 as base image version, the end result is minimally bigger because while the servercore image has become a lot smaller, the nanoserver one has grown by 12 MB.

As I am not yet sure, if and how I can share those images on the Docker hub or on an Azure container registry, I will only share the Dockerfiles at the moment. You can find the on [Github][Github].

## The details, part 1: The navcontainerhelper image
As I already wrote, I decided to go with the artifact cmdlets in navcontainerhelper instead of just using the code because it's more convenient. But because I need the artifacts in a container image and I don't want to rely on anything on the host, navcontainerhelper needs to run in a container. Fortunately, creating am image for that purpose is quite easy by using the following Dockerfile:

{% highlight dockerfile linenos %}
# escape='
ARG BASE
FROM mcr.microsoft.com/windows/servercore:$BASE
ARG NCHVERSION
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop';"]

RUN Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force; '
Install-Module navcontainerhelper -MinimumVersion $env:NCHVERSION -MaximumVersion $env:NCHVERSION -Force;
{% endhighlight %}

The interesting part is in lines 7 and 8 where the right package provider as well as the right navcontainerhelper version is installed. With that in place, we can run a command like 'docker build -t tobiasfenster/navcontainerhelper:0.7.0.9-1809 --build-arg BASE=1809 .' to create the image. Navcontainerhelper online adds 40MB to the image, so that doesn't really hurt, especially considering how big the standard Windows image is.

## The details, part 2: The artifacts image
With navcontainerhelper in place, we can now go ahead and download the artifacts that we need. In order to get the right artifacts, I have added build args for type, country and version (similar to the artifact cmdlets). The artifacts are downloaded, the AL language .vsix file is extracted to get the compiler (alc.exe) and the System.app file is put in the same folder as the other symbol files.

{% highlight dockerfile linenos %}
# escape='
ARG BASE
ARG NCHVERSION
FROM tobiasfenster/navcontainerhelper:$NCHVERSION-$BASE

ARG TYPE
ARG COUNTRY
ARG VERSION
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop';"]

RUN Import-Module navcontainerhelper; '
Download-Artifacts -artifactUrl (Get-BCArtifactUrl -type $env:TYPE -country $env:COUNTRY -version $env:VERSION) -includePlatform;
RUN Copy-Item "C:\bcartifacts.cache\$env:TYPE\$env:VERSION\platform\ModernDev\program' files\Microsoft' Dynamics' NAV\*\AL' Development' Environment\ALLanguage.vsix" "C:\bcartifacts.cache\$env:TYPE\$env:VERSION\ALLanguage.zip"; '
Copy-Item "C:\bcartifacts.cache\$env:TYPE\$env:VERSION\platform\ModernDev\program' files\Microsoft' Dynamics' NAV\*\AL' Development' Environment\System.app" "C:\bcartifacts.cache\$env:TYPE\$env:VERSION\$env:COUNTRY\Applications.$env:COUNTRY"; '
Expand-Archive "C:\bcartifacts.cache\$env:TYPE\$env:VERSION\ALLanguage.zip" "C:\bcartifacts.cache\$env:TYPE\$env:VERSION\ALLanguage";
{% endhighlight %}

Again, to build the image, all that is needed is a build command with all the necessary args: 'docker build -t tobiasfenster/bc-artifacts:sandbox-16.2.13509.14155-de-1809 --build-arg NCHVERSION=0.7.0.9 --build-arg BASE=1809 --build-arg TYPE=Sandbox --build-arg COUNTRY=de --build-arg VERSION=16.2.13509.14155 .'. The artifacts (including the platform) are rather big and add 2.35 GB to the image size.

## The details, part 3: The "SDK" image
Now everything is prepared for the last step, the "SDK" image. It needs to have the alc compiler as well as the symbols, so those need to be copied from an artifacts image to the target image:

{% highlight dockerfile linenos %}
# escape='
ARG BASE
ARG TYPE
ARG COUNTRY
ARG VERSION
FROM tobiasfenster/bc-artifacts:$TYPE-$VERSION-$COUNTRY-$BASE AS artifacts
ARG TYPE
ARG COUNTRY
ARG VERSION
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop';"]
RUN Remove-Item "C:\bcartifacts.cache\$env:TYPE\$env:VERSION\$env:COUNTRY\Applications.$env:COUNTRY\*.zip"

FROM mcr.microsoft.com/windows/nanoserver:$BASE
ARG TYPE
ARG COUNTRY
ARG VERSION
COPY --from=artifacts C:\bcartifacts.cache\$TYPE\$VERSION\ALLanguage\extension\bin c:\bin
COPY --from=artifacts C:\bcartifacts.cache\$TYPE\$VERSION\$COUNTRY\Applications.$COUNTRY c:\symbols

CMD c:\bin\win32\alc.exe /project:c:\src /packagecachepath:c:\symbols /out:c:\src\app.app
{% endhighlight %}

The last line shows the compilation command that is executed when you run the image, so you need to make sure to bind mount your project folder to c:\src.

After running something like 'docker build -t tobiasfenster/bc-sdk:sandbox-16.2.13509.14155-de-1809 --build-arg BASE=1809 --build-arg TYPE=sandbox --build-arg COUNTRY=de --build-arg VERSION=16.2.13509.14155 -f Dockerfile .', we now have an image with the alc compiler and all the standard symbols we might need. Because I have used nanoserver, the image is very small in total with the Business Central stuff adding 330 MB to the image.

Because of this and as we don't need to wait for SQL and BC to start, the compilation is very quick. Of course, to run e.g. automated tests, you still need all the other components, but if you only want to compile, maybe because it is just a push to a feature branch and you run the whole story including tests only nightly but are fine with just a compilation for the push. And 5.5 seconds to find out if your code still compiles in a pristine environment seems quite fair.

[^1]: and chances are this list is no longer complete by the time you are reading this
[^2]: Kudos to Freddy, that was not easy to pull off, but once again he did an amazing job

[1]: https://freddysblog.com/2020/06/25/changing-the-way-you-run-business-central-in-docker/
[2]: https://freddysblog.com/2020/06/25/working-with-artifacts/
[3]: https://freddysblog.com/2020/06/27/ci-cd-and-artifacts/
[4]: https://freddysblog.com/2020/06/28/the-hello-world-ci-cd-sample/
[Github]: https://github.com/tfenster/bc-docker-images