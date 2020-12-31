---
layout: post
title: "Creating a Windows Docker Swarm on Azure using Terraform, part I"
permalink: creating-a-docker-swarm-on-azure-using-terraform-part-i
date: 2020-08-29 14:12:38
comments: false
description: "Creating a Windows Docker Swarm on Azure using Terraform, part I"
keywords: ""
categories:
image: /images/terraform-azure-swarm.png

tags:

---

This post has taken a very long time. Two years and one day ago I wrote about [Windows authentication in Docker Swarm][win-auth-swarm] and nine months[^1] ago I showed a Docker Swarm at [NAV TechDays][techdays]. However, I was not completely happy with my setup and — as is probably true with every tech project — there still is room for improvement, but I am satisfied enough with it to share it. Also, we have been using a Swarm created with what am sharing today for a couple of months now and it works well, so that probably is a good sign.

## The TL;DR
[Docker Swarm][docker-swarm] is the container orchestrator provided by Docker itself and allows you to bring multiple virtual[^2] machines together to form a cluster called “swarm” on which you can run Docker containers. By using [Azure Virtual Machine Scale Sets][az-vmss] in the background, I can very easily add and remove machines (or “nodes”) to and from that swarm or even let it [auto-scale][auto-scale]. To automate the deployment, I have used [Terraform][terraform][^3], an Infrastructure as Code (IaC) tool which allows me to define the Azure infrastructure I need, run `terraform apply`, wait a bit and then have my swarm up and running. The whole architecture is a bit more complex as it also includes among others an [Azure Files][az-files] share, an [Azure Load Balancer][az-lb] and an [Azure Key Vault][az-kv], but overall, that's it. I am assuming that whoever uses this will want to expose something over the web and some kind of management interface for the swarm should come in handy, so I have by default added [Traefik][traefik] as reverse proxy and [Portainer][portainer] as container management interface.

To just use it as is, do the following:
- Prereqs: 
  - Make sure you have the [Azure CLI][azure-cli] [installed][azure-cli-install] as well as [Terraform][tf-install].
  - Make sure you have a public SSH key available in `$HOME\.ssh\id_rsa.pub` as this will be uploaded. If you don't have one, you can follow the instructions [here][ssh] to create one. Note that the documentation talks about Linux VMs, but it works with the Windows VMs in my setup as well.
- Run `git clone https://github.com/cosmoconsult/azure-swarm` to get my setup
- Open the file `variables.tf` in subfolder `tf` and change the default value for the variable `eMail` to your eMail address.
- Open a cmd or PowerShell and go to the `tf` subfolder
- Run `az login` to log in to your Azure account
- If you have multiple subscriptions, you can run `az account set --subscription="<subscription-id>"` to select the one you want to use
- Run `terraform init` to initialize Terraform
- Run `terraform apply -auto-approve` to create the infrastructure

After a couple of minutes, you should see something like this:

{% highlight none linenos %}
Apply complete! Resources: 47 added, 0 changed, 0 destroyed.

Outputs:

password = 2kwVQZlc2xOj%cfL
portainer = https://swarm-bbzavtmk.westeurope.cloudapp.azure.com/portainer/
ssh-copy-private-key = If you know what you are doing (this is copying your PRIVATE ssh key): ssh -l VM-Administrator swarm-bbzavtmk-ssh.westeurope.cloudapp.azure.com "mkdir c:\users\VM-Administrator\.ssh"; scp $HOME\.ssh\id_rsa VM-Administrator@swarm-bbzavtmk-ssh.westeurope.cloudapp.azure.com:c:\users\VM-Administrator\.ssh
ssh-to-jumpbox = ssh -l VM-Administrator swarm-bbzavtmk-ssh.westeurope.cloudapp.azure.com
{% endhighlight %}

If you go to the URL provided in line 6 (it will be different when you do it because the eight letters after `swarm-` are random) and enter `admin` as username with the password on line 5 (of course that will also be different on your machine), then you have the admin interface of portainer which should show your swarm with three manager nodes and two worker nodes. 

## The details: The base components and overall architecture
I don't want to introduce you to the base components that I used because each of them provides very good documentation:

- Docker gives an introduction to the [key concepts of a Swarm][swarm-key]
- Getting an overview of Azure is a bit of a daunting task because of the sheer size of it but you can find good overviews of the components that I mainly used above
- Terraform has a very good [intro][tf-intro] to give you an idea and then you can check out the information and examples for the Azure provider either [by Terraform][az-terraform] or [by Microsoft][az-terraform2]
- Traefik has a very nice [documentation][traefik-docs] to get you started quickly
- Portainer actually is a bit thin on the [documentation][portainer-docs] side, but very intuitive to use

The simplified overview looks like this:

![swarm-full](/images/swarm-full.png)
{: .centered}

Sorry, I could not resist showing this :) Of course this isn't a simplified overview but rather the full setup visualized with the great [ARM Template Viewer][arm-viewer]. Now for a really simplified overview:

