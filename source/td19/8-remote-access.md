---
layout: page
title: "8 Bonus topic: Remote access and Portainer"
description: ""
keywords: ""
permalink: "td19-8-remote-access"
slug: "td19-8-remote-access"
---
{::options parse_block_html="true" /}
Table of content
- [Remote access](#remote-access)
- [Use Portainer](#use-portainer)

&nbsp;<br />

### Remote access
Setting up remote access in the following way might make sense for an internal Docker host were you trust everyone how might be able to get network access to that host. Please make sure that this is never exposes to the internet as you basically would allow everyone to do whatever the want on your host like running a crypto miner or some container with a worm. If you are sure, go ahead. First we change the config file and then we restart the Docker service. To allow the client VM access, we also add a rule to the Windows firewall. Please note that external access e.g. from your laptop is still blocked by the Azure firewall.
```bash
'{ "hosts": ["tcp://0.0.0.0:2375", "npipe://"] }' | Set-Content c:\programdata\docker\config\daemon.json
Restart-Service docker
netsh advfirewall firewall add rule name="Open Port 2375" dir=in action=allow protocol=TCP localport=2375
```

<details><summary markdown="span">Full output of config and restart</summary>
```bash
PS C:\> '{ "hosts": ["tcp://0.0.0.0:2375", "npipe://"] }' | Set-Content c:\programdata\docker\config\daemon.json
PS C:\> Restart-Service docker
PS C:\> netsh advfirewall firewall add rule name="Open Port 2375" dir=in action=allow protocol=TCP localport=2375
Ok.
```
</details>
&nbsp;<br />
Now switch to the client VM and try to access our Docker engine on the host. For that we need to let the Docker client know to which host we want to connect and then we can validate the connection e.g. with `docker info`
```bash
$env:DOCKER_HOST="10.1.0.4"
docker info
```
<details><summary markdown="span">Full output of remote access to the engine</summary>
```bash
PS C:\Users\Verwalter> $env:DOCKER_HOST="10.1.0.4"
PS C:\Users\Verwalter> docker info
Client:
 Debug Mode: false

Server:
 Containers: 4
  Running: 0
  Paused: 0
  Stopped: 4
 Images: 58
 Server Version: 19.03.4
 Storage Driver: windowsfilter
  Windows:
 Logging Driver: json-file
 Plugins:
  Volume: local
  Network: ics internal l2bridge l2tunnel nat null overlay private transparent
  Log: awslogs etwlogs fluentd gcplogs gelf json-file local logentries splunk syslog
 Swarm: inactive
 Default Isolation: process
 Kernel Version: 10.0 17763 (17763.1.amd64fre.rs5_release.180914-1434)
 Operating System: Windows Server 2019 Datacenter Version 1809 (OS Build 17763.805)
 OSType: windows
 Architecture: x86_64
 CPUs: 16
 Total Memory: 64GiB
 Name: techdays-prep
 ID: G2F4:KJOZ:PDG4:XT5R:35YM:BRJW:RTQ7:ZBG4:BERB:7C3C:2WGL:MPSJ
 Docker Root Dir: C:\ProgramData\docker
 Debug Mode: false
 Registry: https://index.docker.io/v1/
 Labels:
 Experimental: false
 Insecure Registries:
  127.0.0.0/8
 Live Restore Enabled: false

WARNING: API is accessible on http://0.0.0.0:2375 without encryption.
         Access to the remote API is equivalent to root access on the host. Refer
         to the 'Docker daemon attack surface' section in the documentation for
         more information: https://docs.docker.com/engine/security/security/#docker-daemon-attack-surface
```
</details>
&nbsp;<br />
With that in place, you can do all the Docker commands on the client that we did on the host, but the containers will still be running on the host. In fact, on the client only the Docker CLI is installed, but not the engine.

### Use Portainer
Portainer is a very nice web GUI for Docker that you can use to do almost everything Docker-related. See [https://portainer.io](https://portainer.io) for documentation. It is of course distributed as container image itself, so spinning it up is very easy.
```bash
docker run -d -p 9000:9000 --name portainer -v \\.\pipe\docker_engine:\\.\pipe\docker_engine portainer/portainer
```

<details><summary markdown="span">Full output of portainer startup</summary>
```bash
PS C:\> netsh advfirewall firewall add rule name="Open Port 9000" dir=in action=allow protocol=TCP localport=9000
Ok.
PS C:\> docker run -d -p 9000:9000 --name portainer -v \\.\pipe\docker_engine:\\.\pipe\docker_engine portainer/portainer
75b9f606caede81af67640c955cb04e74718e6c927b9f5e4c4ae45913ac0b419
```
</details>
&nbsp;<br />
Open [http://localhost:9000](http://localhost:9000) where you should get a login screen. Define an admin password there and select "Local" on the next screen. Then hit "connect" and you should be up and running!
{::options parse_block_html="true" /}
