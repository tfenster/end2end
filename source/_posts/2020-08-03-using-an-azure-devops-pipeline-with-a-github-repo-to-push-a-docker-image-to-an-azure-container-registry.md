---
layout: post
title: "Using an Azure DevOps pipeline with a GitHub repo to push a Docker image to an Azure Container Registry"
permalink: using-an-azure-devops-pipeline-with-a-github-repo-to-push-a-docker-image-to-an-azure-container-registry
date: 2020-08-03 21:33:55
comments: false
description: "Using an Azure DevOps pipeline with a GitHub repo to push a Docker image to an Azure Container Registry"
keywords: ""
categories:
image: /images/github-repo-azdevops-pipeline-acr.png

tags:

---

When [Microsoft bought GitHub][microsoft-bought-github], a bit of an uproar went through the Open Source community as many developers still thought of Microsoft as a very closed, anti-Open-Source company, and they feared that Microsoft would take GitHub away as leading platform for Open Source developments. This fear has since turned out to be unfounded as Microsoft has actually started to expand the free service offerings for GitHub and instead of taking away features, has enriched its capabilities by offering — among other nice improvements — a perfect integration into Azure DevOps. One part of that integration story is the easy setup of an Azure pipeline to build code in a GitHub repository. While GitHub actions as equivalent to Azure pipelines are already well-featured (and I previously [wrote][wrote] about that), I knew that the setup for building and pushing a Docker image from an Azure pipeline to an Azure Container Registry (ACR) repository is effortless, so I went with Azure pipelines this time.

## The TL;DR
The setup actually is almost child's play: When you create a new pipeline, Azure DevOps asks you where your code is and one of the predefined answers is GitHub

![where-is-your-code](/images/wiyc.png)
{: .centered}

The next step is to select the right Git repository on GitHub and you can easily search for the one you want

![select-a-repository](/images/select-repo.png)
{: .centered}

After that, you might have to set up the authentication between the pipeline and the GitHub repo and then you are presented with a selection of predefined pipelines, including one to "Build and push an image" to Azure Container Registry

![configure-pipeline](/images/configure-pipeline.png)
{: .centered}

As the last step, you need to select the subscription and then your ACR followed by entering a name for the image you want and the Dockerfile to use. If you don't have an ACR yet, it is only a couple of clicks away as explained in this [step-by-step guide][acr-create].

![repo-config](/images/repo-config.png)
{: .centered}

With that, everything is configured and created for you and you end up with an azure-pipelines.yml file which allows you to build and push your image. You might have to change a couple of things as it e.g. uses a Linux agent VM by default, but that should be fairly easy as well.

## The details: Improving the pipeline
As I already wrote, the generated pipeline is fine, but you might have to do some things to adjust it to your specific use case. I wanted to build the enhanced version of the "SDK" image for Business Central described [here][sdk], more on that later, so I had to use a Windows-based build agent. Fixing that is easy by you just changing the `vmImageName` to `windows-2019`, other possible images can be found [here][images].

{% highlight yaml linenos %}
variables:
  ...
  # Agent VM image name
  vmImageName: 'windows-2019'
{% endhighlight %}

The other major change I had to do was to avoid the `buildAndPush` command and instead use separate tasks, one with the `build` and one with the `push` command. This was necessary because I am using multiple Docker build arguments (again, more on that later) and as explained [here][buildAndPush], those are ignored when using `buildAndPush`. While it is a bit inconvenient, it makes sense as the command wouldn't know whether the arguments are intended for build or push, and the actual change is also quite straightforward as you can see in lines 9-18 and 20-27:

{% highlight yaml linenos %}
stages:
- stage: Build
  displayName: Build and push stage
  jobs:  
  - job: Build
    displayName: Build
    ...
    steps:
    - task: Docker@2
      displayName: Build an image
      inputs:
        command: build
        repository: $(imageRepository)
        dockerfile: $(dockerfilePath)
        containerRegistry: $(dockerRegistryServiceConnection)
        tags: |
          $(tag)
        arguments: ...
    
    - task: Docker@2
      displayName: Push an image to container registry
      inputs:
        command: push
        repository: $(imageRepository)
        containerRegistry: $(dockerRegistryServiceConnection)
        tags: |
          $(tag)
{% endhighlight %}

If you want to check out the full yaml pipeline, you can find it [here][full-pipeline]

