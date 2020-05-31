---
layout: post
title: "Remote Dev with VS Code against a Windows host is easy now"
permalink: remote-dev-with-vs-code-against-a-windows-host-is-easy-now
date: 2020-04-30 20:22:37
comments: false
description: "Remote dev with VS Code against a Windows host is easy now"
keywords: ""
categories:
image: /images/remote dev.png

tags:

---

I previously wrote about [remote dev][remote-dev] and why I think this might be a game changer. At that time, it was quite a number of burning hoops you had to jump through, but that really has become easier with the VS Code February 2020 release (1.43). I usually look quite closely at the VS Code release notes, but somehow I missed this and only became aware a couple of weeks ago. To quote from the [release notes][release-notes]: 

*Stabilized support for Windows hosts
We have had experimental support for Windows hosts in VS Code Insiders for a few months, but we are now ready to add this support to the VS Code Stable release!*

And stable release really means stable in this case! I have been doing quite some development in the last couple of weeks in different languages and environments: A bit of AL (although starting the browser and debugging unfortunately still needs the workaround explained [here][workaround]), quite a lot[^1] of C# for my Docker / Azure DevOps [automation project][automation] and TypeScript / Node for the accompanying VS Code extension, some Go for Docker and Traefik and a bit of PowerShell / bash here and there. I tend to mess up my local machine with too many SDKs and stuff installed, so I really like having the ability to very smoothly use a development environment somewhere else[^2]. But with the remote dev functionality it becomes a breeze as I just have to select the right host and project and with a simple click I am up and running:

![remote-dev-img](/images/remote dev.png)
{: .centered}

In this blog post, I don't want to cover the setup again as last time, because by now it has become very easy and also very well [documented][documented], but instead explain the setup of an Azure VM for the purpose of acting as a Remote Dev host as this already is documented for Linux, but not for Windows hosts[^3].

## The TL;DR
Just click on the "Deploy to Azure" button below, enter your **public** SSH key and your eMail address (which will be notified before the automated shutdown at 3 am German time) and you should be ready to go. After waiting for approx. 10 minutes, your virtual machine is set up and configured so that you start developing by again following the [documentation][documentation].

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fcosmoconsult%2Fremote-dev%2Fmaster%2Ftemplate.json)
{: .centered}

## A bit more detail
The setup is about as easy as it gets for an Azure VM:

![interface-base](/images/remote dev overview.png)
{: .centered}

You can see the VM, which is connected to the network using a network interface, which in turn is connected to a virtual network, secured by a network security group and reachable from the outside through a public IP address. The virtual machine also has a schedule, which shuts it down at 3 a.m. German time if you don't do something about it. You will get an email half an hour before that (that's why the template is asking for your email address) and can then decide to keep it running. But code written after 3 a.m.[^4] has a tendency to look something in between funny, embarrassing and completely useless at the next day, so if you get this email and are still working, it would probably be a good idea to stop working anyway. The last element is an extension which actually just runs a [script][script] that does the setup of the machine.

It first [installs chocolatey and uses that to install git, vim and OpenSSH][installs-choco]. It then downloads my [SSH daemon config][ssh] which enables key-based authentication and disables password-based authentication. This is also the reason why I am pre-generating a password and don't show it in clear text because password-based authentication will be disabled anyway. The last step is to put the provided SSH public key into the right file in the right folder [folder][] so that public key authentication works with SSH, directly and through the Remote Dev extension. 

The ARM template does a couple of quite opinionated things and if you want to change them, you will need to change the template.json file, most likely somewhere in the [variables][variables] section. Some of those decisions are:

- The VM has the same name as the resource group which also is the label of the DNS name of your VM, so make sure to select something unique
- Auto shutdown and the notification before that are both enabled
- The OS disk is a premium disk, which means fast but more expensive than others
- You can only select a Standard_D2s_v3 (2 CPU / 8 GB RAM / 4000 IOPS), Standard_D4s_v3 (4 / 16 / 8000) or Standard_D8s_v3 (8 / 32 / 16000) size.
- I am using a Windows Server 2019 Core image with Docker pre-installed. If you e.g. want a GUI, you need to change the image.

After the VM has started, you can use chocolatey to easily install whatever toolchain you need, like the [.NET Core SDK][dotnetcore-sdk] or [Node][node]. If the environment for whatever reason breaks, you just run the ARM template again.

Happy coding!

[remote-dev]: https://tobiasfenster.io/remote-development-for-bc-with-vs-code
[release-notes]: https://github.com/microsoft/vscode-docs/blob/master/remote-release-notes/v1_43.md#ssh
[workaround]: https://tobiasfenster.io/debugging-with-remote-development
[automation]: https://twitter.com/tobiasfenster/status/1249094247535558657
[documented]: https://code.visualstudio.com/docs/remote/ssh
[documentation]: https://code.visualstudio.com/docs/remote/ssh#_connect-to-a-remote-host
[script]: https://github.com/cosmoconsult/remote-dev/blob/master/InitVM.ps1
[choco]: https://github.com/cosmoconsult/remote-dev/blob/3d48c06237a9f07aa609f35eb804115410addcda/master/InitVM.ps1#L11,L16
[ssh]: https://github.com/cosmoconsult/remote-dev/blob/master/sshd_config
[variables]: https://github.com/cosmoconsult/remote-dev/blob/master/InitVM.ps1#L38,L81
[dotnetcore-sdk]: https://chocolatey.org/packages/dotnetcore-sdk
[node]: https://chocolatey.org/packages/nodejs-lts
[installs-choco]: https://github.com/cosmoconsult/remote-dev/blob/master/InitVM.ps1#L11,L16]
[folder]: https://github.com/cosmoconsult/remote-dev/blob/master/InitVM.ps1#L18,L21

[^1]: by my standards, most of my work these days is not dev but that actually makes development more fun when I get to do it
[^2]: You know the quote about the Cloud, right? "There is still hardware in the Cloud, it is just owned by someone else and located somewhere else". Which immediately brings me to my favorite explanation about serverless computing: "Serverless doesn't mean that there are no servers, same as using a taxi doesn't mean there's no car". But I am getting sidetracked...
[^3]: Funny how far Microsoft has come :)
[^4]: Written at 2:30...