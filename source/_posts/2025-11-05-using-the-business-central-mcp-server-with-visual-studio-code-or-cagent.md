---
layout: post
title: "Using the Business Central MCP Server with Visual Studio Code or cagent"
permalink: using-the-business-central-mcp-server-with-visual-studio-code-or-cagent
date: 2025-11-05 23:18:36
comments: false
description: "Using the Business Central MCP Server with Visual Studio Code or cagent"
keywords: ""
image: /images/bc mcp.png
categories:

tags:

---

At the [Directions EMEA 2025][diremea] conference, Microsoft announced the public preview of their [Business Central][bc] [MCP Server][mcp]. In case you haven't heard, MCP is an open-source standard to connect AI applications to external systems. In the case of the BC MCP Server, this means that AI applications can access Business Central. I don't want to go into the details on the BC side, as I'm sure that Microsoft will do a good job in documenting that. But for very understandable reasons, Microsoft only supports the [Microsoft Copilot Studio][mcs] as client, even though you may still want to use it with other clients, such as [Visual Studio Code][vsc] with [Github Copilot][ghc] or [cagent][cagent]. 

## The TL;DR

Here's what you need to do for that:

- Get the code from the [BcMCPProxy sample in the BCTech Github repo][proxy]
- Compile it into an executable file
- Follow the instructions in the repository to create an app registration, which you will need to authenticate against Business Central
- Configure the proxy as an MCP Server in your client 
- Start using it!

For example, this is what it looks like in VS Code:

<video width="100%" controls="">
  <source type="video/mp4" src="/images/bc mcp.mp4" />
</video>

## The details: Getting the BcMCPProxy executable

The BC MCP Proxy is a .NET 8 application, which means that you need a .NET SDK to compile it. To make that easier, I have created a [pull request][pr] that adds [devcontainer][devc] support as well as build tasks for VS Code to make building self-contained executables easier. Until that PR is merged (if at all), you can clone [my fork][fork] and open the `samples/BcMCPProxy` folder in a dev container. Once it has started, you can run the build tasks and select your operating system. In my case, this is Windows-ARM64, but of course your setup may differ. You will then have an executable file that you can copy to your host machine and use it in the MCP setup later.

## Configuring VS Code

One way to configure an MCP Server in VS Code is to use a `.vscode/mcp.json` file (see the [official docs][vsc-docs] for all options). As explained in the repo mentioned above for [Claude Desktop][claude], you need to add some configuration options. It should look like this:

{% highlight json linenos %}
{
    "servers": {
        "bc": {
            "type": "stdio",
            "command": "C:\\Users\\tobia\\deleteme\\BcMCPProxy.exe",
            "args": [
                "--TenantId",
                "<tenant-id>",
                "--ClientId",
                "<client-id>",
                "--Environment",
                "<environment>",
                "--Company",
                "<company>",
                "--ConfigurationName",
                "<configuration-name>"
            ]
        }
    }
}
{% endhighlight %}

As you can see, you need to fill in the following:
- the ID of your Entra ID tenant in line 8;
- the client ID of your app registration in line 10;
- the name of your BC environment where you have the MCP feature enabled and configured in line 12;
- the name of the BC company you want to use in line 14;
- the name of the MCP configuration in line 16. 
You can then click on "Start" and use the tools in GitHub Copilot Chat within VS Code, as shown in the video above!

## Configuring cagent

Another client that works well is [Docker's cagent][cagent]. In this case, the configuration is very similar, we only need to also add the LLM that we want to use. An example could look like this, using an Azure AI Foundry model:

{% highlight json linenos %}
version: "1"

agents:
  root:
    description: An agent that interacts with Microsoft Dynamics 365 Business Central
    instruction: |
      You are an agent helping the user to interact with the ERP system Microsoft Dynamics 365 Business Central.
    model: cloud-gpt-5
    toolsets:
      - type: mcp
        command: C:\Users\tobia\deleteme\BcMCPProxy.exe
        args: [
            "--TenantId",
            "<tenant-id>",
            "--ClientId",
            "<client-id>",
            "--Environment",
            "<environment>",
            "--Company",
            "<company>",
            "--ConfigurationName",
            "<configuration-name>"
        ]

models:
  cloud-gpt-5:
    provider: azure
    model: gpt-5
    base_url: <your-azure-ai-foundry-endpoint>
    provider_opts:
      azure_api_version: 2025-01-01-preview

{% endhighlight %}

You can see the same setup as for VS Code in lines 10–23, as well as the model setup in lines 25–31 and the reference to it in line 8. With this configuration, the BC MCP Server can be used in a similar way:

<video width="100%" controls="">
  <source type="video/mp4" src="/images/bc mcp cagent.mp4" />
</video>

With that, you should also be able to adapt the configuration for other clients. Have fun building applications and solving problems with it!

[diremea]: https://www.directionsforpartners.com/emea2025
[bc]: https://www.microsoft.com/en-us/dynamics-365/products/business-central
[mcp]: https://modelcontextprotocol.io/docs/getting-started/intro
[mcs]: https://www.microsoft.com/en-us/microsoft-365-copilot/microsoft-copilot-studio
[vsc]: https://code.visualstudio.com/
[ghc]: https://code.visualstudio.com/docs/copilot/overview
[cagent]: https://docs.docker.com/ai/cagent/
[proxy]: https://github.com/microsoft/BCTech/tree/master/samples/BcMCPProxy
[pr]: https://github.com/microsoft/BCTech/pull/330
[devc]: https://containers.dev/
[fork]: https://github.com/tfenster/BCTech/tree/master/samples/BcMCPProxy
[vsc-docs]: https://code.visualstudio.com/docs/copilot/customization/mcp-servers#_add-an-mcp-server
[claude]: https://claude.com/product/overview
[cagent]: https://docs.docker.com/ai/cagent/