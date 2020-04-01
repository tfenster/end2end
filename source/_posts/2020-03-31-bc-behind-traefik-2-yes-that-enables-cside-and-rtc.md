---
layout: post
title: "BC behind Traefik 2 (yes, that enables C/SIDE and RTC)"
permalink: bc-behind-traefik-2-yes-that-enables-cside-and-rtc
date: 2020-03-31 21:30:39
comments: false
description: "BC behind Traefik 2 (yes, that enables C/SIDE and RTC)"
keywords: ""
categories:
image: /images/traefik2.png

tags:

---

Every since the [release of Traefik 2][traefik2] half a year ago I wanted to give it a try. Partly because I just like trying out new stuff, but mainly because Traefik 2 now support TCP, which means that it should be possible to run a NAV / BC container behind Traefik and be able to connect to it with good (not really) old C/SIDE and RTC. Unfortunately a change of jobs and lots of work to get started in the new company happened in between, so while I really like working for [COSMO CONSULT][cosmo] [^1], it also meant that I had to postpone my adventures with Traefik 2. But now I found the time and while there are a couple of not-so-nice aspects, it actually works!

## The TL;DR
Basically everything works as expected. There is a new syntax in Traefik 2 compared to Traefik 1, but once you understand the base concepts, it isn't a big deal to move from 1 to 2. TCP is a bit more interesting as that just wasn't there in v1, but in the end it actually is easier to configure than HTTP. The problem is that you can't use the same port for multiple backend containers as TCP has no concept of something like paths, so the only distinguishing factor is the port. That is quite a limitation, but I don't see any technical solution at all for a way to implement this more elegant. But, it works... Also, for the moment you can't combine Windows auth and backend https which means that the mobile app and the modern Windows client won't work with Windows auth. The fallback is NavUserPassword and I still hope I am missing something or Traefik will make something happen in response to the [issue][issue] I have opened in their GitHub repo. But as this is the TL;DR, I'll just show you that it actually works: I connect with the RTC using Win Auth, I connect with C/SIDE using Win Auth and I compile a table change with validation, so you know that this critical part also works:

![interface-base](/images/traefik2-demo.gif)
{: .centered}

## The details
If you really want to take a look, this is how the configuration looks like. I won't give a primer on the new concepts in Traefik 2 as the [offical docs][docs] are quite good in my opinion and if you know your way around Traefik 1, I would especially recommend the [migration guide][mig-guide]. But to go through the configuration elements: For my first trials, I decided to go with one big docker-compose.yml file as it allows me to configure everything in one place. The configuration of Traefik itself looks like this:

{% highlight yaml linenos %}
  traefik:
    image: traefik:2.2-windowsservercore-1809
    container_name: traefik
    command:
      - --api.dashboard=true
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false
      - --providers.docker.endpoint=npipe:////./pipe/docker_engine
      - --entrypoints.websecure.address=:443
      - --entrypoints.sql.address=:1433
      - --entrypoints.mgmt.address=:7045
      - --entrypoints.rtc.address=:7046
      - --certificatesresolvers.myresolver.acme.tlschallenge=true
      - --certificatesresolvers.myresolver.acme.email=tobias.fenster@cosmoconsult.com
      - --certificatesresolvers.myresolver.acme.storage=c:/le/acme.json
      - --serversTransport.insecureSkipVerify=true
    ports:
      - "443:443"
      - "1433:1433"
      - "7045:7045"
      - "7046:7046"
    volumes:
      - c:\users\tfenster8982\traefik:c:/le
      - type: npipe
        source: \\.\pipe\docker_engine
        target: \\.\pipe\docker_engine
    labels:
      - traefik.enable=true
      - traefik.http.routers.api.entrypoints=websecure
      - traefik.http.routers.api.tls.certresolver=myresolver
      - traefik.http.routers.api.rule=Host(`traeftest.westeurope.cloudapp.azure.com`) && (PathPrefix(`/api`) || PathPrefix(`/dashboard`))
      - traefik.http.routers.api.service=api@internal
{% endhighlight %}

If you are familiar with Traefik 1, you will see that the syntax has changed quite a bit, but basically the same things happen. What is probably interesting is how the entrypoints are defined: You can see ports 1433, 7045 and 7046 as mapped ports (lines 19-21) and as entrypoints (lines 10-12) and we'll see later how that is used. The last couple of lines expose the Traefik dashboard through Traefik itself, so you can get to it through SSL. You should also protect it with a password or don't enable it for external access, but for my demo, this was good enough. It has a new design as well and looks like this:

