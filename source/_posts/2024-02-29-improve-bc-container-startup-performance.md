---
layout: post
title: "Improve BC container startup performance"
permalink: improve-bc-container-startup
date: 2024-02-28 23:09:51
comments: false
description: "Improve BC container startup performance"
keywords: ""
image: /images/bc startup performance.png
categories:

tags:

---

This is a little nugget on how to improve the BC container startup performance, but only in a specific scenario: If you have a persisted database (e.g. by storing the database files on the host or simply connecting to an external SQL server), create a container, delete it and then want to create another one, this will help you. Yes, quite a restricted scenario, so I won't blame you if you stop reading here :)

## The TL;DR

The startup time of a BC container is typically massively affected by the "Starting Service Tier" step. I was referred to [Christian Heide Damm][chdamm] when I asked about this and he explained that this is most likely due to the compilation of the required C# code. And he was kind enough to share an undocumented BCST setting with me called `ServerFileCacheDirectory` which you can use to make the BCST store these assemblies in a specific directory. By mapping this to a host directory, you can keep them even after deleting a container and if you do the same when creating the next container, the assemblies will be reused, speeding up the start.

In the logs you can see how it looks for a CRONUS database. On the first start, the "Starting Service Tier" step takes almost 2 minutes:

{% highlight text linenos %}
...
2024-02-26T23:29:54.098645200Z Creating ServerFileCacheDirectory and setting it to c:\data\cache
2024-02-26T23:29:54.611445700Z Starting Service Tier
2024-02-26T23:31:52.373512800Z CertificateThumprint 7D432A84DB8BA2842BD584662A10F97C1E74BE4A
...
{% endhighlight %}

After removing this container and creating a new one, it goes down to 23 seconds!

{% highlight text linenos %}
...
2024-02-26T23:32:43.553157200Z Creating ServerFileCacheDirectory and setting it to c:\data\cache
2024-02-26T23:32:44.195593500Z Starting Service Tier
2024-02-26T23:33:07.693662200Z CertificateThumprint 2273363CF52C32FA47AA8180C08DF3517F984967
...
{% endhighlight %}

Thanks for sharing, Christian, and I hope some readers are as happy about it as I am!

## The details: How to start the container

If you want to do this, you need two parts, as explained in the TL;DR: you need to set the configuration setting (line 10) and you need a folder mapped to the host (line 11). I set it up to use an external database (lines 5-9) so that the database is preserved even if the container is deleted:

{% highlight powershell linenos %}
docker run `
  -e accept_eula=y `
  -e username=admin `
  -e password=Super5ecret! `
  -e databaseserver=sql `
  -e databaseinstance= `
  -e databasename=cronus `
  -e databaseusername=sa `
  -e databasepassword=Super5ecret! `
  -e customnavsettings=ServerFileCacheDirectory=c:\data\cache `
  -v bcassemblies:c:\data `
  mybc:onprem-23.3.14876.15024-de-nodb
{% endhighlight %}

## The details: Some more testing

I also did some more testing: My first question was what would the impact on a heavily modified base application (yes, those still exist). A bit to my surprise - we are talking approx. 3x the number of objects - the result was very similar. First run with the compilation:

{% highlight text linenos %}
...
2024-02-26T23:24:39.812934100Z Creating ServerFileCacheDirectory and setting it to c:\data\cache
2024-02-26T23:24:40.447213700Z Starting Service Tier
2024-02-26T23:26:34.174036600Z CertificateThumprint 6400B7B9FA5BDC8553381A3ACD764828279B8E90
...
{% endhighlight %}

Basically 2 minutes again. Now the second run using the cached assemblies:

{% highlight text linenos %}
...
2024-02-26T23:27:34.433702600Z Creating ServerFileCacheDirectory and setting it to c:\data\cache
2024-02-26T23:27:35.126509400Z Starting Service Tier
2024-02-26T23:27:58.091896000Z CertificateThumprint 997D9A36E57DA297440097FB6B40C809CE519188
...
{% endhighlight %}

Exactly 23 seconds again[^1], as with the CRONUS database. Of course, you would have to repeat this a few times to get really reliable results, but I guess the big picture is already clear.

My second question was whether there was any performance impact from having this setting in place. So I compared the same setup with an external SQL server, but this time without the `ServerFileCacheDirectory`. This is the result for a CRONUS database:

{% highlight text linenos %}
...
2024-02-26T23:34:50.664973400Z Modifying Service Tier Config File with Instance Specific Settings
2024-02-26T23:34:51.173164300Z Starting Service Tier
2024-02-26T23:36:08.528247900Z CertificateThumprint B953B35C666C26D1EACA6E4C980F77D8A94E50B0
...
{% endhighlight %}

And for the modified base app:

{% highlight text linenos %}
...
2024-02-26T23:37:44.127080600Z Modifying Service Tier Config File with Instance Specific Settings
2024-02-26T23:37:44.686692200Z Starting Service Tier
2024-02-26T23:39:11.459392000Z CertificateThumprint F1C03CFBF851C601B906D01CDDFDD88167A391CA
...
{% endhighlight %}

As you can see, we have 1:19 for the CRONUS database (compared to 1:58 with the cache setting) and 1:27 for the modified base app (compared to 1:54). The storage performance should be close to native, so my best guess is that there are still artifacts from the image build in the default cache folder, but I haven't dug any deeper. The bottom line is that you do seem to lose a bit of performance through the `ServerFileCacheDirectory` setting on first startup, but obviously win more on the second and all subsequent startups.

So if this particular scenario is relevant to you, you can improve startup performance quite a bit with this setting.

[chdamm]: https://twitter.com/chdamm
[^1]: Maybe the BC containers are Basketball fans and want to tell us something?