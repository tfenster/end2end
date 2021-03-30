---
layout: post
title: "Minimalistic C# APIs with FeatherHttp"
permalink: minimalistic-c-apis-with-featherhttp
date: 2021-03-30 21:32:45
comments: false
description: "Minimalistic C# APIs with FeatherHttp"
keywords: ""
image: /images/featherhttp.png
categories:

tags:

---

As you may or may not be aware, the annual MVP Summit for Microsoft MVPs is happening from March 29th to April 1st 2021. I've had the chance to travel to Redmond for the Summits in 2018 and 2019, while the Summit 2020 was one of the first virtual-only events because of Covid. I really enjoyed '18 and '19 and to a much lesser degree '20. In all fairness, the decision to have '20 as a virtual event was made with very short notice before the event itself, so it was a miracle that it actually happened, so I say this with all due respect to the people who still made it happen, but it obviously didn't have the same vibe and quality as the in-person event. Given the fact that basically everything is virtual these days, I wasn't extremely thrilled about the prospect of more Teams calls, mostly between 5pm and 11pm in my timezone, not to mention that we are only days before the long-anticipated external release of our COSMO Azure DevOps & Docker Self-Service. 

Why am I writing all of this? Because today something similar to the Summit in 2018 happened to me when I first heard Steven Sanderson talk about Blazor: I joined a session with David Fowler and was completely blown away by an idea in the early stages of materializing! And that is why I was absolutely unable to resist playing with it and then blogging about it instead of doing something sensible like sleeping. He showed stuff I am not allowed to share, but he also has the publicly available Github project [FeatherHttp][FeatherHttp], which we were allowed to share and that is - to quote from the publicly available Github page of the project:

*A lightweight low ceremony APIs for .NET Core applications.*

- *Built on the same primitives as .NET Core*
- *Optimized for building HTTP APIs quickly*
- *Take advantage of existing .NET Core middleware and frameworks*

What does that mean?

## The TL;DR
It allows you to create .NET Core based APIs with very little effort and overhead. To give you an idea, this is an actually fully functional API built with FeatherHttp:

Program.cs:
{% highlight csharp linenos %}
using System.Threading.Tasks;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;

var app = WebApplication.Create(args);

app.MapGet("/", async http =>
{
    await http.Response.WriteAsync("Hello World!");
});
await app.RunAsync();
{% endhighlight %}

Just amazing! It of course needs a project file to let .NET Core now how to build and what to pull in, but that also can be extremely small:

feather.csproj
{% highlight xml linenos %}
<?xml version="1.0" encoding="utf-8"?>
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net5.0</TargetFramework>
    <RestoreSources>
      $(RestoreSources);
      https://api.nuget.org/v3/index.json;
      https://f.feedz.io/featherhttp/framework/nuget/index.json
    </RestoreSources>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="FeatherHttp" Version="0.1.82-alpha.g7c8518a220" />
  </ItemGroup>
</Project>
{% endhighlight %}

I absolutely love the simplicity and lack of about anything unnecessary or repeating, just the core functionality itself. We are building a couple of APIs ourselves, and it isn't a monolith by any stretch but to be honest, the tendency still is to add a controller to an existing service and not create a new one because of the plumbing you have to do to get a "traditional" C# API up and running. With this, it becomes incredibly easy to create, understand and maintain.

## The details: setting it up, throwing weird stuff at it and putting it into a VS Code dev container

Here is what I did to get started: First of all, take a look at the [Github page of the project][FeatherHttp] and use the [version link][versions] to find the latest released version. As I am writing this, that is `0.1.82-alpha.g7c8518a220`. With that knowledge you can install and use the latest FeatherHttp template for the `dotnet` CLI (the only prereq is .NET Core 5, e.g. installable with `choco install dotnet-5.0-sdk`):

{% highlight bash linenos %}
dotnet new -i FeatherHttp.Templates::0.1.82-alpha.g7c8518a220 --nuget-source https://f.feedz.io/featherhttp/framework/nuget/index.json
dotnet new feather -n feather -o .
{% endhighlight %}

With that, you could already do a `dotnet restore` to get the dependencies and `dotnet run` to initially start and get the traditional greeting of all new programming projects at `http://localhost:5000`:

![hello world](/images/hello-world-feather.png)
{: .centered}

