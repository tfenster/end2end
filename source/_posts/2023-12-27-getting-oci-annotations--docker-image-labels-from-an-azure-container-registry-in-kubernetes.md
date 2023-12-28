---
layout: post
title: "Getting OCI annotations / Docker image labels from an Azure Container Registry in Kubernetes"
permalink: getting-oci-annotations--docker-image-labels-from-an-azure-container-registry-in-kubernetes
date: 2023-12-27 15:28:24
comments: false
description: "Getting OCI annotations / Docker image labels from an Azure Container Registry in Kubernetes"
keywords: ""
image: /images/k8s acr oci docker.png
categories:

tags:

---

When you create container images using Dockerfiles, you can easily set up convenient labels to store more information about an image for later retrieval. These follow the definition in the [Open Container Initiative (OCI) Image Format Specification][oci], where they are called [Annotations][annotations]. The specification even comes with a [list of predefined keys][keys] like `org.opencontainers.image.authors`, `org.opencontainers.image.created` or `org.opencontainers.image.source`. This is really helpful when you want to know more about an image that you have already pulled. A simple `docker inspect` with a bit of output parsing can give you something like this e.g. for a recent Business Central image:

{% highlight PowerShell linenos %}
PS C:\Users\tfenster> (docker inspect mcr.microsoft.com/businesscentral:10.0.20348.587 | ConvertFrom-Json).Config.Labels | fl

created    : 202302030931
eula       : https://go.microsoft.com/fwlink/?linkid=861843
maintainer : Dynamics SMB
osversion  : 10.0.20348.587
tag        : 1.0.2.14
{% endhighlight %}

In this case, I can see when it was created, where I can find the End User License Agreement (EULA), who the maintainer is, what OS version it is intended for, and what tag it has. Keep in mind that labels / annotations are purely optional, so you might not get anything at all as a response.

Unfortunately, in Kubernetes there is no direct way to access this information. A workaround might be to have the Docker CLI around and run a command similar to the one above, but I didn't really like that idea, so I dug a bit deeper and with some online results and the OCI specification, I found a way how to get the relevant information from the [Azure Container Registry (ACR)][acr] where our images are stored. Basically the same should be possible for other OCI-compliant registries.

## The TL;DR

If we omit authentication (details on that below, if you really want), it is a three-step process:

1\. Get the manifest of the image you are interested in via the [ACR REST API][acr-api]. Assuming that we want to look at the image `myimage` with the tag `mytag` on the ACR instance `myacr`, you would do something like this:
{% highlight bash linenos %}
curl https://myacr.azurecr.io/v2/myimage/manifests/mytag --header 'accept: application/vnd.docker.distribution.manifest.v2+json' --header 'authorization: Bearer ...'

{
   "schemaVersion": 2,
   "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
   "config": {
      "mediaType": "application/vnd.docker.container.image.v1+json",
      "size": 11340,
      "digest": "sha256:a6814abf4268cfe40a912fda2be96f6f2d998a0bd96fed823e858f0617eef044"
   },
   "layers": [
      {
         "mediaType": "application/vnd.docker.image.rootfs.diff.tar.gzip",
         "size": 120753560,
         "digest": "sha256:1ca4fbe907f22e883670decfa8d7f4490a79a995bb94b6c286248c21d61a62f5"
      }
      ...
   ]
}
{% endhighlight %}
If yo want to use an image digest as a reference instead of a tag, you can also get the information via `curl https://myacr.azurecr.io/v2/myimage/manifests/<digest> ...`

2\. Use the config digest (line 8 above) to get the configuration, in this example with
{% highlight bash linenos %}
curl https://myacr.azurecr.io/v2/myimage/blobs/sha256:a6814abf4268cfe40a912fda2be96f6f2d998a0bd96fed823e858f0617eef044 --header 'accept: application/vnd.docker.distribution.manifest.v2+json' --header 'authorization: Bearer ...'

