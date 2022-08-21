---
layout: post
title: "Microsoft Dev Box   A new Azure service for developer productivity"
permalink: microsoft-dev-box---a-new-azure-service-for-developer-productivity
date: 2022-09-01 01:28:54
comments: false
description: "Microsoft Dev Box - A new Azure service for developer productivity"
keywords: ""
image: /images/ms-dev-portal.png
categories:

tags:

---

With a recent [announcement], Microsoft launched a very interesting new Azure service, which has the potential to drastically increase developer productivity: [Azure Dev Box][devbox]. Dev Box allows companies to provide tailored virtual machines to their developers, so that they have the right tools and the right resources for the task they need to work on next. With developers being in really high demand, it is in the pure business interest of every company to make them as productive as possible. The sometimes overhyped, but nevertheless very important idea of "developer flow" can be a key factor why one team delivers faster and/or more than another and Satya Nadella explains in his [Build 2022 keynote][build] how Dev Box can contribute to reaching that state. But most importantly, in my own experience and from talking to colleagues, developers that can code without impediments and without having to worry about infrastructure, are the happiest and (as a consequence) the most productive. I am convinced that a machine that works well, is properly set up and performant is crucial for getting into the flow and staying there. And Dev Box has the potential to help us achieve that.

## The TL;DR

As a developer, you just go into a portal called the "Microsoft developer portal", click "Add dev box", potentially select the right configuration, wait for a bit and you are ready to connect and start coding. You'll notice a bit of a blur in the following walkthrough, where I fast forwarded the waiting time until the box is created

<video width="100%" controls>
  <source type="video/mp4" src="/images/dev-box-create.mp4">
</video>

In this walkthrough, you see only one possible size configuration, but in the future, more will be available. And you can already predefine a list of VM images that could be used by developers, a topic I hope to dive into in the upcoming weeks.

## The details: Setup

Setting up the whole environment so that developers can create their boxes is a moderately complex process at the moment, but I want to first start with the idea of the three roles or "personas" that Dev Box has: 

1. You have infrastructure admins who have the responsibility to provide - surprise - infrastructure to the dev teams, but also tools. In the Dev Box world, they create everything up to the "projects" and they define the available images. On a side note, I am very thankful that Microsoft didn't call that role anything like "DevOps", which would have been the fancy term straight off the development management bullshit bingo list, but definitely the wrong one.
1. Then "project admins" come into play. They know what tech stack and tooling is required for which project and can set up "dev box pools", so that developers can later create their Dev Boxes. For me, "project admin" is someone who worries about the list of open issues, time recording and maybe sending out invoices, so for me this would be more like the "lead developer" or maybe "technical project manager", but I guess that you have an idea of that group of people.
1. Last but not least, we have the Dev Box users a.k.a. developers. They can create their Dev Boxes as needed, without the help of an IT administrator or anything.

With that in mind, let's take a quick look at what needs to happen before a developer can create such a Dev Box:

- A "Dev center" needs to be created, which is a collection of projects and Dev Box definitions. My expectation would be that those Dev centers map to teams or groups of teams within a development organization.
- In a Dev center, you can create "Dev Box definitions" where you select the base image (standard images or potentially your own, coming from an [Azure Compute Gallery][acg]), the compute and storage resources, and you can also define the network configuration, including the authentication mechanism like Azure AD.
- Also in a Dev center, you define the projects, where you in turn define which boxes are available. You also set up access control on the project level. I would guess that this will be used more as "project type" than as "project", in the sense that I wouldn't expect Dev Box projects to be created for every real life project, but instead the same Dev Box project would be used for similar real life projects.
- In a project, you use "Dev Box pools" to define which Dev Box definitions are available, which network connection they use and who has access. This is the moment where the project admin persona is intended to come into the picture.
- When all of that is in place, the Dev Box users can log in to the developer portal and create their boxes. When that has happened, they can decide to either use the Dev Box directly in the browser or install a new remote desktop app by Microsoft and use that to connect.

In the box itself, you can work in the same way as you would with any other remote connection. The performance is quite good. Everything feels snappy and fast, installing a coupe of things like VS Code or Docker Desktop felt faster than on my laptop and e.g. compiling the Business Central base app takes around 2:15 min on my laptop (Surface Book 3) and only 1:20 min on the Dev Box. The sizing information is not correct as it says in the documentation that 8 Core / 32 GB / 512 GB are available, while in reality it is 8 Core / 16 GB / 1 TB, but in the future there will be more options any way.

So overall, I am quite pleased with my first impression of Dev Boxes and will try to figure out next how the custom image flow works.

[announcement]: https://azure.microsoft.com/en-us/blog/announcing-microsoft-dev-box-preview/
[devbox]: https://docs.microsoft.com/en-us/azure/dev-box/overview-what-is-microsoft-dev-box
[build]: https://www.youtube.com/watch?v=yDnmj1kh_TY
[acg]: https://docs.microsoft.com/en-us/azure/virtual-machines/azure-compute-gallery