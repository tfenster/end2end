---
layout: post
title: "Exploring files from a Windows container host through Filebrowser"
permalink: sharing-files-from-a-windows-container-host-through-filebrowser
date: 2021-11-08 20:21:03
comments: false
description: "Exploring files from a Windows container host through Filebrowser"
keywords: ""
image: /images/filebrowser-docker-windows.png
categories:

tags:

---

Having a web-based file explorer functionality for a Windows-Server-base container host is a surprisingly difficult task. In our [COSMO Azure DevOps & Docker Self-Service][self-service], we always include an [Azure File Share][afs] for - surprise - sharing files, but while it offers perfect functionality for our needs, it isn't exactly end-user friendly. Therefore, I searched for an easy-to-use alternative, allowing our end-users to have an explorer-like functionality through a web client. Everything in that environment is containerized and on Windows Server hosts, and to my surprise I didn't find anything that worked straight-up on Windows. If ignored my Windows requirement, the one option that came up very often in searches and also was suggested by Portainer's Neil Cresswell was [Filebrowser][filebrowser]. It didn't have a Windows container image, but fortunately, that turned out to be very easy to create.

## The TL;DR

If you want to use it for yourself, you can just run 

```
docker run -e "FB_ROOT=c:\" tobiasfenster/filebrowser-windows:v2.18.0
```

After that, you can access [http://localhost:8080], log in with the default user / password combination of admin / admin, and you can start using Filebrowser! 

![Screenshot of Filebrowser](/images/filebrowser-screenshot.png)
{: .centered}

As you have probably guessed, the `FB_ROOT=...` environment variable defines which folder is the root folder for Filebrowser. E.g. if I wanted to explore only my home folder, I would run 

```
docker run -e "FB_ROOT=c:\users\tfenster8982" tobiasfenster/filebrowser-windows:v2.18.0
```

## The Details: The container image, setting the default password and other configurations

As I already mentioned, there wasn't a Windows container image for Filebrowser, so I created one. If you are interested, you can find the sources [here][github]. The only interesting part in that repo is the [Dockerfile][dockerfile] and even that hast only a few interesting lines:

{% highlight Dockerfile linenos %}
RUN Write-Host "Downloading and expanding $($env:VERSION)"; `
    $url = ('https://github.com/filebrowser/filebrowser/releases/download/' + $env:VERSION + '/windows-amd64-filebrowser.zip'); `
    New-Item -ItemType Directory -Path 'c:\filebrowser' | Out-Null ; `
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile 'c:\filebrowser.zip'; `
    Expand-Archive 'c:\filebrowser.zip' 'c:\filebrowser'; `
    Remove-Item 'c:\filebrowser.zip'; 

ENTRYPOINT [ "c:\\filebrowser\\filebrowser.exe" ]
{% endhighlight %}

You can see in line 2 the definition of the download URL for a zip file of a specific version of Filebrowser. Then in lines 3-5 a new folder is created, the zip file is downloaded and expanded into the new folder. As a last step in line 6, the zip file is removed as we don't need it in the image. 

Line 8 shows you how Filebrowser is started, using the `ENTRYPOINT` directive, pointing at the `filebrowser.exe` file. Setting it up in this way instead of the `CMD` directive allows you to use another nice feature of the Filebrowser image: You can generate the (bcrypt) hash of a password you want to use by running 

```
docker run tobiasfenster/filebrowser-windows:v2.18.0 hash Super5ecret!
```

This returns the hash, in my case `$2a$10$Icqg9QIqjuQqwDrQvhuLhOo8j7CA5sUNGglms6otq7lFYu8o3EMVy`. With that, you can now improve the `docker run` command above to not set the default password, but instead your own. To do that, you run the following

```
docker run -e "FB_ROOT=c:\" -e 'FB_PASSWORD=$2a$10$Icqg9QIqjuQqwDrQvhuLhOo8j7CA5sUNGglms6otq7lFYu8o3EMVy' tobiasfenster/filebrowser-windows:v2.18.0
```

As your hash will contain `$` signs, make sure to use single quotes `'` for the FB_PASSWORD env variable or escape the `$` as `` `$ `` as powershell will otherwise try to resolve it has variable.

## The Details: More configuration options

There are a couple of options in Filebrowser, similar to the root and password configuration you have seen above. All of them are documented [here][options] (note that setting the options as env parameters works by upper casing and prefixing with `FB_`, so e.g. the option `root` becomes `FB_ROOT`), but I want to give you our scenario as an example: 

- We are defining the service as stack, using the [compose file format][compose]
- We run Filebrowser behind [Traefik][traefik], so we need to add a couple of labels (lines 17-22 below) for that and let Filebrowser know that it runs as `/filebrowser` by setting `FB_BASEURL=c:\azurefileshare` (line 26)
- As I wrote above, we want to use Filebrowser to explore an Azure File Share, which is available as `s:\` on the host, so we need to map this as bind mount (lines 7-9) and set the mapped path as `FB_ROOT` by setting `FB_ROOT=c:\azurefileshare` (line 25)
- Filebrowser needs to listen to requests coming in through Traefik, so we are opening it up for all IPs by setting `FB_ADDRESS=0.0.0.0` (line 24)
- As seen above, we also set the default password (line 27)

Overall, the stack definition looks like this:

{% highlight yaml linenos %}
version: "3.7"

services:
  filebrowser:
    image: tobiasfenster/filebrowser-windows:v2.18.0
    volumes:
      - source: s:\
        target: C:\azurefileshare
        type: bind
    networks:
      - traefik-public
    deploy:
      placement:
        constraints:
          - node.role != manager
      labels:
        - traefik.enable=true
        - traefik.http.routers.filebrowser.rule=Host(`${BASE_URL}`) && (PathPrefix(`/filebrowser`))
        - traefik.http.routers.filebrowser.entrypoints=websecure
        - traefik.http.routers.filebrowser.tls.certresolver=myresolver
        - traefik.http.services.filebrowser.loadBalancer.server.scheme=http
        - traefik.http.services.filebrowser.loadBalancer.server.port=8080
    environment:
      - FB_ADDRESS=0.0.0.0
      - FB_ROOT=c:\azurefileshare
      - FB_BASEURL=/filebrowser
      - FB_PASSWORD=${PASSWORD}
        
networks:
  traefik-public:
    external: true
{% endhighlight %}

Because of the great stack support in [Portainer][portainer], which we are using to manage our environments, we can easily define and deploy everything:

![stack deployment in portainer](/images/stack.png)
{: .centered}

I hope this gives you a good starting point with Filebrowser and allows you to run it on your Windows-based container hosts.

[self-service]: http://marketplace.cosmoconsult.com/product/?id=345E2CCC-C480-4DB3-9309-3FCD4065CED4
[afs]: https://docs.microsoft.com/en-us/azure/storage/files/storage-files-introduction
[filebrowser]: https://filebrowser.org/
[github]: https://github.com/tfenster/filebrowser-windows
[dockerfile]: https://github.com/tfenster/filebrowser-windows/blob/main/Dockerfile
[options]: https://filebrowser.org/cli/filebrowser#options
[compose]: https://docs.docker.com/compose/compose-file/
[traefik]: https://traefik.io
[portainer]: https://portainer.io