## The details: An improved SDK image
Since writing my blog post on an artifacts-based [SDK image][sdk], my colleague [Bert Krätge][bert] has taken the approach [a couple of steps further][bert-github] by adding the assemblies necessary for some solutions as well as a dummy ruleset to prepare that part. He also provided a [handy script][converter] to convert the output of the compiler to something that Azure DevOps can understand.

I moved this over to our [company GitHub repo][cosmo-github] and unified the Dockerfile so that it can use both nanoserver and servercore Windows base image. This is done by adding another build variable which needs to be set to either `nanoserver` or `servercore`, so that the `FROM` statement correctly refers to the right base image:

{% highlight Dockerfile linenos %}
FROM mcr.microsoft.com/windows/$BASETYPE:$BASEVERSION
{% endhighlight %}

With that, the [Dockerfile][Dockerfile] now has eight build arguments:

- `BASEVERSION` and `BASETYPE` for the Windows Server base image which is used, e.g. `1809` and `servercore`
- `NCHVERSION` for the [navcontainerhelper][navcontainerhelper] version
- `BCTYPE`, `BCVERSION` and `BCCOUNTRY` for the Business Central artifact type (`onprem` or `sandbox`), version (e.g. `16.3`) and country (e.g. `de`)
- `BCSTORAGEACCOUNT` and `BCSASTOKEN` for the Business Central storage account type (`bcartifacts` or `bcinsider`) and if necessary the SAS token to authenticate

Those need to be set during the Docker build, so I needed to add them to the right task in the pipeline. As I wrote before, the `buildAndPush` command doesn't support that, so I split it into separate tasks using the `build` and `push` commands. The task with the `build` command now also has an input `arguments` which contains all the build arguments:

{% highlight yaml linenos %}
arguments: --build-arg BASEVERSION=$(BASEVERSION) --build-arg BASETYPE=$(BASETYPE) --build-arg NCHVERSION=$(NCHVERSION) --build-arg BCTYPE=$(BCTYPE) --build-arg BCVERSION=$(BCVERSION) --build-arg BCCOUNTRY=$(BCCOUNTRY) --build-arg BCSASTOKEN=$(BCSASTOKEN) --build-arg BCSTORAGEACCOUNT=$(BCSTORAGEACCOUNT)
{% endhighlight %}

As you can see, all arguments are referencing variables of the same name. Those are defined for the Azure pipeline, so the pipeline itself stays generic.

![pipeline-variables](/images/pipeline-variables.png)
{: .centered}

When I now run the Azure pipeline, it fetches the code from the GitHub repository and pushes the image to the Azure Container Registry, all very seamlessly integrated between the "old" Microsoft product Azure pipelines (looking back at a fairly long history in Team Foundation Server), the "new" Microsoft product Azure Container Registry and the recently acquired Microsoft product GitHub.

[microsoft-bought-github]: https://news.microsoft.com/2018/06/04/microsoft-to-acquire-github-for-7-5-billion/
[wrote]: https://tobiasfenster.io/handle-secrets-in-windows-based-github-actions-and-docker-containers
[sdk]: https://tobiasfenster.io/making-use-of-the-new-bc-artifacts
[images]: https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/hosted?view=azure-devops&tabs=yaml
[buildAndPush]: https://docs.microsoft.com/en-us/azure/devops/pipelines/tasks/build/docker?view=azure-devops#why-does-docker-task-ignore-arguments-passed-to-buildandpush-command
[full-pipeline]: https://github.com/cosmoconsult/cosmo-compiler/blob/87a6786810d978db26fe2f00f4a24c99e46ee2b4/azure-pipelines.yml
[acr-create]: https://docs.microsoft.com/de-de/azure/container-registry/container-registry-get-started-portal#create-a-container-registry
[bert]: https://twitter.com/rockclimber81
[bert-github]: https://github.com/navrockClimber/alc-docker/
[converter]: https://github.com/NAVRockClimber/convert-alc-output/blob/d7abd2beac382db885b94511b4939840a29066aa/Convert-ALC-Output.ps1
[cosmo-github]: https://github.com/cosmoconsult/cosmo-compiler
[Dockerfile]: https://github.com/cosmoconsult/cosmo-compiler/blob/7374d7d258f0c78a34bae69e272299f8891ba66f/Dockerfile
[navcontainerhelper]: https://github.com/microsoft/navcontainerhelper