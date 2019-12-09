---
layout: post
title: "Access your BC container behind traefik using the mobile app"
permalink: access-your-bc-container-behind-traefik-using-the-mobile-app
date: 2019-12-07 21:37:19
comments: true
description: "Access your BC container behind traefik using the mobile app"
keywords: ""
categories:
image: /images/traefik and bc.png

tags:

---

If you are running multiple Business Central containers on the same VM and want to have access to them from outside of that VM, you have to implement a way how to connect to them. I have shown multiple options, including a setup based on the reverse proxy [traefik][traefik] in [blog posts][blog-post], [webinars][areopa] and [conference sessions][techdays]. But as a [Yammer post][yammer] first made me aware of, this didn't work for the mobile app and as I then found out, it also didn't work for the new BC Windows client. Leon Knollmeyer, who posted this on Yammer, had already dug a bit and found out that for whatever reason, the header.png file was requested using http instead of https, which caused the problem. I invested a bit of time to find out why that particular file is handled differently, but to be honest didn't make the slightest progress. So I decided to tackle this the other way by switching the containers to https even behind traefik which turned out to be a bit more complicated then I first thought[^1]

## The TL;DR
- Containers started with [navcontainerhelper][github] and the `-useTraefik` switch now use https unless explicitely told otherwise
- This needed changes in the traefik rules, the traefik config file and the container health check
- If you have an already existing traefik based setup and update navcontainerhelper to 0.6.4.21 (confirmed as the version where you will start seeing those features), new containers will still not use this as it needs an updated traefik config. If you want to change the behavior, run `Setup-TraefikContainerForNavContainers -Recreate` and new containers will get the fix. Please note that existing containers will still use http and therefore can't be reached using the mobile app or modern Windows client.

## The details
The easy part was making the containers use https as this is handled by the environment variable `usessl` in the BC Docker images and actually using https is the default behavior. But then the connection to the containers through traefik completely failed, because it was configured to go to port 80 on the container (the default http port) and now needed to go to port 443 (the default https port). At the same moment I realized that the protocol needed to change as traefik previously had used http to connect to the container and now had to use https. That can be achieved with a label like `-l "traefik.protocol=https"` but the file download site inside of the container always uses http, so for that particular part the protocol needed to stay http. One more label `-l "traefik.dl.protocol=http"` fixed that. The changed code looks like this, more about the `forceHttpWithTraefik` and why this is parameterized below

{% highlight powershell linenos %}
$webPort = "443"
if ($forceHttpWithTraefik) {
    $webPort = "80"
}
$traefikProtocol = "https"
if ($forceHttpWithTraefik) {
    $traefikProtocol = "http"
}

$additionalParameters += @("--hostname $traefikHostname",
                            "-e webserverinstance=$containerName",
                            "-e publicdnsname=$publicDnsName", 
                            "-l `"traefik.protocol=$traefikProtocol`"",
                            "-l `"traefik.web.frontend.rule=$webclientRule`"", 
                            "-l `"traefik.web.port=$webPort`"",
                            "-l `"traefik.soap.frontend.rule=$soapRule`"", 
                            "-l `"traefik.soap.port=7047`"",
                            "-l `"traefik.rest.frontend.rule=$restRule`"", 
                            "-l `"traefik.rest.port=7048`"",
                            "-l `"traefik.dev.frontend.rule=$devRule`"", 
                            "-l `"traefik.dev.port=7049`"",
                            "-l `"traefik.dl.frontend.rule=$dlRule`"", 
                            "-l `"traefik.dl.port=8080`"",
                            "-l `"traefik.dl.protocol=http`"",
                            "-l `"traefik.enable=true`"",
                            "-l `"traefik.frontend.entryPoints=https`""
        )
{% endhighlight %}

But still no connection... Digging some more, I found out that the container started, but never got healthy, so I checked the CheckHealth.ps1 script. And of course, that one had a hardcoded http reference as well, so I had to also fix that. And because the container certificates are self signed, I needed to make sure that the certificate validation still returns true, which can be done by implementing a custom `ServerCertificateValidationCallback`. Also traefik needs to accept the self signed certificates, which can be achieved with a `insecureSkipVerify = true` directive in the traefik config file. The new health check look like this:

