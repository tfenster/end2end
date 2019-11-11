---
layout: page
title: "3 File handling and volumes"
description: ""
keywords: ""
permalink: "td19-3-files"
slug: "td19-3-files"
---
{::options parse_block_html="true" /}

Table of content
- [Preparation](#preparation)
- [Use docker cp to copy files](#use-docker-cp-to-copy-files)
- [Use a bind mount to share files between host and container](#use-a-bind-mount-to-share-files-between-host-and-container)
- [See the bind mount in the inspect output](#see-the-bind-mount-in-the-inspect-output)

&nbsp;<br />

### Preparation
We will be using PowerShell cmdlets for this, so we run a container of the Windows Server core image that has PowerShell and create a temp folder
```bash
docker run -ti --name core mcr.microsoft.com/windows/servercore:1809 powershell
mkdir c:\temp
```

<details><summary markdown="span">Full output of docker run command</summary>
```bash
PS C:\Users\Verwalter> docker run -ti --name core mcr.microsoft.com/windows/servercore:1809 powershell
Windows PowerShell
Copyright (C) Microsoft Corporation. All rights reserved.

PS C:\> mkdir c:\temp

    Directory: C:\

Mode                LastWriteTime         Length Name
----                -------------         ------ ----
d-----       11/10/2019   4:12 PM                temp
```
</details>
&nbsp;<br />

### Use docker cp to copy files
Go to a second PowerShell session on your host, create a file and copy it into the container. Get a session into the container and check the content
```bash
"This is a TechDays workshop" | Out-File temp.txt
docker cp temp.txt core:c:\temp\temp.txt
docker exec -ti core powershell
get-content temp\temp.txt
```

<details><summary markdown="span">Full output of copy and check</summary>
```bash
PS C:\Users\Verwalter> "This is a TechDays workshop" | Out-File temp.txt
PS C:\Users\Verwalter> docker cp temp.txt core:c:\temp\temp.txt
PS C:\Users\Verwalter> docker exec -ti core powershell
Windows PowerShell
Copyright (C) Microsoft Corporation. All rights reserved.

PS C:\> get-content temp\temp.txt
This is a TechDays workshop
```
</details>
&nbsp;<br />

Now change the file inside of the container and copy it back out to your host. Check the content of the changed and the original file
```bash
"Hello from inside the container" | Out-File temp\temp.txt
exit
docker cp core:c:\temp\temp.txt temp_changed.txt
cat .\temp_changed.txt
cat .\temp.txt
```

<details><summary markdown="span">Full output of the change and copy</summary>
```bash
PS C:\> "Hello from inside the container" | Out-File temp\temp.txt
PS C:\> exit
PS C:\Users\Verwalter> docker cp core:c:\temp\temp.txt temp_changed.txt
PS C:\Users\Verwalter> cat .\temp_changed.txt
Hello from inside the container
PS C:\Users\Verwalter> cat .\temp.txt
This is a TechDays workshop
```
</details>
&nbsp;<br />

### Use a bind mount to share files between host and container
To see files and changes "live" without copying, we will use a bind mount. This is only possible on startup, so we create a new container with param `-v`. Before that we create a folder on the host that we want to share. After starting the container, make sure that it actually is empty
```bash
mkdir c:\bind_mount
docker run -ti --name shared -v c:\bind_mount:c:\temp mcr.microsoft.com/windows/servercore:1809 powershell
dir c:\temp
```

<details><summary markdown="span">Full output of the container start and folder check</summary>
```bash
PS C:\Users\Verwalter> mkdir c:\bind_mount

    Directory: C:\

Mode                LastWriteTime         Length Name
----                -------------         ------ ----
d-----       11/10/2019   6:18 PM                bind_mount

PS C:\Users\Verwalter> docker run -ti --name shared -v c:\bind_mount:c:\temp mcr.microsoft.com/windows/servercore:1809 powershell
Windows PowerShell
Copyright (C) Microsoft Corporation. All rights reserved.

PS C:\> dir c:\temp
```
</details>
&nbsp;<br />

Now we create a file in the shared folder on your host. For that, go to the second PowerShell and run the following commands.
```bash
cd c:\bind_mount\
"Hello from the host" | Out-File temp.txt
```

<details><summary markdown="span">Full output of the file creation</summary>
```bash
PS C:\Users\Verwalter> cd c:\bind_mount\
PS C:\bind_mount> "Hello from the host" | Out-File temp.txt
```
</details>
&nbsp;<br />

After that, go back to the session inside of the container and check the content of the folder and the file. After that, overwrite it with new content
```bash
dir c:\temp
get-content c:\temp\temp.txt
"Hello from the container" | Out-File c:\temp\temp.txt
```

<details><summary markdown="span">Full output of details</summary>
```bash
PS C:\> dir c:\temp

    Directory: C:\temp

Mode                LastWriteTime         Length Name
----                -------------         ------ ----
-a----       11/10/2019   6:23 PM             44 temp.txt


PS C:\> get-content c:\temp\temp.txt
Hello from the host
PS C:\> "Hello from the container" | Out-File c:\temp\temp.txt
```
</details>
&nbsp;<br />

Finally, go back to the session on the host and check that the file has changed
```bash
get-content c:\bind_mount\temp.txt
```

<details><summary markdown="span">Full output of the content check</summary>
```bash
PS C:\bind_mount> get-content c:\bind_mount\temp.txt
Hello from the container
```
</details>
&nbsp;<br />

### See the bind mount in the inspect output
We have seen in lab 2 that all configuration of a container is visible through `docker inspect`. Run that command and also a filtered command to get that information
{% raw %}
```bash
docker inspect shared
docker inspect --format='{{ .HostConfig.Binds }}' shared
```
{% endraw %}

<details><summary markdown="span">Full output of the inspect commands</summary>
{% raw %}
```bash
PS C:\bind_mount> docker inspect shared
[
    {
        "Id": "1be91944c46e53ce2b44f3e8ff7e4e449f86b05025b51df3072e6b9b1185ddec",
        "Created": "2019-11-10T18:18:39.9106676Z",
        "Path": "powershell",
        "Args": [],
        "State": {
            "Status": "running",
            "Running": true,
            "Paused": false,
            "Restarting": false,
            "OOMKilled": false,
            "Dead": false,
            "Pid": 3212,
            "ExitCode": 0,
            "Error": "",
            "StartedAt": "2019-11-10T18:18:40.8331626Z",
            "FinishedAt": "0001-01-01T00:00:00Z"
        },
        "Image": "sha256:8392a5f2ef18001bd52f7d40dd074e0183f6a5d770c649468fe88fb851ea0aae",
        "ResolvConfPath": "",
        "HostnamePath": "",
        "HostsPath": "",
        "LogPath": "C:\\ProgramData\\docker\\containers\\1be91944c46e53ce2b44f3e8ff7e4e449f86b05025b51df3072e6b9b1185ddec\\1be91944c46e53ce2b44f3e8ff7e4e449f86b05025b51df3072e6b9b1185ddec-json.log",
        "Name": "/shared",
        "RestartCount": 0,
        "Driver": "windowsfilter",
        "Platform": "windows",
        "MountLabel": "",
        "ProcessLabel": "",
        "AppArmorProfile": "",
        "ExecIDs": null,
        "HostConfig": {
            "Binds": [
                "c:\\bind_mount:c:\\temp"
            ],
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
                "dir": "C:\\ProgramData\\docker\\windowsfilter\\1be91944c46e53ce2b44f3e8ff7e4e449f86b05025b51df3072e6b9b1185ddec"
            },
            "Name": "windowsfilter"
        },
        "Mounts": [
            {
                "Type": "bind",
                "Source": "c:\\bind_mount",
                "Destination": "c:\\temp",
                "Mode": "",
                "RW": true,
                "Propagation": ""
            }
        ],
        "Config": {
            "Hostname": "1be91944c46e",
            "Domainname": "",
            "User": "",
            "AttachStdin": true,
            "AttachStdout": true,
            "AttachStderr": true,
            "Tty": true,
            "OpenStdin": true,
            "StdinOnce": true,
            "Env": null,
            "Cmd": [
                "powershell"
            ],
            "Image": "mcr.microsoft.com/windows/servercore:1809",
            "Volumes": null,
            "WorkingDir": "",
            "Entrypoint": null,
            "OnBuild": null,
            "Labels": {}
        },
        "NetworkSettings": {
            "Bridge": "",
            "SandboxID": "1be91944c46e53ce2b44f3e8ff7e4e449f86b05025b51df3072e6b9b1185ddec",
            "HairpinMode": false,
            "LinkLocalIPv6Address": "",
            "LinkLocalIPv6PrefixLen": 0,
            "Ports": {},
            "SandboxKey": "1be91944c46e53ce2b44f3e8ff7e4e449f86b05025b51df3072e6b9b1185ddec",
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
                    "EndpointID": "df8bfb10dbdb602217e19bcce2f93b295c59583f168c4e377ce95a562d83e763",
                    "Gateway": "172.27.0.1",
                    "IPAddress": "172.27.7.193",
                    "IPPrefixLen": 16,
                    "IPv6Gateway": "",
                    "GlobalIPv6Address": "",
                    "GlobalIPv6PrefixLen": 0,
                    "MacAddress": "00:15:5d:1e:c4:59",
                    "DriverOpts": null
                }
            }
        }
    }
]
PS C:\bind_mount> docker inspect --format='{{ .HostConfig.Binds }}' shared
[c:\bind_mount:c:\temp]
```
{% endraw %}
</details>
&nbsp;<br />

{::options parse_block_html="false" /}