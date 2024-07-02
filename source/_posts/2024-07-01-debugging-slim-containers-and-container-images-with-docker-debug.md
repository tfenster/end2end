---
layout: post
title: "Debugging slim containers and container images with Docker debug"
permalink: debugging-slim-containers-and-container-images-with-docker-debug
date: 2024-07-02 16:28:10
comments: false
description: "Debugging slim containers and container images with Docker debug"
keywords: ""
image: /images/docker-debug.png
categories:

tags:

---

I've talked a few times over the past months about using slimmed down container images as one of the best practices for containerized workloads (e.g. at [Visual Studio Toolbox Live][vstl]). One of the challenges with this is debugging, because if you have no tools, not even a shell in your container, how are you going to debug problems inside that container? One of the options is `docker debug`, which makes this and other scenarios very easy.

## The TL;DR

Assuming that you have a running container called `drafted_dadiet`, created from a slim container image, you can't just do a `docker exec`, because there is no shell in that container. If you try, you will get something like this:

{% highlight bash linenos %}
PS C:\Users\vmadmin> docker exec -ti drafted_dadiet bash
OCI runtime exec failed: exec failed: unable to start container process: exec: "bash": executable file not found in $PATH: unknown
{% endhighlight %}

`docker debug` to the rescue! You can call it like this and it will give you a shell e.g. with `ps`, `vim` or `htop`

{% highlight bash linenos %}
PS C:\Users\vmadmin> docker debug drafted_dadiet
         ▄
     ▄ ▄ ▄  ▀▄▀
   ▄ ▄ ▄ ▄ ▄▇▀  █▀▄ █▀█ █▀▀ █▄▀ █▀▀ █▀█
  ▀████████▀     █▄▀ █▄█ █▄▄ █ █ ██▄ █▀▄
   ▀█████▀                        DEBUG

Builtin commands:
- install [tool1] [tool2] ...    Add Nix packages from: https://search.nixos.org/packages
- uninstall [tool1] [tool2] ...  Uninstall NixOS package(s).
- entrypoint                     Print/lint/run the entrypoint.
- builtins                       Show builtin commands.

Checks:
✓ distro:            Ubuntu 22.04.4 LTS
✓ entrypoint linter: no errors (run 'entrypoint' for details)

This is an attach shell, i.e.:
- Any changes to the container filesystem are visible to the container directly.
- The /nix directory is invisible to the actual container.
                                                                                                  Version: 0.0.29 (BETA)
root@53065c16687b /app [drafted_dadiet]
docker > ps aux
USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
app          1  0.2  0.2 275083528 84124 ?     Ssl  19:18   0:00 dotnet dotnet.dll
root        49  0.2  0.0   4612  2080 pts/0    Ss   19:21   0:00 /nix/var/nix/profiles/default/bin/bash -i
root        60  0.0  0.0   7208  1572 pts/0    R+   19:21   0:00 ps aux
root@53065c16687b /app [drafted_dadiet]
docker >
{% endhighlight %}

You can do the same with stopped containers or even just images. More on this and other topics in the details.

## The details: Installing additional packages

As mentioned above, some tools like `vim`, `htop` or the built-in bash commands are already available. But you may need something else, for which you can use the whole [Nix][nix] package collection. You can search directly from the Nix website using the [package search][nixpgs]. Let's say we want to do some kind of performance analysis with `mpstat`. Searching for it in the Nix package search shows `sysstat` as the right package, so we can do the following to install and use the tool:

{% highlight bash linenos %}
docker > install sysstat
Tip: You can install any package available at: https://search.nixos.org/packages.
installing 'sysstat-12.7.4'
this path will be fetched (0.39 MiB download, 1.70 MiB unpacked):
  /nix/store/j845mjw1w3jmqywzd4cddbj8hqcgqk25-sysstat-12.7.4
copying path '/nix/store/j845mjw1w3jmqywzd4cddbj8hqcgqk25-sysstat-12.7.4' from 'https://cache.nixos.org'...
building '/nix/store/v5gbk1z5nd5v3634ykw5bkz9912yhscl-user-environment.drv'...
root@53065c16687b /app [drafted_dadiet]
docker > mpstat -P ALL
Linux 5.15.146.1-microsoft-standard-WSL2 (53065c16687b)         07/02/24        _x86_64_        (16 CPU)

