---
layout: post
title: "Getting BC insider artifacts without powershell or a token (and the BC community is great!)"
permalink: getting-bc-insider-artifacts-without-powershell-or-a-token-and-the-bc-community-is-great
date: 2024-03-18 19:52:34
comments: false
description: "Getting BC insider artifacts without powershell or a token (and the BC community is great!)"
keywords: ""
image: /images/community.png
categories:

tags:

---

In a [previous blog post][bcaup] I shared how you can use a little [Azure Function][azfunc] to get a BC artifact (actually the URL to a BC artifact) without PowerShell by just doing an http request. With that it was also possible to get the so-called insider artifacts for preview versions of BC that were not yet publicly available, using a specific token shared by Microsoft to partners in a collaboration program. But since version 6.0.0 of the [bccontainerhelper][bcch] and specifically [this commit][commit], that is no longer required. You only need to accept the insider EULA by now. That didn't change too much for me because I am using COSMO Alpaca for my BC containers, so all that stuff is magically handled behind the scenes for me, but others do have the requirement.

## The TL;DR

Thanks to [Arthur][avdv], my Azure Function can now handle that as well. All you need to do is request on of the insider artifacts like `NextMajor` and it automatically works. Try this link for example, and it will just give you the artifact url for the next major release: [https://bca-url-proxy.azurewebsites.net/bca-url/Sandbox/BASE?select=NextMajor&DoNotRedirect=true][https://bca-url-proxy.azurewebsites.net/bca-url/Sandbox/BASE?select=NextMajor&DoNotRedirect=true]

## The details

Actually, there are not that many details. Arthur reached out to me via a [Github issue][ghissue] whether I could implement support for the insider EULA, but as I had seen his name pop up quite often in the BC tech community, I thought that I might be able to convince him to give it a try by himself. And sure enough, his answer was "Challenge accepted 😅". And not only did he accept the challenge, he implemeted it flawlessly and even made my code better along the way in his [pull request][pr]. The most relevant part of it are those two lines:

{% highlight csharp linenos %}
var accept_insiderEulaParam = GetAcceptInsiderEulaParam(accept_insiderEula, select, sasToken);

...

bcchCommand = $"Get-BCArtifactUrl{typeParam}{countryParam}{versionParam}{selectParam}{afterParam}{beforeParam}{storageAccountParam}{sasTokenParam}{accept_insiderEulaParam}{doNotCheckPlatformParam}";
{% endhighlight %}

But to make it really flexible and help everyone who wants to use it, he created a very fool-proof implementation for identifying the need for the insider EULA flag:

{% highlight csharp linenos %}
private string GetAcceptInsiderEulaParam(string accept_insiderEula, string select, string sasToken)
{
    var accept_insiderEulaParam = " -accept_insiderEula";

    if (IsValidParamSet(accept_insiderEula))
        return accept_insiderEulaParam;

    if (!string.IsNullOrEmpty(accept_insiderEula))
        return string.Empty;

    if (!string.IsNullOrEmpty(sasToken))
        return string.Empty;

    if (string.IsNullOrEmpty(select))
        return string.Empty;

    switch (select.ToLower())
    {
        case "nextminor":
        case "nextmajor":
            return accept_insiderEulaParam;
        default:
            return string.Empty;
    }
}
{% endhighlight %}

Bottom line: A nice PR that helped me (and "help" really is an understatement) to support this new functionality in my BC artifact URL proxy. Once more, I am very happy to be in the BC community, where a lot of knowledge and skill is shared freely!


[bcaup]: https://tobiasfenster.io/get-your-bc-artifact-urls-without-powershell
[azfunc]: https://azure.microsoft.com/en-us/products/functions/
[commit]: https://github.com/microsoft/navcontainerhelper/commit/b918ae1a80fe873b247618ab45f9ae2d1abd3f85
[bcch]: https://github.com/microsoft/navcontainerhelper
[avdv]: https://github.com/Arthurvdv
[ghissue]: https://github.com/tfenster/bcartifacturl-proxy/issues/1
[pr]: https://github.com/tfenster/bcartifacturl-proxy/pull/2