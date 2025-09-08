---
layout: post
title: "Orchestrate multiple AI agents with cagent by Docker to create a BC/AL coding assistant"
permalink: orchestrate-multiple-ai-agents-with-cagent-by-docker
date: 2025-09-07 20:18:12
comments: false
description: "Orchestrate multiple AI agents with cagent by Docker to create a BC/AL coding assistant"
keywords: ""
image: /images/cagent post image.png
categories:

tags:

---

One of the easiest ways to lure me into trying something is labelling it as "experimental". I absolutely love playing with early-stage tools, seeing the raw and basic ideas of the creators and maybe even help to shape them into something useful. So when I recently was made aware of a new tool created and shared by [Docker][docker] called "[cagent][cagent]" in very early experimental stage, I of course couldn't resist to give it a try. 

## The TL;DR

cagent is a multi-agent runtime that orchestrates AI agents with specialized capabilities and tools, and the interactions between agents. The example scenario I want to share with you is a [Microsoft Dynamics 365 Business Central][bc] (programming language [AL][al]) coding assistant that orchestrates three agents: The first one develops the code based on a requirement, the second one reviews the code and the third one does the git handling (create a branch, checkout, commit). To allow it to work, the coding and review agents have access to the filesystem and shell to make sure they can see existing code which I want to extend. They also have access to the [AL MCP Server][al-mcp] by [Stefan Maron][sf] to help them understand the existing code structure in Business Central. The git handling agent has access to the [reference git MCP server][git-mcp]. 

With that I can give my multi-agent system in cagent the following task, based on an already existing application where one specific small feature is missing: "i want to add a flag on the item card to show whether an item is an alloy item or not. Note that I already have that on the item list, but I also want it on the item card. make the required changes to the already existing code in the app folder". Here is how it does:

<video width="100%" controls="">
  <source type="video/mp4" src="/images/cagent.mp4" />
</video>

To be honest, it took me quite a few attempts to get there, but I really like the result. It isn't perfect and it doesn't generate perfect code. But it is a helpful starting point and I will test with more complex examples to see where the boundaries are (admittedly, this is basically the simplest possible example). Also note that I am using a coding assistant as an example, but this is not limited to coding. It could be agents for everything you can think of and the [examples in the GitHub repo of cagent][fe] give you an idea of that.

Is this the only or even the best way to create and maintain multi-agent systems? I can't claim to know enough about that landscape to really answer that. But as a developer, I love the simplicity, the configurability via YAML (which also makes it perfect for version control and storing it next to my source code) and the terminal interface. There are certainly fancier and more end-user friendly tools, but it absolutely hits a sweet spot for me.

## The details: Defining the agents and their orchestration

To learn how cagent works, I would point you at the [official docs][cagent-docs], the [readme][cagent-readme] and the [usage][cagent-usage] file. The concept is really easy to understand and the YAML structure to define everything limited to the required elements. So I want make this a general introduction but point you at some key aspects:

First, we have a "root" agent, which gets the initial input and orchestrates the other agents. The root agent has access to subagents:

{% highlight yaml linenos %}
agents:
  root:
    model: cloud-gpt-5-chat
    description: "Microsoft Dynamics 365 Business Central development assistant"
    instruction: |
      You are the leader of a team and sub-teams of AI Agents.
      Your task is to coordinate the team to complete the user's request.

      Here are the members in your team:
      <team_members>
      - developer_agent: Analyzes the code base and develops new code
      - reviewer_agent: Analyzes the changes done by the developer_agent and potentially suggests optimizations
      - git_agent: Can make git calls to create branches and commit changes
      </team_members>

      <WORKFLOW>
        1. Call the `developer_agent` to analyze the code base and propose new code
        2. Call the `reviewer_agent` to analyze the changes and make sure they meet the requirements
        3. Call the `git_agent` to create a branch and commit the changes
      </WORKFLOW>
      ...
    sub_agents:
      - developer_agent
      - reviewer_agent
      - git_agent
{% endhighlight %}

