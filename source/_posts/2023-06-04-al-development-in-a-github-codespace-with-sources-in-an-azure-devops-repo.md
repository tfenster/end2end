---
layout: post
title: "AL development in a GitHub Codespace with sources in an Azure DevOps repo"
permalink: al-development-in-a-github-codespace-with-sources-in-an-azure-devops-repo
date: 2023-06-04 10:45:49
comments: false
description: "AL development in a GitHub Codespace with sources in an Azure DevOps repo"
keywords: ""
image: /images/al-codespace.png
categories:

tags:

---

[GitHub Codespaces][codespaces] and the underlying technology of [Visual Studio Code devcontainers][devcontainers] are a real game changer when it comes to development efficiency and velocity. I've been using them as much as possible for the past few years and really love them, but there are two restrictions that have made them difficult to use for Microsoft Dynamics 365 Business Central development: Devcontainers are generally limited to Linux, and GitHub Codespaces are limited to GitHub repos (or so I thought). Over the last few days, I've learned that the Linux limitation actually matters less for AL development than I thought and the GitHub repo limitation doesn't really exist.

## The TL;DR

In the end, I have a GitHub Codespace connected to an Azure DevOps repo and I can debug (against a [COSMO Alpaca][alpaca] development container in this demo, but that could also be something else):

<video width="100%" controls="">
  <source type="video/mp4" src="/images/al-codespace.mp4" />
</video>

As you can see, debugging against the Customer List via a .dal file works fine, so with a breakpoint set in code where I only have the symbols in this workspace. Unfortunately, for my own Customer List page extension, for which I have the sources in my workspace, debugging fails. Let's see, maybe someone in the community or I myself might find a workaround.

Two important things to mention:

- This is totally unsupported by Microsoft. I hope they will come up with official support for this scenario soon, but for now it is just a workaround.
- I just put together existing pieces, so I basically don't deserve any credit for creating the solution, just for combining them. [Stefan Maron][stefan] has figured out a way to patch the [AL Language extension][al-extension] with his [AL Language Linux patcher][al-patcher] to make it work in Linux, and [Mark Phippard][mark] created a Codespace feature to [use external repositories][ext-rep], especially from Azure DevOps.

All credit and honor to them!

## The details: First step - AL in a local devcontainer

The first step is to create a local devcontainer for AL development, using [Docker Desktop][dd] with the [WSL backend][wsl]. This is the most convenient way to use local devcontainers. Here are the steps:

1. To keep it as simple as possible for now, I used the "AL: Go!" command in VS Code to create a trivial sample project
2. Then I added the right devcontainer configuration with the "Dev Containers: Add Dev Container Configuration Files" command, then selecting "C# (.NET) devcontainers" as configuration and "6.0" as .NET version.
3. VS Code now recognizes that I have a devcontainer configuration and offers to "Reopen in Container", which I did.
4. For AL development, we of course need the [AL Language extension][al-extension] and to make this part of my devcontainer setup, I searched for it and instead of installing it directly, I right-clicked and selected "Add to devcontainer.json", which adds it to the configuration file.
5. Since we need to patch if for Linux use, I did the same with Stefan's [AL Language Linux patcher][al-patcher] extension. As the extension has a default path for dotnet (which it uses behind the scenes to make the AL Language extension work on Linux) of `/bin/dotnet`, but the C# devcontainer has it in `/usr/bin/dotnet`, it doesn't work right away, but fortunately Stefan has made this path configurable, so I just had to add the following setting to our devcontainer configuration: `"allanguagelinuxpatcher.dotnet-path": "/usr/bin/dotnet"`
6. VS Code recognizes that the devcontainer configuration has changed, so it offers to rebuild the container, which I did, then ran the "Patch current AL Language extension" command and after VS Code reloaded, I could open `HelloWorld.al` and see the project loaded and the extension complaining about missing symbols.
7. After setting up a `launch.json` config as usual, you can download symbols and work with the extension! (Only breakpoints won't be hit correctly as mentioned above, because the AL Language extension seems to have hardcoded backslashes as separators and in my example looks for `\workspaces\ALProject1\HelloWorld.al` instead of `/workspaces/ALProject1/HelloWorld.al` as would be correct on Linux)

In the end, my devcontainer configuration file `devcontainer.json` looks like this

{% highlight JSON linenos %}
{
	"name": "C# (.NET)",
	"image": "mcr.microsoft.com/devcontainers/dotnet:0-6.0",
	"customizations": {
		"vscode": {
			"extensions": [
				"ms-dynamics-smb.al",
				"StefanMaron.allanguagelinuxpatcher"
			],
			"settings": {
				"allanguagelinuxpatcher.dotnet-path": "/usr/bin/dotnet"
			}
		}
	}
}
{% endhighlight %}

You can see the default .NET 6.0 base image (line 3), the extensions to install (lines 7 and 8) and the config setting (line 11). Building on top of the great work of Stefan, it was quite easy :)

