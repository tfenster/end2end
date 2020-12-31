---
layout: post
title: "Creating a Windows Docker Swarm on Azure using Terraform, part II"
permalink: creating-a-windows-docker-swarm-on-azure-using-terraform-part-ii
date: 2021-01-05 09:00:00
comments: false
description: "Creating a Windows Docker Swarm on Azure using Terraform, part II"
keywords: ""
categories:
image: /images/terraform-azure-swarm.png

tags:

---

It's been a while, but in [part one][one] of this post series, I have explained the overall architecture and approach to create a Windows [Docker Swarm][docker-swarm] on Azure using [Terraform][terraform], preloaded with [Portainer][portainer] and [Traefik][traefik]. In this second part, I want to dig deeper into the Terraform setup as well as the configuration files used to make this happen.

## The TL;DR
I assume that you have some basic knowledge about Terraform, but if not, you might want to read the very good [intro][tf-intro] to give you an idea. Also, if you don't know the Azure Provider for Terraform, you might want to take a look at the [documentation by Terraform][az-terraform] or the [documentation by Microsoft][az-terraform2]. With that, you should be able to understand the following files:

- Basics: [variables][variables.tf] and [common][common.tf] things
- Shared infrastructure: [storage][storage.tf], [load balancer][loadbalancer.tf] and [jumpbox][jumpbox.tf]
- The actual Docker Swarm: [managers][managers.tf] and [workers][workers.tf]

This gets the infrastructure in place. Then, using some scripts that I'll introduce in part three of the post series, the [OpenSSH server][openssh] is set up and configured on the jumpbox with a [passwordless config file][sshd_config_wopwd] as you shouldn't be able to connect to an externally reachable machine using a password. The managers and workers have an [SSH config file that allows password access][sshd_config_wpwd] as those machines are only reachable through the jumbpox.

The last section for now is the [Docker Compose][docker-compose] [config file][docker-compose.yml.template] that takes care of deploying [Traefik][traefik], [Portainer][portainer] and the Portainer agent.

## The details about deploying the infrastructure with Terraform: Variables and common things
I can't go through each and every line of all the Terraform files because that would be an extremely long blog post[^1] and a lot of it is quite trivial, but I'd like to point out a couple of special things:

In the [variables.tf][variables.tf] file, a local called `name` is set up, which is used as prefix for almost all resources. It is generated using another prefix which defaults to `swarm` but can be overridden by something else if you want your resources to start differently. It also has a random part which makes sense if you deploy the infrastructure fully or partially automated and often, so you don't have to worry about naming conflicts. But if you want a more speaking name, you can change that part easily. This is what the setup in the variables file looks like:

{% highlight hcl linenos %}
variable "prefix" {
  description = "Prefix for all names"
  default     = "swarm"
}

locals {
  name = "${var.prefix}-${random_string.name.result}"
}
{% endhighlight %}

The random string is defined in the [common.tf][common.tf] file like this, including the `random` provider that we need to reference to use this functionality and the output so that we can get the password in the end:

{% highlight hcl linenos %}
provider "random" {
  version = "=2.3.0"
}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "_%@"
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
  min_upper        = 1
}

output "password" {
  value = random_password.password.result
}
{% endhighlight %}

If you forget to copy the password and store is somewhere safe, you can always run `terraform output` to get the output again. But to get back to the `name` local: If you want to only change the prefix, you can add your own .tfvars file to override that. For example, if you want to use a prefix of `cluster` instead of `swarm`, you would put this into e.g. a file vars.tfvars:

{% highlight hcl linenos %}
prefix = "cluster"
{% endhighlight %}

If you then do a `terraform apply -var-file vars.tfvars`, it will pick up the variable definition from the .tfvars file and your prefix is changed. You also find other configuration options like the Azure region to use (variable `location`) or more complex variables like the size and SKU settings for the VMs (e.g. variable `workerVmssSettings`). They should have a description to explain what they are doing, and you can also override the settings. E.g. this is the default for the worker configuration

{% highlight hcl linenos %}
variable "workerVmssSettings" {
  description = "The Azure VM scale set settings for the workers"
  default = {
    size       = "Standard_D8s_v3"
    number     = 2
    sku        = "2019-datacenter-core-with-containers"
    version    = "17763.1158.2004131759"
    diskSizeGb = 1024
  }
}
{% endhighlight %}

Let's say you are fine with most of it but want to have 4 workers and use a 2004 Windows Server. In that case, you could do something like this in your .tfvars file

{% highlight hcl linenos %}
workerVmssSettings = {
    number     = 4
    sku        = "datacenter-core-2004-with-containers-smalldisk"
    version    = "latest"
}
{% endhighlight %}

This would give you four instead of two workers and use the 2004 image instead of the 2019 (1809) one.

