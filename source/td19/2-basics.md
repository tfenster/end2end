---
layout: page
title: "2 Basics of container handling"
description: ""
keywords: ""
permalink: "td19-2-basics"
slug: "td19-2-basics"
---
{::options parse_block_html="true" /}

Table of content
- [Create a container in interactive mode](#create-a-container-in-interactive-mode)
- [Show running and all containers](#show-running-and-all-containers)
- [Show resource consumption and logs](#show-resource-consumption-and-logs)
- [Get a cmd session inside an already running container](#get-a-cmd-session-inside-an-already-running-container)
- [Inspect the configuration of a container](#inspect-the-configuration-of-a-container)
- [Stop and remove containers](#stop-and-remove-containers)
- [Show and remove images](#show-and-remove-images)
- [Give your container a name and reference it that way](#give-your-container-a-name-and-reference-it-that-way)

&nbsp;<br />

### Create a container in interactive mode
Starting container with param `-ti` creates a terminal inside that container and `cmd` in the end tells it to use cmd as process to start
```bash
docker run -ti mcr.microsoft.com/windows/nanoserver:1809 cmd
dir
```
<details><summary markdown="span">Full output of the interactive command</summary>
```bash
PS C:\Users\AdminTechDays> docker run -ti mcr.microsoft.com/windows/nanoserver:1809 pwsh
Unable to find image 'mcr.microsoft.com/windows/nanoserver:1809' locally
1809: Pulling from windows/nanoserver
9ff41eda0887: Already exists
Digest: sha256:da46159cc4409ccdfe8e25d1e2b2e2705c31d956122d39ea89733b19d76340dd
Status: Downloaded newer image for mcr.microsoft.com/windows/nanoserver:1809
Microsoft Windows [Version 10.0.17763.802]
(c) 2018 Microsoft Corporation. All rights reserved.

C:\>dir
 Volume in drive C has no label.
 Volume Serial Number is 9207-440D

 Directory of C:\

10/02/2019  12:46 PM             5,510 License.txt
10/02/2019  12:47 PM    <DIR>          Users
11/09/2019  09:39 PM    <DIR>          Windows
               1 File(s)          5,510 bytes
               2 Dir(s)  21,297,684,480 bytes free
```
</details>
&nbsp;<br />

### Show running and all containers
Open a second PowerShell as admin on the host to show the running containers
```bash
docker ps
```
<details><summary markdown="span">Full output of the container list</summary>
```bash
PS C:\Users\AdminTechDays> docker ps
CONTAINER ID        IMAGE                                       COMMAND             CREATED             STATUS              PORTS               NAMES
bee7f05d3210        mcr.microsoft.com/windows/nanoserver:1809   "cmd"               2 minutes ago       Up 2 minutes                            sharp_edison
```
</details>
&nbsp;<br />

To show all containers instead of only the running onec, we add parameter `-a`). Notice the generated names and ids
```bash
docker ps -a
```
<details><summary markdown="span">Full output of the container list</summary>
```bash
PS C:\Users\AdminTechDays> docker ps -a
CONTAINER ID        IMAGE                                       COMMAND                   CREATED             STATUS                   PORTS               NAMES
bee7f05d3210        mcr.microsoft.com/windows/nanoserver:1809   "cmd"                     4 minutes ago       Up 4 minutes                                 sharp_edison
46013aca11a1        hello-world:nanoserver                      "cmd /C 'type C:\\hel…"   6 hours ago         Exited (0) 6 hours ago                       amazing_pike
```
</details>
&nbsp;<br />

### Show resource consumption and logs
Run the following command to see the resource usage of your running containers
```bash
docker stats
```
<details><summary markdown="span">Full output of the resource view</summary>
```bash
PS C:\Users\AdminTechDays> docker stats
CONTAINER ID        NAME                CPU %               PRIV WORKING SET    NET I/O             BLOCK I/O
bee7f05d3210        sharp_edison        0.00%               25.2MiB             202kB / 29.1kB      5.23MB / 6.05MB
```
</details>
&nbsp;<br />
Hit ctrl-c to exit the stats  
To see logs from a running container, you need to run `docker logs` followed by the name or enough letters of the id to be able to identify the container. In our case, only one container is running, so it should be enough to specify the first letter. In my case it's a `b`, your's of course might be different
```bash
docker logs b
```
<details><summary markdown="span">Full output of the logs view</summary>
```bash
Microsoft Windows [Version 10.0.17763.802]
(c) 2018 Microsoft Corporation. All rights reserved.

C:\>dir
 Volume in drive C has no label.
 Volume Serial Number is 9207-440D

 Directory of C:\

10/02/2019  12:46 PM             5,510 License.txt
10/02/2019  12:47 PM    <DIR>          Users
11/09/2019  09:39 PM    <DIR>          Windows
               1 File(s)          5,510 bytes
               2 Dir(s)  21,297,684,480 bytes free
```
</details>
&nbsp;<br />

### Get a cmd session inside an already running container
With `docker exec` we can execute commands on a container and param `-ti` again gives us an interactive terminal. Get a second session into the container, exit it and see that the container is still running
```bash
docker exec -ti b cmd
exit
docker ps
```
<details><summary markdown="span">Full output of the session, exit and container status</summary>
```bash
docker exec -ti b cmd
Microsoft Windows [Version 10.0.17763.802]
(c) 2018 Microsoft Corporation. All rights reserved.

C:\>exit
PS C:\Users\AdminTechDays> docker ps
CONTAINER ID        IMAGE                                       COMMAND             CREATED             STATUS              PORTS               NAMES
bee7f05d3210        mcr.microsoft.com/windows/nanoserver:1809   "cmd"               18 minutes ago      Up 18 minutes                           sharp_edison
```
</details>
&nbsp;<br />

Get back to the first powershell and exit there, see that the container now stops (main process has ended)
```bash
exit
docker ps
```
<details><summary markdown="span">Full output of the exit and container status</summary>
```bash
C:\>exit
PS C:\Users\AdminTechDays> docker ps
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS               NAMES
```
</details>
&nbsp;<br />

### Inspect the configuration of a container
You can get all configuration information of a container, whether it is running or not. The most common use cases for that are checking environment parameters or getting the IP address. To get more meaningful results, start the container and inspect it
```bash
docker start b
docker inspect b
```
<details><summary markdown="span">Full configuration output</summary>
```bash
PS C:\Users\AdminTechDays> docker start b
b
PS C:\Users\AdminTechDays> docker inspect b
[
    {
        "Id": "bee7f05d3210417371c2d17005cbbc2a551e26acf1e1a5de3dfc0d926b54a9dc",
        "Created": "2019-11-09T21:39:29.3720658Z",
        "Path": "cmd",
        "Args": [],
        "State": {
            "Status": "running",
            "Running": true,
            "Paused": false,
            "Restarting": false,
            "OOMKilled": false,
            "Dead": false,
            "Pid": 5620,
            "ExitCode": 0,
            "Error": "",
            "StartedAt": "2019-11-09T22:05:11.3280773Z",
            "FinishedAt": "2019-11-09T21:58:58.283549Z"
        },
        "Image": "sha256:8a09fa9e06cd9128dc86b7b2561072877cfe13e38b0527223f42b03b90c4af3d",
        "ResolvConfPath": "",
        "HostnamePath": "",
        "HostsPath": "",
        "LogPath": "C:\\ProgramData\\docker\\containers\\bee7f05d3210417371c2d17005cbbc2a551e26acf1e1a5de3dfc0d926b54a9dc\\bee7f05d3210417371c2d17005cbbc2a551e26acf1e1a5de3dfc0d926b54a9dc-json.log",
        "Name": "/sharp_edison",
        "RestartCount": 0,
        "Driver": "windowsfilter",
        "Platform": "windows",
        "MountLabel": "",
        "ProcessLabel": "",
        "AppArmorProfile": "",
        "ExecIDs": null,
        "HostConfig": {
            "Binds": null,
            "ContainerIDFile": "",
            "LogConfig": {
                "Type": "json-file",
                "Config": {}
            },
            "NetworkMode": "default",
            "PortBindings": {},
            "RestartPolicy": {
                "Name": "no",
                "MaximumRetryCount": 0
            },
            "AutoRemove": false,
            "VolumeDriver": "",
            "VolumesFrom": null,
            "CapAdd": null,
            "CapDrop": null,
            "Capabilities": null,
            "Dns": [],
            "DnsOptions": [],
            "DnsSearch": [],
            "ExtraHosts": null,
            "GroupAdd": null,
            "IpcMode": "",
            "Cgroup": "",
            "Links": null,
            "OomScoreAdj": 0,
            "PidMode": "",
            "Privileged": false,
            "PublishAllPorts": false,
            "ReadonlyRootfs": false,
            "SecurityOpt": null,
            "UTSMode": "",
            "UsernsMode": "",
            "ShmSize": 0,
            "ConsoleSize": [
                75,
                317
            ],
            "Isolation": "process",
            "CpuShares": 0,
            "Memory": 0,
            "NanoCpus": 0,
            "CgroupParent": "",
            "BlkioWeight": 0,
            "BlkioWeightDevice": [],
            "BlkioDeviceReadBps": null,
            "BlkioDeviceWriteBps": null,
            "BlkioDeviceReadIOps": null,
            "BlkioDeviceWriteIOps": null,
            "CpuPeriod": 0,
            "CpuQuota": 0,
            "CpuRealtimePeriod": 0,
            "CpuRealtimeRuntime": 0,
            "CpusetCpus": "",
            "CpusetMems": "",
            "Devices": [],
            "DeviceCgroupRules": null,
            "DeviceRequests": null,
            "KernelMemory": 0,
            "KernelMemoryTCP": 0,
            "MemoryReservation": 0,
            "MemorySwap": 0,
            "MemorySwappiness": null,
            "OomKillDisable": false,
            "PidsLimit": null,
            "Ulimits": null,
            "CpuCount": 0,
            "CpuPercent": 0,
            "IOMaximumIOps": 0,
            "IOMaximumBandwidth": 0,
            "MaskedPaths": null,
            "ReadonlyPaths": null
        },
        "GraphDriver": {
            "Data": {
                "dir": "C:\\ProgramData\\docker\\windowsfilter\\bee7f05d3210417371c2d17005cbbc2a551e26acf1e1a5de3dfc0d926b54a9dc"
            },
            "Name": "windowsfilter"
        },
        "Mounts": [],
        "Config": {
            "Hostname": "bee7f05d3210",
            "Domainname": "",
            "User": "ContainerUser",
            "AttachStdin": true,
            "AttachStdout": true,
            "AttachStderr": true,
            "Tty": true,
            "OpenStdin": true,
            "StdinOnce": true,
            "Env": null,
            "Cmd": [
                "cmd"
            ],
            "Image": "mcr.microsoft.com/windows/nanoserver:1809",
            "Volumes": null,
            "WorkingDir": "",
            "Entrypoint": null,
            "OnBuild": null,
            "Labels": {}
        },
        "NetworkSettings": {
            "Bridge": "",
            "SandboxID": "bee7f05d3210417371c2d17005cbbc2a551e26acf1e1a5de3dfc0d926b54a9dc",
            "HairpinMode": false,
            "LinkLocalIPv6Address": "",
            "LinkLocalIPv6PrefixLen": 0,
            "Ports": {},
            "SandboxKey": "bee7f05d3210417371c2d17005cbbc2a551e26acf1e1a5de3dfc0d926b54a9dc",
            "SecondaryIPAddresses": null,
            "SecondaryIPv6Addresses": null,
            "EndpointID": "",
            "Gateway": "",
            "GlobalIPv6Address": "",
            "GlobalIPv6PrefixLen": 0,
            "IPAddress": "",
            "IPPrefixLen": 0,
            "IPv6Gateway": "",
            "MacAddress": "",
            "Networks": {
                "nat": {
                    "IPAMConfig": null,
                    "Links": null,
                    "Aliases": null,
                    "NetworkID": "aeeb9f02f0093236f0de08dedfc334b24870624a17abc6437d952fe36172dac6",
                    "EndpointID": "3d5090937d4e8ce4d700fcd7726e25d2439fb2da0c2bf44e2c3a55339fa42a18",
                    "Gateway": "172.27.0.1",
                    "IPAddress": "172.27.8.29",
                    "IPPrefixLen": 16,
                    "IPv6Gateway": "",
                    "GlobalIPv6Address": "",
                    "GlobalIPv6PrefixLen": 0,
                    "MacAddress": "00:15:5d:1e:c9:9b",
                    "DriverOpts": null
                }
            }
        }
    }
]
```
</details>
&nbsp;<br />

As this can be somewhat difficult to read, you can also filter the output, e.g. to only return the IP address
{% raw %}
```bash
docker inspect --format='{{ .NetworkSettings.Networks.nat.IPAddress }}' b
```
{% endraw %}
<details><summary markdown="span">Network address output</summary>
{% raw %}
```bash
PS C:\Users\AdminTechDays> docker inspect --format='{{ .NetworkSettings.Networks.nat.IPAddress }}' b
172.27.8.29
```
{% endraw %}
</details>
&nbsp;<br />

### Stop and remove containers
Remove the already stopped container using it's id
```bash
docker ps -a
docker rm 4
```
<details><summary markdown="span">Full ouptut of the removal</summary>
```bash
PS C:\Users\AdminTechDays> docker ps -a
CONTAINER ID        IMAGE                                       COMMAND                   CREATED             STATUS                   PORTS               NAMES
bee7f05d3210        mcr.microsoft.com/windows/nanoserver:1809   "cmd"                     36 minutes ago      Up 10 minutes                                sharp_edison
46013aca11a1        hello-world:nanoserver                      "cmd /C 'type C:\\hel…"   6 hours ago         Exited (0) 6 hours ago                       amazing_pike
PS C:\Users\AdminTechDays> docker rm 4
4
```
</details>
&nbsp;<br />

Try the same with the still running container, this will return an error. You can solve ths using either `docker stop` or the `-f` parameter (force) for the `docker rm` command. The same `docker stop` command is also used regularly to stop a container.
```bash
docker rm b
docker stop b
docker rm b
```
<details><summary markdown="span">Full ouptut of the removal, first with an error message</summary>
```bash
PS C:\Users\AdminTechDays> docker rm b
Error response from daemon: You cannot remove a running container bee7f05d3210417371c2d17005cbbc2a551e26acf1e1a5de3dfc0d926b54a9dc. Stop the container before attempting removal or force remove
PS C:\Users\AdminTechDays> docker stop b
b
PS C:\Users\AdminTechDays> docker rm b
b
```
</details>
&nbsp;<br />

### Show and remove images
You use the `docker images` command to show all locally available images. To remove an image, you do `docker rmi` and give it the id of the image you want to remove. This only works if there is no container referencing that image. Look for the hello-world image and use that one to delete.
```bash
docker images
docker rmi 1
```
<details><summary markdown="span">Full ouptut of the image list and removal commands</summary>
```bash
PS C:\Users\AdminTechDays> docker images
REPOSITORY                             TAG                 IMAGE ID            CREATED             SIZE
hello-world                            nanoserver          158c64d77ced        4 weeks ago         251MB
mcr.microsoft.com/windows/nanoserver   1809                8a09fa9e06cd        4 weeks ago         250MB
PS C:\Users\AdminTechDays> docker rmi 1
Untagged: hello-world:nanoserver
Untagged: hello-world@sha256:6923ba909bd4b9b8ee22e434a8353a77ceafb6a5dfa24cde98ec8e5371e25588
Deleted: sha256:158c64d77ced2c0887665320be9a0875daa0438c550dce56ba66de6689ad1d4f
Deleted: sha256:3c5e83de0c0fba4fc42bd4ee5f3419e738e884e87087c16438fc6613c2d62791
Deleted: sha256:54c8a4534b8e2bce6336620c0e094dcc8ca06dfb4be8c70469c36e54d86b3f7b
```
</details>
&nbsp;<br />

### Give your container a name and reference it that way
If you don't want to use the container id, you can also use it's name. But as those are dynamically generated, you would first need to look those up as well. Instead you can give your container a name when starting it, allowing you easier reference later. Start a container again, giving it a name of "test" and then reference it from your second powershell, e.g. to get the logs
```bash
docker run -ti --name test mcr.microsoft.com/windows/nanoserver:1809 cmd
dir
## switch to the second powershell
docker logs test
```
<details><summary markdown="span">Full ouptut of the docker run in the first powershell</summary>
```bash
PS C:\Users\AdminTechDays> docker run -ti --name test mcr.microsoft.com/windows/nanoserver:1809 cmd
Microsoft Windows [Version 10.0.17763.802]
(c) 2018 Microsoft Corporation. All rights reserved.

C:\>dir
 Volume in drive C has no label.
 Volume Serial Number is 9207-440D

 Directory of C:\

10/02/2019  12:46 PM             5,510 License.txt
10/02/2019  12:47 PM    <DIR>          Users
11/09/2019  10:28 PM    <DIR>          Windows
               1 File(s)          5,510 bytes
               2 Dir(s)  21,297,668,096 bytes free
```
</details>
<details><summary markdown="span">Full ouptut of the docker logs in the second powershell</summary>
```bash
PS C:\Users\AdminTechDays> docker logs test
Microsoft Windows [Version 10.0.17763.802]
(c) 2018 Microsoft Corporation. All rights reserved.

C:\>dir
 Volume in drive C has no label.
 Volume Serial Number is 9207-440D

 Directory of C:\

10/02/2019  12:46 PM             5,510 License.txt
10/02/2019  12:47 PM    <DIR>          Users
11/09/2019  10:28 PM    <DIR>          Windows
               1 File(s)          5,510 bytes
               2 Dir(s)  21,297,668,096 bytes free
```
</details>
{::options parse_block_html="false" /}