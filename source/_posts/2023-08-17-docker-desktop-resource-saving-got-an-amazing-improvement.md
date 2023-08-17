---
layout: post
title: "Docker Desktop resource saving got an amazing improvement"
permalink: docker-desktop-resource-saving-got-an-amazing-improvement
date: 2023-08-17 19:11:34
comments: false
description: "Docker Desktop resource saving got an amazing improvement"
keywords: ""
image: /images/dd.png
categories:

tags:

---

[Docker Desktop][dd], the "one-click-install application for your Mac, Linux, or Windows environment that lets you build, share, and run containerized applications and microservices" has a new release, [v4.22][rel], and for me, it has the potential to change my habits and the way I develop. Here's why:

## The TL;DR

Up until v4.21, running Linux containers on Windows with Docker Desktop was quite a resource hog. Even right out of the box, Docker Desktop (or technically the VM behind it, but for simplicity's sake, I'll just call it "Docker Desktop") was hogging a huge chunk of memory. For example, when I was running two VS Code dev containers, I've seen this go up to 8 or even 10 GB of memory. If I were a full-time developer, this might have been fine, but I also (unfortunately ;)) have to spend some time with Teams, Office and other applications, so my machine could be under quite a bit of resource pressure overall if, for example, I went into a meeting and had to present something while Docker Desktop was running. For the same reason, I never configured Docker Desktop to start automatically, as it was just too resource hungry.

Fortunately, v4.22 changes that dramatically! There are some nice new features, but the "Resource Saver" in particular is a game changer for me. To give you an idea, this is what an idle Docker Desktop with two stopped containers looked like in v4.20.1

![status bar in Docker Desktop showing 6.91 GB memory usage](/images/4.20.1 2stop.png)
{: .centered}

This is what it looked like in v4.21.1, already a good improvement

![status bar in Docker Desktop showing 4.35 GB memory usage](/images/4.21.1 2stop.png)
{: .centered}

But here comes the real change, v4.22

![status bar in Docker Desktop showing 0 GB memory usage](/images/4.22 2stop.png)
{: .centered}

As you can see by the little leaf next to the Docker icon, Docker Desktop has activated "Resource Saver" mode and goes to 0 bytes of memory usage! With this improvement, I'm happy to let Docker Desktop autostart and just stop my containers when I need to do something else, knowing that Docker Desktop is no longer hogging resources.

## The details: How I tested it

After reading the announcement, I wanted to try for myself, so I created a new Windows 11 VM and first installed Docker Desktop v4.20.1 and created a VS Code .NET devcontainer to have the image in place. Then I rebooted the machine and started with my tests:

- First, look at the memory usage after startup.
- Then create two devcontainers and look at the memory usage again.
- Finally, stop and delete the devcontainers and check the memory usage again.

Then I installed v4.21.1, rebooted and ran my test case again. After that I installed 4.22, rebooted and did it one last time.

## The details: All the results

You already saw the biggest change above, but the other results are also interesting, showing how Docker Desktop has improved in all areas over the last two releases.

The results with v4.20.1 show 2.69 GB of RAM being used initially, rising to 7.29 GB with two containers running, and then dropping only slightly to 6.91 GB when they are stopped.

![status bar in Docker Desktop showing 2.69 GB memory usage](/images/4.20.1 initial.png)
{: .centered}

![status bar in Docker Desktop showing 7.29 GB memory usage](/images/4.20.1 2run.png)
{: .centered}

![status bar in Docker Desktop showing 6.91 GB memory usage](/images/4.20.1 2stop.png)
{: .centered}

With v4.21.1, we already got a quite an improvement: The initial usage is 1.86 GB (~ 30% less), then 4.76 GB for two running (~ 35% less) and 4.35 GB when they are stopped (~ 37% less)

![status bar in Docker Desktop showing 2.69 GB memory usage](/images/4.21.1 initial.png)
{: .centered}

![status bar in Docker Desktop showing 7.29 GB memory usage](/images/4.21.1 2run.png)
{: .centered}

![status bar in Docker Desktop showing 6.91 GB memory usage](/images/4.21.1 2stop.png)
{: .centered}

The same improvements are visible in v4.22, but the biggest impact is of course the Resource Saver: 1.98 GB at first, about the same as in 4.21.1. Running two containers brings us to 3.21 GB (~33% less than 4.21.1 and ~56% less than 4.20.1), again a very nice improvement, but once again the real change comes with the Resource Saver and the drop to 0.

![status bar in Docker Desktop showing 2.69 GB memory usage](/images/4.22 initial.png)
{: .centered}

![status bar in Docker Desktop showing 2.69 GB memory usage](/images/4.22 initial saver.png)
{: .centered}

![status bar in Docker Desktop showing 7.29 GB memory usage](/images/4.22 2run.png)
{: .centered}

![status bar in Docker Desktop showing 6.91 GB memory usage](/images/4.22 2stop.png)
{: .centered}

To be honest, for a while I stopped using Docker Desktop as my main driver for dev containers and started using dev VMs (Windows and Linux) to run my containers. But with this incredible improvement, I'm going back to local development with Docker Desktop.

[dd]: https://www.docker.com/products/docker-desktop/
[rel]: https://www.docker.com/blog/docker-desktop-4-22/?utm_campaign=blog&utm_content=1692294121&utm_medium=social&utm_source=twitter