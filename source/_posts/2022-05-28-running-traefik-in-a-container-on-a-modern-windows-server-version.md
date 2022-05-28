---
layout: post
title: "Running Traefik in a container on a modern Windows Server version"
permalink: running-traefik-in-a-container-on-a-modern-windows-server-version
date: 2022-05-28 15:17:50
comments: false
description: "Running Traefik in a container on a modern Windows Server version"
keywords: ""
image: /images/traefik-for-windows.png
categories:

tags:

---

[Traefik][traefik] is one of the most popular choices for reverse proxies, especially in containerized environments where it is extremely easy to set up and configure. However, due to a [limitation][issue] in the way [Docker Official Images][doi] are built, we currently only have [Traefik images on the Docker hub][traefik-images] for the rather outdated Windows Server 2019 (1809) version. That can run in hyperv isolation on more recent Windows Server versions as well, but that is not the best way to do it. Therefore, I have decided to create a trivial Dockerfile and build a multi-arch image for all currently supported versions of Windows Server.

## The TL;DR

Just using that image is straight forward and works exactly as the standard Traefik image, only the name is of course different:

```
docker run -p 80:80 -p 8080:8080 -v //./pipe/docker_engine://./pipe/docker_engine tobiasfenster/traefik-for-windows:v2.7.0
```

If you just want to use the image, that should do the trick :)

## The details: Multi-arch for easy usage

Note that we didn't have to put in something like `ltsc2022` as part of the image tag. The reason for that is that the image is built as a multi-arch image. The [official docs][multi-arch-docs] on the topic only explain what it does for Linux images, but you can also use it for Windows images, where it allows you to build one image per Windows host version and then "combine" them with `docker manifest` (marked as experimental, but very stable) into a "generic" image manifest that points at all the "specific" images. At least the [official docs for manifest][manifest-docs] have a hint that there might be some Windows goodness in it as well. Now, if we take a look at the manifest, we see the following:

{% highlight powershell linenos %}
PS C:\Users\tfenster> docker manifest inspect tobiasfenster/traefik-for-windows:v2.7.0
{
   "schemaVersion": 2,
   "mediaType": "application/vnd.docker.distribution.manifest.list.v2+json",
   "manifests": [
      {
         "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
         "size": 3811,
         "digest": "sha256:e5160e0ff97f5dbb84fc4b65ab2a777fe3785211ee2be8fa4fd3dfd107681a1d",
         "platform": {
            "architecture": "amd64",
            "os": "windows",
            "os.version": "10.0.19041.1415"
         }
      },
      {
         "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
         "size": 3810,
         "digest": "sha256:e7a19e2ee287b4b0d55be2ca467f7bfc122a0ec5d444aef081e7b92e1a525840",
         "platform": {
            "architecture": "amd64",
            "os": "windows",
            "os.version": "10.0.17763.2803"
         }
      },
      {
         "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
         "size": 3810,
         "digest": "sha256:d1b83a9849435d6be0d8d6fd3c08d384e7a59f2778a4865b0e4c85f88c45191d",
         "platform": {
            "architecture": "amd64",
            "os": "windows",
            "os.version": "10.0.20348.643"
         }
      }
   ]
}
{% endhighlight %}

You can see that the manifest consists of three elements, all pointing at a different image with a different `os.version`. We have `10.0.19041.1415` (Windows Server 2019 (2004)), `10.0.17763.2803` (Windows Server 2019 (1809)) and `10.0.20348.643` (Windows Server 2022). Docker is able to automatically give you the right image from that list, depending on which Windows Server version you are running. So if you are executing the `docker run` command above on a Windows Server 2022, you get the Windows Server 2022 image. Pretty nice, right?

Creating this also isn't particularly complex. The first step is to create the specific images, so basically you have to run a `docker build` for the individual images, e.g.

{% highlight powershell linenos %}
docker build --isolation hyperv --build-arg BASE=ltsc2019 --build-arg VERSION=v2.7.0 -t tobiasfenster/traefik-for-windows:v2.7.0-ltsc2019 .
Sending build context to Docker daemon    150kB

