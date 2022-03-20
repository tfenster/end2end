---
layout: post
title: "Get your BC artifact URLs without PowerShell"
permalink: get-your-bc-artifact-urls-without-powershell
date: 2022-02-19 14:38:34
comments: false
description: "Get your BC artifact URLs without PowerShell"
keywords: ""
image: /images/bca-function.png
categories:

tags:

---

In June 2020, a drastic change happened to how we can work with Microsoft Dynamics 365 Business Central in containers: Instead of ready made images, BC started to rely on artifacts (see Freddy's [blog post][bca-intro] on the topic). As a result of that, you can no longer just use an image to start BC but instead need to first find out what the right BC artifact URL for your type, version, localization etc. is. As far as I know, this is only possible through a PowerShell cmdlet ([Get-BCArtifactUrl][get-bca]), of course part of [bccontainerhelper][bcch]. But sometimes you are in a situation where you can't easily run a PowerShell command, so I decided to create a little Web API for that purpose.

## The TL;DR
The idea is very simple: You call [https://bca-url-proxy.azurewebsites.net/bca-url/](https://bca-url-proxy.azurewebsites.net/bca-url/) and get redirected to the right BC artifact URL. Of course you can add parameters to the path (&lt;type&gt;/&lt;country&gt;/&lt;version&gt;) to get exactly what you want, e.g. [https://bca-url-proxy.azurewebsites.net/bca-url/onprem/de/19.4](https://bca-url-proxy.azurewebsites.net/bca-url/onprem/de/19.4) redirects you to the BC artifact URL for the onprem, German, 19.4 artifacts. That means that you can use

```New-BcContainer -artifactUrl https://bca-url-proxy.azurewebsites.net/bca-url/onprem/de/19.4 ...```

instead of 

```New-BcContainer -artifactUrl (Get-BcArtifactUrl -type onprem -country de -version 19.4) ...```

Or if you need a BC artifact URL, e.g. to download the artifact package create an Azure Container Instance, you can just use it directly. If you want the URL as text instead of getting redirected, you can use [https://bca-url-proxy.azurewebsites.net/bca-url/onprem/de/19.4?DoNotRedirect=true](https://bca-url-proxy.azurewebsites.net/bca-url/onprem/de/19.4?DoNotRedirect=true).

## The details: Define exactly the artifact you want

If you have worked with Get-BcArtifactUrl before, you know that it comes with a lot more parameters: You can not only define type, country and version, but also `select` / `storageAccount` / `sasToken` for e.g. nextMinor / nextMajor artifacts, `before` / `after` for defining the time period and `doNotCheckPlatform` to avoid the platform check. As those parameters are more unusual to use and can have a lot of different combinations, I decided to only have type, country and version in the URL path and put the others in query parameters. So if you e.g. want to get the daily German sandbox artifacts, you call [https://bca-url-proxy.azurewebsites.net/bca-url/sandbox/de?select=Daily](https://bca-url-proxy.azurewebsites.net/bca-url/sandbox/de?select=Daily).

As you can also see in this example, you don't have to put in all the path parameters, but actually they are all optional. That means that [https://bca-url-proxy.azurewebsites.net/bca-url/](https://bca-url-proxy.azurewebsites.net/bca-url/) is also valid, same as calling `Get-BcArtifactUrl` also works. If you add path parameters, you have to use &lt;type&gt;/&lt;country&gt;/&lt;version&gt;. But you can also put them in the query like [https://bca-url-proxy.azurewebsites.net/bca-url/onprem?version=19](https://bca-url-proxy.azurewebsites.net/bca-url/onprem?version=19).

## The details: How it works behind the scenes

Behind the scenes, this is using an Azure Function. I decided to go with Linux and a custom image (reasons for that in a later blog post) and created the functionality in C#. When a call comes in, it first checks a cache to find out if that artifact URLs has previously been requested. Those cache entries stay valid for one hour (sandbox artifacts) or one day (onprem artifacts). If a valid entry is found, the URL from the cache is returned. If no valid entry is found, Get-BcArtifactUrl is called with the supplied parameters and the resulting URL is either returned as redirect or as text content. The sources for all of this are open and you can find them [here][bcaup].

If you want to better understand the results, you need to take a look at the result headers. Here is how a request and response could look like:

{% highlight HTTP linenos %}
GET https://bca-url-proxy.azurewebsites.net/bca-url/onprem/de?DoNotRedirect=true

HTTP/1.1 200 OK
Transfer-Encoding: chunked
Content-Type: text/plain; charset=utf-8
Server: Kestrel
Request-Context: appId=cid-v1:e1624cc1-81aa-4913-8fa7-05653b9c16a9
X-bccontainerhelper-version: 3.0.2
X-bcaup-version: 1.0.2
X-bccontainerhelper-command: Get-BCArtifactUrl -type "onprem" -country "de"
X-bcaup-from-cache: true
Date: Sat, 19 Feb 2022 15:18:08 GMT
Connection: close

https://bcartifacts.azureedge.net/onprem/19.4.35398.35482/de
{% endhighlight %}

Line 8 shows the BcContainerHelper version that was used, same as line 9 shows the version of my little tool. Line 10 gives you the BcContainerHelper command, so you know how the URL was retrieved. And Line 11 finally gives you the information whether the URL was pulled from the cache or not.

I hope this works for you if you ever need a BC artifact URL but don't have a PowerShell session in reach. If you spot a bug in the code or have ideas for improvements, as always, please let me know or just create a Pull Request.

[bca-intro]: https://freddysblog.com/2020/06/25/changing-the-way-you-run-business-central-in-docker/
[get-bca]: https://github.com/microsoft/navcontainerhelper/blob/master/Misc/Get-BCArtifactUrl.ps1
[bcch]: https://www.powershellgallery.com/packages/bccontainerhelper
[bcaup]: https://github.com/tfenster/bcartifacturl-proxy/blob/master/GetUrl.cs