{% highlight powershell linenos %}
if (-not("dummy" -as [type])) {
    add-type -TypeDefinition @"
using System;
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
public static class Dummy {
    public static bool ReturnTrue(object sender,
        X509Certificate certificate,
        X509Chain chain,
        SslPolicyErrors sslPolicyErrors) { return true; }
    public static RemoteCertificateValidationCallback GetDelegate() {
        return new RemoteCertificateValidationCallback(Dummy.ReturnTrue);
    }
}
"@
}

[System.Net.ServicePointManager]::ServerCertificateValidationCallback = [dummy]::GetDelegate()

$healthcheckurl = ("https://localhost/" + $env:webserverinstance + "/")
try {
    $result = Invoke-WebRequest -Uri "${healthcheckurl}Health/System" -UseBasicParsing -TimeoutSec 10
    if ($result.StatusCode -eq 200 -and ((ConvertFrom-Json $result.Content).result)) {
        # Web Client Health Check Endpoint will test Web Client, Service Tier and Database Connection
        exit 0
    }
} catch {
}
exit 1
{% endhighlight %}

With that I was able to connect to the containers with the mobile app and the modern Web client. Freddy Kristiansen then made me aware of the problem that this would break existing installations because someone out their might rely on the containers using http. So I went back and added some parameters as well as a check of the traefik config which hopefully should mean no pre-existing setups are broken and you can still force it to use http. To be more specific, those are the scenarios I can think of:

1. You are setting up a new VM with navcontainerhelper 0.6.4.21 or newer e.g. by using Microsoft's ARM templates or doing it yourself: In that case you should get full https support and everything "just works". If you want to force http, you need to run `Setup-TraefikContainerForNavContainers` with the `-forceHttpWithTraefik` param. 
2. You have a pre-existing system and want to stay with http: This should work out of the box, but you still wouldn't be able to connect with the mobile app or the modern Windows client
3. You have a pre-existing system and want to switch to https: Run `Setup-TraefikContainerForNavContainers -Recreate -forceHttpWithTraefik` to recreate the traefik setup, now with https support. Again, please be aware that containers existing prior to the recreate will still use http with the consequences outlined below 2.

If you want to take a look at all the changes, check out the [files section of the pull request][prfiles]

## A word about Open Source pull requests
I provided those changes as pull request to the navcontainerhelper [Github repo][github]. I had everything in place for my [NAV TechDays][techdayshp] [session][techdays], so I thought it would be easy to replicate. But a) I had to solve the problem with pre-existing setups / allowing to force http and b) I was very bad at putting my existing solutions into place. If you follow the [pull request conversation][pr], you can literally see me forgetting about everything I could forget and turning wrong at every possible turn. Amazing... 

But my point is that Freddy gave me very polite feedback and helped me to bring this to a good conclusion. So if you ever wondered if your coding skills are "good enough" to submit a PR, just remember this one and go ahead! At the same time, please also make sure to address Open Source maintainers politely and provide as much input as possible. It is a tough job and if you want your PRs to succeed, do everything you can for that.


[traefik]: https://traefik.io
[blog-post]: https://www.axians-infoma.com/techblog/traefik-support-for-navcontainerhelper-the-nav-arm-templates-for-azure-vms-and-local-environments/
[areopa]: https://www.youtube.com/watch?v=rjZ9DXsi9_w
[techdays]: https://www.youtube.com/watch?v=Dr6bFoRELnY
[yammer]: https://www.yammer.com/dynamicsnavdev/threads/396327303618560
[github]: https://www.github.com/microsoft/navcontainerhelper
[pr]: https://github.com/microsoft/navcontainerhelper/pull/758
[prfiles]: https://github.com/microsoft/navcontainerhelper/pull/758/files
[techdayshp]: https://navtechdays.com

[^1]: Leon had asked me "Is the -useSSL flag sufficient to accomplish that?" and my answer was "yes, that should be enough". I was quite wrong there :)