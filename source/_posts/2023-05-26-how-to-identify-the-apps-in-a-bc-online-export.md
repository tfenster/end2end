---
layout: post
title: "How to identify the apps in a BC Online export"
permalink: how-to-identify-the-apps-in-a-bc-online-export
date: 2023-05-26 16:40:45
comments: false
description: "How to identify the apps in a BC Online export"
keywords: ""
image: /images/bc-online-export.png
categories:

tags:

---

This is going to be a very short blog post, but hopefully still helpful for those of you in the same situation as me: How can I find out what apps are installed in an export from a Microsoft Dynamics 365 Business Central Online environment?

As [Freddy Kristiansen in his blog][freddy] and others have shared before, it is possible to use a BC Online environment export ([this][export] explains how to create one) and restore it in an onprem environment. In [COSMO Alpaca][alpaca] this is fully automated, so fortunately I don't have to deal with all the setup and scripting for this, but one challenge remains: How can I find out in advance, which apps in which versions I will need? I can let the process run until it fails to mount the tenant database because of missing apps, but I can get there easier and faster: If the export is restored to a database even without BC connected to it, I can use the following SQL commands to find out

{% highlight SQL linenos %}
SELECT Name, Publisher, [Version Major], [Version Minor], [Version Build], [Version Revision], [App ID], [Package ID], [Extension Type], [Published As], [Compatibility Major], [Compatibility Minor], [Compatibility Build], [Compatibility Revision] FROM [mydb].[dbo].[NAV App Installed App]
SELECT Name, Publisher, [Version Major], [Version Minor], [Version Build], [Version Revision], [App ID], [Package ID] FROM [mydb].[dbo].[NAV App Published App]
{% endhighlight %}

As you have probably guessed, the first one gives you the installed apps, and the second one the published apps. If you don't happen to have a SQL Server readily available, you can easily just use a container:

{% highlight bash linenos %}
docker run -e 'ACCEPT_EULA=Y' -e 'MSSQL_SA_PASSWORD=YourStrong!Passw0rd' --name 'sql1' -p 1401:1433 -d mcr.microsoft.com/mssql/server:2022-latest
{% endhighlight %}

Note that Microsoft only releases official SQL images for Linux (I am not kidding), but with e.g. [Docker Desktop][dd] and the [WSL][wsl] backend that is not a problem even on a Windows machine. Once that is up and running, you can use e.g. the [Azure Data Studio][ads] to connect and restore the database and execute these commands. If you automate the process, you can also use the following commands to run the above commands directly in the container:

{% highlight bash linenos %}
/opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P 'YourStrong!Passw0rd' -Q 'SELECT Name, Publisher, [Version Major], [Version Minor], [Version Build], [Version Revision], [App ID], [Package ID], [Extension Type], [Published As], [Compatibility Major], [Compatibility Minor], [Compatibility Build], [Compatibility Revision] FROM [mydb].[dbo].[NAV App Installed App]'
/opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P 'YourStrong!Passw0rd' -Q 'SELECT Name, Publisher, [Version Major], [Version Minor], [Version Build], [Version Revision], [App ID], [Package ID] FROM [mydb].[dbo].[NAV App Published App]'
{% endhighlight %}

That's what I wanted to share this time. As I wrote in the beginning, not much, but I hope it is still useful :)

[freddy]: https://freddysblog.com/2021/03/02/restoring-your-online-business-central-database-locally/
[export]: https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/tenant-admin-center-database-export
[alpaca]: https://cosmoconsult.com/alpaca
[dd]: https://www.docker.com/products/docker-desktop/
[wsl]: https://docs.docker.com/desktop/windows/wsl/
[ads]: https://azure.microsoft.com/en-us/products/data-studio