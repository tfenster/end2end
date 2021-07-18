---
layout: post
title: "MS SQL Server in Windows containers"
permalink: ms-sql-server-in-windows-containers
date: 2021-07-18 20:26:21
comments: false
description: "MS SQL Server in Windows containers"
keywords: ""
image: /images/sql-windows-container.png
categories:

tags:

---

Running databases in containers is maybe not the most intuitive usage of containers, but certainly stateful containers in general are no longer completely out of limits, and that means that databases in containers are also becoming more relevant. If you are working in the Microsoft ecosystem, then chances are that you will have at least some workloads running on MS SQL Server and as weird as that sounds, there are only supported container images for MS SQL Server on Linux. I am not kidding... Anyway, I had a need for it, so I decided to create a container image for it and share both the sources and the resulting images with the community.

## The TL;DR
There are two image types, one for the enterprise edition and one for the developer edition. But most importantly: **Both are completely unsupported, come as-is and are in no way connected to Microsoft!** If you run into any issues, I am happy to take a look if time permits, but you won't have any luck when asking Microsoft support for help. To run them, you need to reference the name and the version, either as technical version number or as &lt;major&gt;-cu&lt;cu&gt;. As a first release, I have 2019 CU 11 (15.0.4138.2). I plan to add new versions when they appear, but if you need another one, feel free to get in touch. To run it exposed on port 1433 of the container host with an SA password of "Super5ecret!", do the following for the developer edition image:

{% highlight bash linenos %}
docker run -p 1433:1433 -e accept_eula=y -e sa_password=Super5ecret! tobiasfenster/mssql-server-dev-unsupported:2019-cu11
{% endhighlight %}

For the express edition, it looks like this:

{% highlight bash linenos %}
docker run -p 1433:1433 -e accept_eula=y -e sa_password=Super5ecret! tobiasfenster/mssql-server-exp-unsupported:2019-cu11
{% endhighlight %}

Afterwards, you can use e.g. the Azure Data Studio to connect to your database server using your container hostname as server, SA as user and Super5ecret! as password. The home screen should have a part like this:

![screenshot of the Azure Data Studio home screen](/images/azure-data-studio.png)
{: .centered}

## The details: A bit of background and how the image works
As I wrote above, there is an [official, supported MS SQL Server container image for Linux][linux-image], but none for Windows. There used to be one for the [Express edition][windows-image-exp] and one for the [Developer edition][windows-image-dev] or actually they are still available, but the latest one is three years old for SQL Server 2017 CU3 and intended for Windows Server 2016. Not a particularly attractive proposition... There also was a private preview for SQL Server 2019 containers on Windows which had produced working images, but the preview ended without every going public and from what I heard, there probably won't be an official image soon.

When I built my images, I leaned heavily on the [Microsoft Github repo for SQL in Docker][msft-github] as well as on the [Microsoft Github repo for Business Central in Docker][nav-docker] as the latter also comes with SQL Express. The only fundamentally different thing I did is to include a step to optionally install a CU. The full Dockerfile looks like this:

{% highlight Dockerfile linenos %}
# escape=`
ARG BASE
FROM mcr.microsoft.com/dotnet/framework/runtime:4.8-windowsservercore-$BASE

ARG DEV_ISO= `
    EXP_EXE= `
    CU= `
    VERSION=`
    TYPE=
ENV DEV_ISO=$DEV_ISO `
    EXP_EXE=$EXP_EXE `
    CU=$CU `
    VERSION=$VERSION `
    sa_password="_" `
    attach_dbs="[]" `
    accept_eula="_" `
    sa_password_path="C:\ProgramData\Docker\secrets\sa-password"

LABEL org.opencontainers.image.authors="Tobias Fenster (https://tobiasfenster.io)"
LABEL org.opencontainers.image.source="https://github.com/tfenster/mssql-image"
LABEL org.opencontainers.image.description="An unofficial, unsupported and in no way connected to Microsoft container image for MS SQL Server"
LABEL org.opencontainers.image.version=$VERSION-$TYPE

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]
USER ContainerAdministrator

RUN $ProgressPreference = 'SilentlyContinue'; `
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')); `
    choco feature enable -n allowGlobalConfirmation; `
    choco install --no-progress --limit-output vim 7zip sqlpackage; `
    refreshenv;