## The details: Second step - use it in a GitHub Codespace

GitHub Codespaces are very similar to local devcontainers, the only difference being that they run "somewhere in the Cloud". So using our current setup in a Codespace is actually quite simple:

1. Initialize a git repository and set up `.gitignore` properly, if you want
2. Use the "Publish to GitHub" command in VS Code
3. Open the created repository
4. Click on the green "Code" button and create a Codespace.

This left me in the same place as in step 6 above: Inside a devcontainer with the required extensions and settings, only this time not running locally, but in a Codespace. I could patch the extension, create a `launch.json` config and get started!

If you want to check out the full result, you can find it at [https://github.com/tfenster/al-codespace](https://github.com/tfenster/al-codespace).

## The details: Third step - use an Azure DevOps repository

Most of the BC partners that I know and all the companies that I've worked for have used Azure DevOps repositories for their source code, not GitHub. I don't want to get into a debate about which is better, but my personal preference is clear :) So I was actually a bit annoyed that GitHub Codespaces couldn't be used for Azure DevOps repositories. Fortunately, I recently found Mark's great Codespace feature, which allows you to easily set up a Codespace with a connection to any external Git repository, and Azure DevOps repositories are particularly well supported. The idea is that you have a "shadow" repository in GitHub with the Codespace configuration pointing to the Azure DevOps repo. The latter is checked out as soon as the codespace is created, so you can start working with it. I'll skip the part about the Azure DevOps repository itself, because it doesn't need anything special, and the shadow repository in GitHub is extremely simple as well:

1. Create the repository and follow the [Example Usage Scenarios][example] from Mark's GitHub repo
2. Adjust it with the relevant parts of our devcontainer configuration above as well as the correct clone URL ([https://dev.azure.com/demo-codespaces/al-demo/_git/al-demo-app][https://dev.azure.com/demo-codespaces/al-demo/_git/al-demo-app] in my case, which is publicly visible, if you want to take a look)
3. Create a Codespace secret with a PAT with read access to the Azure DevOps repo as explained in the usage scenario doc mentioned in 1.
4. Do the same as above by clicking on the green "Code" button and creating a Codespace. You will be promoted to log in and from then on, you can work in the Codespace as expected!

The new `devcontainer.json` file looks like this:

{% highlight JSON linenos %}
{
    "name": "C# (.NET)",
    "image": "mcr.microsoft.com/devcontainers/dotnet:0-6.0",
    "features": {
        "ghcr.io/microsoft/codespace-features/external-repository:latest": {
            "cloneUrl": "https://dev.azure.com/demo-codespaces/al-demo/_git/al-demo-app",
            "cloneSecret": "ADO_PAT",
            "folder": "/workspaces/al-demo-app"
        }
    },
    "customizations": {
		"vscode": {
			"settings": {
				"allanguagelinuxpatcher.dotnet-path": "/usr/bin/dotnet"
			},
			"extensions": [
				"ms-dynamics-smb.al",
                                "StefanMaron.allanguagelinuxpatcher"
			]
		}
	},
    "workspaceFolder": "/workspaces/al-demo-app",
    "initializeCommand": "mkdir -p ${localWorkspaceFolder}/../al-demo-app",
    "onCreateCommand": "external-git clone",
    "postStartCommand": "external-git config"     
}
{% endhighlight %}

You'll recognize a lot of the configurations we used before, but it also has the `external-repository` feature and configuration (lines 5-9) to use the Azure DevOps repository as well as some specific configurations (lines 22-25) to make it work. But actually it's not that difficult and with that, we have a GitHub Codespace with a (mostly) working AL extension connected to an Azure DevOps repository!

If you find a way how to work around the debugging problem or have other ideas for improvement, please reach out.

[codespaces]: https://docs.github.com/en/codespaces/overview
[devcontainers]: https://code.visualstudio.com/docs/devcontainers/containers
[alpaca]: https://cosmoconsult.com/cosmo-alpaca
[stefan]: https://stefanmaron.com/
[al-extension]: https://marketplace.visualstudio.com/items?itemName=ms-dynamics-smb.al
[al-patcher]: https://marketplace.visualstudio.com/items?itemName=StefanMaron.allanguagelinuxpatcher
[mark]: https://github.com/markphip
[ext-rep]: https://github.com/microsoft/codespace-features/tree/main/src/external-repository
[dd]: https://www.docker.com/products/docker-desktop/
[wsl]: https://docs.docker.com/desktop/windows/wsl/
[example]: https://github.com/microsoft/codespace-features/tree/main/src/external-repository#example-usage-scenarios