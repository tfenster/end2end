---
layout: post
title: "Use Portainer to deploy and update Docker container stacks from a git repo"
permalink: use-portainer-to-deploy-and-update-docker-container-stacks-from-a-git-repo
date: 2021-06-05 21:07:06
comments: false
description: "Use Portainer to deploy and update Docker container stacks from a git repo"
keywords: ""
image: /images/portainer-stack.png
categories:

tags:

---

This will be a quick intro to an upcoming feature in [Portainer][portainer], but please note that as of today (June 5th 2021) this is in preview, so you shouldn't use it in a production environment, and it is scheduled for but not guaranteed to appear as supported in Portainer Community Edition 2.6. 

## The TL;DR
If you run containerized environments in any way that you need to update, you might already use a mechanism like [docker compose][docker-compose] files, either directly for standalone deployments or as stacks in [Docker Swarm][swarm]. If you want to be able to do that in a reproducible way across target environments and have an easy, traceable way to update, then you probably put them into a version control system like git. However you still need a mechanism to get the compose files initially to those environments and also to deliver updates. With the new feature in portainer, you can get them from a repository, possibly including authentication and environment variables. If you have a new version, you just push it to the repository and then easily get those changes from Portainer. The initial deployment can look like this:

![screenshot of the deployment screen](/images/portainer-stack-screen.png)
{: .centered}

As you can see, you let Portainer know where to find the file (repository URL, reference, path and authentication) and then you can deploy it with "Deploy the stack". If you later need to update it, you open the stack by clicking on the name and then start the process with "Pull and redeploy".

![screenshot of the update screen](/images/portainer-stack-update.png)
{: .centered}

You can also change the repository reference, e.g. to switch branches or use a specific tag. 

There are still a couple of small issues, but once those are ironed out, this amazing new feature will be a tremendous help in managing your containerized environments!

## The details: Defining a compose file
If you are now wondering, how you can define such a compose file, this is an example how you might deploy a test and a prod Microsoft Dynamics 365 Business Central service with the country/language version as environment variable:

{% highlight yaml linenos %}
version: "3.7"

services:
  bc-prod:
    image: bcartifacts/cosmobc:onprem-18.0.23013.23795-{LANG}
    environment:
      - accept_eula=y
      ...
    networks:
      - traefik-public
    deploy:
      placement:
        constraints:
          - node.role == manager
      labels:
        - traefik.enable=true
        ...
        
  bc-test:
    image: bcartifacts/cosmobc:onprem-18.1.24822.26330-{LANG}
    environment:
      - accept_eula=y
      ...
    networks:
      - traefik-public
    deploy:
      placement:
        constraints:
          - node.role == manager
      labels:
        - traefik.enable=true
        ...

networks:
  traefik-public:
    external: true
{% endhighlight %}

You would definitely have more environment variables and also more labels if running behind traefik (both left out to reduce it to the relevant parts), but you can see in lines 5 and 20 how you would define the version. If you later update the production system to 18.1 and then maybe the test system to 18.2, you could just do that in git, pull the changes in Portainer and easily update that way. If you need to go back, you do that in git and deploy again. 

You can also see in the same lines, how an environment variable (in this case for the language version) can be used. The first deployment could e.g. have an environment variable `LANG=de` for the German version, while a second one could have `LANG=dk` for the Danish version. That way you could use the same definition, but differentiate through the environment variable. And because Portainer doesn't automatically pull the changes but requires a manual trigger, you can easily hold back new version if they e.g. are only working as expected for a specific localization. Of course there are also other use cases where you would want to have an automatic check with a schedule or a webhook, which is planned for an upcoming release as well as you can see in the [roadmap][roadmap].

Once more, great new feature coming to Portainer!


[portainer]: https://portainer.io
[docker-compose]: https://docs.docker.com/compose/
[swarm]: https://docs.docker.com/engine/swarm/
[roadmap]: https://github.com/portainer/roadmap/issues/9