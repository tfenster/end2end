---
layout: post
title: "Creating a Windows Docker Swarm on Azure using Terraform, part IV: Easily navigate the nodes with SSH"
permalink: creating-a-windows-docker-swarm-on-azure-using-terraform-part-iv
date: 2021-03-02 08:30:00
comments: false
description: "Creating a Windows Docker Swarm on Azure using Terraform, part IV: Easily navigate the nodes with SSH"
keywords: ""
image: /images/terraform-azure-swarm.png
categories:

tags:

---

After talking about the overall picture in [part one][one], the infrastructure setup and configuration in [part two][two] and the PowerShell scripts in [part three][three], I now want to share in the fourth and last part of this blog post series how you can make it easier to navigate between the nodes and also from other machines to the nodes without the need to separately log in to the jumpbox. Basically, this is about configuring and using OpenSSH on Windows with the Docker Swarm as an example environment.

## The TL;DR
If you are more experienced with SSH, this likely will be nothing new but given the fact that it is fairly new for Windows and needs a bit of special setup for the second part, I still wanted to share how it is done:

- To easily navigate between jumpbox and Swarm nodes, you can generate a key pair on the jumpbox and copy the public key to all nodes. You can define a password for the private key, but IMHO in this setup, this doesn't make a lot of sense, so I would keep it empty.
- If you want direct access from e.g. your laptop to the nodes, then you need to download the private key and set up the SSH client so that it knows to use this key when connecting to a specific host. It will then tunnel your connection from your laptop through the jumpbox to the target node.

## The details on connecting to the nodes from the jumpbox
If you want to be able to connect from the jumpbox to the other nodes in the swarm without a password, you can do the following. Please note that this means that anyone with access to the jumpbox directly has access to all other nodes as well. IMHO this is ok, but you need to make that decision for your own
 
1. Create a key pair without a password on the jumpbox: Run `ssh-keygen` on the jumpbox and accept all default parameters including an empty password
1. Copy the public key to all other nodes. Note that your worker nodes might have different names, you can easily find out with `docker node ls`
{% highlight powershell linenos %}
$pub = Get-Content .\.ssh\id_rsa.pub
ssh -l VM-Administrator mgr1 "'$pub' | Out-File 'c:\ProgramData\ssh\administrators_authorized_keys' -Encoding utf8"
ssh -l VM-Administrator mgr2 "'$pub' | Out-File 'c:\ProgramData\ssh\administrators_authorized_keys' -Encoding utf8"
ssh -l VM-Administrator mgr3 "'$pub' | Out-File 'c:\ProgramData\ssh\administrators_authorized_keys' -Encoding utf8"
ssh -l VM-Administrator worker000001 "'$pub' | Out-File 'c:\ProgramData\ssh\administrators_authorized_keys' -Encoding utf8"
ssh -l VM-Administrator worker000003 "'$pub' | Out-File 'c:\ProgramData\ssh\administrators_authorized_keys' -Encoding utf8"
{% endhighlight %}

## The details on connecting directly to the nodes from somewhere else
If you have the setup as explained above, you can do the following to make it even more convenient and have seemingly direct access. I am assuming that I talk to the Swarm `swarm-vfsedbuv`, this will of course be different for you and you need to change it
 
1. Download the private key from the jumpbox to your machine. Make sure that you append the name of the swarm to the local file, so that it doesn't override your own key
{% highlight powershell linenos %}
scp vm-administrator@swarm-vfsedbuv-ssh.westeurope.cloudapp.azure.com:c:\users\vm-administrator\.ssh\id_rsa .\.ssh\id_rsa_swarm-vfsedbuv
{% endhighlight %}
1. Open (or create, if it doesn't exist) a file called `config` (no extension) in the subfolder `.ssh` of your home folder
1. Create a section like this and replicate for mgr2 and mgr3
{% highlight none linenos %}
Host mgr1.se
  HostName mgr1
  ProxyCommand C:\Windows\System32\OpenSSH\ssh.exe -W %h:%p -q VM-Administrator@swarm-vfsedbuv-ssh.westeurope.cloudapp.azure.com
  User VM-Administrator
  IdentityFile ~\.ssh\id_rsa_swarm-vfsedbuv
{% endhighlight %}
1. Run `ssh mgr1.se` in a console and celebrate :)

As I wrote in the beginning, if you are already familiar with SSH, this won't be special, but I hope it still helps some of you to make life easier and especially figuring out the configuration in step 3 on Windows took me quite some time.

[one]: https://tobiasfenster.io/creating-a-docker-swarm-on-azure-using-terraform-part-i
[two]: https://tobiasfenster.io/creating-a-docker-swarm-on-azure-using-terraform-part-ii
[three]: https://tobiasfenster.io/creating-a-docker-swarm-on-azure-using-terraform-part-iii