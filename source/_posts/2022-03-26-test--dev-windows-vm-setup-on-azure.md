---
layout: post
title: "Test / dev Windows VM setup on Azure"
permalink: test--dev-windows-vm-setup-on-azure
date: 2022-03-26 14:29:52
comments: false
description: "Test / dev Windows VM setup on Azure"
keywords: ""
image: /images/remote-ssh.png
categories:

tags:

---

I have written about [remote development][remote-dev] in the past ([1][one], [2][two]), but in the last couple of month and years, I have also had more and more occasions where it just is nice to easily create a test VM on Azure. For both scenarios, setting up key-based SSH is a good idea or even a requirement, but it can be a bit tricky. To solve that and make it very convenient, I have created a quickstart template for a [Windows Server VM with SSH][quickstart]. With only a couple of clicks, you get a test / dev VM and can immediately connect.

## The TL;DR

Here are the steps to get up and running: Click on the [deployment link][deploy], enter the basics (subscription, resource group, region, SKU, VM size and data disk size) and define admin username and SSH key. Then you only need to click on "Review + create" and then "create", wait for approx. five minutes and you are done.

<video width="100%" controls>
  <source type="video/mp4" src="/images/win-ssh.mp4">
</video>

If you are wondering how to set up the SSH key, [here][ssh-key] are the docs on storing it in the Azure portal.

## The details: Using it 

As I already wrote about the basic setup (see above) and it actually is very easy, I want to show a bit more on how I use it instead of how it is created:

For a VM that I plan to use longer or for VS Code remote, I create an entry in my SSH config file, which by default is in your home folder, subfolder `.ssh`, file `config`. As you have seen, the hostname is randomly generated, so I give it a name that is easier to remember and because I tend to be not very consistent with the username (sometimes `vmadmin`, sometimes `vmadministrator`, sometimes `tfenster` and more...), I also enter that as well. So an entry for the config file could look like this

{% highlight yaml linenos %}
Host ssh-vm
  HostName winssh-aroeeg4rupu2i.northeurope.cloudapp.azure.com
  User vmadmin
{% endhighlight %}

With that in place, I can just use `ssh ssh-vm`. Now, because I tend to even forget that, I also set up a [Windows Terminal][terminal] [profile][profile]. In this example, I would put "ssh-vm" as name and `ssh ssh-vm` as command. Afterwards, I can just use the dropdown when creating a new tab in the terminal and be immediately connected.

![Screenshot of Terminal profiles](/images/terminal-profile.png)
{: .centered}

And VS Code also automatically picks up the SSH config file, so using it for remote dev is also very easy.

![Screenshot of VS Code remote dev SSH targets](/images/remote-ssh.png)
{: .centered}

I hope this little time saver helps you to become more productive.

[one]: https://tobiasfenster.io/remote-dev-with-vs-code-against-a-windows-host-is-easy-now
[two]: https://tobiasfenster.io/remote-development-for-bc-with-vs-code
[remote-dev]: https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.vscode-remote-extensionpack
[quickstart]: https://azure.microsoft.com/en-us/resources/templates/vm-windows-ssh/
[deploy]: https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2Fquickstarts%2Fmicrosoft.compute%2Fvm-windows-ssh%2Fazuredeploy.json/createUIDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2Fquickstarts%2Fmicrosoft.compute%2Fvm-windows-ssh%2FcreateUiDefinition.json
[terminal]: https://docs.microsoft.com/en-us/windows/terminal/
[profile]: https://docs.microsoft.com/en-us/windows/terminal/customize-settings/profile-general
[ssh-key]: https://docs.microsoft.com/en-us/azure/virtual-machines/ssh-keys-portal