![interface-base](/images/traefik2.png)
{: .centered}

An annoying problem at the moment is that Traefik tries to create a new file for the Let's Encrypt certificate and then do a [`chmod 600`][chmod] on it, which is a Linux thing and doesn't work on Windows. The friendly Traefik bot on their GitHub page decided to classify my [bug report][bug] as configuration issue, but fortunately I found a workaround: If you just create an empty file, then Traefik will use that and don't check the permissions as they already [found out][check] that this is not as easy as on Linux. Beats me why they decide to ignore the check but not the create, but maybe something will be done in the future.

The configuration of the BC container is more complex as we now have 5 HTTP based endpoints (WebClient, Dev service, SOAP, REST and file download) and 3 TCP based endpoints (SQL, Client service and Management service):

{% highlight yaml linenos %}
  bc:
    image: mcr.microsoft.com/businesscentral/onprem:1810-ltsc2019
    container_name: bc
    hostname: traeftest.westeurope.cloudapp.azure.com
    environment:
      - accept_eula=y
      - webserverinstance=bc
      - publicdnsname=traeftest.westeurope.cloudapp.azure.com
      - auth=Windows
      - username=VM-Administrator
      - password=Super5ecret!
      - usessl=n
      - customNavSettings=PublicODataBaseUrl=https://traeftest.westeurope.cloudapp.azure.com/bcrest/odata,PublicSOAPBaseUrl=https://traeftest.westeurope.cloudapp.azure.com/bcsoap/ws,PublicWebBaseUrl=https://traeftest.westeurope.cloudapp.azure.com/bc
    labels:
      - traefik.enable=true
      - traefik.http.routers.bc.rule=Host(`traeftest.westeurope.cloudapp.azure.com`) && PathPrefix(`/bc`)
      - traefik.http.routers.bc.entrypoints=websecure
      - traefik.http.routers.bc.tls.certresolver=myresolver
      - traefik.http.routers.bc.service=bc@docker
      - traefik.http.services.bc.loadBalancer.server.scheme=http
      - traefik.http.services.bc.loadBalancer.server.port=80

      - traefik.http.routers.bcdl.rule=Host(`traeftest.westeurope.cloudapp.azure.com`) && PathPrefix(`/bcdl`)
      - traefik.http.routers.bcdl.entrypoints=websecure
      - traefik.http.routers.bcdl.tls.certresolver=myresolver
      - traefik.http.routers.bcdl.service=bcdl@docker
      - traefik.http.services.bcdl.loadBalancer.server.scheme=http
      - traefik.http.services.bcdl.loadBalancer.server.port=8080
      - traefik.http.middlewares.bcdl.stripprefix.prefixes=/bcdl
      - traefik.http.routers.bcdl.middlewares=bcdl@docker

      - traefik.http.routers.bcdev.rule=Host(`traeftest.westeurope.cloudapp.azure.com`) && PathPrefix(`/bcdev`)
      - traefik.http.routers.bcdev.entrypoints=websecure
      - traefik.http.routers.bcdev.tls.certresolver=myresolver
      - traefik.http.routers.bcdev.service=bcdev@docker
      - traefik.http.services.bcdev.loadBalancer.server.scheme=http
      - traefik.http.services.bcdev.loadBalancer.server.port=7049
      - traefik.http.middlewares.bcdev.replacepathregex.regex=^/bcdev(.*)
      - traefik.http.middlewares.bcdev.replacepathregex.replacement=/NAV$${1}
      - traefik.http.routers.bcdev.middlewares=bcdev@docker
      
      - traefik.http.routers.bcrest.rule=Host(`traeftest.westeurope.cloudapp.azure.com`) && PathPrefix(`/bcrest`)
      - traefik.http.routers.bcrest.entrypoints=websecure
      - traefik.http.routers.bcrest.tls.certresolver=myresolver
      - traefik.http.routers.bcrest.service=bcrest@docker
      - traefik.http.services.bcrest.loadBalancer.server.scheme=http
      - traefik.http.services.bcrest.loadBalancer.server.port=7048
      - traefik.http.middlewares.bcrest.replacepathregex.regex=^/bcrest(.*)
      - traefik.http.middlewares.bcrest.replacepathregex.replacement=/NAV$${1}
      - traefik.http.routers.bcrest.middlewares=bcrest@docker

      - traefik.http.routers.bcsoap.rule=Host(`traeftest.westeurope.cloudapp.azure.com`) && PathPrefix(`/bcsoap`)
      - traefik.http.routers.bcsoap.entrypoints=websecure
      - traefik.http.routers.bcsoap.tls.certresolver=myresolver
      - traefik.http.routers.bcsoap.service=bcsoap@docker
      - traefik.http.services.bcsoap.loadBalancer.server.scheme=http
      - traefik.http.services.bcsoap.loadBalancer.server.port=7047
      - traefik.http.middlewares.bcsoap.replacepathregex.regex=^/bcsoap(.*)
      - traefik.http.middlewares.bcsoap.replacepathregex.replacement=/NAV$${1}
      - traefik.http.routers.bcsoap.middlewares=bcsoap@docker

      - traefik.tcp.routers.bcsql.rule=HostSNI(`*`)
      - traefik.tcp.routers.bcsql.entrypoints=sql
      - traefik.tcp.routers.bcsql.service=bcsql@docker
      - traefik.tcp.services.bcsql.loadBalancer.server.port=1433

      - traefik.tcp.routers.bcmgmt.rule=HostSNI(`*`)
      - traefik.tcp.routers.bcmgmt.entrypoints=mgmt
      - traefik.tcp.routers.bcmgmt.service=bcmgmt@docker
      - traefik.tcp.services.bcmgmt.loadBalancer.server.port=7045

      - traefik.tcp.routers.bcrtc.rule=HostSNI(`*`)
      - traefik.tcp.routers.bcrtc.entrypoints=rtc
      - traefik.tcp.routers.bcrtc.service=bcrtc@docker
      - traefik.tcp.services.bcrtc.loadBalancer.server.port=7046
    volumes:
      - c:\users\tfenster8982\my:c:\run\my
{% endhighlight %}

