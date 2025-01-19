---
layout: post
title: "Test BuildKit support for Windows"
permalink: test-buildkit-support-for-windows
date: 2024-04-21 09:07:16
comments: false
description: "Test BuildKit support for Windows"
keywords: ""
image: /images/buildkit.png
categories:

tags:

---
Maybe you have already seen it, after [quite some time][early-issue], we now have [experimental Windows Containers Support for BuildKit][announcement]. This is great news because [BuildKit][buildkit] is far superior to the legacy builder that has been most commonly used in [Docker][docker] for Windows. In fact, BuildKit has been the default builder for Linux containers in Docker for quite a while now. Microsoft also provides a [Getting started][getting-started] blog and Docker has a similar section in [its documentation][buildkit-docker], but that puts the binaries in some "prominent" places on your machine like `c:\program files` and `c:\programdata`, it registers a Windows service for containerd and it pushes the image to a Docker hub repo, which you may not all want, as it is a bit more permanent than necessary. At least I didn't, as I only wanted to give it a quick try... Also, it is hardcoded to use specific versions of BuildKit and containerd, but as development and bugfixes hopefully will progress quickly, I think it's better to get the latest version. Therefore, I created a small collection of scripts, that rely heavily on what Microsoft and Docker provide, but automates it a bit more, puts things in a temporary folder structure, always gets the latest version, and keeps the image local.

## The TL;DR
All you need is a PowerShell in admin mode and you are good to go:

1. `Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://github.com/tfenster/buildkit-windows/raw/main/SetupFolderStructure.ps1'))`

   `Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://github.com/tfenster/buildkit-windows/raw/main/SetupContainerd.ps1'))`

   This will set up the folder structure and download and start containerd in the latest version
2. In a second tab, run `Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://github.com/tfenster/buildkit-windows/raw/main/SetupBuildkit.ps1'))`

   This will download and run the latest version of BuildKit
3. In a third tab, run `Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://github.com/tfenster/buildkit-windows/raw/main/SetupSampleDockerfileAndBuild.ps1'))`

   This will create a Dockerfile and an additional hello.txt, build the image (of course using BuildKit) and run a container from that image.

This is what it should look like

<video width="100%" controls="" class="centered">
  <source type="video/mp4" src="/images/buildkit.mp4" />
</video>

If you follow these steps, you should be able to easily give BuildKit on Windows a try. And if you want to remove it, just remove the container and image, and delete the base folder `buildkit-windows-test`.

## The details: Prerequisites
As prerequisites, I assume that you have set up [Docker Desktop][dd] with at least version 4.29. You also need to make sure that you have switched to Windows containers in Docker Desktop (the default is Linux containers). To successfully run the scripts explained above, you will need the three PowerShell sessions in admin mode. And of course, be sure to review these scripts before you run them! Never run anything from the internet blindly...

## The details: The scripts
The first one, `SetupFolderStructure.ps1`, checks if the expected base folder already exists and removes it if it does. This would be the case if you have already run these scripts and now want to run them again, e.g. to get a new version

{% highlight powershell linenos %}
Write-Host "Creating file structure (and remove existing, if it exists)"
if (Test-Path -Path "buildkit-windows-test") {
    Remove-Item -Path "buildkit-windows-test" -Recurse -Force
}
New-Item -Name "buildkit-windows-test" -ItemType Directory
Set-Location "buildkit-windows-test"
New-Item -Name "containerd" -ItemType Directory 
New-Item -Name "buildkit" -ItemType Directory 
New-Item -Name "sample-dockerfile" -ItemType Directory 
{% endhighlight %}

The second one, `SetupContainerd.ps1`, is inspired by [this gist][gist] from [Maksym Koshovyi][maxk] and by the Microsoft scripts mentioned above. It first gets the latest released version of containerd from GitHub (lines 4 and 5), then downloads and extracts it (lines 7 and 8), creates a default configuration (line 10), overwrites the used paths in that configuration (lines 11 and 12) and finally starts it (line 13).

{% highlight powershell linenos %}
# based on https://gist.github.com/maxkoshevoi/60d7b7910ad6ddcc6e1c9b656a8d0301 and https://techcommunity.microsoft.com/t5/containers/getting-started-build-a-basic-hello-world-image-with-buildkit/ba-p/4096154

Set-Location "containerd"
$containerdReleasesUri = "https://api.github.com/repos/containerd/containerd/releases/latest"
$containerdDownloadUrl = ((Invoke-WebRequest $containerdReleasesUri | ConvertFrom-Json).assets | Where-Object name -like "containerd-*-windows-amd64.tar.gz").browser_download_url
Write-Host "Found download URL $containerdDownloadUrl for containerd, fetching and expanding it"
Invoke-WebRequest -Uri $containerdDownloadUrl -OutFile "containerd-windows-amd64.tar.gz"
tar.exe xvf .\containerd-windows-amd64.tar.gz
Write-Host "Configuring containerd"
bin\containerd.exe config default | Out-File config.toml -Encoding ascii
((Get-Content -path config.toml -Raw) -replace 'C:\\\\ProgramData\\\\containerd', ((Get-Location) -replace '\\', '\\')) | Set-Content -Path config.toml
((Get-Content -path config.toml -Raw) -replace 'C:\\\\Program Files\\\\containerd', ((Get-Location) -replace '\\', '\\')) | Set-Content -Path config.toml
.\bin\containerd.exe -c .\config.toml
{% endhighlight %}

