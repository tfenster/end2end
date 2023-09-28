---
layout: post
title: "Easily access files in your containers"
permalink: easily-access-files-in-your-containers
date: 2023-09-07 19:56:39
comments: false
description: "Easily access files in your containers"
keywords: ""
image: /images/fe.png
categories:

tags:

---

This is a little "service post" where I want to show you three ways how to easily interact with the file system of your container, mainly driven by the relatively new [file explorer][fe] built into [Docker Desktop][dd], but I also want to show you alternatives.

## The TL;DR
In my opinion, it's pretty simple: If you need a user-friendly, easy-to-use, general-purpose solution, go with Docker Desktop. It comes with a straightforward file explorer that you will feel right at home with, and it does what you want. Alternatively, you can use the [VS Code Docker extension][vsc], but it e.g. can't put new files into your container and doesn't show you what has changed. If you're working with [COSMO Alpaca][ca] for [Microsoft Dynamics 365 Business Central][bc] containers, then that also comes with a great solution, but it only works for that scenario.

## The details: Docker Desktop file explorer
As a demo scenario, I'll use a simple [NGINX][n] container, so to start it, I just do `docker run -p 8080:80 nginx`. Once started, I can access the default NGINX starting page at [http://localhost:8080](http://localhost:8080).

![Screenshot of the standard NGINX starting page](/images/fe1.png)
{: .centered}

Now let's got to the Docker Desktop container list and select the container that I just created. This will open the log view directly, but I can also go to the "files" tab to open the file explorer.

![Screenshot of the file explorer, showing a "modified" tag at /etc](/images/fe2.png)
{: .centered}

Here you can see one of the nice features: I can immediately spot that the `/etc` folder has been modified. This means that since startup, a file in that folder has either been added or modified. If I expand this folder and sort it by "Note" to make it easier to check, I can see that the `/etc/hosts` file has been added and the `/etc/nginx` subfolder also has modifications.

![Screenshot of the file explorer showing an "added" tag at /etc/hosts and "modified" tag at /etc/ngnix](/images/fe3.png)
{: .centered}

If I go to `/usr/share/nginx/html`, I can find the file `index.html`. Double-clicking it opens the internal editor and I can modify the file. For example, I can replace the entire body with my own text and save it, which will cause the file and its parent folders to all get the "modified" tag.

![Screenshot of the file explorer showing the replaced content of index.html and the "modified" tags](/images/fe4.png)
{: .centered}

Of course, when I now reload [http://localhost:8080][http://localhost:8080], it shows the changed content

![Screenshot of the changed NGINX home page](/images/fe5.png)
{: .centered}

With a right click in the file explorer, I can also launch the editor, delete files and folders, or get files from the container to the host ("Save") or from the host to the container ("Import"). Nice and simple, works as expected!

## The details: VS Code Docker extension file access

If you are coding in VS Code, using the Docker extension can also be an option as it is directly where you are alread. As you can see, it also comes with a "Files" view

![Screenshot of the file tree in the VS Code Docker extension](/images/fe6.png)
{: .centered}

Not surprisingly, editing works quite well here since we are in an editor. I can also copy files from the container to the host, but navigating the tree is much slower than in Docker Desktop, and there are no actions to delete files or copy them from the host to the container, and the feature requests to get that have been closed by the team building the extension. Therefore, the extension is a nice alternative for quick viewing or editing, but it can't compete with the speed and features of Docker Desktop.

## The details: COSMO Alpaca file access

As I mentioned in the beginning, if you happen to work with Business Central containers using COSMO Alpaca, then you have another option. I know, a niche scenario, but the implementation is quite interesting: COSMO Alpaca also comes with a VS Code extension with a list of containers and with a right click, I can can select "Open file share"

![Screenshot of the "open file share" action in the VS Code COSMO Alpaca extension](/images/fe7.png)
{: .centered}

The interesting thing is what happens next: Since this is technically a container running in [AKS][aks], the Alpaca backend can use the API to make this container externally reachable via an IP address. As the container also has an SSH server installed, it can then open an SSH connection and launch a remote instance of VS Code. As a user, I get a new VS Code window with the server component running inside of the container, so we get the full file system in the explorer and can edit, delete, copy in and copy out as needed with great performance.

![Screenshot of the remote VS Code instance showing the file system within the container](/images/fe8.png)
{: .centered}

Of course, you can't see what files are being added or modified because the VS Code server has no idea that it's running inside a container. So overall, this is pretty close to the Docker Desktop file explorer experience, but of course for a very specific target and audience.

I hope this blog post has given you an idea of how you can easily access the files in your containers!

[fe]: https://docs.docker.com/desktop/use-desktop/container/#files
[dd]: https://www.docker.com/products/docker-desktop/
[vsc]: https://code.visualstudio.com/docs/containers/overview
[ca]: https://www.cosmoconsult.com/cosmo-alpaca/
[bc]: https://dynamics.microsoft.com/en-us/business-central/overview/
[n]: https://www.nginx.com/
[aks]: https://learn.microsoft.com/en-us/azure/aks/intro-kubernetes