---
layout: post
title: "Making applications served through Traefik more secure"
permalink: making-applications-served-through-traefik-more-secure
date: 2020-07-04 21:30:59
comments: false
description: "Making applications served through Traefik more secure"
keywords: ""
categories:
image: /images/traefik-tls.png

tags:

---

If you use [Traefik][traefik] to securely and flexibly make your containers reachable, you might use a service like the [Qualys SSL Labs Server Test][qualys] to find out how good your SSL based security is. You might be in for a surprise because you only get a B rating:

![qualys-bad](/images/qualys-bad.png)
{: .centered}

Not bad, but also not brilliant. Fortunately you also get detailed feedback on the things you could improve: Mainly the fact that TLS 1.0 and 1.1 (older protocol versions for encrypted communication) are available, which are no longer considered safe, and the used cipher suites (those define the encryption algorithm), some of which are considered weak. What can we do about that? It took a bit more effort than expected, but int the end I found out how to let Traefik know what is needed.

## The TL;DR
The necessary steps are the following:

- Add a Traefik config file which sets the minimal TLS version to 1.2 and lists only strong cipher suites
- Add that file as provider for Traefik
- Reference the configuration in that file when configuring the TLS options for your endpoint in Traefik

The result looks a lot better:

![qualys-good](/images/qualys-good.png)
{: .centered}

## The details: The starting point
I won't go into the details because I have covered this a couple of times already, but as a reference, here is what a docker compose file might look like to start Traefik and use it to make another container externally available, in my example a Microsoft Dynamics 365 Business Central instance:

{% highlight yaml linenos %}
version: '3.7'

services:
  traefik:
    image: traefik:2.2-windowsservercore-1809
    command:
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false
      - --providers.docker.endpoint=npipe:////./pipe/docker_engine
      - --entrypoints.websecure.address=:443
      - --certificatesresolvers.myresolver.acme.tlschallenge=true
      - --certificatesresolvers.myresolver.acme.email=tobias.fenster@cosmoconsult.com
      - --certificatesresolvers.myresolver.acme.storage=c:/le/acme.json
      - --serversTransport.insecureSkipVerify=true
    volumes:
      - source: 'C:/iac/le'
        target: 'C:/le'
        type: bind
      - source: '\\.\pipe\docker_engine'
        target: '\\.\pipe\docker_engine'
        type: npipe
    ports:
      - 443:443

  bc:
    image: mcr.microsoft.com/businesscentral/sandbox:ltsc2019
    hostname: devtfe.westeurope.cloudapp.azure.com
    environment:
      - accept_eula=y
      - accept_outdated=y
      - webserverinstance=bc
      - publicdnsname=devtfe.westeurope.cloudapp.azure.com
      - usessl=y
      - customNavSettings=PublicWebBaseUrl=https://devtfe.westeurope.cloudapp.azure.com/bc
      - folders=c:\run=https://github.com/tfenster/nav-docker-samples/archive/conf-healthcheck.zip\nav-docker-samples-conf-healthcheck
      - healthCheckBaseUrl=https://localhost/bc
    labels:
      - traefik.enable=true
      - traefik.http.routers.bc.rule=Host(`devtfe.westeurope.cloudapp.azure.com`) && PathPrefix(`/bc`)
      - traefik.http.routers.bc.entrypoints=websecure
      - traefik.http.routers.bc.tls.certresolver=myresolver
      - traefik.http.routers.bc.service=bc@docker
      - traefik.http.services.bc.loadBalancer.server.scheme=https
      - traefik.http.services.bc.loadBalancer.server.port=443
{% endhighlight %}

## The details: Adding the TLS config file
To let Traefik know how we want to configure TLS we need to create a config file, because we can't configure the TLS options through the command arguments. At first, I couldn't believe that and lost some time tinkering with the syntax, but it really is true as stated in the [documentation][documentation]:

*In the above example, we've used the file provider to handle these definitions. It is the only available method to configure the certificates (as well as the options and the stores)*

The necessary config file looks like this, effectively disabling TLS 1.0 and 1.1 and also only accepting a limited list of cipher suites:

{% highlight toml linenos %}
[tls.options]
  [tls.options.default]
    minVersion = "VersionTLS12"
    cipherSuites = [
        "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384",
        "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
        "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
        "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
        "TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256",
        "TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256",
    ]
{% endhighlight %}

Note that the last two are needed for Internet Explorer 11 and older Safari versions. If you don't care about those, you can remove them as that cipher suite is also considered weak.

Now we need to let Traefik know that we want to use that config file to define TLS options and then to use those options on our endpoint. This can easily be done in the command part of the traefik service in our docker compose file by adding the following two lines:

{% highlight yaml linenos %}
      - --providers.file.filename=c:/le/traefik-tls.toml
      - --entrypoints.websecure.http.tls.options=default@file
{% endhighlight %}

With that in place, Traefik takes the configuration from the file and uses it for the websecure endpoint.

[qualys]: https://www.ssllabs.com/ssltest/index.html
[documentation]: https://docs.traefik.io/v2.0/https/tls/#user-defined
[traefik]: https://traefik.io