<a href="https://weureplstore76.blob.core.windows.net/a5714abf4268cfe4-980761fcffd84acb990689b218f5b394-91787a7165//docker/registry/v2/blobs/sha256/a6/a6814abf4268cfe40a912fda2be96f6f2d998a0bd96dfe934e858f0617eef044/data?se=2023-12-27T16%3A59%3A11Z&amp;sig=79rlv6H7eSU%2BQLhSDFW6k5kcwP%2FfLPIXG2RafcaUtQw%3D&amp;sp=r&amp;spr=https&amp;sr=b&amp;sv=2018-03-28&amp;regid=980761fcffd84acb990689b218f5b394">Temporary Redirect</a>.
{% endhighlight %}

3\. As you can see, the request only returns a temporary redirect. So we need to follow this to get what we really want
{% highlight bash linenos %}
curl 'https://weureplstore76.blob.core.windows.net/a5714abf4268cfe4-980761fcffd84acb990689b218f5b394-91787a7165//docker/registry/v2/blobs/sha256/a6/a6814abf4268cfe40a912fda2be96f6f2d998a0bd96dfe934e858f0617eef044/data?se=2023-12-27T16%3A59%3A11Z&sig=79rlv6H7eSU%2BQLhSDFW6k5kcwP%2FfLPIXG2RafcaUtQw%3D&sp=r&spr=https&sr=b&sv=2018-03-28&regid=980761fcffd84acb990689b218f5b394'
{% endhighlight %}

This will give us the full configuration, including the labels / annotations. In my case, I have set up the builds in Azure DevOps using the [Docker v2 task][docker-task], which automatically adds [a bunch of useful labels][azdevops-labels]. So in my case, I get something like this in return

{% highlight json linenos %}
{
  "architecture": "amd64",
  "config": {
    ...
    "Labels": {
      "com.visualstudio.myorg.image.build.buildnumber": "20231121.1",
      "com.visualstudio.myorg.image.build.builduri": "vstfs:///Build/Build/127294",
      "com.visualstudio.myorg.image.build.definitionname": "myimg container image",
      "com.visualstudio.myorg.image.build.repository.name": "myrepo",
      "com.visualstudio.myorg.image.build.repository.uri": "https://myorg.visualstudio.com/myproj/_git/myrepo",
      "com.visualstudio.myorg.image.build.sourcebranchname": "add-containerization",
      "com.visualstudio.myorg.image.build.sourceversion": "13c0f2b5a2ab438dd9dab2a669fef68b61f18bed",
      "com.visualstudio.myorg.image.system.teamfoundationcollectionuri": "https://myorg.visualstudio.com/",
      "com.visualstudio.myorg.image.system.teamproject": "myrepo",
      "image.base.digest": "sha256:9ca091d652fd9345ee0ead002e012d6262514e151e1b51150211a6edc50462a9",
      "image.base.ref.name": "mcr.microsoft.com/dotnet/aspnet:7.0-nanoserver-ltsc2022"
    }
  },
  ...
}
{% endhighlight %}

Hopefully, this helps if you are also facing the need to get image labels from a Kubernetes context (or other contexts without a Docker CLI). The implementation on our side is a .NET API, I might follow up with a small container image that can be used directly.

## The details: Authentication
What I left out to get to the point faster (and because everyone hates it) is authentication. But of course it's absolutely necessary, so let's see what we need to do. There are several options as explained in the [docs][auth-options], but I'll focus on two: 

If you have an Azure Entra ID account that has the right permissions, you can use that to translate it into an access token for the API. The following is what works for me, but I actually feel like it should be a little simpler, so if you know better, please let me know:

1\. Use the Azure CLI to get a general access token:
{% highlight bash linenos %}
az account get-access-token

{
  "accessToken": "eyJ0eXAiOiJKV1QiLCJhbG...Dt_mk8JKZjMTAd2vZSxxLUGfFCNeOH5pLAuFlHRgi_2Kjy_nCZM69tcyK6ls_A79Et477TQQ",
  "expiresOn": "2023-12-28 15:37:48.000000",
  "expires_on": 1703777868,
  "subscription": "f8760c7c-86dc-434b-b734-3b12a8e79802",
  "tenant": "92f4dd01-f0ea-4b5f-97f2-505c2945189c",
  "tokenType": "Bearer"
}
{% endhighlight %}
From this output, we grab the `accessToken` in line 4

