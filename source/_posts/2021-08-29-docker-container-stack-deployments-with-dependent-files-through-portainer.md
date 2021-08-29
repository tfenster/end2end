---
layout: post
title: "Docker container stack deployments with dependent files through Portainer"
permalink: docker-container-stack-deployments-with-dependent-files-through-portainer
date: 2021-08-29 17:58:00
comments: false
description: "Docker container stack deployments with dependent files through Portainer"
keywords: ""
image: /images/portainer-stack-2.png
categories:

tags:

---

I have [written before][prev-post] about the recently released [Portainer][portainer] feature of deploying a Docker container stack from a git repo. A part of that feature that I didn't immediately understand is that Portainer clones the whole repository before running the stack deployment command, and I want to explain why that can be very useful.

## The TL;DR
The two main scenarios for this that came to my mind are:

1. Use it to also deliver and update something like a configuration file
2. Use it to deliver sources and build an image on the fly

## The details: Use it to also deliver and update something like a configuration file

We are using [YARP][yarp] for some scenarios, which is a reverse proxy that can be configured with a JSON config file. My colleague [Markus Lippert][lippert] created a generic image that can do a couple of things that we need, like a custom authentication logic. But it needs configuration as you can see e.g. [here][yarp-sample] in a sample provided by the YARP team because this is the mechanism to let YARP know which requests to forward and where and how to forward them. Because Portainer clones the whole repository, we can just put that configuration file next to the compose file and deployment works easily.  To give you an idea, this is how the configuration file looks currently in dev:

{% highlight json linenos %}
{
    "ReverseProxy": {
        "Routes": {
            "script-updater": {
                "ClusterId": "script-updater",
                "AuthorizationPolicy": "default",
                "Match": {
                    "Path": "script-updater/{**catch-all}"
                },
                "Transforms": [
                    {
                        "PathRemovePrefix": "/script-updater"
                    }
                ]
            },
            "swarm-cleanup": {
                "ClusterId": "swarm-cleanup",
                "AuthorizationPolicy": "default",
                "Match": {
                    "Path": "swarm-cleanup/{**catch-all}"
                },
                "Transforms": [
                    {
                        "PathRemovePrefix": "/swarm-cleanup"
                    }
                ]
            }
        },
        "Clusters": {
            "script-updater": {
                "Destinations": {
                    "destination1": {
                        "Address": "http://script-updater-dev/"
                    }
                }
            },
            "swarm-cleanup": {
                "Destinations": {
                    "destination1": {
                        "Address": "http://swarm-cleanup-dev/"
                    }
                }
            }
        }
    }
}
{% endhighlight %}

Whenever we need to make a change, we can just do that in the repo as well, use the update mechanism in Portainer and have the change delivered to the target environment. With that, we are able to have good separation between the generic image and the specific configuration while at the same time allowing for easy rollouts.

## The details: Use it to deliver sources and build an image on the fly

We are not actively using that scenario at the moment, but I think it might prove handy in the future to set up environments where you want to test or debug your current dev code. To again give you an idea what this might look like: I just used the [Redis][redis] and [Flask][flask] web app combination which is provided as [getting started sample][compose-started] for [docker compose][docker-compose] and put it into a publicly available [Github repo][github]. If I deploy this stack initially, it looks like this

![screenshot of the deployment screen](/images/portainer-sample.png)
{: .centered}

If I then click on "Deploy the stack", Portainer clones the whole repo and uses the instructions in the compose file to create an image and start a container with it as well as the standard Redis container. Here is the compose file:

{% highlight docker-compose linenos %}
version: "3.9"
services:
  web:
    build: .
    ports:
      - "5000:5000"
  redis:
    image: "redis:alpine"
{% endhighlight %}

Line 4 tells the Docker engine to look into the current folder for a Dockerfile and build the image. I don't want to go into details how this particular image works because that is not the point of this blog post, but feel free to explore the [repo][github] as it is really simple. Now if I make a change to the Flask web app in the repo, I need to delete the container and image to allow a rebuild, and after that, I can just click "Pull and redeploy" to get the latest files and create an image again. 

As I wrote, we are not actively using this mechanism at the moment, but I am pretty sure we will at some point in the future because like with so many features in Portainer, it just works well and is easy to use!

[github]: https://github.com/tfenster/portainer-compose-sample
[redis]: https://redis.io/
[flask]: https://flask.palletsprojects.com/en/2.0.x/
[prev-post]: https://tobiasfenster.io/use-portainer-to-deploy-and-update-docker-container-stacks-from-a-git-repo
[portainer]: https://portainer.io
[docker-compose]: https://docs.docker.com/compose/
[compose-started]: https://docs.docker.com/compose/gettingstarted/
[yarp]: https://microsoft.github.io/reverse-proxy/index.html
[lippert]: https://twitter.com/lippert_markus
[yarp-sample]: https://github.com/microsoft/reverse-proxy/blob/main/samples/BasicYarpSample/appsettings.json