RUN if (-not [string]::IsNullOrEmpty($env:DEV_ISO)) { `
        Invoke-WebRequest -UseBasicParsing -Uri $env:DEV_ISO -OutFile c:\SQLServer.iso; `
        mkdir c:\installer; `
        7z x -y -oc:\installer .\SQLServer.iso; `
        .\installer\setup.exe /q /ACTION=Install /INSTANCENAME=MSSQLSERVER /FEATURES=SQLEngine /UPDATEENABLED=0 /SQLSVCACCOUNT='NT AUTHORITY\NETWORK SERVICE' /SQLSYSADMINACCOUNTS='BUILTIN\ADMINISTRATORS' /TCPENABLED=1 /NPENABLED=0 /IACCEPTSQLSERVERLICENSETERMS; `
        remove-item c:\SQLServer.iso -ErrorAction SilentlyContinue; `
        remove-item -recurse -force c:\installer -ErrorAction SilentlyContinue; `
    }

RUN if (-not [string]::IsNullOrEmpty($env:EXP_EXE)) { `
        Invoke-WebRequest -UseBasicParsing -Uri $env:EXP_EXE -OutFile c:\SQLServerExpress.exe; `
        Start-Process -Wait -FilePath .\SQLServerExpress.exe -ArgumentList /qs, /x:installer ; `
        .\installer\setup.exe /q /ACTION=Install /INSTANCENAME=SQLEXPRESS /FEATURES=SQLEngine /UPDATEENABLED=0 /SQLSVCACCOUNT='NT AUTHORITY\NETWORK SERVICE' /SQLSYSADMINACCOUNTS='BUILTIN\ADMINISTRATORS' /TCPENABLED=1 /NPENABLED=0 /IACCEPTSQLSERVERLICENSETERMS; `
        remove-item c:\SQLServerExpress.exe -ErrorAction SilentlyContinue; `
        remove-item -recurse -force c:\installer -ErrorAction SilentlyContinue; `
    } 

RUN $SqlServiceName = 'MSSQLSERVER'; `
    if ($env:TYPE -eq 'exp') { `
        $SqlServiceName = 'MSSQL$SQLEXPRESS'; `
    } `
    While (!(get-service $SqlServiceName -ErrorAction SilentlyContinue)) { Start-Sleep -Seconds 5 } ; `
    Stop-Service $SqlServiceName ; `
    $databaseFolder = 'c:\databases'; `
    mkdir $databaseFolder; `
    $SqlWriterServiceName = 'SQLWriter'; `
    $SqlBrowserServiceName = 'SQLBrowser'; `
    Set-Service $SqlServiceName -startuptype automatic ; `
    Set-Service $SqlWriterServiceName -startuptype manual ; `
    Stop-Service $SqlWriterServiceName; `
    Set-Service $SqlBrowserServiceName -startuptype manual ; `
    Stop-Service $SqlBrowserServiceName; `
    $SqlTelemetryName = 'SQLTELEMETRY'; `
    if ($env:TYPE -eq 'exp') { `
        $SqlTelemetryName = 'SQLTELEMETRY$SQLEXPRESS'; `
    } `
    Set-Service $SqlTelemetryName -startuptype manual ; `
    Stop-Service $SqlTelemetryName; `
    $version = [System.Version]::Parse($env:VERSION); `
    $id = ('mssql' + $version.Major + '.MSSQLSERVER'); `
    if ($env:TYPE -eq 'exp') { `
        $id = ('mssql' + $version.Major + '.SQLEXPRESS'); `
    } `
    Set-itemproperty -path ('HKLM:\software\microsoft\microsoft sql server\' + $id + '\mssqlserver\supersocketnetlib\tcp\ipall') -name tcpdynamicports -value '' ; `
    Set-itemproperty -path ('HKLM:\software\microsoft\microsoft sql server\' + $id + '\mssqlserver\supersocketnetlib\tcp\ipall') -name tcpdynamicports -value '' ; `
    Set-itemproperty -path ('HKLM:\software\microsoft\microsoft sql server\' + $id + '\mssqlserver\supersocketnetlib\tcp\ipall') -name tcpport -value 1433 ; `
    Set-itemproperty -path ('HKLM:\software\microsoft\microsoft sql server\' + $id + '\mssqlserver') -name LoginMode -value 2; `
    Set-itemproperty -path ('HKLM:\software\microsoft\microsoft sql server\' + $id + '\mssqlserver') -name DefaultData -value $databaseFolder; `
    Set-itemproperty -path ('HKLM:\software\microsoft\microsoft sql server\' + $id + '\mssqlserver') -name DefaultLog -value $databaseFolder; 

RUN if (-not [string]::IsNullOrEmpty($env:CU)) { `
        $ProgressPreference = 'SilentlyContinue'; `
        Write-Host ('Install CU from ' + $env:CU) ; `
        Invoke-WebRequest -UseBasicParsing -Uri $env:CU -OutFile c:\SQLServer-cu.exe ; `
        .\SQLServer-cu.exe /q /IAcceptSQLServerLicenseTerms /Action=Patch /AllInstances ; `
        $try = 0; `
        while ($try -lt 20) { `
            try { `
                $var = sqlcmd -Q 'select SERVERPROPERTY(''productversion'') as version' -W -m 1 | ConvertFrom-Csv | Select-Object -Skip 1 ; `
                if ($var.version[0] -eq $env:VERSION) { `
                    Write-Host ('Patch done, found expected version ' + $var.version[0]) ; `
                    $try = 21 ; `
                } else { `
                    Write-Host ('Patch seems to be ongoing, found version ' + $var.version[0] + ', try ' + $try) ; `
                } `
            } catch { `
                Write-Host 'Something unexpected happened, try' $try ; `
                Write-Host $_.ScriptStackTrace ; `
            } finally { `
                if ($try -lt 20) { `
                    Start-Sleep -Seconds 60 ; `
                } `
                $try++ ; `
            } `
        } `
        if ($try -eq 20) { `
            Write-Error 'Patch failed' `
        } else { `
            Write-Host 'Successfully patched!' `
        } `
    } `
    remove-item c:\SQLServer-cu.exe -ErrorAction SilentlyContinue; 

WORKDIR c:\scripts
COPY .\start.ps1 c:\scripts\

CMD .\start.ps1
{% endhighlight %}

The first thing worth mentioning is the base image, which is the runtime of .NET Framework 4.8 (line 3). This also limits the number of base OS versions my image can support, because I'll stick with the ones supported by the base image, i.e. Windows Server 2019 LTSC, 2004 and 20H2. If and when the .NET Framework 4.8 runtime supports more base images, I'll also support them.

After some variables and labels, I install vim (you never know when you want to edit a file), 7zip as I use an ISO later and sqlpackage for the client stuff. For the installation, I use [chocolatey][choco] (lines 27-31). I then use a build arg `DEV_ISO` to share the download path of the developer edition iso file or `EXP_EXE` to share the download path of the Express Edition installer. Those are downloaded, extracted, setup is started and the source files are deleted again (lines 33-40 for the dev edition, lines 42-48 for the Express Edition. After that, the services, especially their startup behavior and some registry settings are done (lines 50-81). Last but not least, a potential CU is also downloaded and installed (lines 83-114). To trigger the build for a 20H2 image of SQL Server 2019 Express Edition CU 11, you would run something like this:

{% highlight bash linenos %}
docker build --build-arg BASE=20H2 --build-arg EXP_EXE=https://download.microsoft.com/download/7/c/1/7c14e92e-bdcb-4f89-b7cf-93543e7112d1/SQLEXPR_x64_ENU.exe 
--build-arg CU=https://download.microsoft.com/download/6/e/7/6e72dddf-dfa4-4889-bc3d-e5d3a0fd11ce/SQLServer2019-KB5003249-x64.exe 
--build-arg VERSION=15.0.4138.2 --build-arg TYPE=exp -t tobiasfenster/mssql-server-exp-unsupported:2019-CU11 .
{% endhighlight %}

Of course I am also sharing them through the Docker hub ([Developer Edition][hub-dev] and [Express Edition][hub-exp]), so you don't need to build them and instead just can run them with the commands explained above. 

Maybe also interesting: I created a multi-arch manifest for the three base image versions (Windows Server 2019 LTSC, 2004 and 20H2), which means that you can just reference `tobiasfenster/mssql-server-dev-unsupported:2019-cu11` and you will get e.g. `tobiasfenster/mssql-server-dev-unsupported:2019-cu11-20H2` on a 20H2 container host.

I hope some of you will find this useful and if you have ideas for improvement or find bugs that neeed to be fixed, please let me know through the [Github repo][github-image]

[linux-image]: https://hub.docker.com/_/microsoft-mssql-server
[windows-image-exp]: https://hub.docker.com/r/microsoft/mssql-server-windows-express/
[windows-image-dev]: https://hub.docker.com/r/microsoft/mssql-server-windows-developer/
[msft-github]: https://github.com/microsoft/mssql-docker/tree/3d2c7d0779124ff4a1cccc9a21e7b038118f623f/windows/mssql-server-windows-developer
[nav-docker]: https://github.com/microsoft/nav-docker/tree/37f46a5ff31b4e31918ada62c289780f4e321022
[choco]: https://www.chocolatey.org
[hub-dev]: https://hub.docker.com/r/tobiasfenster/mssql-server-dev-unsupported
[hub-exp]: https://hub.docker.com/repository/docker/tobiasfenster/mssql-server-exp-unsupported
[github-image]: https://github.com/tfenster/mssql-image/