2\. Use the general access token to get a refresh token for ACR by sending a POST request to the `/oauth2/exchange` endpoint of the ACR API
{% highlight bash linenos %}
curl --request POST https://myacr.azurecr.io/oauth2/exchange \
--header 'content-type: application/x-www-form-urlencoded' \
--data grant_type=access_token \
--data service=myacr.azurecr.io \
--data tenant=92f4dd01-f0ea-4b5f-97f2-505c2945189c \
--data access_token=eyJ0eXAiOiJKV1QiLCJhb...

{"refresh_token":"eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVC...nBsaHJxOaXx7Cunl_G8j-8XhIOIdtaSPNS-C-kPIu419jV6KX7Q7DcxtW-Uw"}
{% endhighlight %}
From this output, we grab the `refresh_token`

3\. Use the refresh token to get an ACR access token by sending another POST request, this time to `/oauth2/token`
{% highlight bash linenos %}
curl --request POST --url https://myacr.azurecr.io/oauth2/token \
--header 'content-type: application/x-www-form-urlencoded' \
--data grant_type=refresh_token \
--data service=myacr.azurecr.io --data 'scope=repository:myrepo:*' \
--data refresh_token=eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6Il...qi09LnBsaHJxOaXx7Cunl_G8j-8XhIOIdtaSPNS-C-kPIu419jV6KX7Q7DcxtW-Uw

{"access_token":"eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVC...UPvd-iYBW5KKFSqbszDBavq99BEsorXwvv02HAr-2QUe11lEFx1e7EukQpBcEQcY9ty5iShAJBMXwWsJpxT1ozKAQlxJwYQ"}
{% endhighlight %}

Finally, this is the `access_token` we need to set in the `Authorization` headers seen in the TL;DR steps above.

The other way to get a valid access token is to set up repository-scoped tokens with passwords. I'll spare you the details of how to set these up, but they're useful if you need to share credentials with clients that don't know things like the Azure Entra ID. The steps are explained [here][tokens] and if you follow them, you will end up with a token name (similar to a username) and a password. These can be used to get an ACR access token in a single step:

{% highlight bash linenos %}
curl 'https://myacr.azurecr.io/oauth2/token?service=myacr.azurecr.io&scope=repository%3Amyrepo%3A*' -u mytokenname:mypassword

{"access_token":"eyJhbGciOiJSUzI1NiIsInR5cC...UtBuWX7uGi_lmy5V1ViAsweQufTSGojEaO6YzzE19asO0svdrcMc2AmPmFDWWwtOJkZ-cs_C0KyHOXcBGs_FyyhF86g"}
{% endhighlight %}

Easier, but of course the token/password combination has to be stored, managed, etc., so not the best solution if you can avoid it.

The last thing to mention here is the `scope` parameter, which you may have noticed in some of the calls above. I have used `repository:myrepo:*`, which means that I am requesting an access token with full access to the `myrepo` repository. If you need to figure out which scope you want to use, you either check the [documentation][scopes] or follow the neat trick outlined [here][call], which tells you to just make the call that you want unauthenticated, because it will return the scope you need.

## The details: To follow or not to follow (automatically)
One thing that really made me question my mental capacity for a bit[^1], was the second step in the TL;DR above. As a reminder, we make a request to get the `config` in the manifest of our image:

{% highlight bash linenos %}
curl https://myacr.azurecr.io/v2/myimage/blobs/sha256:a6814abf4268cfe40a912fda2be96f6f2d998a0bd96fed823e858f0617eef044 --header 'accept: application/vnd.docker.distribution.manifest.v2+json' --header 'authorization: Bearer ...'

<a href="https://weureplstore76.blob.core.windows.net/a5714abf4268cfe4-980761fcffd84acb990689b218f5b394-91787a7165//docker/registry/v2/blobs/sha256/a6/a6814abf4268cfe40a912fda2be96f6f2d998a0bd96dfe934e858f0617eef044/data?se=2023-12-27T16%3A59%3A11Z&amp;sig=79rlv6H7eSU%2BQLhSDFW6k5kcwP%2FfLPIXG2RafcaUtQw%3D&amp;sp=r&amp;spr=https&amp;sr=b&amp;sv=2018-03-28&amp;regid=980761fcffd84acb990689b218f5b394">Temporary Redirect</a>.
{% endhighlight %}

