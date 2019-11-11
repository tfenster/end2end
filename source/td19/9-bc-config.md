---
layout: page
title: "9 Business Central configuration"
description: ""
keywords: ""
permalink: "td19-9-bc-config"
slug: "td19-9-bc-config"
---
{::options parse_block_html="true" /}
Table of content
- [Custom NAV / BC settings and Web settings](#custom-nav--bc-settings-and-web-settings)
- [Use Windows authentication and enable ClickOnce](#use-windows-authentication-and-enable-clickonce)
- [Connect to an external SQL Server](#connect-to-an-external-sql-server)

&nbsp;<br />
### Custom NAV / BC settings and Web settings
There are hundreds of configuration options for both NAV / BC and the WebClient. While some of them made it to easily accessible environment variables of the Docker containers, you might end up in a situation where you want to set a specific setting on container startup. This is easily done with the `customNavSettings` and `customWebSettings` parameters as follows where we disable Word and Excel export and also set "TechDays" as product name for the WebClient
```bash
docker run -e usessl=n -e accept_eula=y -e customNavSettings=EnableSaveToExcelForRdlcReports=false,EnableSaveToWordForRdlcReports=false -e customWebSettings=Productname=TechDays --name custom mcr.microsoft.com/businesscentral/onprem:ltsc2019
```

<details><summary markdown="span">Full output of docker run</summary>
```bash
PS C:\> docker run -e usessl=n -e accept_eula=y -e customNavSettings=EnableSaveToExcelForRdlcReports=false,EnableSaveToWordForRdlcReports=false -e customWebSettings=Productname=TechDays --name custom mcr.microsoft.com/businesscentral/onprem:ltsc2019
Initializing...
Starting Container
Hostname is 7ac17d457294
PublicDnsName is 7ac17d457294
Using NavUserPassword Authentication
Starting Local SQL Server
Starting Internet Information Server
Creating Self Signed Certificate
Self Signed Certificate Thumbprint E4FE563C6BC9CF4EEAC094E4DFEF1503AA59BEA4
Modifying Service Tier Config File with Instance Specific Settings
Modifying Service Tier Config File with settings from environment variable
Setting EnableSaveToExcelForRdlcReports to false
Setting EnableSaveToWordForRdlcReports to false
Starting Service Tier
Registering event sources
Creating DotNetCore Web Server Instance
Modifying Web Client config with settings from environment variable
Creating Productname and setting it to TechDays
Creating http download site
Setting SA Password and enabling SA
Creating admin as SQL User and add to sysadmin
Creating SUPER user
Container IP Address: 172.27.11.42
Container Hostname  : 7ac17d457294
Container Dns Name  : 7ac17d457294
Web Client          : http://7ac17d457294/BC/
Admin Username      : admin
Admin Password      : Zove4171
Dev. Server         : http://7ac17d457294
Dev. ServerInstance : BC

Files:
http://7ac17d457294:8080/al-4.0.194000.vsix

Initialization took 47 seconds
Ready for connections!
Starting EventLog Monitor
Monitoring EventSources from EventLog[Application]:
- MicrosoftDynamicsNAVClientClientService
- MicrosoftDynamicsNAVClientWebClient
- MicrosoftDynamicsNavServer$BC
- MSSQL$SQLEXPRESS
```
</details>
&nbsp;<br />
After that, open your local browser at http://&lt;ip&gt;/BC and enter username and password as provided. You should see "TechDays" in the top left corner and if you open a report and select "Send to...", you should see onl "PDF Document" and "Schedule..." as we disabled Word and Excel export.
&nbsp;<br />
Don't stop this container as we will be usig it again in a later part of the lab. Also note down the password as we will need that later as well.

### Use Windows authentication and enable ClickOnce
The second example is a bit more old-school as it will allow us to use ClickOnce (param `clickonce=y`) to get the old Windows Client and also use Windows authentication (params `username` and `password`). Make sure to use your username and password as provided for the VM. As ClickOnce and SSO are sensitive to the network names, we also add `--name sso --hostname sso`.
```bash
docker run -e accept_eula=y --name sso --hostname sso -e auth=windows -e username=Verwalter -e password=Passw0rd*123 -e clickonce=y
```

<details><summary markdown="span">Full output of details</summary>
```bash
PS C:\> docker run -e accept_eula=y --name sso --hostname sso -e auth=windows -e username=Verwalter -e password=Passw0rd*123 -e clickonce=y mcr.microsoft.com/dynamicsnav:2018-gb-ltsc2019
Initializing...
Starting Container
Hostname is sso
PublicDnsName is sso
Using Windows Authentication
Starting Local SQL Server
Starting Internet Information Server
Modifying Service Tier Config File with Instance Specific Settings
Starting Service Tier
Registering event sources
Creating DotNetCore Web Server Instance
Creating http download site
Creating Windows user Verwalter
Setting SA Password and enabling SA
Creating SUPER user
Creating ClickOnce Manifest
Container IP Address: 172.27.8.80
Container Hostname  : sso
Container Dns Name  : sso
Web Client          : http://sso/NAV/
Dev. Server         : http://sso
Dev. ServerInstance : NAV
ClickOnce Manifest  : http://sso:8080/NAV

Files:
http://sso:8080/al-0.13.149996.vsix

Initialization took 71 seconds
Ready for connections!
Starting EventLog Monitor
Monitoring EventSources from EventLog[Application]:
- MicrosoftDynamicsNAVClientClientService
- MicrosoftDynamicsNAVClientWebClient
- MicrosoftDynamicsNavServer$NAV
- MSSQL$SQLEXPRESS
```
</details>
&nbsp;<br />
To make sure we can access the container by name, we need to add an entry to the hosts file of our host VM. Make sure to replace the IP address with the one provided in the log output of your container. After that, ping sso to make sure the connection works
```bash
Add-Content C:\Windows\System32\drivers\etc\hosts '172.27.8.80 sso'
ping sso
```
After that, you can open [http://sso:8080/NAV](http://sso:8080/NAV) and install the Windows Client from there after checking the "I accept the license"-chechbox. The ClickOnce client comes pre-configured, so it should automatically connect you to the right instance on startup and as we enabled Windows authentication, you should also be automatically logged in. You can even install C/SIDE through ClickOnce, but make sure to also install the SQL Native Client referenced under "Required components".

### Connect to an external SQL Server
Connecting a container to an already existing database is a common use case, so we are going to do that here as well. We will reuse the database in our container from the first example. First we enter the container, stop the SQL service, exit the container again and copy the database files to the host
```bash
docker exec -ti custom powershell
stop-service MSSQL`$SQLEXPRESS
exit
docker cp custom:c:\databases\ .
dir .\databases\
```

<details><summary markdown="span">Full output of the SQL database preparation</summary>
```bash
PS C:\> docker exec -ti custom powershell
Windows PowerShell
Copyright (C) Microsoft Corporation. All rights reserved.

PS C:\> stop-service MSSQL`$SQLEXPRESS
PS C:\> exit
PS C:\> docker cp custom:c:\databases\ .
PS C:\> dir .\databases\

    Directory: C:\databases

Mode                LastWriteTime         Length Name
----                -------------         ------ ----
-a----       11/11/2019   2:40 PM        4325376 Demo Database NAV (15-0).ldf
-a----       11/11/2019   2:40 PM      256573440 Demo Database NAV (15-0).mdf

```
</details>
&nbsp;<br />

Now we have the database files on our host VM, so we don't need the custom container anymore and you can delete it, if you want. The next step is to create a SQL Server container which attaches the Cronus database on startup. We bind mount our database folder into the container to give it access to the files and we set a password for the default sa user.
```bash
docker run --hostname sql --name sql -v C:/databases/:C:/databases/ -e sa_password=Passw0rd*123 -e ACCEPT_EULA=Y -e attach_dbs="[{'dbName':'Cronus','dbFiles':['C:\\databases\\Demo Database NAV (15-0).mdf','C:\\databases\\Demo Database NAV (15-0).ldf']}]" chrml/mssql-server-windows-express:1809
```

<details><summary markdown="span">Full output of SQL start and attach</summary>
```bash
PS C:\> docker run --hostname sql --name sql -v C:/databases/:C:/databases/ -e sa_password=Passw0rd*123 -e ACCEPT_EULA=Y -e attach_dbs="[{'dbName':'Cronus','dbFiles':['C:\\databases\\Demo Database NAV (15-0).mdf','C:\\databases\\Demo Database NAV (15-0).ldf']}]" chrml/mssql-server-windows-express:1809
VERBOSE: Starting SQL Server
VERBOSE: Changing SA login credentials
VERBOSE: Attaching 1 database(s)
VERBOSE: Invoke-Sqlcmd -Query IF EXISTS (SELECT 1 FROM SYS.DATABASES WHERE NAME
 = 'Cronus') BEGIN EXEC sp_detach_db [Cronus] END;CREATE DATABASE [Cronus] ON
(FILENAME = N'C:\databases\Demo Database NAV (15-0).mdf'),(FILENAME =
N'C:\databases\Demo Database NAV (15-0).ldf') FOR ATTACH;
VERBOSE: Started SQL Server.
```
</details>
&nbsp;<br />

With our SQL Server container ready for connections, we can now start our BC container again, but this time tell it to connect to the container. You will see that the ouput no longer shows "Starting local SQL Server" as it is now connecting to our SQL container instead.
```bash
docker run -e usessl=n -e accept_eula=y -e databaseusername=sa -e databasepassword=Passw0rd*123 -e databaseserver=sql -e databasename=Cronus --name custom mcr.microsoft.com/businesscentral/onprem:ltsc2019
```

<details><summary markdown="span">Full output of the docker run</summary>
```bash
PS C:\> docker run -e usessl=n -e accept_eula=y -e databaseusername=sa -e databasepassword=Passw0rd*123 -e databaseserver=sql -e databasename=Cronus --name custom mcr.microsoft.com/businesscentral/onprem:ltsc2019
Initializing...
Starting Container
Hostname is dbaf0b667ef5
PublicDnsName is dbaf0b667ef5
Using NavUserPassword Authentication
Starting Internet Information Server
Import Encryption Key
Creating Self Signed Certificate
Self Signed Certificate Thumbprint 6E46F1D91471B06580640091CFE96DF4B037824F
Modifying Service Tier Config File with Instance Specific Settings
Starting Service Tier
Registering event sources
Creating DotNetCore Web Server Instance
Creating http download site
Container IP Address: 172.27.10.250
Container Hostname  : dbaf0b667ef5
Container Dns Name  : dbaf0b667ef5
Web Client          : http://dbaf0b667ef5/BC/
Dev. Server         : http://dbaf0b667ef5
Dev. ServerInstance : BC

Files:
http://dbaf0b667ef5:8080/al-4.0.194000.vsix

Initialization took 41 seconds
Ready for connections!
Starting EventLog Monitor
Monitoring EventSources from EventLog[Application]:
- MicrosoftDynamicsNAVClientClientService
- MicrosoftDynamicsNAVClientWebClient
- MicrosoftDynamicsNavServer$BC
- MSSQL$SQLEXPRESS
```
</details>
&nbsp;<br />
This is now a multi-container environment, so it makes sense to put it into a compose file. You can either try to create it yourself or find the solution under Desktop\sources\presentation-src-techdays-19\bc-compose where the [docker-compose.yml](https://github.com/tfenster/presentation-src/blob/techdays-19/bc-compose/docker-compose.yml) is stored.
&nbsp;<br />
Stop the other containers and then call `docker-compose up` to start them again, this time using the definition in the compose file

```bash
docker rm -f sql
docker rm -f custom
cd ~\Desktop\sources\presentation-src-techdays-19\bc-compose
docker-compose up
```

<details><summary markdown="span">Full output of docker-compose up</summary>
```bash
PS C:\> docker rm -f sql
sql
PS C:\> docker rm -f custom
custom
PS C:\> cd ~\Desktop\sources\presentation-src-techdays-19\bc-compose
PS C:\Users\Verwalter\Desktop\sources\presentation-src-techdays-19\bc-compose> docker-compose up
Creating temp_sql_1 ... done
Creating temp_nav_1 ... done
Attaching to temp_sql_1, temp_nav_1
nav_1  | Initializing...
nav_1  | Starting Container
nav_1  | Hostname is nav
nav_1  | PublicDnsName is nav
sql_1  | VERBOSE: Starting SQL Server
nav_1  | Using NavUserPassword Authentication
sql_1  | VERBOSE: Changing SA login credentials
nav_1  | Starting Internet Information Server
sql_1  | VERBOSE: Attaching 1 database(s)
sql_1  | VERBOSE: Invoke-Sqlcmd -Query IF EXISTS (SELECT 1 FROM SYS.DATABASES WHERE NAME
sql_1  |  = 'Cronus') BEGIN EXEC sp_detach_db [Cronus] END;CREATE DATABASE [Cronus] ON
sql_1  | (FILENAME = N'C:\databases\Demo Database NAV (15-0).mdf'),(FILENAME =
sql_1  | N'C:\databases\Demo Database NAV (15-0).ldf') FOR ATTACH;
sql_1  | VERBOSE: Started SQL Server.
sql_1  |
nav_1  | Import Encryption Key
nav_1  | Creating Self Signed Certificate
nav_1  | Self Signed Certificate Thumbprint 8B18EC474C70CEEE0C59EC9AA020871BC6CAD0CC
nav_1  | Modifying Service Tier Config File with Instance Specific Settings
nav_1  | Starting Service Tier
sql_1  | TimeGenerated           EntryType Message
sql_1  | -------------           --------- -------
sql_1  | 11/11/2019 3:06:49 PM Information Parallel redo is shutdown for database 'Cr...
sql_1  | 11/11/2019 3:06:49 PM Information Recovery is writing a checkpoint in databa...
sql_1  | 11/11/2019 3:06:49 PM Information 0 transactions rolled back in database 'Cr...
sql_1  | 11/11/2019 3:06:49 PM Information 65 transactions rolled forward in database...
sql_1  | 11/11/2019 3:06:49 PM Information Parallel redo is started for database 'Cro...
sql_1  | 11/11/2019 3:06:49 PM Information Starting up database 'Cronus'.
sql_1  | 11/11/2019 3:06:55 PM Information Parallel redo is shutdown for database 'Cr...
sql_1  | 11/11/2019 3:06:55 PM Information Parallel redo is started for database 'Cro...
sql_1  | 11/11/2019 3:06:55 PM Information Starting up database 'Cronus'.
nav_1  | Registering event sources
nav_1  | Creating DotNetCore Web Server Instance
nav_1  | Creating http download site
nav_1  | Container IP Address: 172.27.1.213
nav_1  | Container Hostname  : nav
nav_1  | Container Dns Name  : nav
nav_1  | Web Client          : http://nav/BC/
nav_1  | Dev. Server         : http://nav
nav_1  | Dev. ServerInstance : BC
nav_1  |
nav_1  | Files:
nav_1  | http://nav:8080/al-4.0.194000.vsix
nav_1  |
nav_1  | Initialization took 41 seconds
nav_1  | Ready for connections!
nav_1  | Starting EventLog Monitor
nav_1  | Monitoring EventSources from EventLog[Application]:
nav_1  | - MicrosoftDynamicsNAVClientClientService
nav_1  | - MicrosoftDynamicsNAVClientWebClient
nav_1  | - MicrosoftDynamicsNavServer$BC
nav_1  | - MSSQL$SQLEXPRESS
```
</details>
&nbsp;<br />
Verify that you can connect by going to http://&lt;ip&gt;/BC and logging in. Now that we have everything in place, we can easily extend this, e.g. to also include a test environment. All we need to do is copy the database files to a new folder, tell the SQL container about that and add a second BC container connected to the test database. To be able to reach them easier, we'll also map the ports to host ports. And to make sure we always now which environment we are using, we set the Product name property accordingly. Those changes are already done in the [docker-compose.extended.yml](https://github.com/tfenster/presentation-src/blob/techdays-19/bc-compose/docker-compose.extended.yml) file

```bash
docker-compose down
copy -r c:\databases\ c:\databases-test
docker-compose -f docker-compose.extended.yml up
```

<details><summary markdown="span">Full output of the extended run</summary>
```bash
PS C:\Users\Verwalter\Desktop\sources\presentation-src-techdays-19\bc-compose> docker-compose -f docker-compose.extended.yml up
Creating bc-compose_sql_1 ... done
Creating bc-compose_nav-test_1 ... done
Creating bc-compose_nav_1      ... done
Attaching to bc-compose_sql_1, bc-compose_nav_1, bc-compose_nav-test_1
nav_1       | Initializing...
nav-test_1  | Initializing...
nav-test_1  | Starting Container
nav_1       | Starting Container
nav_1       | Hostname is nav
nav_1       | PublicDnsName is nav
nav-test_1  | Hostname is nav-test
nav-test_1  | PublicDnsName is nav-test
sql_1       | VERBOSE: Starting SQL Server
nav-test_1  | Using NavUserPassword Authentication
nav_1       | Using NavUserPassword Authentication
nav-test_1  | Starting Internet Information Server
nav_1       | Starting Internet Information Server
sql_1       | VERBOSE: Changing SA login credentials
sql_1       | VERBOSE: Attaching 2 database(s)
sql_1       | VERBOSE: Invoke-Sqlcmd -Query IF EXISTS (SELECT 1 FROM SYS.DATABASES WHERE NAME
sql_1       |  = 'Cronus') BEGIN EXEC sp_detach_db [Cronus] END;CREATE DATABASE [Cronus] ON
sql_1       | (FILENAME = N'C:\databases\Demo Database NAV (15-0).mdf'),(FILENAME =
sql_1       | N'C:\databases\Demo Database NAV (15-0).ldf') FOR ATTACH;
sql_1       | VERBOSE: Invoke-Sqlcmd -Query IF EXISTS (SELECT 1 FROM SYS.DATABASES WHERE NAME
sql_1       |  = 'CronusTest') BEGIN EXEC sp_detach_db [CronusTest] END;CREATE DATABASE
sql_1       | [CronusTest] ON (FILENAME = N'C:\databases-test\Demo Database NAV
sql_1       | (15-0).mdf'),(FILENAME = N'C:\databases-test\Demo Database NAV (15-0).ldf') FOR
sql_1       |  ATTACH;
sql_1       | VERBOSE: Started SQL Server.
sql_1       |
nav_1       | Import Encryption Key
nav-test_1  | Import Encryption Key
sql_1       | TimeGenerated           EntryType Message
sql_1       | -------------           --------- -------
sql_1       | 11/11/2019 3:34:27 PM Information Parallel redo is shutdown for database 'Cr...
sql_1       | 11/11/2019 3:34:27 PM Information Parallel redo is started for database 'Cro...
sql_1       | 11/11/2019 3:34:27 PM Information Starting up database 'CronusTest'.
sql_1       | 11/11/2019 3:34:27 PM Information Parallel redo is shutdown for database 'Cr...
sql_1       | 11/11/2019 3:34:27 PM Information Parallel redo is started for database 'Cro...
sql_1       | 11/11/2019 3:34:26 PM Information Starting up database 'Cronus'.
sql_1       | 11/11/2019 3:34:29 PM Information Parallel redo is shutdown for database 'Cr...
sql_1       | 11/11/2019 3:34:29 PM Information Parallel redo is shutdown for database 'Cr...
sql_1       | 11/11/2019 3:34:29 PM Information Parallel redo is started for database 'Cro...
sql_1       | 11/11/2019 3:34:29 PM Information Parallel redo is started for database 'Cro...
sql_1       | 11/11/2019 3:34:29 PM Information Starting up database 'CronusTest'.
sql_1       | 11/11/2019 3:34:29 PM Information Starting up database 'Cronus'.
nav_1       | Creating Self Signed Certificate
nav-test_1  | Creating Self Signed Certificate
nav_1       | Self Signed Certificate Thumbprint A37FDFF9902061E67994B8F5E27B54EDF4FC692F
nav-test_1  | Self Signed Certificate Thumbprint 40298476F6732A831D4F980191FF2F52B6E007F5
nav_1       | Modifying Service Tier Config File with Instance Specific Settings
nav-test_1  | Modifying Service Tier Config File with Instance Specific Settings
nav_1       | Starting Service Tier
nav-test_1  | Starting Service Tier
sql_1       | 11/11/2019 3:34:33 PM Information Parallel redo is shutdown for database 'Cr...
sql_1       | 11/11/2019 3:34:33 PM Information Parallel redo is started for database 'Cro...
sql_1       | 11/11/2019 3:34:32 PM Information Parallel redo is shutdown for database 'Cr...
sql_1       | 11/11/2019 3:34:32 PM Information Parallel redo is started for database 'Cro...
sql_1       | 11/11/2019 3:34:32 PM Information Starting up database 'CronusTest'.
sql_1       | 11/11/2019 3:34:32 PM Information Starting up database 'Cronus'.
nav_1       | Registering event sources
nav_1       | Creating DotNetCore Web Server Instance
nav-test_1  | Registering event sources
nav-test_1  | Creating DotNetCore Web Server Instance
nav_1       | Modifying Web Client config with settings from environment variable
nav-test_1  | Modifying Web Client config with settings from environment variable
nav_1       | Creating Productname and setting it to Production
nav-test_1  | Creating Productname and setting it to Test
nav_1       | Creating http download site
nav-test_1  | Creating http download site
nav-test_1  | Container IP Address: 172.27.10.151
nav-test_1  | Container Hostname  : nav-test
nav_1       | Container IP Address: 172.27.11.215
nav-test_1  | Container Dns Name  : nav-test
nav_1       | Container Hostname  : nav
nav-test_1  | Web Client          : http://nav-test/BC/
nav_1       | Container Dns Name  : nav
nav_1       | Web Client          : http://nav/BC/
nav-test_1  | Dev. Server         : http://nav-test
nav-test_1  | Dev. ServerInstance : BC
nav_1       | Dev. Server         : http://nav
nav_1       | Dev. ServerInstance : BC
nav-test_1  |
nav_1       |
nav-test_1  | Files:
nav_1       | Files:
nav-test_1  | http://nav-test:8080/al-4.0.194000.vsix
nav-test_1  |
nav_1       | http://nav:8080/al-4.0.194000.vsix
nav_1       |
nav-test_1  | Initialization took 41 seconds
nav-test_1  | Ready for connections!
nav_1       | Initialization took 41 seconds
nav_1       | Ready for connections!
nav-test_1  | Starting EventLog Monitor
nav_1       | Starting EventLog Monitor
nav-test_1  | Monitoring EventSources from EventLog[Application]:
nav-test_1  | - MicrosoftDynamicsNAVClientClientService
nav-test_1  | - MicrosoftDynamicsNAVClientWebClient
nav-test_1  | - MicrosoftDynamicsNavServer$BC
nav_1       | Monitoring EventSources from EventLog[Application]:
nav-test_1  | - MSSQL$SQLEXPRESS
nav-test_1  |
nav_1       | - MicrosoftDynamicsNAVClientClientService
nav_1       | - MicrosoftDynamicsNAVClientWebClient
nav_1       | - MicrosoftDynamicsNavServer$BC
nav_1       | - MSSQL$SQLEXPRESS
```
</details>
&nbsp;<br />
When both BC containers are ready, go to [http://localhost/BC](http://localhost/BC) and [http://localhost:8080/BC](http://localhost:8080/BC) to see both environments. You should see "Production" in the top left of one environment and "Test" in the other one. You can e.g. post an open Sales Order in one environment and then check the other one to make sure that you indeed have two separate environments. If you want to give it a try, see if you can extend this example to also include a Staging environment on port 8180.
&nbsp;<br />
In the end, stop it all with `docker-compose -f docker-compose.extended.yml down` again
{::options parse_block_html="true" /}