You will also find many variables referencing additional scripts, but that will be explained in the next part of the blog post series. In the [common.tf][common.tf] file you can also find the Azure resource group, the virtual network and the Azure key vault, but those have no special configuration. The only thing here worth mentioning is that a public key is searched in the standard location (`~/.ssh/id_rsa.pub`) and uploaded to the key vault, so if you store your public key in a non-standard location, you have to change this part

{% highlight hcl linenos %}
resource "azurerm_key_vault_secret" "sshPubKey" {
  name         = "sshPubKey"
  value        = file(pathexpand("~/.ssh/id_rsa.pub"))
  key_vault_id = azurerm_key_vault.main.id
}
{% endhighlight %}

## The details about deploying the infrastructure with Terraform: Shared components
Some components of the infrastructure are shared between the others: Storage in [storage.tf][storage.tf], the Azure load balancer in [loadbalancer.tf][loadbalancer.tf] and the jumpbox in [jumpbox.tf][jumpbox.tf]. All of that is fairly straightforward as well, just a couple of things to mention:

The jumpbox has two security rules, one to open up for SSH traffic and one to explicitely deny RDP traffic. The second one is in place if for whatever reason SSH fails and you want to have a fallback. Then you can simply go to the network configuration in the Azure portal and change that rule from `deny` to `allow`.

{% highlight hcl linenos %}
resource "azurerm_network_security_rule" "ssh" {
  name                        = "sshIn"
  network_security_group_name = azurerm_network_security_group.jumpbox.name
  resource_group_name         = azurerm_resource_group.main.name
  priority                    = 300
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
}

resource "azurerm_network_security_rule" "rdp" {
  name                        = "rdpIn"
  network_security_group_name = azurerm_network_security_group.jumpbox.name
  resource_group_name         = azurerm_resource_group.main.name
  priority                    = 310
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
}
{% endhighlight %} 

The jumpbox also needs to download the SSH public key from the Azure key vault and for that, it needs the `Get` permission. This is done with a `azurerm_key_vault_access_policy` which references the key vault and the principal of the VM. This means that we can later get access to the key vault in one of the scripts.

{% highlight hcl linenos %}
resource "azurerm_key_vault_access_policy" "jumpbox" {
  key_vault_id = azurerm_key_vault.main.id
  object_id    = azurerm_windows_virtual_machine.jumpbox.identity.0.principal_id

  secret_permissions = [
    "Get"
  ]
  ...
}
{% endhighlight %}

For the load balancer, I want to mention a mechanism which is used in other places as well to make a resource "conditional". This is currently not possible straightforward in Terraform with something like an `enabled` flag. The workaround is to the `count` property which is intended to be used for deploying multiple resource with the same configuration. In this case, I am setting the count either to 1 or to 0, essentially making it an optional component. I have a variable called `managerVmSettings.useThree` which configures if you have one or three managers (three is preferable as it gives you fault tolerance, but for a simple dev or test scenario, one might be enough). If that variable is true, the count is 1. If it is false, the count is 0. For this, we can conveniently use a ternary if, e.g. for the association of the second manager to the backend address pool of the load balancer:

{% highlight hcl linenos %}
resource "azurerm_network_interface_backend_address_pool_association" "mgr2" {
  count                   = var.managerVmSettings.useThree ? 1 : 0
  network_interface_id    = azurerm_network_interface.mgr2.0.id
  ip_configuration_name   = "static-mgr2"
  backend_address_pool_id = azurerm_lb_backend_address_pool.main.id
}
{% endhighlight %}

The same mechanism is used for the manager and its network interface as well, so we can't reference it as `azurerm_network_interface.mgr2.id` but instead need to use `azurerm_network_interface.mgr2.0.id` because it is the first instance.

## The details about deploying the infrastructure with Terraform: The Docker Swarm - managers and workers
The managers are three (or one) separately configured VMs, defined in [managers.tf][managers.tf]. It would have been easier from a Terraform point of view to configure them only once and use the `count` mechanism to have one or three but because of how setting up a Swarm works, I needed the following things:

- The first manager needs to do something different[^2] than the others. This is realized as a script param, again explained in more detail in the next post, but the only good way to set that up was a different configuration for the first manager.
- Also, the first manager needs a dedicated, static IP address to advertise when creating and when joining the Swarm.
- The second manager can only come start its configuration when the first one is completely done. This is easily accomplished with a `depends_on` setting that tells the second manager to start only after the initialization script of the first one is finished and I couldn't find a good way to get that implemented when using a `count`-based setup.

