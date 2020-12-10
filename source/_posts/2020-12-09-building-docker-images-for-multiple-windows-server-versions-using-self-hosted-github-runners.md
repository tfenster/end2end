---
layout: post
title: "Building Docker images for multiple Windows Server versions using self hosted containerized Github runners"
permalink: building-docker-images-for-multiple-windows-server-versions-using-self-hosted-github-runners
date: 2020-12-09 22:22:36
comments: false
description: "Building Docker images for multiple Windows Server versions using self-hosted, containerized Github runners"
keywords: ""
categories:
image: /images/multi-windows.png

tags:

---

In our Azure DevOps & Docker Self-Service offering, we already have a couple of instances up and running, based on Windows Server 1809. And while that works well, we also decided to take a look at newer Windows Server versions, namely Windows Server 2004. But if we want to start new instances on 2004 while keeping the older ones supported on 1809, that means that we have to create Docker images for our service tier on both versions. The easy approach is one image with "-1809" and one with "-2004" as suffix for the tag, but that is not exactly an elegant solution which has a couple of drawbacks. Fortunately, Docker has an (experimental) concept called [manifests][manifests], that allows you to "hide" multiple tags behind one and let Docker decide, which is the right one.

## The TL;DR
Assuming that we have an image `tobiasfenster/my-fantastic-image` with two tags, `1.0.0-1809` (for Windows Server 1809) and `1.0.0-2004` (for Windows Server 2004), we can do something like

`docker manifest create tobiasfenster/my-fantastic-image:1.0.0 tobiasfenster/my-fantastic-image:1.0.0-1809 tobiasfenster/my-fantastic-image:1.0.0-2004`

and then

`docker manifest push tobiasfenster/my-fantastic-image:1.0.0`

If you want to use those images, you can just do

`docker run tobiasfenster/my-fantastic-image:1.0.0`

and Docker will automatically decide, which one is the right image for you. On a side note, the same works for different architectures as well, e.g. linux/amd64, linux/arm64 and windows/amd64. Some info on that can be found in my old blog post [here][linux]. For our .NET Core based services, we are using GitHub for version control and also GitHub [actions][actions]. However the problem is, that GitHub currently only offer Windows Server 1809 based runners and while you can build 1809 images on a 2004 host using hyperv isolation, the way doesn't work. But you can connect your own runners, so I created a container image for that ([sources][sources] and [Docker hub][hub]) to make deployment easier and with that setup, we can now build all our images for all needed Windows Server versions and still reference them with the same name!

## The details: Creating multiple Docker images from the same Dockerfile and combining them with a manifest
As we have already seen, it is possible, to reference multiple different images[^1] with the same name, but of course we also want to make producing them as easy as possible as well by only using one Dockerfile. The trick here are build arguments: You have variables in your Dockerfile and let the `docker build` call now, how to substitute them. As an example, let's take the following Dockerfile which is actually one that we use for one of our services

{% highlight Dockerfile linenos %}
# escape=`
ARG BASE
FROM mcr.microsoft.com/dotnet/core/sdk:3.1-nanoserver-$BASE AS build

WORKDIR /src

COPY ["shared/shared.csproj", "shared/"]
RUN dotnet restore "shared/shared.csproj"
COPY ./shared/ shared/

COPY ["core/core.csproj", "core/"]
RUN dotnet restore "core/core.csproj"
COPY ./core/ core/

WORKDIR "/src/core"
USER ContainerAdministrator
RUN dotnet build "core.csproj" -c Release -o /app/build
RUN dotnet publish "core.csproj" -c Release -o /app/publish

