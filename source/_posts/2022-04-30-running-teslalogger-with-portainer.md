---
layout: post
title: "Running Teslalogger with Portainer"
permalink: running-teslalogger-with-portainer
date: 2022-04-30 13:14:33
comments: false
description: "Running Teslalogger with Portainer"
keywords: ""
image: /images/teslalogger1.png
categories:

tags:

---

This time, a blog post about "non-business tech", but of course containerized and with [Portainer][portainer]: [Teslalogger][teslalogger] is a self-hosted data logger for [Tesla][tesla] cars. The idea of this and similar offerings is to use the extensive Tesla API to collect data about your car, keep for historical comparison and graphical analysis. The special thing about Teslalogger is, that it is not a cloud service like most other similar offerings, but instead you host it yourself on a [Raspberry Pi][raspi] or as a collection of four Linux containers. Of course, I went with the latter :)

## The TL;DR

The Teslalogger authors provide good documentation for the [containerized setup][doc], but if you want a setup like mine where I use Portainer for the deployment and the host is ARMv7 (actually a [SolidRun CuBox][solidrun]), it works slightly differently:

1. Follow the instructions in the [Teslalogger docs][doc] until step 5. I'll assume that you have cloned the Git repo into `/src/github/TeslaLogger` for the next steps 
2. Create a subfolder `GrafanaDashboards` in the TeslaLogger subfolder. Assuming the folder mentioned abouve, that would be `mkdir /src/github/TeslaLogger/TeslaLogger/GrafanaDashboards`
3. Run `docker-compose build` (or `docker compose build` on newer docker versions) on your host to create the necessary images. 
4. With that we have everything in place and can use Portainer to deploy the four containers in a stack:
    - Open Portainer, go to "Stacks" and select "Add stack"
    - Give it a name, e.g. "teslalogger" and select "Git repository" as build method
    - Use `https://github.com/tfenster/TeslaLogger/` as Repository URL as I had to make some small changes (check the details, if you want to learn more) and `docker-compose.portainer.yml` as compose path
    - Add environment variables as follows in "advanced mode":
    ```
    TESLALOGGER_DIR=/src/github/TeslaLogger
    MYSQL_USER=teslalogger
    MYSQL_PASSWORD=teslalogger
    MYSQL_DATABASE=teslalogger
    MYSQL_ROOT_PASSWORD=teslalogger
    GRAFANA_PASSWORD=teslalogger
    ```
5. Hit "Deploy the stack", wait for 5-10 minutes and then go to http://&lt;your host&gt;:8888/admin. Mine is called `cubox`, so I can go to http://cubox:8888/admin. The dashboards using [Grafana][grafana] are available at http://&lt;your host&gt;:3000

With that you should get the TeslaLogger admin interface and the dashboards:

![TeslaLogger admin interface](/images/teslalogger1.png)
{: .centered}

![TeslaLogger grafana dashboard](/images/teslalogger2.png)
{: .centered}

As you can probably see just from those two screenshots, an incredibly great piece of software. Kudos to [bassmaster187] and [superfloh247] (if the Github statistics are an indication who has done the most work on this)!

## The details: How it works and what I've changed

Looking behind the scenes, you see four containers working together to provide the "Teslalogger experience"

- [MariaDB][mariadb] as relational database
- [Grafana][grafana] as platform for the dashboards
- The core Teslalogger service
- A web server as frontend

To make it work for me, I had to change the following things as I want to run it on ARMv7 and in Portainer:

- As I can't run a docker compose build from within Portainer, I am creating the images first and then reference them. I would like to have ready-made images for those scenarios, but I'll ask the Teslalogger developers first, if they mind.
- The standard docker-compose file uses `mariadb:10.4.7` from the docker hub, but that doesn't work with ARMv7, so I went to `lscr.io/linuxserver/mariadb:10.5.15`
- The volumes referenced in the standard docker-compose file references relative paths. Again, as I am running from Portainer, that doesn't work, so I added an environment variable `TESLALOGGER_DIR` to add the path as environment variable
- As Portainer stacks have a great way to work with environment variables, I moved away from the `.env` file in general
- I removed the port mappings for the core service and MariaDB as it didn't seem necessary and I didn't want to expose those ports in case anyone is running this on a public network

As I wrote above, I'll try to contact the Teslalogger developers to combine this into an even easier experience where deploying the whole thing could become extremely easy through a Portainer app template, but let's see if they agree :)

[portainer]: https://www.portainer.io
[teslalogger]: https://github.com/bassmaster187/TeslaLogger#teslalogger
[tesla]: https://tesla.com
[raspi]: https://www.raspberrypi.org/
[doc]: https://github.com/bassmaster187/TeslaLogger/blob/master/docker_setup.md
[solidrun]: https://www.solid-run.com/fanless-computers/cubox/
[grafana]: https://grafana.com/
[mariadb]: https://mariadb.org/
[bassmaster187]: https://github.com/bassmaster187
[superfloh247]: https://github.com/superfloh247