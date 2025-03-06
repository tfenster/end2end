---
layout: post
title: "34spiele.de, an easy containerized, Azure-driven dev and ops experience"
permalink: 34spielede-an-easy-containerized-azure-driven-dev-experience
date: 2023-04-23 13:00:41
comments: false
description: "34spiele.de, an easy containerized, Azure-driven dev and ops experience"
keywords: ""
image: /images/34spiele.png
categories:

tags:

---

The [easyCredit Basketball Bundesliga][ecbbl] is the top-level German Basketball league, but it doesn't have an option to try and predict the remaining games of a season to see what the standings at the end might be. As that isn't such a complicated task, I decided to just build it: [34spiele.de][vs].

## The TL;DR

As the regular season ends in two weeks, this will be quite short-lived, so I tried to go with the easiest, least-effort options, and it went quite well:

- The dev stack is [server-side Blazor][blazor] with the [Ant Design Blazor][antblazor] components, one of the setups I feel most comfortable and efficient with.
- Development was and is done in a local [devcontainer][devc] while travelling and in a [GitHub Codespace][ghc] in case of a good internet connection, which makes it rapidly reproducible and without no to very few local dependencies (a browser or [Docker Desktop][dd]).
- The sources are stored in a (private) GitHub repo with a workflow to trigger the build and push of a custom image with the code for every tag.
- Operations is using an [Azure Web App][awa] with a custom container image, which was effortless to set up and brings scalability, observability and continuous deployment out of the box.
- I've held the domain 34spiele.de ("34 Spiele" means "34 games" as the league has 34 regular season games) for a couple of years as I always had some ideas about doing something related to German basketball there, and again, setting that up as custom domain for the web app and getting a free SSL certificate for it worked immediately.

If you want to take a look at the result, go check [34spiele.de][vs]. Be warned though that it is only available in German, as I sincerely doubt that there is a lot of interest outside of Germany for this offering[^1].

![Screenshot of 34spiele.de](/images/34spiele.png)
{: .centered}

## The details: The very few things I struggled with for a bit

First, I wanted to go with an [Azure Container App][aca], but I couldn't figure out how to easily set up a custom domain and SSL certificate for it. Azure Web Apps offer both out of the box (see [here][domain] and [here][ssl]), so I went with that.

With the [build and push Docker images][bap] action, the CI (Continuous Integration) part of CI/CD was only very few lines of code, as the automated tests are running as part of the Dockerfile:

GitHub workflow:
{% highlight YAML linenos %}
...
    -
      name: Build and push
      uses: docker/build-push-action@v4
      with:
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        push: true
...
{% endhighlight %}

Dockerfile:
{% highlight Dockerfile linenos %}
...
RUN dotnet test
...
{% endhighlight %}

One might argue that this isn't an ideal setup and I would fully agree for bigger applications and teams, I think it is perfectly fine for a small app created and maintained by only me.

The CD (Continuous Deployment) part was slightly more interesting: The [documentation][cd] states that "App Service adds a webhook to your repository in Azure Container Registry or Docker Hub". However, this didn't automatically happen for me. But the solution was trivial again: In Azure Web App Deployment Center, you can find a webhook URL (make sure to have "SCM Basic Auth Publishing Credentials" is enabled in the Configurations -> Platform Settings of the Web App). I could copy that and paste it into the webhook field of my repository on Docker Hub, and from then on, it worked fine. So my delivery process now is to just create a tag on my GitHub repo, which automatically triggers a workflow run with the build and push of the container image (including running the automated tests), which in turn through the webhook triggers an update of the Azure Web App.

The last thing wasn't really technical: The Basketball Bundesliga doesn't provide any kind of public data feed. I could probably have reverse engineered their website or scraped the data from the HTML output, but I kind of feared that this would be an illegal use of their data[^2], so I just entered all played and outstanding games manually. Approx. 350 lines of code, so no big problem.

That's it, that's the list of my "problems" when creating it. Bottom line: With the combination of GitHub (repo, workflow, Codespace), VS Code (devcontainer), Docker (Docker Desktop, container image), Azure (Azure Web Apps) and C# (Blazor, Ant Design) it was quite a smooth experience for a fun little side project, so I can only recommend that setup for anyone with a similar task ahead.


[^1]: Actually, there is also quite limited interest within Germany :)
[^2]: And this is Germany, so that could lead to serious problems. One might wonder whether open data could lead to more applications like mine, which in turn might lead to more interest in the league, but past experience shows that the league doesn't necessarily agree to such progressive ideas.

[ecbbl]: https://www.easycredit-bbl.de
[vs]: https://34spiele.de
[blazor]: https://learn.microsoft.com/en-us/aspnet/core/blazor/hosting-models?view=aspnetcore-7.0#blazor-server
[antblazor]: https://antblazor.com/
[devc]: https://code.visualstudio.com/docs/devcontainers/containers
[ghc]: https://github.com/features/codespaces
[dd]: https://docs.docker.com/desktop/
[awa]: https://azure.microsoft.com/en-us/products/app-service/web
[aca]: https://learn.microsoft.com/en-us/azure/container-apps/overview
[domain]: https://learn.microsoft.com/en-us/azure/app-service/app-service-web-tutorial-custom-domain
[ssl]: https://learn.microsoft.com/en-us/azure/app-service/configure-ssl-bindings
[bap]: https://github.com/marketplace/actions/build-and-push-docker-images
[cd]: https://learn.microsoft.com/en-us/azure/app-service/deploy-ci-cd-custom-container?tabs=dockerhub&pivots=container-linux#4-enable-cicd