The agent needs to know which model to use (more on that later) and gets a basic description and instructions. Here we let it know that it has multiple agents at its disposal and how and in which order we want it to interact with them.

The other agents also have access to tools, as mentioned above. E.g., the `developer_agent` looks like this:

{% highlight yaml linenos %}
  developer_agent:
    model: cloud-gpt-5-chat
    description: "Expert code analysis and development assistant"
    instruction: |
      ...
    toolsets:
      - type: shell
      - type: filesystem
      - type: todo
      - type: mcp
        command: npx
        args: ["al-mcp-server"]
{% endhighlight %}

Here you can see that it has access to the shell to execute commands, to the filesystem to read and write files and to todos to create a multi-step action. Those are built-in tools, so the name is enough. The last tool is the `al-mcp-server` which allows the agent to understand the AL code in compiled dependencies already in the project ("AL packages") and work with them. In this case, the MCP server is called via [npx][npx]. But we can also use the [Docker MCP Gateway][mcp-gateway], which you can see in the configuration of the `git_agent`:

{% highlight yaml linenos %}
  git_agent:
    model: cloud-gpt-5-chat
    description: "Git expert who uses git to fullfil tasks"
    instruction: |
      ...
    toolsets:
      - type: shell
      - type: filesystem
      - type: mcp
        ref: docker:git
{% endhighlight %}

Here we only need the `ref: docker:git` to point it in the right direction.

As already briefly mentioned above, every agent also needs a model that it uses. And you already saw lines like this `model: cloud-gpt-5-chat`. The models are configured or made available in a separate section:

{% highlight yaml linenos %}
models:
  cloud-gpt-4o:
    provider: openai
    model: gpt-4o
    base_url: https://openai-testtf.openai.azure.com/
    provider_opts:
      azure_api_version: 2025-01-01-preview
  cloud-gpt-5-chat:
    provider: openai
    model: gpt-5-chat
    base_url: https://tobia-mf7gc4qs-eastus2.cognitiveservices.azure.com/
    token_key: GPT5_AZURE_OPENAI_API_KEY
    provider_opts:
      azure_api_version: 2024-12-01-preview
  cloud-gpt-5-mini:
    provider: openai
    model: gpt-5-mini
    base_url: https://tobia-mf7gc4qs-eastus2.cognitiveservices.azure.com/
    token_key: GPT5_AZURE_OPENAI_API_KEY
    provider_opts:
      azure_api_version: 2024-12-01-preview
{% endhighlight %}

Here you can see three model definitions: `cloud-gpt-4o`, `cloud-gpt-5-chat` and `cloud-gpt-5-mini`. You probably saw it above, I only used `cloud-gpt-5-chat` as it got me by far the best results. Each of them needs a `provider` (in my case `openai`, but could also be `anthropic`, `google` or `dmr` for the [Docker Model Runner][dmr]) and a `model`, which is the name of the model to be used as defined by the provider like `gpt-4o` or `gpt-5-chat`. That would be enough for "regular" `openai`, `google` or `anthropic` as it now has all information and reads the corresponding API keys from environment variables like `OPENAI_API_KEY`. I however wanted to use [Azure OpenAI][openai]. That requires a bit more configuration: At least the `base_url` where my Azure Open AI / Azure AI Foundry deployment is available and the `azure_api_version` to identify the version to be used. In this case, the API key is read by default from `AZURE_OPENAI_API_KEY`, but as you can see, I have different deployments for GPT-4o and GPT-5, so I had to use different keys. That is also configurable via the `token_key`, which is the name of the environment variable to read the key from.

## The details: Support for Azure OpenAI / Azure AI Foundry and devcontainers

What was most impressive for me was the collaboration with the development team. I asked about Azure OpenAI support and it wasn't there initially, but only a couple hours after I raised the [request][issue], there already was a [PR][pull]. We discussed the implementation a bit, and the team even picked up a suggestion. I am confident that this will make it into one of the next releases, but, like me, you can easily build it yourself thanks to a multi-arch Dockerfile and build task. And I [contributed devcontainer support][devc], so setting up your own development environment is also very easy.

