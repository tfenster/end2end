---
layout: post
title: "Handle secrets in Windows based GitHub actions and Docker containers"
permalink: handle-secrets-in-windows-based-github-actions-and-docker-containers
date: 2020-02-24 22:02:46
comments: true
description: "Handle secrets in Windows-based GitHub actions and Docker containers"
keywords: ""
categories:
image: /images/github-secret.png

tags:

---

Handling secrets can be a tough problem, especially in automated build environments that are publicly available like GitHub actions[^1] in a public repository. Consider the following examples:

1. You need to provide a username and password, e.g. to push an image to the Docker hub
1. You need to use a file with private content, e.g. a nuget config file that contains a private feed URL

Fortunately there are out of the box solutions but some don't directly work when using Windows based actions

## The TL;DR
GitHub allows you to set secrets which you can easily reference in your actions, so they are well secured. If someone forks your repo, she still doesn't have access to your secrets. Creating them is done in an easy to use GUI.

![remote debug](/images/github-secret.png)
{: .centered}

As explained [here][limits-secrets], you can also conveniently use gpg to encrypt whole files and only store the password as secret but as gpg is not a standard part of Windows, that gets a bit more complicated. In order to make this easier, I have created a very small Docker image containing a .NET Core application that allows you to encrypt and decrypt a file.

## The details for text-based, small secrets
For the first example above (username and password), you can just create a secret, provide a name and a value. You can then very easily reference them from your workflow file for your action, e.g. like this:

{% highlight yaml linenos %}
name: Build Image

...

jobs:

  build:

    runs-on: windows-latest

    steps:
    ...
    
    - uses: azure/docker-login@v1
      with:
        username: ${{ secrets.docker_user }}
        password: ${{ secrets.docker_pwd }}

    ...

{% endhighlight %}

This example logs in to the Docker hub using the provided username and password, so that in the next steps a Docker image can be created and pushed (see [this][build] for the full code). With that setup, the username and password are well protected and your automated builds still work well

## The details for private files
The second example (a file with private content) is a bit more complicated. They [recommended][limits-secrets] approach is to encrypt that file using gpg and add the encrypted file to your repository. That way it is available during build, but you are not sharing private content. During the build process, you just decrypt the file again, using the password set up as GitHub secret, and use it as needed. On Linux this can be done out of the box using gpg, but that is not available by default on Windows, so I created a little [helper tool][rijndael] that allows you to encrypt and decrypt a file with a provided password.

To make this easily transferable and useable, I created a Docker image, so you can just run the following Docker command to encrypt a file. In that example, it would encrypt a file called `nuget.config` which is stored in the folder `c:\sources`. That folder is available to the container as a bind mount, set up through the `-v` parameter, the desired action is to encrypt (param `--action`) and the password is SuperSecret! (param `--password`):

{% highlight shell linenos %}
docker run --rm -v c:\sources\:c:\crypt tobiasfenster/rijndaelfileenc:0.1-1909 --action encrypt --password SuperSecret! --file c:\crypt\nuget.config
{% endhighlight %}

As a result, you get an encrypted file called `nuget.config.enc` which you can then safely add to your repository. When you need it again as part of your build, you can use the same image, just with the decrypt action and the password set as secret, so a GitHub action could look like this:

{% highlight yaml linenos %}
name: Build Image

... 

jobs:

  build:

    runs-on: windows-latest

    steps:
    ...
      
    - name: Decrypt nuget config
      run: Invoke-Expression "docker run --rm -v $(pwd)\web:c:\crypt tobiasfenster/rijndaelfileenc:0.1-1809 --action decrypt --password $env:crypt_pwd --file c:\crypt\nuget.config.enc"
      env:
        crypt_pwd: ${{ secrets.crypt_pwd }}
    
    ...  

{% endhighlight %}

Note that this time I am using `tobiasfenster/rijndaelfileenc:0.1-1809` because the action runs on a Windows Server 2019 LTSC machine while before on my laptop I had used `tobiasfenster/rijndaelfileenc:0.1-1909`. That doesn't matter because the implemented algorithm is still the same. You can also see, that no the `--action` parameter has the value decrypt and the `--file` parameter points to the .enc file. As a result, we get the decrypted file, which can then be used during the build process, in that case a Docker image build as well.

Now all you need to do is make sure that this decrypted file is only part of the build process, but never actually delivered. In Docker that is quite easy, as you can use a concept called multi-stage builds[^2]. Basically the idea is to have a build stage, where the build itself happens and in our scenario the decrypted file is used. After that the image creation enters a second stage and only the results of the build (without the decrypted file) are copied to the second stage. That way the file can be used as needed during the build, but it never gets delivered to the outside world.

## The details about private nuget feeds
As I struggled to find that information, I also want to add a note about my actual problem, which was using a private nuget feed. I needed this for my [Azure DevOps work item collector][azdevops-wi-reader], where I used the [DevExpress Blazor components][devexpress], which are free but you need to register and then use your personal, private feed URL. This worked well for the initial add and restore, but it took me some time to find out how to get this to work in a Docker image build. The answer turned out to be a nuget.config file, which in my case looks like this:

{% highlight xml linenos %}
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
    <add key="DevExpress Nuget server" value="https://nuget.devexpress.com/<this is secret>/api" />
  </packageSources>
</configuration>
{% endhighlight %}

With that setup and the two mechanisms of multi-stage Docker builds and encrypted files in GitHub actions ans introduced above, I was able to set up the automated build process securely.

[^1]: If you don't know what GitHub actions are, you can find an introduction [here][actions]. If you are familiar with Azure DevOps, think pipelines and you are very close.
[^2]: I've written a very quick introduction [here][intro-multistage] or you can read more about it in the [official documentation][multistage-docs]. 

[actions]: https://github.com/features/actions
[limits-secrets]: https://help.github.com/en/actions/configuring-and-managing-workflows/creating-and-storing-encrypted-secrets#limits-for-secrets
[this]: https://github.com/tfenster/azdevops-wi-reader/blob/e2867818065a994d3ab1c1eeb1f3c2d8dc17a277/.github/workflows/build-image.yml
[rijndael]: https://github.com/tfenster/RijndaelFileEncryption/blob/master/Program.cs
[intro-multistage]: https://www.axians-infoma.de/techblog/optimize-ci-build-appveyor-multi-stage-image/
[multistage-docs]: https://docs.docker.com/develop/develop-images/multistage-build/
[azdevops-wi-reader]: https://tobiasfenster.io/creating-a-combined-work-item-list-from-multiple-azure-devops-organizations-and-why-that-matters-for-gdpr
[devexpress]: https://www.devexpress.com/blazor/