---
layout: post
title: "Docker Offload for blazing fast AI development"
permalink: docker-offload-for-blazing-fast-ai-development
date: 2025-07-10 08:00:24
comments: false
description: "Docker Offload for blazing fast AI development"
keywords: ""
image: /images/offload.png
categories:

tags:

---

Maybe you have seen the announcement, Docker just introduced [Docker Offload][offload], an offering to run especially (but not only) GPU-reliant AI workloads in a secure, managed cloud environment. It works seamlessly through the familiar UI of Docker Desktop or the Docker CLI. Docker has shared a very good introduction and samples, but I want to show you how my little sample application I introduced in a [previous blog post][prev] can be used in Offload as well.

## The TL;DR

If you want to follow along quickly, here are the steps

- Clone my repository at [http://github.com/tfenster/dotnet-model-runner/](http://github.com/tfenster/dotnet-model-runner/)
- Go to the `.devcontainer` folder and run `docker compose up -d`
- Once it has pulled and started everything (should be blazing fast thanks to the Offloud cloud inftrastructure), use the `Dev Containers: Attach to Running Container...` action of the VS Code "Dev Containers" [extension][devc]. To learn more why the usual `Dev Containers: Clone Repository in Container Volume` action doesn't work (yet), check the details below
- Wait until everything has loaded ("installing server", "starting server")
- Do two steps which typically would happen automatically through the devcontainer setup, but for now doesn't for the reasons explained below:
  - Install the "C# Dev Kit" [extension][devk] in the devcontainer
  - Run `dotnet dev-certs https` in the devcontainer
- Start debugging by hitting F5

With that you should get my little chat application to talk to the LLMs via the [Docker Model Runner (DMR)][dmr], but this time not locally, but in the Offload cloud infrastructure. The whole interaction, debugging, executing etc works exactly the same, but (at least for me) at lot more performant than locally. A really smooth experience.

## The details: Models in docker compose and how to reference them

I want to point out one feature in docker compose that is relatively new and lets you define DMR AI models as components of your application like other (containerized) parts. It looks like this in my example application:

{% highlight yaml linenos %}
services:
  dev:
    image: "mcr.microsoft.com/devcontainers/dotnet:1-9.0-bookworm"
    models:
      - smollm2
      - phi4
    volumes:
      - ..:/workspace:cached
    command: /bin/sh -c "while sleep 1000; do :; done"

models:
  smollm2:
    model: ai/smollm2
  phi4:
    model: ai/phi4
{% endhighlight %}

In lines 11-15 you see how DMR models can be easily defined and lines 5 and 6 show how they are referenced by applications. This leads to among others an environment variable `SMOLLM2_URL` being populated with the URL where the models are available from within the container. If you want to learn more about how to configure this and other elements, check the [official docs][docs]. Now in my client application, I need a reference to the models. As I am using the OpenAI .NET API library, that is just a small piece of code:

{% highlight csharp linenos %}
var baseUrl = Environment.GetEnvironmentVariable("SMOLLM2_URL")
    ?? throw new InvalidOperationException("SMOLLM2_URL environment variable is not set.");
var endpoint = baseUrl.Replace("/v1", "/llama.cpp/v1");
var options = new OpenAIClientOptions
{
    Endpoint = new Uri(endpoint),
};
return new OpenAIClient(new ApiKeyCredential("unused"), options);
{% endhighlight %}

You can see first the retrieval of the environment variable, then I small change to the URL to get the expected endpoint and then the configuration of the `OpenAIClient`.

## The details: Why so complicated (when it comes to the devcontainer)

Now, why can't we just clone the repo into a volume and run the container on that? The model configuration as explained above is only supported with docker compose v2.28 and newer. However, VS Code starts what they call a "bootstrap container" to set up the actual devcontainer and in this case also running the docker compose commands and unfortunately doesn't provide a way to override or configure that. Because that container has docker compose v2.17, the model element doesn't work and startup fails.

I have added [a comment][comment] that a configuration option for this bootstrap container would be very useful, but until that happens, a workaround like explained above is needed.

[offload]: https://www.docker.com/products/docker-offload/
[prev]: /docker-ai-models-are-available-on-windows-laptops-now
[devc]: https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers
[devk]: https://marketplace.visualstudio.com/items?itemName=ms-dotnettools.csdevkit
[dmr]: https://docs.docker.com/ai/model-runner/
[comment]: https://github.com/microsoft/vscode-remote-release/issues/8102#issuecomment-3054282845