It returns a redirect that we need to follow. When exploring something like this, I usually don't work in a terminal with `curl`, but instead use the excellent [VS Code REST Client extension][rest-client]. This way I have all the calls in a simple text file and can easily jump between calls. When I do this in a terminal, I always lose parts of it and when the time comes to put it into a blog post, I have to figure it out all over again[^2]. But one of the things that the REST Client apparently does is follow this redirect, but it adds the same `Authorization` header as to the initial request, which in my opinion is a perfectly reasonable approach. But unfortunately, here is what happens:

{% highlight HTTP linenos %}
GET https://myacr.azurecr.io/v2/myrepo/manifests/mytag
Authorization: {{acrauth}}
Accept: application/vnd.docker.distribution.manifest.v2+json

HTTP/1.1 400 Authentication information is not given in the correct format. Check the value of Authorization header.
Content-Length: 297
Content-Type: application/xml
Server: Microsoft-HTTPAPI/2.0
x-ms-request-id: 74b57fdf-601e-0031-32a6-3955ad000000
Date: Thu, 28 Dec 2023 15:58:23 GMT
Connection: close

<?xml version="1.0" encoding="utf-8"?>
<Error>
  <Code>InvalidAuthenticationInfo</Code>
  <Message>Authentication information is not given in the correct format. Check the value of Authorization header.
RequestId:74b57fdf-601e-0031-32a6-3955ad000000
Time:2023-12-28T15:58:24.0080179Z</Message>
</Error>
{% endhighlight %}

The solution is either to use something else that doesn't follow the redirect by default (like `curl`), or to configure the REST Client to behave differently with the following setting: `"rest-client.followredirect": false`. With that in place, the same call returns a different result, and now it's the right and expected one:

{% highlight HTTP linenos %}

HTTP/1.1 307 Temporary Redirect
Server: openresty
Date: Thu, 28 Dec 2023 15:54:12 GMT
Content-Type: text/html; charset=utf-8
Content-Length: 423
Connection: close
Access-Control-Expose-Headers: Docker-Content-Digest, WWW-Authenticate, Link, X-Ms-Correlation-Request-Id
Docker-Content-Digest: sha256:a6814abf4268cfe40a912fda2be96f6f2d998a0bd96fed934e858f0617eef044
Docker-Distribution-Api-Version: registry/2.0
Location: https://weureplstore76.blob.core.windows.net/a5714abf4268cfe4-980761fcffd84acb990689b218f5b394-91787a7165//docker/registry/v2/blobs/sha256/a6/a6814abf4268cfe40a912fda2be96f6f2d998a0bd96dfe934e858f0617eef044/data?se=2023-12-27T16%3A59%3A11Z;sig=79rlv6H7eSU%2BQLhSDFW6k5kcwP%2FfLPIXG2RafcaUtQw%3D;sp=r;spr=https;sr=b;sv=2018-03-28;regid=980761fcffd84acb990689b218f5b394
Strict-Transport-Security: max-age=31536000; includeSubDomains, max-age=31536000; includeSubDomains
X-Content-Type-Options: nosniff
X-Ms-Correlation-Request-Id: ee6a32fe-d53b-44f2-afd9-ddd25d17ff1b

<a href="https://weureplstore76.blob.core.windows.net/a5714abf4268cfe4-980761fcffd84acb990689b218f5b394-91787a7165//docker/registry/v2/blobs/sha256/a6/a6814abf4268cfe40a912fda2be96f6f2d998a0bd96dfe934e858f0617eef044/data?se=2023-12-27T16%3A59%3A11Z&amp;sig=79rlv6H7eSU%2BQLhSDFW6k5kcwP%2FfLPIXG2RafcaUtQw%3D&amp;sp=r&amp;spr=https&amp;sr=b&amp;sv=2018-03-28&amp;regid=980761fcffd84acb990689b218f5b394">Temporary Redirect</a>.
{% endhighlight %}

For me, the error message "Authentication information is not given in the correct format. Check the value of Authorization header." didn't really tell me to have no authorization header at all. Anyway, if you follow this little exercise, hopefully I have saved you some of the frustration that I experienced at that point.

