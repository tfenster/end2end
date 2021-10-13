---
layout: post
title: "Connecting a BC container to an external SQL server"
permalink: connecting-a-bc-container-to-an-external-sql-server
date: 2021-10-13 14:51:08
comments: false
description: "Connecting a BC container to an external SQL server"
keywords: ""
image: /images/bc-sql-docker.png
categories:

tags:

---

As part of my [DynamicsCon][dynamicscon] session in September 2021, I wanted to show how you can connect a Business Central container to an existing SQL Server. Unfortunately, I ran out of time and couldn't show that demo, so I'll quickly show it here.

## The TL;DR

You just use a couple of parameters for `New-BCContainer`. As an example, here I am connecting to a SQL Server on IP `172.29.148.76` with an unnamed instance, database name `cronus` and I enter the credentials in a credential popup

```
New-BcContainer -accept_eula -containerName externalSql -imageName mybc:18.3.27240.27480-w1 `
    -databaseServer 172.29.148.76 -databaseInstance "" -databaseName cronus `
    -databaseCredential (Get-Credential -Message "SQL Server Credentials") `
    -auth NavUserPassword
```

You can find a quick walkthrough here and you will notice at the end that between `Starting Container` and `Starting Service Tier` there is no `Starting local SQL Server` like you would typically see, because the BC container knows not to start the included SQL Server, if you are connecting to an external SQL Server.

<video width="100%" controls>
  <source type="video/mp4" src="/images/demo4.mp4">
</video>

## The Details

Well, there aren't any details... If you want more context, I would suggest to watch my DynamicsCon session. I'll share the link to the recording on YouTube as soon as it appears, the slides are already available [here][here] and slide 29 would have been the one where I would have liked to show this as well.

[dynamicscon]: https://dynamicscon.com/
[here]: https://dynamicscon.com/wp-content/uploads/2021/09/Tobias-Fenster-BC-on-Docker_-Basics-Tools-and-Advanced-Scenarios.pdf