{% highlight hcl linenos %}
resource "azurerm_windows_virtual_machine" "mgr2" {
  ...
  depends_on = [
    azurerm_virtual_machine_extension.initMgr1
  ]
}
{% endhighlight %}
- If the second and third manager start the Swarm join process at the same time, I sometimes got errors that there wasn't a majority of managers available. It looked to me like the second one was not fully there but already registered and then the third couldn't join. It wasn't completely reliably succeeding or failing, so it seems to be some kind of race condition. The solution again was a `depends_on` property.
- The first manager needs to write the Swarm join tokens for managers and workers to the Azure key vault, so it needs `Set` permission and in case of a re-create also `Delete`, while the other managers (and workers) only need `Get`

Apart from that, the managers have no special setup in Terraform. The workers are defined in [workers.tf][workers.tf] implemented with a Virtual Machine Scale Set as explained in part one of this blog post series, so the Terraform file only has that and the number of workers can simply configred through the SKU capacity:

{% highlight hcl linenos %}
resource "azurerm_virtual_machine_scale_set" "worker" {
  ...
  sku {
    ...
    capacity = var.workerVmssSettings.number
  }
  ...
}
{% endhighlight %}

The rest is again nothing sepcial.

## The details: Configuring OpenSSH
The OpenSSH configuration has two different variants: The jumpbox is the only machine where SSH is publicly available, so it only has public key authentication enabled with password authentication disabled in its [configuration][sshd_config_wopwd]. I had some issues with connections failing after a couple of minutes, so I also added `ClientAliveInterval` of 60 (seconds) as explained [here][ClientAliveInterval], the rest is once again pretty standard:

{% highlight none linenos %}
Port 22
PubkeyAuthentication yes
PasswordAuthentication no
ClientAliveInterval 60
Subsystem	sftp	sftp-server.exe
Match Group administrators
       AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys
{% endhighlight %}

The managers and workers have password authentication enabled, so that you can log in from the jumbpox using a password. The fourth part of this blog post series will show you how you can instead use a private/public SSH key setup on the jumpbox. Therefore, the only line different in the [configuration][sshd_config_wpwd] for that setup is this:

{% highlight none linenos %}
PasswordAuthentication yes
{% endhighlight %}

## The details: Using a Docker Compose file to deploy Traefik and Portainer as Swarm service
With all of the above, the infrastructure is in place, and we have a Docker Swarm with one or three managers and a configurable number of workers. Now it's time to deploy Swarm services, basically Docker containers with a configurable number of replicas and placement (e.g. "everywhere" or "only on managers"). For that, I used a Docker Compose file to define a stack, which is a collection of services. The [configuration file][docker-compose.yml.template] is a template file with a couple of placeholders like `$email` and `$externaldns` which are also replaced through the scripts so that something like 

`- --certificatesresolvers.myresolver.acme.email=$email`

becomes

`- --certificatesresolvers.myresolver.acme.email=tobias.fenster@cosmoconsult.com`

The Traefik configuration has those notable parts:

- It uses a custom generated image because I wanted the ability to have a multi-arch image as explained [here][multi-arch] and Docker library images like `traefik` can't do that. Weird, but I [asked][library] and got that as answer. Therefore I don't reference the standard image:
{% highlight yaml linenos %}
services:
  traefik:
    image: tobiasfenster/french-reverse-proxy:2.3.4-windowsservercore
...
{% endhighlight %}
- The configuration to make the Traefik API and dashboard available throught Traefik itself is already there, but handling is disabled. In case you need, you only need to switch that boolean in line 2 to true:
{% highlight yaml linenos %}
...
      labels:
        - traefik.enable=false
        - traefik.http.routers.api.entrypoints=websecure
        - traefik.http.routers.api.tls.certresolver=myresolver
        - traefik.http.routers.api.rule=Host(``$externaldns``) && (PathPrefix(``/api``) || PathPrefix(``/dashboard``))
        - traefik.http.routers.api.service=api@internal
        - traefik.http.services.api.loadBalancer.server.port=8080
