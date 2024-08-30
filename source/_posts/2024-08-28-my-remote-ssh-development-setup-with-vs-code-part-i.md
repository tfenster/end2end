---
layout: post
title: "My remote (SSH) development setup with VS Code, part I"
permalink: my-remote-ssh-development-setup-with-vs-code-part-i
date: 2024-08-28 21:21:40
comments: false
description: "My remote (SSH) development setup with VS Code, part I"
keywords: ""
image: /images/remote-dev-shortcut.png
categories:

tags:

---

## The TL;DR

My development workflow depends a lot on the technology I use. E.g. when working with BC, I use [COSMO Alpaca][alpaca] with a local [VS Code][vsc] instance. But for other tech stacks, e.g. .NET or TypeScript, I am a big fan of [development containers][devcontainers] in [VS Code][vsc-dc]. As Windows is my main OS, this means that I use [Docker Desktop][dd] with the [WSL2 backend][wsl2], and as my laptop tends to already be near its limits with Teams, Office and other things I need for day-to-day work, I run this on an Azure VM and connect via SSH. Fortunately, this is extremely well supported by [Remote development over SSH in VS Code][vsc-ssh]. My only small issue was that I had to find the VM in the (excellent) [Azure Virtual Machines extension][azvm-ext], start it and then connect via SSH. All done quite easily with a few clicks, but I wanted to optimize it a bit more as I always have to do this for the same VM. So I built a little extension (to be published when part 2 of this blog post comes out) to streamline my process. It allows me to run a single command in VS Code that will start my configured dev VM - if it's not already running - and launch a remote SSH instance of VS Code on that VM. Here is what it looks like:

<video width="100%" controls="" class="centered">
  <source type="video/mp4" src="/images/remote-dev-shortcut-1.mp4" />
</video>

## The details: Configuring the target dev VM in VS Code

You may be wondering why I didn't have to select which VM to start and use for the remote SSH session. Because I typically use the same VM for an extended period of time, my extension takes a subscription, resource group and VM name as configuration. You can enter this information manually, but you can also use the "Remote dev shortcut: Select as dev VM" command, which will open a VM picker and populate the configuration with the correct information. Alternatively (and only if you have also installed the optional Azure Virtual Machines extension mentioned above), you can also do this from the right-click menu of the VM:

![remote-dev-shortcut-1](/images/remote-dev-shortcut-1.png)
{: .centered}

In both cases, you will end up with something like this in your settings

![remote-dev-shortcut-2](/images/remote-dev-shortcut-2.png)
{: .centered}

As you can see, next to the three settings already mentioned above, you can also configure an "Ssh Host Name" which corresponds to the name you might use in your SSH config file if you have special settings. In my case, I have the following to set up the user and SSH key to use

{% highlight yaml linenos %}
Host devtfe-24
  HostName devtfe-24.germanywestcentral.cloudapp.azure.com
  User azuretfenster
  IdentityFile c:\users\tfenster\.ssh\id_azure
{% endhighlight %}

Hence, I also need to set "devtfe-24" as Ssh Host Name in the settings.

## The details: Starting the VM and a remote session in VS Code

When the start command is executed, it looks for the configuration explained above, finds the VM and checks if it is already running. The simplified code to get the VM and possibly start it looks like this:

{% highlight TypeScript linenos %}
const config = vscode.workspace.getConfiguration('remote-dev-shortcut');
const subscriptionName = config.get<string>('subscriptionName');
const resourceGroupName = config.get<string>('resourceGroupName');
const vmName = config.get<string>('vmName');
const subscriptions = await ext.rgApi.appResourceTree.getChildren();
const subscription = subscriptions.find(s => s.subscription.subscriptionDisplayName === subscriptionName);
if (subscription === undefined) {
    showErrorAndLog(`Could not find subscription "${subscriptionName}". Make sure it appears in the Azure Resources extension.`);
    return;
}
const computeClient: ComputeManagementClient = await createComputeClient([context, subscription.subscription]);
const vm = await computeClient.virtualMachines.get(resourceGroupName, vmName, { expand: 'instanceView' });
const running = vm.instanceView?.statuses?.find(s => s.code === 'PowerState/running') !== undefined;
if (running) {
    ext.outputChannel.appendLog(`"${vm.name}" is already running.`);
} else {
    showInfoAndLog(`Starting "${vm.name}"...`);
    await computeClient.virtualMachines.beginStartAndWait(resourceGroupName, vm.name!);
    showInfoAndLog(`"${vm.name}" has been started.`);
}
{% endhighlight %}

You can find the full code with error checking and a bit more structure [here][vm.ts]. As you can see in line 5, I use an external API, which is published by the [Azure Resources VS Code extension][ar-ext]. With that, I can just reuse the authentication and resource listing provided by that extension.

## The details: Stopping the VM

As a running VM costs more money than a stopped VM in Azure, I also added a simple command to stop it. You can just call "Remote dev shortcut: Stop SSH host" and it will stop the configured dev VM if it is running.

## The details: Next part

In the next part, I will explain a bit more how I set up my dev VM and how I work around an issue with Docker Desktop. Stay tuned!

[alpaca]: https://www.cosmoconsult.com/cosmo-alpaca/
[devcontainers]: https://containers.dev/
[vsc]: https://code.visualstudio.com/
[dd]: https://www.docker.com/products/docker-desktop/
[wsl2]: https://docs.docker.com/desktop/wsl/
[vsc-dc]: https://code.visualstudio.com/docs/devcontainers/containers
[vsc-ssh]: https://code.visualstudio.com/docs/remote/ssh-tutorial
[azvm-ext]: https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-azurevirtualmachines
[vm.ts]: https://github.com/tfenster/remote-dev-shortcut/blob/16756103270ba5a66ac81fed099ec12ae122f4c9/src/vm.ts
[ar-ext]: https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-azureresourcegroups