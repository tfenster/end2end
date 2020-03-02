---
layout: page
title: "4 Networking"
description: ""
keywords: ""
permalink: "cosmo-docker-4-networking"
slug: "cosmo-docker-4-networking"
---
{::options parse_block_html="true" /}
Table of content
- [Preparation](#preparation)
- [Host-only networking with no additional setup](#host-only-networking-with-no-additional-setup)
- [Port mapping to give access to select ports](#port-mapping-to-give-access-to-select-ports)
- [Transparent networking setup (theory)](#transparent-networking-setup-theory)

&nbsp;<br />

### Preparation
We will need to make sure the Windows firewall isn't in our way. To achieve that, run the following command to open port 80 on the firewall. Note that this is only the Windows firewall, external access e.g. from your laptop is still blocked by the Azure firewall.
```bash
netsh advfirewall firewall add rule name="Open Port 80" dir=in action=allow protocol=TCP localport=80
```

<details><summary markdown="span">Full output of the preparation steps</summary>
```bash
PS C:\Users\CosmoAdmin> netsh advfirewall firewall add rule name="Open Port 80" dir=in action=allow protocol=TCP localport=80
Ok.
```
</details>
&nbsp;<br />

### Host-only networking with no additional setup
We just run an IIS container without additional config and make sure that we can reach it locally by getting it's IP address and trying to connect. Note that we start it with option `-d` which immediately sends it to the background. Also note one more way to get the IP address by just running `ipconfig` on the container.
```bash
docker run --name iis -d mcr.microsoft.com/windows/servercore/iis:windowsservercore-ltsc2019
docker exec iis ipconfig
```

<details><summary markdown="span">Full output of the start and IP check</summary>
```bash
PS C:\Users\CosmoAdmin> docker run --name iis -d mcr.microsoft.com/windows/servercore/iis:windowsservercore-ltsc2019
91ce3644c78a85fb16899deac7e991d4c16909bf3cd7198a1c9bbe95286e78a6
PS C:\Users\CosmoAdmin> docker exec iis ipconfig

Windows IP Configuration

Ethernet adapter vEthernet (Ethernet):

   Connection-specific DNS Suffix  . : u23ctjkp2ieupkmarl3k35fvva.ax.internal.cloudapp.net
   Link-local IPv6 Address . . . . . : fe80::cdf:b3d9:e463:f20c%18
   IPv4 Address. . . . . . . . . . . : 172.27.8.251
   Subnet Mask . . . . . . . . . . . : 255.255.240.0
   Default Gateway . . . . . . . . . : 172.27.0.1
```
</details>
&nbsp;<br />

Now open your browser and connect to the IPv4 address you just got, in my case http://172.27.8.251. You should see the default IIS start page.

We already know that it doesn't work and what the reason for that is, but if you want to make sure: Connect to the small VM (I'll call it "client" from now on) and try to connect to the same IP, which should give you a connection error.

Again, we already know it doesn't work and why, but if you want to make sure, try to connect to port 80 on the host. For that, run `ipconfig` on the host and note the IPv4 Address that starts with 10.1, not the one starts with 127.27. In my case, and very likely in yours as well, this is 10.1.0.4
```bash
ipconfig
```

<details><summary markdown="span">Full output of ipconfig</summary>
```bash
PS C:\Users\CosmoAdmin> ipconfig

Windows IP Configuration

Ethernet adapter Ethernet:

   Connection-specific DNS Suffix  . : u23ctjkp2ieupkmarl3k35fvva.ax.internal.cloudapp.net
   Link-local IPv6 Address . . . . . : fe80::9d37:f964:2389:6212%5
   IPv4 Address. . . . . . . . . . . : 10.1.0.4
   Subnet Mask . . . . . . . . . . . : 255.255.255.0
   Default Gateway . . . . . . . . . : 10.1.0.1

Ethernet adapter vEthernet (nat):

   Connection-specific DNS Suffix  . :
   Link-local IPv6 Address . . . . . : fe80::b17d:3c3b:2f8b:963f%13
   IPv4 Address. . . . . . . . . . . : 172.27.0.1
   Subnet Mask . . . . . . . . . . . : 255.255.240.0
   Default Gateway . . . . . . . . . :
```
</details>
&nbsp;<br />
Now go back to the client VM and try to connect to that IP address using http://10.1.0.4 in my case. Again, you will get a connection error message.

### Port mapping to give access to select ports
Remove the IIS container on the host and create it again, this time with a port mapping parameter to allow external access.
```bash
docker rm -f iis
docker run --name iis -d -p 80:80 mcr.microsoft.com/windows/servercore/iis:windowsservercore-ltsc2019
```

<details><summary markdown="span">Full output of the remove and create commands</summary>
```bash
PS C:\Users\CosmoAdmin> docker rm -f iis
iis
PS C:\Users\CosmoAdmin> docker run --name iis -d -p 80:80 mcr.microsoft.com/windows/servercore/iis:windowsservercore-ltsc2019
75cb71070bf87a778f638625dc72fd642bf651f2ec164a75e3b16a306ad5ef25
```
</details>
&nbsp;<br />
Now go back to the client VM and again, try to connect to the host, e.g. http://10.1.0.4. This time you will see the start page of IIS as we have mapped port 80 on the host to port 80 on the container.

### Transparent networking setup (theory)
Unfortunately we can't set up transparent networking fully on Azure because that needs MAC address spoofing to be enabled ([see here](https://docs.microsoft.com/en-us/virtualization/windowscontainers/container-networking/network-drivers-topologies)), which isn't the case on Azure for security reasons. But we can do the setup and see how the container get's it's own IP address, we just can't connect. Depending on your setup in your own data center, this might work out of the box or can be configured. Switch back to the host for the following steps:

First we need to create the transparent network (this takes a couple of seconds with no apparent progress and might cause a quick disconnect of the RDP session), then we remove and create the IIS container again, this time referencing the transparent network. Then we run `ipconfig` again to see that the container now got an IP address from the external subnet, which would make it reachable if MAC address spoofing was enabled
```bash
docker network create -d transparent --subnet=10.1.0.0/24 --gateway=10.1.0.1 MyTransparentNetwork
docker rm -f iis
docker run --name iis -d --network MyTransparentNetwork mcr.microsoft.com/windows/servercore/iis:windowsservercore-ltsc2019
docker exec iis ipconfig
```

<details><summary markdown="span">Full output of the transparent networking setup</summary>
```bash
PS C:\Users\CosmoAdmin> docker network create -d transparent --subnet=10.1.0.0/24 --gateway=10.1.0.1 MyTransparentNetwork
a0c6a3d35c065eebd88135b8fa8325ffd16dac4a80a2acb7ed1040118e0841cf
PS C:\Users\CosmoAdmin> docker rm -f iis
iis
PS C:\Users\CosmoAdmin> docker run --name iis -d --network MyTransparentNetwork mcr.microsoft.com/windows/servercore/iis:windowsservercore-ltsc2019
034dc559f78ec8356496c6d2811bd2ef7739f34e8d7534f379e3d59668013797
PS C:\Users\CosmoAdmin> docker exec iis ipconfig

Windows IP Configuration


Ethernet adapter vEthernet (Ethernet):

   Connection-specific DNS Suffix  . :
   Link-local IPv6 Address . . . . . : fe80::4ddf:fe3d:cbae:94f2%18
   IPv4 Address. . . . . . . . . . . : 10.1.0.159
   Subnet Mask . . . . . . . . . . . : 255.255.255.0
   Default Gateway . . . . . . . . . : 10.1.0.1
```
</details>
&nbsp;<br />
If MAC address spoofing was enabled, we could now go to the client VM and access the IP address of the container, in my case http://10.1.0.159
&nbsp;<br />

{::options parse_block_html="false" /}