The third one, `SetupBuildkit.ps1`, does something very similar to the second one, only this time for BuildKit instead of containerd and it just uses the default configuration.

{% highlight powershell linenos %}
# based on https://gist.github.com/maxkoshevoi/60d7b7910ad6ddcc6e1c9b656a8d0301 and https://techcommunity.microsoft.com/t5/containers/getting-started-build-a-basic-hello-world-image-with-buildkit/ba-p/4096154

Set-Location "buildkit-windows-test\buildkit"
$buildkitReleasesUri = "https://api.github.com/repos/moby/buildkit/releases/latest"
$buildkitDownloadUrl = ((Invoke-WebRequest $buildkitReleasesUri | ConvertFrom-Json).assets | Where-Object name -like "buildkit-*.windows-amd64.tar.gz").browser_download_url
Write-Host "Found download URL $buildkitDownloadUrl for buildkit, fetching and expanding it"
Invoke-WebRequest -Uri $buildkitDownloadUrl -OutFile "buildkit-windows-amd64.tar.gz"
tar.exe xvf .\buildkit-windows-amd64.tar.gz
.\bin\buildkitd.exe
{% endhighlight %}

The last one, `SetupSampleDockerfileAndBuild.ps1` creates the sample Dockerfile (lines 6-12) and a simple text file (lines 14-17) to use in the container image. It then creates the required builder in Docker if it doesn't already exist (lines 20-22), shows the details to validate the installation (line 23), and uses it to build the image (line 24). Finally, it runs the container (line 27). This one leans on both the Microsoft and the Docker scripts mentioned above.

{% highlight powershell linenos %}
# based on https://gist.github.com/maxkoshevoi/60d7b7910ad6ddcc6e1c9b656a8d0301, https://techcommunity.microsoft.com/t5/containers/getting-started-build-a-basic-hello-world-image-with-buildkit/ba-p/4096154 and https://docs.docker.com/build/buildkit/#buildkit-on-windows

Write-Host "Create Dockerfile etc."

Set-Location "buildkit-windows-test\sample-dockerfile"
Set-Content Dockerfile @"
FROM mcr.microsoft.com/windows/nanoserver:ltsc2022
USER ContainerAdministrator
COPY hello.txt C:/
RUN echo "Goodbye!" >> hello.txt
CMD ["cmd", "/C", "type C:\\hello.txt"]
"@

Set-Content hello.txt @"
Hello from the buildkit Windows test scripts by Tobias Fenster!
This message shows that your installation appears to be working correctly.
"@

Write-Host "Add builder"
{% raw %}if (-not (docker buildx ls --format "{{.Name}}" | Where-Object { $_ -eq "buildkit-exp" })) { 
  docker buildx create --name buildkit-exp --use --driver=remote npipe:////./pipe/buildkitd 
}
{% endraw %}
docker buildx inspect
docker buildx build -t buildkit-sample --load . 

Write-Host "Run container"
docker run buildkit-sample
{% endhighlight %}

## The details: When it goes wrong after an update
After trying the scripts repeatedly, I sometimes saw errors like this

{% highlight powershell linenos %}
...
=> ERROR [2/3] COPY hello.txt C:/                                                                                 0.0s
------
> [2/3] COPY hello.txt C:/:
------
Dockerfile:3
--------------------
1 |     FROM mcr.microsoft.com/windows/nanoserver:ltsc2022
2 |     USER ContainerAdministrator
3 | >>> COPY hello.txt C:/
4 |     RUN echo "Goodbye!" >> hello.txt
5 |     CMD ["cmd", "/C", "type C:\\hello.txt"]
--------------------
error: failed to solve: failed to prepare sha256:5be502ce3dd6ef4a1ae1aaef7cae12c77e06f349e33ff34218506c868b0d58e1 as tr2idrs1h5o3w0g5vgw0ce2gn: parent snapshot sha256:5be502ce3dd6ef4a1ae1aaef7cae12c77e06f349e33ff34218506c868b0d58e1 does not exist: not found
{% endhighlight %}

If this happens, you can run `buildctl prune` and `buildctl prune-histories` (which you can find in the `buildkit\bin` subfolder), which solved the problem for me.

Have fun playing around with BuildKit, I am sure it is here to stay on Windows too!

[early-issue]: https://github.com/moby/buildkit/issues/616
[announcement]: https://techcommunity.microsoft.com/t5/containers/experimental-windows-containers-support-for-buildkit-released-in/ba-p/4096116
[getting-started]: https://techcommunity.microsoft.com/t5/containers/getting-started-build-a-basic-hello-world-image-with-buildkit/ba-p/4096154
[buildkit]: https://github.com/moby/buildkit
[docker]: https://www.docker.com
[buildkit-docker]: https://docs.docker.com/build/buildkit/#buildkit-on-windows
[dd]: https://www.docker.com/products/docker-desktop/
[gist]: https://gist.github.com/maxkoshevoi/60d7b7910ad6ddcc6e1c9b656a8d0301
[maxk]: https://github.com/maxkoshevoi