...
{% endhighlight %}
- I have a shared Azure File Share as s: in all nodes of the Swarm, so I can store the [Let's Encrypt cert for Traefik][traefik-le] there and don't need to worry on which manager the Traefik container comes up. And of course, Traefik needs to work in [Docker Swarm mode][traefik-swarm]:
{% highlight yaml linenos %}
services:
  traefik:
    command:
      ...
      - --providers.docker.swarmMode=true
      ...
      - --certificatesresolvers.myresolver.acme.storage=c:/le/acme.json
      ...
    volumes:
      - source: 'S:/le'
        target: 'C:/le'
        type: bind
...
{% endhighlight %}

The main Portainer service also stores its data on that share, which again means that I don't mind on which manager the container comes up. I am also sharing the generated password as [Swarm secret][swarm-secret] and make that available to Portainer, so that the admin password there is the same as for the VMs. And then after some usage I ran into the issue that I couldn't transfer larger files through the Portainer file browser. I found out that this was caused by Traefik and increased the size limit there as well (`maxRequestBodyBytes`):

{% highlight yaml linenos %}
services:
...
  portainer:
    image: portainer/portainer-ce:latest
    command: -H tcp://tasks.agent:9001 --tlsskipverify --admin-password-file 'c:\\secrets\\adminPwd'
    volumes:
      - s:/portainer-data:c:/data
    ...
    deploy:
      ...
      labels:
        ...
        - traefik.http.middlewares.limit.buffering.maxRequestBodyBytes=500000000
        - traefik.http.routers.portainer.middlewares=portainer@docker, limit@docker
    ...
    secrets:
      - source: adminPwd
        target: "c:/secrets/adminPwd"
...
secrets:
  adminPwd:
    external: true
{% endhighlight %}

The Portainer agent has only one notable setting: The path for the Docker volumes needs to be configured differently if you move it away from the standard path of `C:\ProgramData\docker\volumes`. I am creating a bigger data disk for that purpose, so this becomes `f:\dockerdata\volumes`. As the agents need to run on all nodes, this also means that we need an f: drive on the managers although I didn't move the Docker data path there. In the configuration it looks like this:

{% highlight yaml linenos %}
services:
...
  agent:
    image: portainer/agent:latest
    ...
    volumes:
      ...
      - source: '$dockerdatapath/volumes'
        target: 'C:/ProgramData/docker/volumes'
        type: bind
...
{% endhighlight %}

This should hopefully explain all relevant, non-standard aspects of my setup. The next part will cover the PowerShell scripts used to set up and configured the VMs and Docker Swarm.

[one]: https://tobiasfenster.io/creating-a-docker-swarm-on-azure-using-terraform-part-i
[docker-swarm]: https://docs.docker.com/engine/swarm/
[terraform]: https://www.terraform.io 
[traefik]: https://traefik.io/
[portainer]: https://www.portainer.io/
[tf-intro]: https://www.terraform.io/intro/index.html
[az-terraform]: https://www.terraform.io/docs/providers/azurerm/index.html
[az-terraform2]: https://docs.microsoft.com/en-us/azure/developer/terraform/overview
[common.tf]: https://github.com/cosmoconsult/azure-swarm/blob/c6333e4392679ced82f70539e78c377995a0a41b/tf/common.tf
[jumpbox.tf]: https://github.com/cosmoconsult/azure-swarm/blob/c6333e4392679ced82f70539e78c377995a0a41b/tf/jumpbox.tf
[loadbalancer.tf]: https://github.com/cosmoconsult/azure-swarm/blob/c6333e4392679ced82f70539e78c377995a0a41b/tf/loadbalancer.tf
[managers.tf]: https://github.com/cosmoconsult/azure-swarm/blob/c6333e4392679ced82f70539e78c377995a0a41b/tf/managers.tf
[storage.tf]: https://github.com/cosmoconsult/azure-swarm/blob/c6333e4392679ced82f70539e78c377995a0a41b/tf/storage.tf
[variables.tf]: https://github.com/cosmoconsult/azure-swarm/blob/c6333e4392679ced82f70539e78c377995a0a41b/tf/variables.tf
[workers.tf]: https://github.com/cosmoconsult/azure-swarm/blob/c6333e4392679ced82f70539e78c377995a0a41b/tf/workers.tf
[sshd_config_wpwd]: https://github.com/cosmoconsult/azure-swarm/blob/c6333e4392679ced82f70539e78c377995a0a41b/configs/sshd_config_wpwd
[sshd_config_wopwd]: https://github.com/cosmoconsult/azure-swarm/blob/c6333e4392679ced82f70539e78c377995a0a41b/configs/sshd_config_wopwd
[docker-compose.yml.template]: https://github.com/cosmoconsult/azure-swarm/blob/c6333e4392679ced82f70539e78c377995a0a41b/configs/docker-compose.yml.template
[openssh]: https://docs.microsoft.com/en-us/windows-server/administration/openssh/openssh_overview
[docker-compose]: https://docs.docker.com/compose/
[ClientAliveInterval]: https://man.openbsd.org/sshd_config#ClientAliveInterval
[library]: https://github.com/docker-library/official-images/issues/9198#issuecomment-737477765
[multi-arch]: /building-docker-images-for-multiple-windows-server-versions-using-self-hosted-github-runners
[traefik-swarm]: https://doc.traefik.io/traefik/providers/docker/
[traefik-le]: https://doc.traefik.io/traefik/https/acme/
[swarm-secret]: https://docs.docker.com/engine/swarm/secrets/
[^1]: which probably no one would be interested in reading anyway
[^2]: `docker swarm init`, while the others need to do `docker swarm join`