---
layout: post
title: "Please, BC, stay healthy (and how can you check that)"
permalink: please-bc-stay-healthy-and-how-can-you-check-that
date: 2020-09-25 06:53:36
comments: false
description: "Please, BC, stay healthy (and how can you check that)"
keywords: ""
categories:
image: /images/tenor.gif

tags:

---

I am not sure how broadly known the topic of this post already is, so this might be a boring one: How can you tell if a Business Central (and NAV) service tier and web client are healthy or not? I got the question and had to agree that it isn't documented anywhere. My first inclination was to add something to the excellent [Business Central docs][bc-docs], but I couldn't identify a good place, so I decided to just write a quick blog post

## The TL;DR
It actually is very simple. Assuming that your web client is running on a server called "mywebserver"[^1] and the instance name is "mybcinstance", then the URL for your web client would be `https://mywebserver/mybcinstance`. Checking for the health state of this web client and service tier is as easy as a GET call to `https://mywebserver/mybcinstance/health/system`. If everything is fine, you get `result=true` as you can see here 

{% highlight http linenos %}
GET https://mywebserver/mybcinstance/health/system

HTTP/1.1 200 OK
...
Content-Type: application/json; charset=utf-8
Date: Fri, 25 Sep 2020 08:53:39 GMT
...
Content-Length: 35
Connection: close

{
  "result": true
}
{% endhighlight %}

## And what about the older versions?
At some point (I think NAV 2018, but am not sure) Microsoft introduced the new path for he web client that you see above. Before that it used to be `https://mywebserver/mybcinstance/WebClient`, so the health check URL for those oder versions is `https://mywebserver/mybcinstance/WebClient/health/system`

That's it :)

![swarm-full](/images/tenor.gif)
{: .centered}

[bc-docs]: https://docs.microsoft.com/en-us/dynamics365/business-central/?WT.mc_id=BA-MVP-5002758
[^1]: Do you also find it weird that the web server component of BC is called web client? I do... :)