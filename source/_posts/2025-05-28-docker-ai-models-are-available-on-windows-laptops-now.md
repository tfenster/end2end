---
layout: post
title: "Docker AI models are available on Windows laptops now"
permalink: docker-ai-models-are-available-on-windows-laptops-now
date: 2025-05-28 17:45:33
comments: false
description: "Docker AI models are available on Windows laptops now"
keywords: ""
image: /images/dmr.png
categories:

tags:

---

Docker recently revealed a new feature of [Docker Desktop][dd]: The [Docker Model Runner][dmr]. Initially it was only available on Mac and Windows with Nvidia GPUs, but with the upcoming release 4.42 of Docker Desktop, also Windows laptops with Qualcomm / ARM GPUs are supported. As I have such a laptop and got a chance to test a pre-release version of 4.42, I could finally join in on the fun.

## The TL;DR

If you have a compatible laptop and Docker Desktop 4.42, here's an example of what you can do:

<video width="100%" controls="">
  <source type="video/mp4" src="/images/docker model runner.mp4" />
</video>

## The details: interacting with a model

As you can see, I used a [SmolLM2] model with 135 million parameters, so it's a very lightweight model. This is visible through the docker command: I executed `docker model run ai/smollm2:135M-Q2_K`, so the `smollm2` indicates the model's name and the `135M` shows that it is the 135M parameter variation. With a simple `docker model run`, you can get an interactive chat session with the model. If you want to learn more about that, I recommend the [official Docker docs][dmr-docs].

To see which models are available, you can go to the [AI section of the Docker Hub][hub-ai]. There, you will find an ever-expanding list of models, each with a description, the different variations and some performance benchmarks to help you decide which model to use.

## The details: using it in a .NET Blazor application

While that is a nice demo case, we probably want to use it for application development. Therefore, I have also created a small example of how it works from a .NET application using the [OpenAI][oa] package. The most relevant part is probably the endpoint where the model runner is reachable or at least it took me the longest to figure that out and put it correctly into my code. As [explained in the docs][endpoint], you need to enable it with `docker desktop enable model-runner`. Afterwards it is available from within a container at `http://model-runner.docker.internal` or from the host at `http://localhost:11434`. If you want a different port, you can also change that using `docker desktop enable model-runner --tcp <port>`. For example to query for the available models, you could make an HTTP call like this

{% highlight http linenos %}
GET http://localhost:11434/engines/llama.cpp/v1/models

{
  "object": "list",
  "data": [
    {
      "id": "ai/smollm2:135M-Q2_K",
      "object": "model",
      "created": 1745936469,
      "owned_by": "docker"
    },
    {
      "id": "ai/deepseek-r1-distill-llama",
      "object": "model",
      "created": 1742905580,
      "owned_by": "docker"
    }
  ]
}
{% endhighlight %}

To integrate this into a simple Blazor application that allows us to chat with the models, we can configure the OpenAI client to use that endpoint. I am (of course ;)) developing this in a [devcontainer][dc], so I can use the internal URL e.g. like this

{% highlight csharp linenos %}
builder.Services.AddSingleton(sp =>
{
    var options = new OpenAIClientOptions
    {
        Endpoint = new Uri("http://model-runner.docker.internal/engines/llama.cpp/v1"),
    };
    return new OpenAIClient(new ApiKeyCredential("unused"), options);
});
{% endhighlight %}

When we want to have a chat interaction with the model, we use something like this:

{% highlight csharp linenos %}
var chatClient = OpenAIClient.GetChatClient(selectedModel);          
cancellationTokenSource = new CancellationTokenSource();

var messages = new[] { ChatMessage.CreateUserMessage(userInput) };
status = "Generating response...";	
await foreach (var message in chatClient.CompleteChatStreamingAsync(messages, null, cancellationTokenSource.Token))
{
    foreach (var update in message.ContentUpdate) {
        response += update.Text;
    }
    StateHasChanged();
}
{% endhighlight %}

You can check the full result on [this Github repo][gh] and run it in a devcontainer. It should look like this, depending on which models you have pulled:

<video width="100%" controls="">
  <source type="video/mp4" src="/images/docker model runner chat app.mp4" />
</video>

I hope this gives you an idea of why I'm so excited about this new Docker Desktop capability! Give it a try once it is officially released and let me know how you like it.

[dmr]: https://www.docker.com/blog/introducing-docker-model-runner/
[dd]: https://www.docker.com/products/docker-desktop/
[smollm2]: https://github.com/huggingface/smollm
[dmr-docs]: https://docs.docker.com/model-runner/
[hub-ai]: https://hub.docker.com/u/ai
[oa]: https://www.nuget.org/packages/OpenAI/
[endpoint]: https://docs.docker.com/model-runner/#how-do-i-interact-through-the-openai-api
[gh]: https://github.com/tfenster/dotnet-model-runner
[dc]: https://code.visualstudio.com/docs/devcontainers/containers