Step 1/15 : ARG BASE
Step 2/15 : FROM mcr.microsoft.com/windows/servercore:$BASE
 ---> e8870c5c3ab2
Step 3/15 : ARG VERSION
 ---> Using cache
 ---> ce849d001e3a
Step 4/15 : ENV VERSION=$VERSION
 ---> Running in 2f7075433597
Removing intermediate container 2f7075433597
 ---> 77367a5e62fc
Step 5/15 : SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]
 ---> Running in a98bdefeccb0
Removing intermediate container a98bdefeccb0
 ---> 3cb6fc44b5a0
Step 6/15 : RUN $url = ('https://github.com/traefik/traefik/releases/download/' + $env:VERSION + '/traefik_' + $env:VERSION + '_windows_amd64.zip');     Write-Host "Downloading and expanding $url";     Invoke-WebRequest -Uri $url -OutFile '/traefik.zip' -UseBasicParsing;     Expand-Archive -Path '/traefik.zip' -DestinationPath '/' -Force;     Remove-Item '/traefik.zip' -Force;
 ---> Running in e84addda2016
Downloading and expanding https://github.com/traefik/traefik/releases/download/v2.7.0/traefik_v2.7.0_windows_amd64.zip
Removing intermediate container e84addda2016
 ---> 6f0ae12832a6
Step 7/15 : EXPOSE 80
 ---> Running in 0801f17fa04b
Removing intermediate container 0801f17fa04b
 ---> ece39a38c760
Step 8/15 : ENTRYPOINT ["/traefik"]
 ---> Running in 1c827f9c07ac
Removing intermediate container 1c827f9c07ac
 ---> bc66463ed696
Step 9/15 : LABEL org.opencontainers.image.vendor="Traefik Labs"
 ---> Running in 063dd462e4c1
Removing intermediate container 063dd462e4c1
 ---> 7f48e4a7a93f
Step 10/15 : LABEL org.opencontainers.image.authors="Tobias Fenster"
 ---> Running in ff21f43bf9c3
Removing intermediate container ff21f43bf9c3
 ---> b12ff1a1475c
Step 11/15 : LABEL org.opencontainers.image.url="https://traefik.io"
 ---> Running in 3ec295046cb8
Removing intermediate container 3ec295046cb8
 ---> bbc16588c613
Step 12/15 : LABEL org.opencontainers.image.title="Traefik"
 ---> Running in 8c28f5358be3
Removing intermediate container 8c28f5358be3
 ---> cd25f114be73
Step 13/15 : LABEL org.opencontainers.image.description="A modern reverse-proxy created by Traefik Labs. The container image is created by Tobias Fenster"
 ---> Running in deff769d4987
Removing intermediate container deff769d4987
 ---> 761c82c049a5
Step 14/15 : LABEL org.opencontainers.image.version="$VERSION"
 ---> Running in aef2e9007855
Removing intermediate container aef2e9007855
 ---> 0579b6d04472
Step 15/15 : LABEL org.opencontainers.image.documentation="https://docs.traefik.io"
 ---> Running in b59807de4f8a
Removing intermediate container b59807de4f8a
 ---> 61e2b046d807
Successfully built 61e2b046d807
Successfully tagged tobiasfenster/traefik-for-windows:v2.7.0-ltsc2019
{% endhighlight %}

More on those `--build-arg` and `--isolation` parameters in a second, but for now, we are fine with having a specific image for ltsc2019. Next step is to push it to the Docker hub