20:22:53     CPU    %usr   %nice    %sys %iowait    %irq   %soft  %steal  %guest  %gnice   %idle
20:22:53     all    0.17    0.00    0.26    0.14    0.00    0.06    0.00    0.00    0.00   99.37
20:22:53       0    0.17    0.00    0.34    0.31    0.00    0.62    0.00    0.00    0.00   98.56
20:22:53       1    0.14    0.00    0.24    0.28    0.00    0.12    0.00    0.00    0.00   99.22
20:22:53       2    0.18    0.00    0.31    0.28    0.00    0.05    0.00    0.00    0.00   99.18
20:22:53       3    0.12    0.00    0.19    0.37    0.00    0.03    0.00    0.00    0.00   99.29
20:22:53       4    0.21    0.00    0.32    0.28    0.00    0.01    0.00    0.00    0.00   99.18
20:22:53       5    0.14    0.00    0.21    0.03    0.00    0.01    0.00    0.00    0.00   99.61
20:22:53       6    0.20    0.00    0.30    0.16    0.00    0.01    0.00    0.00    0.00   99.33
20:22:53       7    0.11    0.00    0.18    0.09    0.00    0.01    0.00    0.00    0.00   99.60
20:22:53       8    0.17    0.00    0.31    0.09    0.00    0.01    0.00    0.00    0.00   99.43
20:22:53       9    0.11    0.00    0.18    0.04    0.00    0.01    0.00    0.00    0.00   99.66
20:22:53      10    0.23    0.00    0.33    0.07    0.00    0.01    0.00    0.00    0.00   99.36
20:22:53      11    0.13    0.00    0.21    0.01    0.00    0.01    0.00    0.00    0.00   99.64
20:22:53      12    0.19    0.00    0.28    0.07    0.00    0.01    0.00    0.00    0.00   99.45
20:22:53      13    0.20    0.00    0.26    0.05    0.00    0.01    0.00    0.00    0.00   99.49
20:22:53      14    0.20    0.00    0.32    0.06    0.00    0.01    0.00    0.00    0.00   99.42
20:22:53      15    0.15    0.00    0.26    0.09    0.00    0.01    0.00    0.00    0.00   99.49
{% endhighlight %}

This will permanently add the `sysstat` package to your `docker debug` toolbox, so even if you stop the debug session and start one with a different container later, the package will still be installed. To remove it, you need to call `uninstall`, e.g. like this:

{% highlight bash linenos %}
docker > uninstall sysstat
uninstalling 'sysstat-12.7.4'
building '/nix/store/xpd745yf419qsy90zbfhld1wd41vdhvs-user-environment.drv'...
{% endhighlight %}

## The details: Debugging stopped containers and images

`docker debug` is not limited to running containers, as in the example above. Even if a container is stopped and you maybe can't start it anymore because it immediately crashes, `docker debug` will still help you. In the following example, you can see that the container is stopped, but debugging still works:

{% highlight bash linenos %}
PS C:\Users\vmadmin> docker ps -a
CONTAINER ID   IMAGE                           COMMAND                  CREATED             STATUS                     PORTS                    NAMES
53065c16687b   chiseled                        "dotnet dotnet.dll"      About an hour ago   Exited (0) 2 seconds ago                            drafted_dadiet
PS C:\Users\vmadmin> docker debug drafted_dadiet
         ▄
     ▄ ▄ ▄  ▀▄▀
   ▄ ▄ ▄ ▄ ▄▇▀  █▀▄ █▀█ █▀▀ █▄▀ █▀▀ █▀█
  ▀████████▀     █▄▀ █▄█ █▄▄ █ █ ██▄ █▀▄
   ▀█████▀                        DEBUG

Builtin commands:
- install [tool1] [tool2] ...    Add Nix packages from: https://search.nixos.org/packages
- uninstall [tool1] [tool2] ...  Uninstall NixOS package(s).
- entrypoint                     Print/lint/run the entrypoint.
- builtins                       Show builtin commands.