## The details: Things to note during the coding session

Now if we take a closer look at the coding session, I want to point out a few things related to the topics above:

![Screenshot showing the root agent calling the developer agent](/images/cagent1.png)
{: .centered}

Here, you can see the root agent reaching out to the developer agent and telling it what to do. I find it very valuable to see how the root agent interpreted my input above, and how it passed it on to the developer agent. This is especially useful for debugging and understanding what happens in cases where the agents don't work as expected.

![Screenshot showing the developer agent not finding information about code in the BC base application](/images/cagent2.png)
{: .centered}

In the second screenshot, you can see how the developer agent searches for information about code in the Business Central base application. However, because that code is not available as source code in this specific workspace, but only as a compiled package, it can't find it. Now, the AL MCP Server kicks in:

![Screenshot showing cagent asking for permissions to call the AL MCP server](/images/cagent3.png)
{: .centered}

As it is an additional tool and the first tool call in this session, `cagent` asks for permission to use the AL MCP Server, specifically the tool to discover all the compiled packages. I answer this with `All`, so no further permission requests pop up. After discovery, the agent can then call the tool to search for the specific page, "Item Card", mentioned in my requirements. I like how cagent shows exactly how it calls the tool, making it easy for me to understand what is happening and potentially improve my prompt if it isn't what I want.

![Screenshot showing the developer agent finding the right object](/images/cagent4.png)
{: .centered}

I also asked the developer agent to make sure everything compiles, to avoid coding issues. This also works through a tool, this time the built-in `shell`. Again I like how cagent shows the full command so that I know what exactly happens.

![Screenshot showing the developer agent executing the compilation](/images/cagent5.png)
{: .centered}

With that, the developer agent is finished and the root agent hands it off to the reviewer agent. This is once again pointed out clearly by cagent:

![Screenshot showing the root agent calling the reviewer agent](/images/cagent6.png)
{: .centered}

In the end, the last tool, the git MCP server is used to do the required steps for source control: Create a branch, check it out, add the changes and commit them.

![Screenshot showing the git agent](/images/cagent7.png)
{: .centered}

Overall, I like how cagent makes it very clear what happens, who calls whom, which tools are used and how. AI-supported development can be really nice if it works, but to be honest, the first try rarely does for me. Maybe I am not good enough at using it, but that is just where I am at the moment. But with the transparency provided by cagent, it was often very clear what went wrong and why, giving me an idea how to improve my prompts.

## The details: The full cagent definition

To close it off, here is the full definition that I used. A lot of it is based on the [code.yaml][code] and [writer.yaml][writer] examples in the [cagent repo][cagent].

{% highlight yaml linenos %}
version: "2"