{% highlight powershell linenos %}
docker push tobiasfenster/traefik-for-windows:v2.7.0-ltsc2019
The push refers to repository [docker.io/tobiasfenster/traefik-for-windows]
ac300f0c494b: Preparing
2d76392c7f5b: Preparing
534d3ba68b75: Preparing
e6c6b8944eb5: Preparing
cfab0cab6780: Preparing
1dcaf8e82f16: Preparing
8b59308a8527: Preparing
3ea608a5e243: Preparing
b9a976eb69e4: Preparing
d8d9ee954a87: Preparing
ea84c3721196: Preparing
7b021c2d0949: Preparing
c1e576ae4707: Preparing
c6723851d2c1: Preparing
a7ba3db29ebb: Preparing
1dcaf8e82f16: Waiting
8b59308a8527: Waiting
3ea608a5e243: Waiting
b9a976eb69e4: Waiting
d8d9ee954a87: Waiting
ea84c3721196: Waiting
7b021c2d0949: Waiting
c1e576ae4707: Waiting
c6723851d2c1: Waiting
a7ba3db29ebb: Waiting
2d76392c7f5b: Pushed
534d3ba68b75: Pushed
ac300f0c494b: Pushed
e6c6b8944eb5: Pushed
cfab0cab6780: Pushed
1dcaf8e82f16: Pushed
8b59308a8527: Pushed
b9a976eb69e4: Pushed
3ea608a5e243: Pushed
c6723851d2c1: Skipped foreign layer
a7ba3db29ebb: Skipped foreign layer
c1e576ae4707: Layer already exists
ea84c3721196: Pushed
7b021c2d0949: Pushed
d8d9ee954a87: Pushed
v2.7.0-ltsc2019: digest: sha256:e7a19e2ee287b4b0d55be2ca467f7bfc122a0ec5d444aef081e7b92e1a525840 size: 3810
{% endhighlight %}

If you look very closely, you can see that the digest in the last line of the output from the `docker push` (`digest: sha256:e7a19e2ee287b4b0d55be2ca467f7bfc122a0ec5d444aef081e7b92e1a525840`) is the same as the `digest` referenced in the element of the manifest above that has version `10.0.17763.2803`, which is ltsc2019. So those digests are the way for docker to make the connection between the manifest and a specific image. But we currently only have a tagged and pushed image, so let's also create the manifest: Imagine that we already have done the build and push for all three specific images for ltsc2019, 2004 and ltsc2022. Now we can do this:

{% highlight powershell linenos %}
docker manifest create tobiasfenster/traefik-for-windows:v2.7.0 tobiasfenster/traefik-for-windows:v2.7.0-ltsc2019 tobiasfenster/traefik-for-windows:v2.7.0-2004 tobiasfenster/traefik-for-windows:v2.7.0-ltsc2022
Created manifest list docker.io/tobiasfenster/traefik-for-windows:v2.7.0
{% endhighlight %}

This creates a manifest called `tobiasfenster/traefik-for-windows:v2.7.0` which points at the other three images. The last step is to simply push the manifest to the Docker hub as well:

{% highlight powershell linenos %}
docker manifest push tobiasfenster/traefik-for-windows:v2.7.0
sha256:65b740bb0f6ab03bfae4cdf14275b1873e7b0cb7e67fb05193e840bc9a9c5ee9
{% endhighlight %}

With that, we have our three specific images and the "generic image", which actually is a manifest, in place and can use it without having to worry about pulling the right version for a host.

## The details: Build parameters and building for different Windows Server versions

The last part to cover is how this works in the Dockerfile, the "recipe" for the container image. The [official Traefik Dockerfile for Windows][Dockerfile-traefik] doesn't worry about different Windows Server versions, as it only covers `1809`:

{% highlight Dockerfile linenos %}
FROM mcr.microsoft.com/windows/servercore:1809
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

RUN Invoke-WebRequest \
        -Uri "https://github.com/traefik/traefik/releases/download/v2.7.0/traefik_v2.7.0_windows_amd64.zip" \
        -OutFile "/traefik.zip"; \
    Expand-Archive -Path "/traefik.zip" -DestinationPath "/" -Force; \
    Remove-Item "/traefik.zip" -Force

EXPOSE 80
ENTRYPOINT [ "/traefik" ]