![swarm-overview](/images/swarm-overview.png)
{: .centered}

You can see that I am using a jumpbox for administrative access, which means that I have a dedicated VM to get access to the terminal on any of the involved virtual machines because none of them can be directly reached. This is a security measure to make it harder for attackers to get access to the system. As a most basic but also most efficient way to secure your environment, you can shut down the jumpbox when it isn't needed and then there literally is no direct way to any of the machines. To further improve the security setup, the jumpbox can only be reached using SSH with a private/public key combination. As part of the Terraform deployment, your public key is uploaded into the Azure Key Vault and when the jumpbox starts, it downloads the key from the Vault and puts it into the right place, so that when you later try to connect using your private key, it's as easy as using the `ssh-to-jumpbox` command shown in line 8 above to connect without having to specify a password. That also means that no one can guess or brute force your password...

![swarm-overview](/images/swarm-ssh.gif)
{: .centered}

If you need help setting up the SSH keys, check out [Microsoft's documentation on OpenSSH key management][msft-openssh-key]. In the overview above you can also see that an Azure Load Balancer is used to balance web traffic coming in to the swarm. The load balancer is connected to three manager VMs, but more on that later. The swarm also is connected to the Azure Key Vault to manage swarm join tokens. Those are secrets that are needed to join the swarm. The first manager initializes the swarm and stores those tokens in the Vault, the other nodes get them from there. This is done without passwords but instead the VMs are assigned a managed identity which in turn gets read access (or read and write in the case of the first manager) to the Vault. The last component you can see is the Azure Files share which is mounted as drive to all VMs except the jumpbox and stores configuration files etc. which are relevant for all swarm nodes. The swarm itself looks like this:

![swarm-overview](/images/swarm-detail.png)
{: .centered}

It seems a bit on the nose but Docker Swarm has managers who control and — surprise — manage the services running in th swarm where every service has 1-n tasks which are the containers. And there are workers in a Docker Swarm where the payload containers, the ones doing the actual work, are running. 

The managers are three separate Azure Virtual Machines which are part of an availability set and are all addressed by the load balancer. For a variety of reasons which I'll explain later, I didn't find a good way to use an Azure Virtual Machine Scale Set for this part although theoretically it would make a lot of sense. Because of the way Docker Swarm ingress networking works, it doesn't matter on which of those managers Traefik, the reverse proxy, is running, it always gets the incoming requests. It then takes them and forwards them to the right containers running on the workers, which are an Azure Virtual Machine Scale Set. This matters because it literally brings us a slider to scale the number of VMs in the scale set. Doesn't get a lot easier than that, right?

![swarm-overview](/images/vmss-scale.png)
{: .centered}

Portainer is also running on one of the managers because swarm management is only possible there.

With that I hope you got a good overview of my setup. In a following post, I'll explain more about the technical details, configurations and scripts.

[win-auth-swarm]: https://www.axians-infoma.de/techblog/windows-authentication-in-docker-swarm/
[techdays]: https://www.youtube.com/watch?v=Dr6bFoRELnY
[docker-swarm]: https://docs.docker.com/engine/swarm/
[az-vmss]: https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/overview
[az-files]: https://docs.microsoft.com/en-us/azure/storage/files/storage-files-introduction
[az-kv]: https://docs.microsoft.com/en-us/azure/key-vault/general/overview
[az-lb]: https://docs.microsoft.com/en-us/azure/load-balancer/load-balancer-overview
[auto-scale]: https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/tutorial-autoscale-cli
[terraform]: https://www.terraform.io 
[tf-intro]: https://www.terraform.io/intro/index.html
[az-terraform]: https://www.terraform.io/docs/providers/azurerm/index.html
[az-terraform2]: https://docs.microsoft.com/en-us/azure/developer/terraform/overview
[traefik]: https://traefik.io/
[portainer]: https://www.portainer.io/
[swarm-key]: https://docs.docker.com/engine/swarm/key-concepts/
[traefik-docs]: https://docs.traefik.io/
[portainer-docs]: https://www.portainer.io/documentation/
[azure-cli]: https://docs.microsoft.com/en-us/cli/azure/what-is-azure-cli?view=azure-cli-latest
[azure-cli-install]: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?view=azure-cli-latest&tabs=azure-cli
[tf-install]: https://learn.hashicorp.com/tutorials/terraform/install-cli
[ssh]: https://docs.microsoft.com/en-us/azure/virtual-machines/linux/ssh-from-windows#create-an-ssh-key-pair
[msft-openssh-key]: https://docs.microsoft.com/en-us/windows-server/administration/openssh/openssh_keymanagement
[arm-viewer]: https://marketplace.visualstudio.com/items?itemName=bencoleman.armview
[^1]: It actually feels like way longer but without a lot of experience, I would guess that pandemics have that effect
[^2]: or physical, if anyone is still doing that
[^3]: or to be precise, mostly the [Azure Provider][az-terraform] for Terraform, also [documented by Microsoft][az-terraform2]