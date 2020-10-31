---
layout: post
title: "Server jobs in Azure DevOps pipelines"
permalink: server-jobs-in-azure-devops-pipelines
date: 2020-10-31 13:29:05
comments: false
description: "Server jobs in Azure DevOps pipelines"
keywords: ""
categories:
image: /images/server-task.jpg

tags:

---

I am a big fan of completely pristine build environments. If you create dedicated VMs for your builds and host Azure DevOps agents there, you can try to keep those under control, but still something might go wrong and you might inadvertently end up with different environments. A nice solution to that are containerized[^1] build agents that are started on demand because you can be 100% sure that the environment is unchanged. Microsoft even provides a [quite detailed documentation][image-doc] of how to create an image for that purpose. One drawback of that approach is that you need a way to start the agent container and the obvious answer to that is a script which calls whatever automation you have in place. But that requires an agent as well, so you have to wait for one of the standard Azure agents to execute that script which creates your agent. That adds an unnecessary overhead which isn't a lot but usually is around 30 seconds. If your actual build is done (or fails) in seconds, that is quite annoying.

## The TL;DR
Azure Pipelines offer a nice solution for that: Server jobs. A limited number of automation tasks can run directly on the server and don't need an agent. Those currently are well hidden in the documentation as you need to switch to the Classic tab [here][here] to get to it[^2], but one of them is the "[Invoke REST API task][rest]". With that you can call an arbitrary REST API, so if you create one to start your agent, this becomes almost instantaneous. Starting the container takes a bit as it needs to register in the right agent pool and you need a way to get notified when the agent is available but that is unavoidable if you want to create your agent containers on demand. Still, you are quicker than with the standard Azure agents, you have the same full control of installed software as with self-hosted VMs and the agent is always pristine. This is what the start of a build looks like with te server job on the left compared to using an Azure agent on the right.

<video width="100%" controls>
  <source type="video/mp4" src="/images/server-tasks.mp4">
</video>
{: .centered}

You can see how the server job starts almost immediately while the Azure agent takes quite some time to get started. The Azure agent sometimes is a bit quicker, sometimes a bit slower, but it always adds significant overhead.

## The details: The service call
Calling the REST service is actually quite straightforward. The only somewhat cumbersome thing is that you can't just give it a URL but instead need to create a [service connection][serv-conn] that you can then reference. I went with a [Generic service connection][gen-serv-conn], which only requires a couple of clicks or two service calls (one to create the connections, one to allow access from the pipelines), but I still don't see the point. After that the relevant part in my YAML-based pipeline looks like this:

{% highlight yaml linenos %}
- task: InvokeRESTAPI@1
  displayName: COSMO - Create Build Agent Container
  inputs:
    connectionType:    connectedServiceName
    serviceConnection: Swarm
    method:            POST
    headers:           '{"Content-Type":"application/json", "Authorization": "Basic $(system.AccessToken)", "Collection-URI": "$(system.CollectionUri)"}'
    urlSuffix:         "docker/$(swarmversion)/Service"
    body: '{
        "mountDockerEngine":  true,
        "serviceName":        "buildagent-$(UID)",
        "environmentVars":    [
                                  "AZP_URL=$(system.CollectionUri)",
                                  "AZP_TOKEN=$(system.AccessToken)",
                                  "AZP_AGENT_NAME=$(UID)",
                                  "UID=$(UID)",
                                  "AZP_POOL=$(poolName)",
                                  "cc.CorrelationID=$(system.CollectionUri)|$(system.TeamProjectId)|$(system.JobId)"
                              ],
        "projectId":          "$(System.TeamProjectId)",
        "orgId":              "$(System.CollectionId)",
        "additionalLabels":   {
                                  "UID":  "$(UID)"
                              },
        "additionalMounts":   [
                                {
                                  "source": "f:\\bcartifacts.cache",
                                  "target": "c:\\bcartifacts.cache",
                                  "type": "bind"
                                }
                              ],
        "memoryGb":           2,
        "image":              "$(containerizedBuildAgentImage)"
      }'
{% endhighlight %}

You can see the reference to the service connection in line 5 which is used for the base URL ("https://myserver.com") and then the urlSuffix in line 8 determines the rest of the URL. You can also see the HTTP method (line 6), headers (line 7) and the body (line 9 to the end). In the body you see that my service in the backend takes a couple of arguments to know which image to use, how much memory to allocate, what mounts to add and so on. You can also see that the task can use YAML variables like everywhere else in a YAML pipeline, like the `containerizedBuildAgentImage` in the next-to-last line

## The details: The build agent image
As I wrote in the beginning, the build agent image is quite close to what Microsoft already suggests with two major changes: I am using the dotnet framework 4.8 runtime image and I install additional software, namely the Docker client, [bccontainerhelper][bccontainerhelper] and a custom PowerShell module created by my colleague Michael Megel. In the Dockerfile it looks like this

{% highlight Dockerfile linenos %}
RUN iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')); `
    choco install -y docker-cli; `
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; `
    Install-PackageProvider -Name 'Nuget' -Force; `
    Install-Module 'bccontainerhelper' -Force; `
    Install-Module AzureDevOpsAPIUtils -Force -ErrorAction SilentlyContinue
{% endhighlight %}

If you want the full context, you can find the Dockerfile [here][Dockerfile]. The reason for most of those additions is that we are mostly building Microsoft Dynamics 365 Business Central solutions and bccontainerhelper and the dotnet framework help there[^3]. The Docker client is necessary because we are also running Docker commands during the builds. Now you might be wondering how we can run Docker commands in a Docker container, but that is fairly easy as well: If you mount the named pipe for the Docker engine into the container, you can then run Docker commands as if you were running directly on the host. Be aware though that this allows full access to your engine...

Overall, I am quite happy with the solution as it in my opinion combines the best of all possible scenarios with only a very small overhead.

[^1]: I might have a slight obsession with containers: https://twitter.com/waldo1001/status/1322074542194462720
[^2]: this hopefully changes soon as I have created a [Pull Request][pr] to fix it as I only stumbled across that by chance after looking for that list for quite some while
[^3]: Actually the dotnet framework is necessary for the new compiler step by [ALOps][alops] but I am not sure how official that is yet ;)
[image-doc]: https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/docker?view=azure-devops
[here]: https://docs.microsoft.com/en-us/azure/devops/pipelines/process/phases?view=azure-devops&tabs=classic#server-jobs
[pr]: https://github.com/MicrosoftDocs/azure-devops-docs/pull/9584
[rest]: https://docs.microsoft.com/en-us/azure/devops/pipelines/tasks/utility/http-rest-api?view=azure-devops
[serv-conn]: https://docs.microsoft.com/en-us/azure/devops/pipelines/library/service-endpoints?view=azure-devops&tabs=yaml
[gen-serv-conn]: https://docs.microsoft.com/en-us/azure/devops/pipelines/library/service-endpoints?view=azure-devops&tabs=yaml#sep-generic
[Dockerfile]: https://github.com/cosmoconsult/azdevops-build-agent-image/blob/master/Dockerfile
[bccontainerhelper]: https://github.com/microsoft/navcontainerhelper
[alops]: https://github.com/HodorNV/ALOps