# Metadata
LABEL org.opencontainers.image.vendor="Traefik Labs" \
    org.opencontainers.image.url="https://traefik.io" \
    org.opencontainers.image.title="Traefik" \
    org.opencontainers.image.description="A modern reverse-proxy" \
    org.opencontainers.image.version="v2.7.0" \
    org.opencontainers.image.documentation="https://docs.traefik.io"
{% endhighlight %}

You can see Windows Server 2019 (1809) hard-coded in line 1 and Traefik v2.7.0 hard-coded in lines 5 and 18. To be fair, those files are generated, but I wanted to handle this a bit more flexibly, so this is how [my Dockerfile][Dockerfile-tf] looks like:

{% highlight Dockerfile linenos %}
# escape=`
ARG BASE
FROM mcr.microsoft.com/windows/servercore:$BASE

ARG VERSION
ENV VERSION=$VERSION

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

RUN $url = ('https://github.com/traefik/traefik/releases/download/' + $env:VERSION + '/traefik_' + $env:VERSION + '_windows_amd64.zip'); `
    Write-Host "Downloading and expanding $url"; `
    Invoke-WebRequest -Uri $url -OutFile '/traefik.zip' -UseBasicParsing; `
    Expand-Archive -Path '/traefik.zip' -DestinationPath '/' -Force; `
    Remove-Item '/traefik.zip' -Force;

EXPOSE 80
ENTRYPOINT ["/traefik"]

LABEL org.opencontainers.image.vendor="Traefik Labs"
LABEL org.opencontainers.image.authors="Tobias Fenster"
LABEL org.opencontainers.image.url="https://traefik.io"
LABEL org.opencontainers.image.title="Traefik"
LABEL org.opencontainers.image.description="A modern reverse-proxy created by Traefik Labs. The container image is created by Tobias Fenster"
LABEL org.opencontainers.image.version="$VERSION"
LABEL org.opencontainers.image.documentation="https://docs.traefik.io"
{% endhighlight %}

As you can see, I am basically doing the exact same thing as the official Dockerfile, with the exception of the `BASE` and `VERSION` variables. `BASE` (lines 2 and 3) is replaced with the Windows Server base image version, and `VERSION` (lines 6, 10 and 24) is replaced with the Traefik version. Because of that, I can use the exact same Dockerfile to create images for all three Windows Server base image versions and all Traefik versions. Let's take a look at the `docker build` command again:

{% highlight powershell linenos %}
docker build --isolation hyperv --build-arg BASE=ltsc2019 --build-arg VERSION=v2.7.0 -t tobiasfenster/traefik-for-windows:v2.7.0-ltsc2019 .
{% endhighlight %}

This is the way how we let `docker build` know what values to use for those variables: `--build-arg BASE=ltsc2019 --build-arg VERSION=v2.7.0`. The last thing that might be puzzling in that line is `--isolation hyperv`. The reason for that is that `docker build` by default runs in process isolation. But that only works if the base image and the host have the same version. However, we now want to create images for the three different base images. Fortunately, by using hyperv isolation, this also isn't a problem.

I hope this gave you an idea how you can a) easily use Traefik on modern Windows Server versions (in process isolation) and b) how you might use multi-arch images and configurable Dockerfiles if you need to create something similar for your own images. The full code of this, including the GitHub actions to create the images, can be found [here][src].

[traefik]: https://traefik.io
[issue]: https://github.com/docker-library/official-images/issues/9198
[doi]: https://github.com/docker-library/official-images
[traefik-images]: https://hub.docker.com/_/traefik
[multi-arch-docs]: https://docs.docker.com/desktop/multi-arch/
[manifest-docs]: https://docs.docker.com/engine/reference/commandline/manifest/
[Dockerfile-traefik]: https://github.com/traefik/traefik-library-image/blob/980d4fad23bdcb2c57d71b8194846caf25005958/windows/1809/Dockerfile
[Dockerfile-tf]: https://github.com/tfenster/traefik-for-windows/blob/main/Dockerfile
[src]: https://github.com/tfenster/traefik-for-windows