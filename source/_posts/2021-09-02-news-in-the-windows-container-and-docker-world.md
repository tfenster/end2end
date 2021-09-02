---
layout: post
title: "News in the Windows container and Docker world"
permalink: news-in-the-windows-container-and-docker-world
date: 2021-09-02 22:09:28
comments: false
description: "News in the Windows container and Docker world"
keywords: ""
image: /images/windows-docker-news.png
categories:

tags:

---

The last couple of days brought a lot of news for the container world, especially for those using Windows containers or Docker Desktop. As it can be difficult to follow all the news and get a complete understanding, I'll try to give a quick overview about the in my opinion and from my professional background most important news. And because I don't like content that just repeats the original sources, I'll try to also share my opinion why the specific parts matter.

## The TL;DR

Here are the headlines:

- Docker Desktop is no longer free, but almost as per Scott Johnston on the [Docker blog][docker]
- Windows Server 2022 and Windows 11 get down-level compatibility for process isolation (and Windows 10 misses out) as per Vinicius Apolinario on the [Microsoft Tech Community][vinicius]
- Updates will happen in the Long-Term Servicing Channel (LTSC) cadence as per Vinicius Apolinario on the [Microsoft Tech Community][vinicius] as well
- Containerd is the only supported container runtime for Windows Server 2022 on Microsoft's first party services as per Weijuan Shi Davis on the [Microsoft Tech Community][weijuan]

## The details: Docker Desktop
As announced on the [Docker blog][docker], Docker Desktop is no longer free. If you want to use it professionally and work for a company with either more than 250 employees or more 10 mio revenue, you will have to pay for it. This is where most stop, but I think it is very important to mention that the paid offerings start at 5$ per user and month. If you are not willing to pay that, you either are incredibly cheap or don't have a use for Docker Desktop in the first place. 

This announcement matters because at least on Windows, my guess would be that more than 90%, maybe even more than 95% of the container and Docker users are using Docker Desktop. Yes, there are other options like getting the Docker binaries directly or even work with [containerd][containerd] and [crictl][crictl], but you really need to make a choice and know what you are doing for those scenarios. The easy way is to just use Docker Desktop. If you want to also use Linux containers, it becomes even more obvious as you get an incredibly smooth integration with WSL2 through Docker Desktop. If you are looking for advanced scenarios, the Kubernetes support and the recently added Developer Environment features are also very interesting.

**Bottom line**: Yes, it is no longer free, but you might still qualify for the free option and if not, pricing is extremely reasonable. If it helps Docker to keep going as an important piece of the container ecosystem and push innovations like dev environments or docker-compose integration with cloud backends like [ACI][aci], I am more than happy to spend that money.

## The details: Down-level compatibility for process isolation
First of all, if you don't know what process isolation and hyperv isolation are and why that matters, you might want to get started reading the [docs][iso]. In my opinion, there are lots of advantages for process isolation, so whenever possible I try to use that. Unfortunately, for previous releases of Windows Server and Windows 10, the build numbers between host and container image needed to match exactly. That means that you could e.g. run only a Windows Server 2004 image on Windows 10 2004 in process isolation. Not that complicated, but explained well in the [docs][matrix]. That could be very cumbersome and annoying. With Windows 11 and Windows Server 2022, we finally get more flexibility here: As long as the host is newer than the container image, a container can run in process isolation. 

To give you an idea, here is the output of first running a container for the new Windows Server 2022 image in hyperv isolation showing an OS version of `10.0.20348.0` which is the exact version of the image. If I then run it in process isolation, you can see a different version of `10.0.22000.0` as the container is now using the kernel of the host. In the end you can see that the version of the host indeed is `10.0.22000.0` (Windows 11).

![screenshot of the different versions](/images/versions.png)
{: .centered}

Side note: Interestingly, `cmd` in the process isolated container shows version `10.0.22000.169` while `cmd` on the host shows version `10.0.22000.168`. So far, I couldn't find anyone who would have been able to explain that... If you can, please let me know. "Mysteries" like that really annoy me :)

**Bottom line**: Just great. Yes, it doesn't fix process isolation for Windows 10 21H1 or newer, but you can't solve everything...

## The details: Container images also follow LTSC now
As you can see in the [servicing channel docs][ltsc], Windows Server 2022 isn't following the Semi-Annual Channel (SAC) cadence of Windows 2019, but goes back to the Long-Term Servicing Channel (LTSC) cadence with new releases every 2-3 years. This is important because if you couldn't immediately take up a new release in the SAC and could update only after e.g. 4 months, you basically had only 14 months of support because SAC had only 18 months support. That was a lot of hustle just to keep up to date and avoid running out of support. Therefore, the news that the container images now also follow LTSC instead if SAC, completely makes sense and give more stability. On top, LTSC has not only 5 years of regular support, but also an additional 5 years of extended support, so if your scenarios requires it, you can really guarantee very long support times. 

The only downside that I can see is that innovation will probably slow down for those outside of AKS / AKS-HCI and probably ACI. Whether that is a good or a bad thing might also be up for debate as it hopefully will help to spend some more time on fixing fundamental issues and have more stability.

**Bottom line**: Good move as well, even if maybe at the price of somewhat slower innovation if you aren't on one of Microsoft's first-level container services.

## The details: Containerd is the only supported runtime
When I first read this, it gave me a bit of a start as we are running a SaaS offering relying heavily on Docker (for now). Fortunately, this is only true for Microsoft's first-level container services, so if you are running just a standalone Windows Server container host, maybe using docker compose or even Docker Swarm, nothing changes. You still have the right to use Docker Enterprise (now owned by Mirantis) if you pay for your Windows Server and you can still create regular support tickets.

**Bottom line**: For now, nothing changes even as a non-first-level service user. But the path for the future is clear and probably doesn't involve Docker on Windows Server, which I personally don't like but can understand the motivation.

[docker]: https://www.docker.com/blog/updating-product-subscriptions/
[weijuan]: https://techcommunity.microsoft.com/t5/containers/windows-server-2022-now-generally-available/ba-p/2689973
[vinicius]: https://techcommunity.microsoft.com/t5/containers/windows-server-2022-and-beyond-for-containers/ba-p/2712487
[containerd]: https://containerd.io/
[crictl]: https://github.com/kubernetes-sigs/cri-tools/blob/master/docs/crictl.md
[aci]: https://docs.docker.com/cloud/aci-integration/
[iso]: https://docs.microsoft.com/en-us/virtualization/windowscontainers/manage-containers/hyperv-container
[matrix]: https://docs.microsoft.com/en-us/virtualization/windowscontainers/deploy-containers/version-compatibility?tabs=windows-server-2022%2Cwindows-10-2004#windows-client-host-os-compatibility
[ltsc]: https://docs.microsoft.com/en-us/windows-server/get-started/servicing-channels-comparison