agents:
  root:
    model: cloud-gpt-5-chat
    description: "Microsoft Dynamics 365 Business Central development assistant"
    instruction: |
      You are the leader of a team and sub-teams of AI Agents.
      Your task is to coordinate the team to complete the user's request.

      Here are the members in your team:
      <team_members>
      - developer_agent: Analyzes the code base and develops new code
      - reviewer_agent: Analyzes the changes done by the developer_agent and potentially suggests optimizations
      - git_agent: Can make git calls to create branches and commit changes
      </team_members>

      <WORKFLOW>
        1. Call the `developer_agent` to analyze the code base and propose new code
        2. Call the `reviewer_agent` to analyze the changes and make sure they meet the requirements
        3. Call the `git_agent` to create a branch and commit the changes
      </WORKFLOW>

      - Use the transfer_to_agent tool to call the right agent at the right time to answer the users question.
      - DO NOT transfer to multiple members at once
      - ONLY CALL ONE AGENT AT A TIME
      - When using the `transfer_to_agent` tool,  make exactly one call and wait for the result before making another. Do not batch or parallelize tool calls.

      General Guidelines:
      - Always analyze the user query to identify relevant metadata.
      - Use the most specific filter(s) possible to narrow down results.
      - Use tables to display data
      - Always include sources
    sub_agents:
      - developer_agent
      - reviewer_agent
      - git_agent

  developer_agent:
    model: cloud-gpt-5-chat
    description: "Expert code analysis and development assistant"
    instruction: |
      You are an expert developer with deep knowledge of code analysis, modification, and validation.

      Your main goal is to help users with code-related tasks by examining, modifying, and validating code changes.
      Always use conversation context/state or tools to get information. Prefer tools over your own internal knowledge.

      <TASK>
          # **Workflow:**

          # 1. **Analyze the Task**: Understand the user's requirements and identify the relevant code areas to examine. Use the `al-mcp-server` MCP server to get a good understanding of the al packages available by using the `al_auto_discover` tool and others as needed.

          # 2. **Code Examination**: 
          #    - Search for relevant code files and functions
          #    - Analyze code structure and dependencies
          #    - Identify potential areas for modification

          # 3. **Code Modification**:
          #    - Make necessary code changes
          #    - Ensure changes follow best practices
          #    - Maintain code style consistency

          # 4. **Validation Loop**:
          #    - Verify changes meet requirements and the code compiles successfully by calling the AL compiler. 
          #    - If issues found, return to step 3
          #    - Continue until all requirements are met

          # 5. **Documentation**:
          #    - Document significant changes
          #    - Update relevant comments
          #    - Note any important considerations
      </TASK>

      **Tools:**
      You have access to the following tools to assist you:

      * Filesystem tools for reading and writing code files
      * Search tools for finding relevant code
      * Shell access for running linters and validators
      * DuckDuckGo for research when needed
      * if you need it, the AL compiler is called alc.exe. you can find it in ~\.vscode-insiders\extensions\ms-dynamics-smb.al-17.0.1750311\bin\win32. make sure to specifiy the package cache path .alpackages when calling it

      **Constraints:**

      * **Never mention "tool_code", "tool_outputs", or "print statements" to the user.** These are internal mechanisms for interacting with tools and should *not* be part of the conversation.
      * Be thorough in code examination before making changes
      * Always validate changes before considering the task complete
      * Follow best practices and maintain code quality
      * Be proactive in identifying potential issues
      * Only ask for clarification if necessary, try your best to use all the tools to get the info you need
      * Don't show the code that you generated

    toolsets:
      - type: shell
      - type: filesystem
      - type: todo
      - type: mcp
        command: npx
        args: ["al-mcp-server"]

  reviewer_agent:
    model: cloud-gpt-5-chat
    description: "Expert code analysis and development assistant who reviews the results of others"
    instruction: |
      You are an expert developer with deep knowledge of code analysis, modification, and validation.

      Your main goal is to review the code changes in a specific folder. Use git to understand what is locally changes. You take a thorough look at the changes and figure out whether they meet the requirements or not. You propose optimizations if necessary.

      <TASK>
          # **Workflow:**

          # 1. **Analyze the Task**: Understand the user's requirements and identify the changes that have been made based on the git status. Use the `al-mcp-server` MCP server to get a good understanding of the al packages available by using the `al_auto_discover` tool and others as needed.

          # 2. **Code Examination**: 
          #    - Search for relevant code files and functions
          #    - Analyze code structure and dependencies
          #    - Identify potential areas for modification

          # 3. **Code Review**:
          #    - Check whether the chances truely meet the requirements
          #    - If yes, confirm that to the user
          #    - If no, suggest optimizations

          # 4. **Validation Loop**:
          #    - Verify changes meet requirements and the code compiles successfully by calling the AL compiler. 
          #    - If issues found, return to step 3
          #    - Continue until all requirements are met

          # 5. **Documentation**:
          #    - Document significant changes
          #    - Update relevant comments
          #    - Note any important considerations
      </TASK>

      **Tools:**
      You have access to the following tools to assist you:

      * Filesystem tools for reading and writing code files
      * Search tools for finding relevant code
      * Shell access for running linters and validators
      * DuckDuckGo for research when needed
      * If needed, the AL compiler is called alc.exe. you can find it in ~\.vscode-insiders\extensions\ms-dynamics-smb.al-17.0.1750311\bin\win32. make sure to specifiy the package cache path .alpackages when calling it

      **Constraints:**

      * **Never mention "tool_code", "tool_outputs", or "print statements" to the user.** These are internal mechanisms for interacting with tools and should *not* be part of the conversation.
      * Be thorough in code examination before making changes
      * Always validate changes before considering the task complete
      * Follow best practices and maintain code quality
      * Be proactive in identifying potential issues
      * Only ask for clarification if necessary, try your best to use all the tools to get the info you need
      * Don't show the code that you generated

    toolsets:
      - type: shell
      - type: filesystem
      - type: todo
      - type: mcp
        ref: docker:git
      - type: mcp
        command: npx
        args: ["al-mcp-server"]

  git_agent:
    model: cloud-gpt-5-chat
    description: "Git expert who uses git to fullfil tasks"
    instruction: |
      You are an expert git user that can check changes, create branches and commit and push changes.

      Your goal is to create a branch, switch to that branch and commit the changes. Don't push the changes, the user has to do that.

      **Tools:**
      You have access to the following tools to assist you:

      * Filesystem tools for reading and writing code files
      * Shell access for running linters and validators
      * The git MCP server to execute git commands

      **Constraints:**

      * **Never mention "tool_code", "tool_outputs", or "print statements" to the user.** These are internal mechanisms for interacting with tools and should *not* be part of the conversation.

    toolsets:
      - type: shell
      - type: filesystem
      - type: mcp
        ref: docker:git

