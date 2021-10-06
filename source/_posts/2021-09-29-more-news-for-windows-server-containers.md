---
layout: post
title: "More news for Windows (Server) containers"
permalink: more-news-for-windows-server-containers
date: 2021-09-29 06:16:10
comments: false
description: "More news for Windows (Server) containers"
keywords: ""
image: /images/mirantis-docker-msft.png
categories:

tags:

---

**Update**: I got some feedback after posting this, so I changed and added some aspects, all marked with **Update:**/**Update end** for those who read it before and only want to check the updates. <br />
**Update 2**: One more update as my colleague Markus Lippert together with some others also gave me a very interesting additional idea

After the recent news about the changes for Docker Desktop, Windows 11 and Windows 2022 (see my thoughts on that [here][prev]), even more has changed: As [Microsoft][msft-announcement] and [Mirantis][mirantis-announcement] have announced, the previously established deal between Docker and Microsoft and after the acquisition of Docker Enterprise between Mirantis and Microsoft will come to an end by end of September 2022. At that point, Microsoft will no longer support the Mirantis Container Runtime, formerly known as Docker Engine - Enterprise. **Update:** To clarify, Microsoft never officially supported the Docker/Mirantis runtime, but there was an agreement with Docker Inc. and then Mirantis that they provide enterprise support for Windows Server customers at no additional charge. Still, the support cases went through Microsoft support and you had the well-known escalation channels.**Update end** Instead, [containerd][containerd] will become the default runtime, but only with support in the context of [AKS (Azure Kubernetes Service)][aks] and its on-prem sibling [AKS-HCI (Azure Kubernetes Service on Azure Stack HCI)][aks-hci]. Now, what does that mean in the context of Business Central? I'll try to answer this FAQ-style. Please note that this is a quite opinionated view of things. I absolutely believe that the statements below are very valid for every Business Central company using containers, but as is true so often, there are of course other valid opinions.

## The TL;DR
- Should I panic? <br />
    No. 
- Why shouldn't I panic? <br />
    The change will come into effect by end of September 2022, so you have a year to prepare. Afterwards, there is an extremely reasonably priced option by Mirantis, see below. And I am pretty sure, Microsoft (aka Freddy Kristiansen in this case) will come up with help as well.
- Do I need to change anything if I am only using Docker Desktop?<br />
    No, everything works as before. 
- Do I need to change anything if I run Business Central containers on Windows Servers, for centralized container environments, build pipelines or other reasons?<br />
    Yes, after September 2022 you won't be able to get updates for the Mirantis Container Runtime as you are used to, and you also won't get support from Microsoft. As explained by [Mirantis][mirantis-announcement] you can get the runtime for free if you run up to 9 nodes (container hosts) and for 50$ per node and <b>year</b> if you run 10-50 nodes. If you want to get support, you need to get in touch with Mirantis. This offer in general is available at least until end of 2021 and the free offering is valid until end of 2023 (see the [offer page][mirantis-offer]). From my point of view, if you run a couple of container hosts, this is the way to go. If containerization of your server workloads isn't worth 4$ per month, then something is wrong with your containerization approach, in my humble opinion. If 4$ per month per environment that potentially can run dozens of containers is breaking your budget, then something is wrong with your budget. This might come across as arrogant, but I really don't understand the point if that pricing is a problem. Companies need to make money because otherwise they will stop to exist and surprisingly, Docker and Mirantis are not an exception of that rule. end-of-rant... **Update 2**: Another option would be to use the way shared by my colleague [Markus Lippert][ml] on Windows Server as well. It was originally intended for Docker Desktop on Windows Clients, but it also works on Windows Server and to the best of my knowledge this will stay stable and doesn't violate any license restrictions as of now. Still no support, but the Mirantis free offering also doesn't include support...**Update 2 end**

## The Details: Others also asked...
- What if I was clever and tried to avoid paying for Docker Desktop?<br />
    As I wrote above, nothing changes if you are using only Docker Desktop. If you decided not to use Docker Desktop and instead go for the workaround of using the DockerMsftProvider to install the engine on Windows clients, as explained by [AJ Kauffmann][ajk] and others, then this won't work in the future as well because the DockerMsftProvider will not be maintained anymore by Microsoft after September 2022. Another workaround as explained by my colleague [Markus Lippert][ml] might continue to work as Docker needs the Docker daemon for Docker Desktop as well. But note that this comes without any support and might or might not break in the future. ~~I am also pretty sure that it wouldn't be in line with the licensing requirements of Docker Desktop.~~ **Update:** The last sentence definitely is wrong as you can find [here][docker-free] below 3): "That means all the binaries (Docker Engine, Docker Daemon, Docker CLI, Docker Compose, BuildKit, libraries, etc) and anything open source continues to be free of charge." With that, the sentence before probably is also wrong and the solution provided by Markus can be expected to be stable. **Update end**
- What are the other options if I don't want to use the free or almost-free Mirantis option, but keep managing my own environments?<br />
    The Mirantis Container Runtime is built on top of some free and open source components, which you can also decide to use. The [Moby project][moby] provides a collection of components including [containerd][containerd] as container runtime, [buildkit][buildkit] as build environment (Windows support is work in progress) and no directly usable client component. I have to say that I am on somewhat shaky ground here as I only know the theory, but never worked with Moby in practice, so if anyone has corrections, please let me know. There are clients like [crictl][crictl], but to the best of my knowledge, nothing that claims to be production ready or with a support offering. **Update:** A better client option would be [nerdctl][nerdctl] as part of the containerd project, which is more feature complete and user friendly than crictl and Windows support is [being worked on][nerdctl-windows].**Update end** Bottom line: This will cost you a lot more time than the Mirantis offering costs money.
- What are managed offerings I might consider?<br />
    The container environments supported directly by Microsoft are [AKS][aks] and [AKS-HCI][aks-hci], offerings built on Kubernetes as the name suggests. You can certainly run Business Central workloads on them as also e.g. my colleague Markus Lippert [has shown][ml-k8s]. However, there are a couple of issues with that, most importantly that bccontainerhelper doesn't work in that context, that you most likely will want to create and maintain your own image repository[^1] and that you need to reorganize your pipelines if they are using containers. All that is doable and as I wrote above, I am pretty sure that Microsoft will come up with suggestions as well, but the main problem with the whole approach is that Kubernetes adds quite some complexity. It is an amazing environment for running stateless microservices at scale. It also is a good environment for running stateful single-instance workloads like Business Central, but the benefits are a lot fewer, as Kubernetes just isn't intended for that scenario. Therefore, the question is whether learning Kubernetes and solving the challenges mentioned above is worth the effort.
- What if I don't want to bother with all of this technology stuff and only want it to work?<br />
    COSMO offers a completely managed service called COSMO Azure DevOps & Docker Self-Service and you can find out more [here][marketplace]. It covers not only the containerization part for dev/test/demo, but also pipelines (built on top of [ALOps][alops]), Azure DevOps organization/project/repo handling, integration into VS Code, a convenient Power App and much more. If you are reading this before [Directions EMEA 2021][directions], come visit our Expo Theater session on the topic. Afterwards, we will also share a highlight walkthrough video of our solution. To be honest, it isn't cheap, but solves a lot of problems, saves a ton of time and therefore is well worth the money. We aren't there yet, but very likely we will change our backend to use AKS, all without additional cost and without the users noticing anything. Basically, this change is a perfect example why we built this service and why it makes sense for all those who don't want to reinvent another technology wheel and rather focus on their core business. Just to give you a quick glimpse, this is how you create a new development container in our service:
<video width="100%" controls>
  <source type="video/mp4" src="/images/container-create.mp4">
</video>

- What if I don't like all of this?<br />
    Go back to VMs or even physical machines and directly installing Business Central or use online sandboxes. Containerization makes life a lot easier, but it isn't necessary, so you are not forced to do anything in that area. I am 100% convinced that you will spend a lot more in time than you would spend in money for Docker Desktop or Mirantis Container Runtime, but the decision is up to you.

If you have other questions around that topic, please get in touch through social media (see below) and I would be happy to try and answer them

[^1]: Technically speaking, you don't have to. The specific images are basically just a caching mechanism to get quicker startup time, and it is also possible to directly use the generic images of your provide the right artifact URL. The problem with that is that you will add somewhere around 15 minutes to the startup time of every container. At least from my point of view, that isn't an acceptable scenario.

[prev]: /news-in-the-windows-container-and-docker-world
[msft-announcement]: https://techcommunity.microsoft.com/t5/containers/updates-to-the-windows-container-runtime-support/ba-p/2788799
[mirantis-announcement]: https://www.mirantis.com/blog/windows-server-container-users-mirantis-is-here-to-support-you/ 
[containerd]: https://containerd.io/
[aks]: https://azure.microsoft.com/en-us/services/kubernetes-service/
[aks-hci]: https://docs.microsoft.com/en-us/azure-stack/aks-hci/overview
[ajk]: https://www.kauffmann.nl/2019/03/04/how-to-install-docker-on-windows-10-without-hyper-v/
[mirantis-offer]: https://info.mirantis.com/docker-engine-support
[ml]: https://lippertmarkus.com/2021/09/04/containers-without-docker-desktop/
[ml-k8s]: https://lippertmarkus.com/2020/10/01/deploy-bc-helm/
[moby]: https://mobyproject.org/
[buildkit]: https://github.com/moby/buildkit
[crictl]: https://github.com/kubernetes-sigs/cri-tools/blob/master/docs/crictl.md
[marketplace]: https://marketplace.cosmoconsult.com/product/?id=345E2CCC-C480-4DB3-9309-3FCD4065CED4#
[alops]: https://www.alops.be/
[directions]: https://directions4partners.com/events/directions-emea/
[nerdctl]: https://github.com/containerd/nerdctl
[nerdctl-windows]: https://github.com/containerd/nerdctl/issues/28
[docker-free]: https://www.docker.com/blog/looking-for-a-docker-alternative-consider-this/