FROM mcr.microsoft.com/powershell:lts-nanoserver-$BASE as vsdbg
WORKDIR /vsdbg
RUN pwsh -Command " `
    Invoke-WebRequest -Uri ((Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/OmniSharp/omnisharp-vscode/master/package.json' -UseBasicParsing | ConvertFrom-Json).runtimeDependencies | Where-Object { $_.Id -eq 'Debugger' -and $_.platforms[0] -eq 'win32'}).url -UseBasicParsing -OutFile coreclr-debug-win7-x64.zip; `
    Expand-Archive coreclr-debug-win7-x64.zip -DestinationPath .; `
    Remove-Item coreclr-debug-win7-x64.zip; "

FROM mcr.microsoft.com/dotnet/core/aspnet:3.1-nanoserver-$BASE AS final
EXPOSE 5100
WORKDIR /vsdbg
COPY --from=vsdbg /vsdbg .

WORKDIR /src
COPY --from=build /src .

WORKDIR /app
COPY --from=build /app/publish .

USER ContainerAdministrator
ENTRYPOINT ["dotnet", "core.dll"]
{% endhighlight %}

In line 2 you can see the definition of a build argument called `BASE`. That argument is referenced in line 3 for the image used in the build stage as well as in line 20 for the stage which downloads the debugger and also in line 27 for the final stage. If we do a `docker build --build-arg 1809`, the used images are Windows Server 1809. If we change that to `docker build --build-arg 2004`, the images are Windows Server 2004. That way, we can create two different images using the same Dockerfile. Of course they also need to have different tags, so the full commands would look like this:

`docker build --build-arg 1809 -t tobiasfenster/my-fantastic-image:1.0.0-1809 --isolation hyperv .`

and 

`docker build --build-arg 2004 -t tobiasfenster/my-fantastic-image:1.0.0-2004 .`

Because of the version discrepancy, the 1809 image must be built with hyperv isolation. After pushing those images, we can now easily create a manifest and push that as well, using the same commands already mentioned above:

`docker manifest create tobiasfenster/my-fantastic-image:1.0.0 tobiasfenster/my-fantastic-image:1.0.0-1809 tobiasfenster/my-fantastic-image:1.0.0-2004`

and then

`docker manifest push tobiasfenster/my-fantastic-image:1.0.0`

So that would be only a couple of lines of code, nice and easy. However, as so often, real life isn't as easy: We actually have 4 images for that one repo alone. There is a core image and an agent image and both have a dev version and a regular version. That means that we have `my-fantastic-core`, `my-fantastic-core:dev`, `my-fantastic-agent` and `my-fantastic-agent:dev`. Of course, we want to build, push, manifest and manifest push those for 1809 and for 2004 each (and who know how many others in the future), so what was only a couple of lines of code suddenly becomes impractical, especially for maintenance. But actually the structure is always the same (build, push, manifest and manifest push), only the images name, base version and Dockerfile differ. With that in mind, I came up with a GitHub action workflow file that looks like this:

{% highlight yml linenos %}
name: Build Images on tag

on:
  push:
    tags:
    - 'v*' 

jobs:

  build:

    runs-on: self-hosted

    steps:
    - uses: actions/checkout@v1
    
    - uses: azure/docker-login@v1
      with:
        username: ${{ secrets.docker_user }}
        password: ${{ secrets.docker_pwd }}

    - name: Set up commands
      run: |
        $version = ((Invoke-Expression "git describe --abbrev=0 --tags").Substring(1))
        $images = @("docker-automation:dev-", "docker-automation:", "docker-automation-agent:dev-", "docker-automation-agent:")
        $targets = @("1809", "2004")
        $dockerfiles = @("Dockerfile.dev.core", "Dockerfile.core", "Dockerfile.dev.agent", "Dockerfile.agent")

        $buildCmds = New-Object System.Collections.Generic.List[System.String]
        $imgPushCmds = New-Object System.Collections.Generic.List[System.String]
        $manifestCmds = New-Object System.Collections.Generic.List[System.String]
        $manifestPushCmds = New-Object System.Collections.Generic.List[System.String]

        for ($i=0; $i -lt $images.length; $i++){
          $currBaseImage = "tobiasfenster/$($images[$i])$($version)"
          $manifestCmd = "docker manifest create $($currBaseImage)"
          $manifestPushCmd = "docker manifest push $($currBaseImage)"
          
          for ($j=0; $j -lt $targets.length; $j++){
            $currImage = "$($currBaseImage)-$($targets[$j])"
            $versionBuildArg = ""
            if ($dockerfiles[$i].IndexOf(".dev.") -eq -1) {
              $versionBuildArg = "--build-arg VERSION=$($version)"
            }
            $buildCmd = "docker build -t $($currImage) -f $($dockerfiles[$i]) --build-arg BASE=$($targets[$j]) --isolation hyperv $versionBuildArg ."
            $buildCmds.Add($buildCmd)

            $imgPushCmd = "docker push $($currImage)"
            $imgPushCmds.Add($imgPushCmd)

            $manifestCmd = "$manifestCmd $currImage"
          } 

          $manifestCmds.Add($manifestCmd)
          $manifestPushCmds.Add($manifestPushCmd)
        }

        echo "buildCmdsString=$($buildCmds -join "###")" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
        echo "imgPushCmdsString=$($imgPushCmds -join "###")" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
        echo "manifestCmdsString=$($manifestCmds -join "###")" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
        echo "manifestPushCmdsString=$($manifestPushCmds -join "###")" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append

        echo $(jq -c '. + { "experimental": \"enabled\" }' "$env:DOCKER_CONFIG\config.json") | Out-File -Encoding ASCII "$env:DOCKER_CONFIG\config.json"

    - name: Build Docker images
      run: |
        $buildCmds = $env:buildCmdsString.Split("###", [StringSplitOptions]::RemoveEmptyEntries)

        foreach ($buildCmd in $buildCmds) {
          Write-Host $buildCmd
          Invoke-Expression $buildCmd
        }

    - name: Push Docker images
      run: |
        $imgPushCmds = $env:imgPushCmdsString.Split("###", [StringSplitOptions]::RemoveEmptyEntries)

        foreach ($imgPushCmd in $imgPushCmds) {
          Write-Host $imgPushCmd
          Invoke-Expression $imgPushCmd
        }

    - name: Create Docker manifests
      run: |
        $manifestCmds = $env:manifestCmdsString.Split("###", [StringSplitOptions]::RemoveEmptyEntries)

        foreach ($manifestCmd in $manifestCmds) {
          Write-Host $manifestCmd
          Invoke-Expression $manifestCmd
        }

    - name: Push Docker manifests
      run: |
        $manifestPushCmds = $env:manifestPushCmdsString.Split("###", [StringSplitOptions]::RemoveEmptyEntries)

        foreach ($manifestPushCmd in $manifestPushCmds) {
          Write-Host $manifestPushCmd
          Invoke-Expression $manifestPushCmd
        }
{% endhighlight %}

After making sure that this runs when a Git tag with a specific pattern is created (lines 3-6), getting the sources (line 15) and logging in to the Docker hub using configured secrets (lines 17-20), you can see a big step (lines 22-63) which only creates the commands for later steps. First it gets the current version of our own code by looking at the Git tag (line 24). Then arrays of the relevant images (line 25), Windows Server target versions (line 26) and Dockerfiles (line 27) are defined as well as lists to later store the commands (lines 29-32). Then in a first for loop (line 34), the base image name, the start of the manifest command and the manifest push command are defined (lines 35-37). The second, nested for loop (line 39) goes through the Windows Server target versions and creates build commands. In our case, the dev images need a second build argument (lines 42-44), but that's a specific implementation detail. With that, we now have everything in place to create the build command, add it to the list of build commands, create the image push command and also add it to the list of push commands (lines 45-49). We can also extend the manifest command with the current image name (line 51) and then go back to the outer loop and add the manifest and manifest push commands to their respective lists (lines 54 and 55).

To bring some structure into our workflow, I have added a dedicated step for actually running the commands, but we need to pass our command list variables to them. For that I am joining each list to a single string and create a file with that content in a special place (lines 58-61), which in turn makes it available as environment variable for other steps (you can find out more [here][envs], if you are interested). And because `docker manifest` is still experimental, we need to enable experimental features for the Docker client (line 63). The path to the docker config file is special because the docker-login action we used above (lines 17-20) creates a dedicated file as it stores the authentication information in there. 

With all that preparation, the rest becomes easy: E.g. in the build step, we get our list of build commands from the environment variable and split it into an array (line 67). With that, it is a simple foreach loop to call our commands (lines 69-72). As you might remember, we have commands for build, push, manifest and manifest push and consequently, we have for steps for that, each built in the same way as the build step (lines 74-99). After that workflow has successfully completed, we have 8 images and 4 manifests on the Docker hub. If we decide to support e.g. 1909 and 20H2, we would only need to add those two values in line 26 and would get 16 images and 4 manifests. I am sure there will be a monkey wrench somewhere, but for now, I am pretty happy with that setup.

## The details: Using self-hosted, containerized GitHub runners
As I already mentioned, we needed to run our own runners because GitHub only supports Windows Server 1809 for now. To my suprise, the [instructions for self-hosted runners][self-hosted] don't even mention to do this in a container, but that works straightforward. The Dockerfile looks like this:

{% highlight Dockerfile linenos %}
# escape=`
ARG BASE
FROM mcr.microsoft.com/windows/servercore:$BASE
ENV VERSION 2.274.2

USER ContainerAdministrator
RUN powershell -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')); `
    choco install -y docker-cli; `
    choco install -y git ; `
    choco install -y jq; "

WORKDIR c:/actions-runner

RUN powershell -Command "`
    Invoke-WebRequest -Uri \"https://github.com/actions/runner/releases/download/v$env:VERSION/actions-runner-win-x64-$env:VERSION.zip\" -OutFile actions-runner.zip -UseBasicParsing; `
    Expand-Archive actions-runner.zip -DestinationPath .; `
    Remove-Item actions-runner.zip; "

CMD powershell -Command "`
    $headers = @{ `
        Authorization=\"token $env:GITHUBPAT\" `
    }; `
    $tokenLevel = \"orgs\"; `
    if ($env:GITHUBREPO_OR_ORG.IndexOf('/') -gt 0) { `
        $tokenLevel = \"repos\" `
    }; `
    $token = ($(Invoke-WebRequest -UseBasicParsing -Uri \"https://api.github.com/$tokenLevel/$env:GITHUBREPO_OR_ORG/actions/runners/registration-token\" -Headers $headers -Method POST).Content | ConvertFrom-Json).token; `
    .\config.cmd --url \"https://github.com/$env:GITHUBREPO_OR_ORG\" --token \"$token\" ; `
    .\run.cmd"
{% endhighlight %}

As you can see in lines 2 and 3, the Windows Server version is again flexibly defined using a build arg called `BASE`. Line 4 then defines the version of the GitHub runner package, which is downloaded and extracted in lines 14-17. As we want to use docker and git (and jq for enabling experimental features in line 63 in our workflow above), I installed those using [chocolatey][choco] (lines 7-10) - although I always get hungry when I use it... 

To configure a GitHub runner and register it with a repository or organization[^2], we need a special token. To get that token, I set up authorization (lines 20-22), find out whether we want to use it on organization or repository scope (lines 24-26) and then make a call to the [GitHub REST API for actions][rest-api]. The response contains the token which we can in turn use to configure and run the runner (lines 28 and 29). The organization or repository and the [Personal Access Token][PAT][^3] used to authenticate the REST API call must be entered as environment variables, and we need access to the Docker engine, so a `docker run` command for the image would look like this:

`docker run -e GITHUBREPO_OR_ORG=cosmoconsult/my-fantastic-repo -e GITHUBPAT=... -v \\.\pipe\docker_engine:\\.\pipe\docker_engine tobiasfenster/github-runner-windows:2004`

The output should look something like this:

{% highlight linenos %}
What is your runner register token?
--------------------------------------------------------------------------------
|        ____ _ _   _   _       _          _        _   _                      |
|       / ___(_) |_| | | |_   _| |__      / \   ___| |_(_) ___  _ __  ___      |
|      | |  _| | __| |_| | | | | '_ \    / _ \ / __| __| |/ _ \| '_ \/ __|     |
|      | |_| | | |_|  _  | |_| | |_) |  / ___ \ (__| |_| | (_) | | | \__ \     |
|       \____|_|\__|_| |_|\__,_|_.__/  /_/   \_\___|\__|_|\___/|_| |_|___/     |
|                                                                              |
|                       Self-hosted runner registration                        |
|                                                                              |
--------------------------------------------------------------------------------

# Authentication


√ Connected to GitHub

# Runner Registration

Enter the name of runner: [press Enter for 6646CA582A67]
This runner will have the following labels: 'self-hosted', 'Windows', 'X64'
Enter any additional labels (ex. label-1,label-2): [press Enter to skip]
√ Runner successfully added
√ Runner connection is good

# Runner settings

Enter name of work folder: [press Enter for _work]
√ Settings Saved.

Would you like to run the runner as service? (Y/N) [press Enter for N]
√ Connected to GitHub

2020-12-09 21:41:00Z: Listening for Jobs
{% endhighlight %}

Because I want to do this multiple times and like the idea of Infrastructure as Code, I put everything into a docker-compose file for easy usage that looks like this and just defines the same parameters as seen above, only this time for two runners:

{% highlight yaml linenos %}
version: "3.7"

services:
  runner-org:
    image: tobiasfenster/github-runner-windows:2004
    volumes:
      - source: '\\.\pipe\docker_engine'
        target: '\\.\pipe\docker_engine'
        type: npipe
    environment:
      - GITHUBREPO_OR_ORG=cosmoconsult
      - GITHUBPAT=...

  runner-repo:
    image: tobiasfenster/github-runner-windows:2004
    deploy:
      replicas: 2
    volumes:
      - source: '\\.\pipe\docker_engine'
        target: '\\.\pipe\docker_engine'
        type: npipe
    environment:
      - GITHUBREPO_OR_ORG=cosmoconsult/github-runner-windows
      - GITHUBPAT=...
{% endhighlight %}

As you can see in the second part, lines 16 and 17, we can even create multiple runners for the same organization or repository by adding a simple parameter.

It has taken quite some time to get everything in place and help or input by [Stefan Scherer][scherer], [Jakub Vanak][vanak] and my colleague [Markus Lippert][lippert]. Thanks for that! Now it seems so far like a pretty convenient and stable setup for creating and using Docker images for different Windows Server versions.

[^1] actually the same image with multiple tags, but let's not split hairs
[^2] org-scoped runners actually are currently not able to pick up jobs as described in [this issue][org-issue], but I would hope that this is fixed soon
[^3] the PAT needs `repo` access for repository scoped runners and `admin:org` for organization scoped runners

[manifests]: https://docs.docker.com/engine/reference/commandline/manifest/
[linux]: https://www.axians-infoma.de/techblog/creating-a-multi-arch-docker-image-with-azure-devops/
[actions]: https://github.com/features/actions
[sources]: https://github.com/cosmoconsult/github-runner-windows
[hub]: https://hub.docker.com/repository/docker/tobiasfenster/github-runner-windows
[envs]: https://docs.github.com/en/free-pro-team@latest/actions/reference/workflow-commands-for-github-actions#setting-an-environment-variable
[self-hosted]: https://docs.github.com/en/free-pro-team@latest/actions/hosting-your-own-runners
[choco]: https://chocolatey.org/
[rest-api]: https://docs.github.com/en/free-pro-team@latest/rest/reference/actions
[org-issue]: https://github.com/actions/runner/issues/831
[PAT]: https://docs.github.com/en/free-pro-team@latest/github/authenticating-to-github/creating-a-personal-access-token
[scherer]: https://twitter.com/stefscherer
[vanak]: https://twitter.com/vanakjakub
[lippert]: https://twitter.com/lippert_markus