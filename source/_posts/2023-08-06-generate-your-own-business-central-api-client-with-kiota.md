---
layout: post
title: "Generate your own Business Central API client with Kiota"
permalink: generate-your-own-business-central-api-client-with-kiota
date: 2023-08-06 18:44:11
comments: false
description: "Generate your own Business Central API client with Kiota"
keywords: ""
image: /images/kiota.png
categories:

tags:

---

I know that there are tons of options for low-code / no-code integrations with Business Central and those certainly have merit. But sometimes, you just want or need a piece of code to talk to BC, but BC doesn't come with a client SDK and while you can handcraft your API calls, you might prefer the type safety and most likely higher development efficiency that typically comes with an SDK. Microsoft thankfully has [Kiota][kiota], "a command line tool for generating an API client to call any OpenAPI-described API you are interested in. [...] Kiota API clients provide a strongly typed experience with all the features you expect from a high quality API SDK, but without having to learn a new library for every HTTP API.". Here is how you can use it in connection with BC:

## The TL;DR

Assuming that you have the .NET 7.0 SDK installed and an [OpenAPI][openapi] yaml file for the v2.0 API of BC called MicrosoftAPIv2.0.yaml, you can do this:

{% highlight powershell linenos %}
dotnet tool install --global Microsoft.OpenApi.Kiota
kiota generate -l CSharp -c MSAPI20Client -n MSAPI20.Client -d .\MicrosoftAPIv2.0.yaml -o .\Client
{% endhighlight %}

Then you can reference the generated API to talk to BC like this:

{% highlight csharp linenos %}
using MSAPI20.Client;
...
var companies = await client.Companies.GetAsync();
Console.WriteLine($"Found {companies!.Value!.Count} companies");
var company = companies.Value.First();
Console.WriteLine($"Name of the first company is {company.Name}");

var customers = await client.CompaniesWithId(company.Id).Customers.GetAsync();
Console.WriteLine($"Found {customers!.Value!.Count} customers");
var customer = customers.Value.First();
Console.WriteLine($"Customer: {customer.DisplayName}");
{% endhighlight %}

For a standard BC Cronus (DE) environment, this would be returned when executed:

{% highlight text linenos %}
Found 1 companies
Name of the first company is CRONUS AG
Found 68 customers
Customer: Möbel-Meller KG
{% endhighlight %}

## The details: Full implementation of the client

To go into a bit more detail, here is the complete guide of what to do to implement a small console application to use the API client that we just generated: You can use the standard `dotnet new console` command to create a new console project and add the following lines to your .csproj to reference the Kiota packages

{% highlight xml linenos %}
<Project Sdk="Microsoft.NET.Sdk">

  ...

  <ItemGroup>
    <PackageReference Include="Microsoft.Kiota.Abstractions" Version="1.3.0" />
    <PackageReference Include="Microsoft.Kiota.Http.HttpClientLibrary" Version="1.0.6" />
    <PackageReference Include="Microsoft.Kiota.Serialization.Form" Version="1.0.1" />
    <PackageReference Include="Microsoft.Kiota.Serialization.Json" Version="1.0.8" />
    <PackageReference Include="Microsoft.Kiota.Serialization.Text" Version="1.0.3" />
  </ItemGroup>

</Project>
{% endhighlight %}

Of course, there may be new versions by the time you read this, so you can also use `dotnet add package Microsoft.Kiota.Abstractions`, `dotnet add package Microsoft.Kiota.Http.HttpClientLibrary` etc. to get the latest. 

In my test scenario, I was using a BC container with NavUserPassword authentication, so I had to implement a Basic authentication provider for Kiota, as it doesn't support this out of the box (rightfully so, don't use Basic auth for anything but dev anymore!). Since Kiota provides the `IAccessTokenProvider` interface, this was quite easy to achieve with the following piece of code.

{% highlight csharp linenos %}
using System.Text;
using Microsoft.Kiota.Abstractions;
using Microsoft.Kiota.Abstractions.Authentication;

public class BasicAccessTokenProvider : IAccessTokenProvider
{
    private readonly string _username;
    private readonly string _password;
    public AllowedHostsValidator AllowedHostsValidator => throw new NotImplementedException();

    public BasicAccessTokenProvider(string username, string password)
    {
        _username = username;
        _password = password;
    }

    public Task<string> GetAuthorizationTokenAsync(Uri uri, Dictionary<string, object>? additionalAuthenticationContext = null, CancellationToken cancellationToken = default)
    {
        string encodedCredentials = Convert.ToBase64String(Encoding.UTF8.GetBytes($"{_username}:{_password}"));
        return Task.FromResult($"Basic {encodedCredentials}");
    }
}

public class BasicAuthenticationProvider : IAuthenticationProvider
{
    private readonly BasicAccessTokenProvider _basicAccessTokenProvider;
    public BasicAuthenticationProvider(string username, string password)
    {
        _basicAccessTokenProvider = new BasicAccessTokenProvider(username, password);
    }