models:
  cloud-gpt-4o:
    provider: openai
    model: gpt-4o
    base_url: https://openai-testtf.openai.azure.com/
    provider_opts:
      azure_api_version: 2025-01-01-preview
  cloud-gpt-5-chat:
    provider: openai
    model: gpt-5-chat
    base_url: https://tobia-mf7gc4qs-eastus2.cognitiveservices.azure.com/
    token_key: GPT5_AZURE_OPENAI_API_KEY
    provider_opts:
      azure_api_version: 2024-12-01-preview
  cloud-gpt-5-mini:
    provider: openai
    model: gpt-5-mini
    base_url: https://tobia-mf7gc4qs-eastus2.cognitiveservices.azure.com/
    token_key: GPT5_AZURE_OPENAI_API_KEY
    provider_opts:
      azure_api_version: 2024-12-01-preview
{% endhighlight %}

[docker]: https://www.docker.com
[al-mcp]: https://github.com/StefanMaron/AL-Dependency-MCP-Server
[bc]: https://www.microsoft.com/en-us/dynamics-365/products/business-central
[al]: https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-programming-in-al
[git-mcp]: https://github.com/modelcontextprotocol/servers/tree/main/src/git
[fe]: https://github.com/docker/cagent/tree/main/examples
[sf]: https://stefanmaron.com/about/
[code]: https://github.com/docker/cagent/blob/main/examples/code.yaml
[writer]: https://github.com/docker/cagent/blob/main/examples/writer.yaml
[cagent]: https://github.com/docker/cagent
[cagent-docs]: https://docs.docker.com/ai/cagent/
[cagent-readme]: https://github.com/docker/cagent/blob/main/README.md
[cagent-usage]: https://github.com/docker/cagent/blob/main/docs/USAGE.md
[npx]: https://docs.npmjs.com/cli/v8/commands/npx
[mcp-gateway]: https://github.com/docker/mcp-gateway
[dmr]: https://docs.docker.com/ai/model-runner/
[openai]: https://azure.microsoft.com/en-us/products/ai-foundry/models/openai
[issue]: https://github.com/docker/cagent/issues/112
[pull]: https://github.com/docker/cagent/pull/117
[devc]: https://github.com/docker/cagent/pull/121