Good to see that this works, but I decided to now throw some weird stuff at it. One of the weirdest things we have in that context is a custom validation logic for OAuth bearer tokens. I might or might not blog about that in the future, but it certainly is an unusual usage of .NET Core. So I just copied that file into the project and satisfied the dependencies with `dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer --version 5.0.4`.

At that point I had to restart Omnisharp in VS Code to make some weird error messages and warning go away, but then it also asked me if I wanted to add the required asset to build and debug, to which I agreed. This generates the necessary files (`.vscode/launch.json` and `.vscode/tasks.json`) to start debugging, so if you are following along, you can now just hit F5 to start it. Again, take a look at `http://localhost:5000` and you will get the friendly greeting. But I of course now wanted to use my auth component, so I changed `Program.cs` like this: 

{% highlight csharp linenos %}
using System.Threading.Tasks;
using Auth;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthorization()
                .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
                .AddScheme<JwtBearerAuthenticationOptions, CustomAuthenticationHandler>(JwtBearerDefaults.AuthenticationScheme, null);

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", async http =>
{
    await http.Response.WriteAsync("Hello feathery MVP Summit!");
}).RequireAuthorization();

app.MapGet("/mvp-treatment", async http =>
{
    await http.Response.WriteAsync("Please authorize!");
});

await app.RunAsync();
{% endhighlight %}

It now has become a bit more complicated, but still amazingly simple. If you take a closer look at lines 23-26, you can see that we still have an anonymous route (http://localhost:5000/mvp-treatment) that kindly asks us to authorize. But we now also have changed the default route (http://localhost:5000) to require authorization as you can see in line 21. If we call this without an Authorization header, we get the expected error 401

{% highlight http linenos %}
GET http://localhost:5000/
{% endhighlight %}

{% highlight http linenos %}
HTTP/1.1 401 Unauthorized
Connection: close
Date: Tue, 31 Mar 2021 01:03:21 GMT
Server: Kestrel
Content-Length: 0
{% endhighlight %}

But if we call it with a valid bearer token, we get an improved greeting:

{% highlight http linenos %}
GET http://localhost:5000/
Authorization: Bearer {{bearer}}
{% endhighlight %}

{% highlight http linenos %}
HTTP/1.1 200 OK
Connection: close
Date: Tue, 31 Mar 2021 01:05:56 GMT
Server: Kestrel
Transfer-Encoding: chunked

Hello feathery MVP Summit!
{% endhighlight %}

I could have left it at that but as I am a big fan of [VS Code dev containers][dev-container], I wanted to put that to the test as well. Here is what you need to do to try the same on a system with [Docker Desktop][docker-desktop] and [WSL2][wsl2] (if you are on Windows) already installed:

1. Run the command `remote-containers: add development container configuration files...`
1. Select `C#`, version `5.0` and deselect any additional components
1. Delete the `bin` and `obj` folders, if you already have them
1. Uncomment the line `"forwardPorts": [5000, 5001],` in .devcontainer\devcontainer.json as this will map ports 5000 and 5001 on localhost to ports 5000 and 5001 in the containers which is the easiest to understand setup
1. VS Code will offer to open the folder in the container now as it recognizes the configuration file. Click `Reopen in container` for that. It will build and start the container. If this is the first dev container you are using, this will take a couple of minutes
1. When it has finished, you can once again hit F5 and access your API on http://localhost:5000 but now it is running in the container!

Now that you know how all of this works, you can also just clone [https://github.com/cosmoconsult/featherhttp](https://github.com/cosmoconsult/featherhttp) and give it a try. As it runs in a dev container as we have seen, you only need [Docker Desktop][docker-desktop] with [WSL2][wsl2], the rest will just work. The only thing you will need to adapt is the [array of valid domains][array] where you have to put the domain that is matching your OAuth token.

I really can't wait to see where David and maybe even the .NET Core / C# team is taking this. I will definitely follow it closely as it certainly makes the creation of .NET Core based APIs a lot easier.

[FeatherHttp]: https://github.com/featherhttp/framework
[versions]: https://f.feedz.io/featherhttp/framework/nuget/v3/packages/FeatherHttp/index.json
[dev-container]: https://code.visualstudio.com/docs/remote/containers
[docker-desktop]: https://www.docker.com/products/docker-desktop
[wsl2]: https://docs.microsoft.com/en-us/windows/wsl/install-win10
[array]: https://github.com/cosmoconsult/featherhttp/blob/b53ba1b1073d93efff3aa87992ee4aac73cf4569/Auth/CustomAuthenticationHandler.cs#L25