    public async Task AuthenticateRequestAsync(RequestInformation request, Dictionary<string, object>? additionalAuthenticationContext = null, CancellationToken cancellationToken = default)
    {
        request.Headers.Add("Authorization", await _basicAccessTokenProvider.GetAuthorizationTokenAsync(request.URI, cancellationToken: cancellationToken));
    }
}
{% endhighlight %}

All we need to do is to generate a base64 encoded string for the authorization token (lines 19 and 20) and put it in the proper request header (line 34).

If you put this in a file named e.g. `BasicAccessTokenProvider.cs`, you can use it later in your Program.cs. We have already seen a snippet of this file above, but here is what it looks like in its entirety:

{% highlight csharp linenos %}
using MSAPI20.Client;
using Microsoft.Kiota.Http.HttpClientLibrary;

var authProvider = new BasicAuthenticationProvider("admin", "Passw0rd*123");
var adapter = new HttpClientRequestAdapter(authProvider)
{
    BaseUrl = "http://test:7048/BC/api/v2.0"
};
var client = new MSAPI20Client(adapter);

var companies = await client.Companies.GetAsync();
Console.WriteLine($"Found {companies!.Value!.Count} companies");
var company = companies.Value.First();
Console.WriteLine($"Name of the first company is {company.Name}");

var customers = await client.CompaniesWithId(company.Id).Customers.GetAsync();
Console.WriteLine($"Found {customers!.Value!.Count} customers");
var customer = customers.Value.First();
Console.WriteLine($"Customer: {customer.DisplayName}");
{% endhighlight %}

The very first line is the reference to our generated API client, more on the naming later. Line 4 uses our custom authentication provider, which is passed to the `HttpClientRequestAdapter` in line 5, which in turn is used by the API client in line 9. In line 7, you can see how we tell the API client where exactly the environment we want to connect to lives. Again, more on this later.

After that, you see the code that you already saw in the TL;DR: In line 11, we get all the companies and then extract the first one in line 13. Using the ID of that company, we retrieve the customers in line 16 and then get the first one again in line 18. While this is a very simple example, it shows how little code is needed to talk to BC once the basics are in place, which would give a developer a lot of speed and efficiency when creating a client application for BC.

## The details: Prereqs and more on the client generation itself

To put all of this together, I followed the steps in [my own blog post][openapi-bc] to generate an OpenAPI spec for BC, which in turn is heavily based on a [blog post by Waldo][waldo]. Basically, it boils down to running this script to get a container called `test` with the spec in place:

{% highlight powershell linenos %}
New-BcContainer -accept_outdated -accept_eula -containerName test -imageName mybc `
  -artifactUrl (Get-BCArtifactUrl -type OnPrem -country DE) -auth NavUserPassword -updateHosts 
  -myscripts @("https://raw.githubusercontent.com/tfenster/nav-docker-samples/swaggerui/AdditionalSetup.ps1")
{% endhighlight %}

Once that has started successfully, you can use the following command to get the OpenAPI yaml file on your host machine:

{% highlight powershell linenos %}
docker cp test:C:\openapi\BusinessCentralOpenAPIToolkit-main\MicrosoftAPIv2.0\MicrosoftAPIv2.0.yaml .
{% endhighlight %}

Now that we have this file, we also need to install the .NET 7 SDK and Kiota. I am a fan of [Chocolatey][choco], so I use it to install the SDK first, and then I use the dotnet CLI to install Kiota:

{% highlight powershell linenos %}
choco install dotnet-7.0-sdk
dotnet tool install --global Microsoft.OpenApi.Kiota
{% endhighlight %}

That's all you need as prereqs. Finally, let's take a closer look at the command used to generate the API client:

{% highlight powershell linenos %}
kiota generate -l CSharp -c MSAPI20Client -n MSAPI20.Client -d .\MicrosoftAPIv2.0.yaml -o .\Client
{% endhighlight %}

Here we use the `kiota` CLI to generate the API client. The parameters are:

- `-l` defines the language, in our case `CSharp`, but Kiota can also generate Go, Java, PHP, Python, Ruby or TypeScript
- `-c` defines the name of the main class, in our case `MSAPI20Client`
- `-n` defines the namespace where all the generated classes should be, in our case `MSAPI20.Client`, hence the `using MSAPI20.Client;` as the first line in Program.cs
- `-d` points to the file where the OpenAPI definition is stored, in our case `.\MicrosoftAPIv2.0.yaml`
- `-o` defines the output folder where all generated files will be placed, in our case `.\Client`

I hope this gave you a good starting point, should you ever need to create a piece of code to talk to BC!

[kiota]: https://learn.microsoft.com/en-us/openapi/kiota/overview
[openapi]: https://swagger.io/specification/
[openapi-bc]: /host-the-swagger-ui-for-your-bc-openapi-spec-in-your-bc-container
[waldo]: https://www.waldo.be/2021/06/09/documenting-your-business-central-custom-apis-with-openapi-swagger/
[choco]: https://chocolatey.org