Checks:
✓ distro:            Ubuntu 22.04.4 LTS
✓ entrypoint linter: no errors (run 'entrypoint' for details)

Note: This is a sandbox shell. All changes will not affect the actual container.
                                                                                                  Version: 0.0.29 (BETA)
root@53065c16687b /app [drafted_dadiet]
docker >
{% endhighlight %}

And debugging is not even limited to containers, instead you can use it directly on images. An example scenario coumightld be that you've created an image and it doesn't start as expected. Using `docker debug` for this looks like this, assuming you have an image named `chiseled`:

{% highlight bash linenos %}
PS C:\Users\vmadmin> docker debug chiseled
         ▄
     ▄ ▄ ▄  ▀▄▀
   ▄ ▄ ▄ ▄ ▄▇▀  █▀▄ █▀█ █▀▀ █▄▀ █▀▀ █▀█
  ▀████████▀     █▄▀ █▄█ █▄▄ █ █ ██▄ █▀▄
   ▀█████▀                        DEBUG

Builtin commands:
- install [tool1] [tool2] ...    Add Nix packages from: https://search.nixos.org/packages
- uninstall [tool1] [tool2] ...  Uninstall NixOS package(s).
- entrypoint                     Print/lint/run the entrypoint.
- builtins                       Show builtin commands.

Checks:
✓ distro:            Ubuntu 22.04.4 LTS
✓ entrypoint linter: no errors (run 'entrypoint' for details)

Note: This is a sandbox shell. All changes will not affect the actual image.
                                                                                                  Version: 0.0.29 (BETA)
root@ed1d1a420c7a /app [chiseled:latest]
docker >
{% endhighlight %}

Note that in this case the image name is given as part of the prompt instead of the container name (line 20, compared to line 23 in the previous output). Of course, checking for running processes does not return the application inside the container, because now we are only working on the image, not the running container:

{% highlight bash linenos %}
docker > ps aux
USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root         1  0.0  0.0   4612  2004 pts/0    Ss   20:42   0:00 /nix/var/nix/profiles/default/bin/bash -i
root        12  0.0  0.0   7208  1576 pts/0    R+   20:45   0:00 ps aux
{% endhighlight %}

Compare this to the TL;DR above, where you can see `ps aux` in a debugging session connected to a running container, which shows the `dotnet` application process in line 25.

## The details: If you want to try it yourself

To try it yourself, you need to have a [Pro, Team, or Business Docker subscription][subsc] and be signed in. Then you can use a slim image, for example my [tobiasfenster/chiseled][https://hub.docker.com/r/tobiasfenster/chiseled] image. It contains the dotnet template for blazor (created with `dotnet new blazor`) and almost the `Dockerfile` as it comes out of the box by using the "Docker: Add Docker Files to Workspace" action provided by the [Docker VS Code extension][dvsc]. My only change was to change the image for the `base` stage to `mcr.microsoft.com/dotnet/aspnet:8.0-jammy-chiseled`, a slim base image provided by Microsoft for .NET applications:

{% highlight Dockerfile linenos %}
FROM mcr.microsoft.com/dotnet/aspnet:8.0-jammy-chiseled AS base
...
{% endhighlight %}

As you saw above, you can use `docker debug tobiasfenster/chiseled` to directly debug the image. It will pull the image and then start the debug session. Or you can run a container for this image, e.g. with `docker run --name drafted_dadiet -p 5295:5295 tobiasfenster/chiseled` and then get the debug session for this container with `docker debug drafted_dadiet`

## The details: Debugging Windows containers

You can't, at least not with `docker debug` as of July '24. And I wouldn't hold my breath that this will ever change, to be honest.

[vstl]: https://www.youtube.com/live/voQvQQKX8ew?si=wtL4fhTfLLs8FlxR
[nix]: https://nixos.org/
[nixpgs]: https://search.nixos.org/packages
[subsc]: https://docs.docker.com/subscription/details/
[dvsc]: https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-docker