## The details: My whole scenario or what to do with it
Finally, I also want to share with you a bit of the larger scenario that led me to the technical problem explained here: In 4PS, we use [COSMO Alpaca][alpaca] for many scenarios around development, testing and validation. While by far the core and most important part of our product portfolio is based on Business Central, we also have some .NET based components that we run in Alpaca as well. This means that we sometimes have "work in progress" code from feature branches in container images, deploy them to Alpaca, and validate that code. For this, it makes a lot of sense to be able to link back to the exact last commit, pull request, or build pipeline run (all connected) represented by that container image. As mentioned in the very beginning, we have that information in the labels of the image:

{% highlight json linenos %}
{
    ...
    "Labels": {
      "com.visualstudio.myorg.image.build.buildnumber": "20231121.1",
      "com.visualstudio.myorg.image.build.builduri": "vstfs:///Build/Build/127294",
      "com.visualstudio.myorg.image.build.definitionname": "myimg container image",
      "com.visualstudio.myorg.image.build.repository.name": "myrepo",
      "com.visualstudio.myorg.image.build.repository.uri": "https://myorg.visualstudio.com/myproj/_git/myrepo",
      "com.visualstudio.myorg.image.build.sourcebranchname": "add-containerization",
      "com.visualstudio.myorg.image.build.sourceversion": "13c0f2b5a2ab438dd9dab2a669fef68b61f18bed",
      "com.visualstudio.myorg.image.system.teamfoundationcollectionuri": "https://myorg.visualstudio.com/",
      "com.visualstudio.myorg.image.system.teamproject": "myrepo",
      "image.base.digest": "sha256:9ca091d652fd9345ee0ead002e012d6262514e151e1b51150211a6edc50462a9",
      "image.base.ref.name": "mcr.microsoft.com/dotnet/aspnet:7.0-nanoserver-ltsc2022"
    }
  ...
}
{% endhighlight %}

Using the information from lines 8 and 10, I can create a link to the latest commit. And with the information from lines 11, 12, and 5, I can create a link to the build that created the image, which also gives me the pull request. This way, I can go directly from a running container in Alpaca to the corresponding source state in Azure DevOps[^3]. Pretty neat, right?

[oci]: https://github.com/opencontainers/image-spec/blob/main/spec.md
[annotations]: https://github.com/opencontainers/image-spec/blob/main/annotations.md
[keys]: https://github.com/opencontainers/image-spec/blob/main/annotations.md#pre-defined-annotation-keys
[acr]: https://learn.microsoft.com/en-us/azure/container-registry/container-registry-intro
[acr-api]: https://learn.microsoft.com/en-us/rest/api/containerregistry/?view=rest-containerregistry-2019-08-15
[docker-task]: https://learn.microsoft.com/en-us/azure/devops/pipelines/tasks/reference/docker-v2?view=azure-pipelines&tabs=yaml
[azdevops-labels]: https://learn.microsoft.com/en-us/azure/devops/pipelines/tasks/reference/docker-v2?view=azure-pipelines&tabs=yaml#remarks
[auth-options]: https://learn.microsoft.com/en-us/azure/container-registry/container-registry-authentication?tabs=azure-cli
[tokens]: https://learn.microsoft.com/en-us/azure/container-registry/container-registry-repository-scoped-permissions
[scopes]: https://distribution.github.io/distribution/spec/auth/scope/
[call]: https://github.com/Azure/acr/blob/main/docs/AAD-OAuth.md#calling-post-oauth2token-to-get-an-acr-access-token
[rest-client]: https://marketplace.visualstudio.com/items?itemName=humao.rest-client
[alpaca]: https://www.cosmoconsult.com/cosmo-alpaca/

[^1]: Always good to be reminded of one's own stupidity, although in this rare case, I still feel like it could be designed in a better way
[^2]: Sometimes faster, sometimes slower. Believe me, I've been there... And yes, also a good reminder of my own stupidity, but I tend to limit those to a fairly low number :)
[^3]: And yes, the same thing could be done in GitHub. We just happen to use Azure DevOps for a number of reasons, but that's not the topic of this blog post