As you can see, the environment parameters and other standard parameters are what is expected for every NAV / BC container with maybe the exception of the Public-URL-parameters which are necessary to let the components know how they are reachable from the outside. The `labels` section (line 14 and on) is where it gets interesting: We create a rule (line 16) to let Traefik know on which DNS name and for which path the given router should listen. We then define that it listens on the `websecure` endpoint (port 443, line 17) which is secured by a Let's Encrypt certificate (line 18) and connected to a service called `bc` (line 19). That one in turn connects to port 80 using HTTP (because of the issue mentioned above, line 20 and 21). If we had HTTPS enabled on the backend containers, this would be port 443 and HTTPS.

The other HTTP based parts are very similar with the addition that they need to replace parts of the URL with something else when talking to the backend service. This is done with a `replacepathregex` middleware, e.g. in lines 58 and 59, and that in turn has to be connected to the router as well, e.g. in line 60.

The TCP based parts are a lot simpler as they basically only forward a specific port to a port on a backend service, e.g. in lines 62-65. It's also worth noting that TCP doesn't have something like a requested host per se, so the HostSNI param has to be set to the wildcard *. If we would enable TLS here, then we could specify the hostname, but I was worried that RTC and / or C/SIDE wouldn't be able to handle that, so I skipped that setting.

In the end, we have a setup that works, but having to bind SQL, Client service and Management service for every container behind Traefik to a dedicated port kind of breaks the benefit of a reverse proxy in my opinion. Still, there is no way around it, so we'll have to find some mechanism to identify free ports and assign them automatically, as bad as that is...

Also, this is my first try with Traefik 2, so if someone comes across this post and sees aspects to simplify or otherwise improve, please let me know using the contact options in the footer.

[traefik2]: https://containo.us/blog/traefik-2-0-6531ec5196c2/
[cosmo]: https://www.cosmoconsult.com
[issue]: https://github.com/containous/traefik/issues/6608
[docs]: https://docs.traefik.io/
[mig-guide]: https://docs.traefik.io/migration/v1-to-v2/
[bug]: https://github.com/containous/traefik/issues/6598
[chmod]: https://github.com/containous/traefik/blob/f624449ccbf42c56279c594eadc226fed6583993/pkg/provider/acme/local_store_windows.go#L15
[check]: https://github.com/containous/traefik/blob/f624449ccbf42c56279c594eadc226fed6583993/pkg/provider/acme/local_store_windows.go#L6
[^1]: Come join me if you want to work for a technologically very advanced, fast-moving Microsoft partner covering not only BC but really the full Microsoft portfolio. Most importantly for me, it truly is a human-centric company with a clear strategy and purpose.