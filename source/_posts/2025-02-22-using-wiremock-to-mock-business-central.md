---
layout: post
title: "Using WireMock to mock Business Central"
permalink: using-wiremock-to-mock-business-central
date: 2025-02-22 21:14:07
comments: false
description: "Using WireMock to mock Business Central"
keywords: ""
image: /images/wiremock.png
categories:

tags:

---

Developing and testing solutions that consist of multiple components is inherently more difficult. Even more so when you need a "big" component like MS Dynamics 365 Business Central, such as when you're building an optimized front end or something else that talks to the BC API. In these scenarios, it can be very helpful to mock the backend, both during development and continuous integration. Typically, this is done either in code or with a tool that replaces the backend with something that behaves as close to the actual backend as possible. The following post explains the basics of a tool called [WireMock][wm] and how it can be used from a [devcontainer][devc] for an easy setup. I may go into more detail in a future post, but this is the starting point.

## The TL;DR

Here is how you can try for yourself:

- Clone [github.com/tfenster/wiremock-demo](https://github.com/tfenster/wiremock-demo) into a folder and use the "Open folder in container" action of the [Dev Containers][devcex] VS Code extension. This will not only start a devcontainer for a small example application interacting with the BC API, but also a WireMock server in a second container.
- Once this is started, you can simply launch the application or run the automated tests. Both will talk to WireMock as a proxy for Business Central.

In the details, I'll explain how the devcontainer setup works, how to mock APIs with WireMock, how to use its recording feature, and even how to simulate stateful behaviour.

## The details: Setting up the devcontainer and WireMock

Setting up a standalone devcontainer is by now pretty straightforward using the actions included in the Dev Containers VS Code extension mentioned above. But for this scenario, I wanted two containers instead of one, and that makes it a bit more interesting. The main configuration, `devcontainer.json`, remains more or less the same, but it needs a reference to a file that controls multiple containers called `docker-compose.yml`[^1] and a reference to one of the parts in that file, called a `service`, that describes the container:

{% highlight JSON linenos %}
{
	"name": "C# (.NET)",
	"dockerComposeFile": "docker-compose.yml",
	"service": "devcontainer",
    ...
}
{% endhighlight %}

The `docker-compose.yml` file itself looks like this

{% highlight yaml linenos %}
version: '3.8'
services:
  devcontainer:
    image: mcr.microsoft.com/devcontainers/dotnet:1-9.0-bookworm
    volumes:
      - ../..:/workspaces:cached
    network_mode: service:wiremock
    command: sleep infinity

  wiremock:
    image: wiremock/wiremock:latest
    restart: no
    volumes:
      - ../wiremock/extensions:/var/wiremock/extensions
      - ../wiremock/__files:/home/wiremock/__files
      - ../wiremock/mappings:/home/wiremock/mappings
    entrypoint: [ "/docker-entrypoint.sh", "--global-response-templating", "--disable-gzip", "--verbose" ]
    ports:
      - "8080:8080"
{% endhighlight %}

Lines 3-8 define the devcontainer itself, with a base image (line 4), the folder containing the source code bindmounted into the container (lines 5 and 6), and a network connection to the other container (line 7).

Lines 10-19 define the wiremock container. Line 11 has the container image, line 17 the startup options and lines 18/19 define that it listens on port 8080. Lines 13-16 took me a few tries to get right, but now you can control WireMock from the devcontainer workspace as all the relevant files are in the `wiremock` subfolder.

It's worth noting that you can't use `Clone repository in container volume`, which is what I usually do. The reason is that WireMock also needs access to the files, as mentioned above, but with the container volume option, only the devcontainer has access to the files. Or at least I haven't found a way to give the second container access as well. If anyone knows, please let me know.

## The details: The scenario and how to mock simple read access

With the infrastructure in place, let's take a look at WireMock itself. To quote from their website: "WireMock frees you from dependence on unstable APIs and allows you to develop with confidence. It's easy to launch a mock API server and simulate a variety of real-world scenarios and APIs - including REST, SOAP, OAuth2 and more". The scenario for this blog post is a small C# console application talking to Business Central APIs. Of course, this is just an example as I want to focus on WireMock. Here is what the application looks like, at least the main `Program.cs` file:

{% highlight csharp linenos %}
using bc_client;
using bc_client.Models;

var bcIntegration = new BCIntegration();
var companies = await bcIntegration.GetCompaniesAsync();
foreach (var company in companies)
{
    Console.WriteLine($"Company: {company.Name}");
    var customers = await bcIntegration.GetCustomersAsync(company.Id);
    foreach (var customer in customers)
    {
        Console.WriteLine($"  Customer: {customer.DisplayName}");
    }
}

var singlecustomer = await bcIntegration.GetCustomerAsync(companies.First().Id, "37fe3458-93e1-ef11-9344-6045bde9ca09");
Console.WriteLine($"Single customer: {singlecustomer.DisplayName}");

var newCustomer = await bcIntegration.CreateCustomerAsync(companies.First().Id, new CustomerRequest
{
    DisplayName = "Ulm Falcons",
    Type = "Company"
});
Console.WriteLine($"New customer id: {newCustomer.Id}");
var newCustomerFromGet = await bcIntegration.GetCustomerAsync(companies.First().Id, newCustomer.Id);
Console.WriteLine($"New customer from get: {newCustomerFromGet.DisplayName}");

var updatedCustomer = await bcIntegration.UpdateCustomerAsync(companies.First().Id, newCustomer.Id, new CustomerRequest
{
    DisplayName = "TSG Söflingen",
    Type = "Company"
}, newCustomer.ETag);
Console.WriteLine($"Updated customer display name: {updatedCustomer.DisplayName}");
var updatedCustomerFromGet = await bcIntegration.GetCustomerAsync(companies.First().Id, newCustomer.Id);
Console.WriteLine($"Updated customer from get: {updatedCustomerFromGet.DisplayName}");

await bcIntegration.DeleteCustomerAsync(companies.First().Id, newCustomer.Id);
Console.WriteLine("Deleted customer");

try
{
    await bcIntegration.GetCustomerAsync(companies.First().Id, newCustomer.Id);
}
catch (ApplicationException e)
{
    Console.WriteLine($"Customer not found as expected: {e.Message}");
}
{% endhighlight %}

Lines 4-14 instantiate the `BCIntegration` class which handles communication with BC, get all the companies, iterate over them, get all the customers per company and print the companies and customers to the console. Lines 16/17 get a specific customer and also print it to the console. All of this is read-only.

Lines 16-26 are a bit more interesting because we first create a new customer and then read it from the API again. So now the backend mock can not only be static, but we create some information and return it again. More interestingly, in lines 28-35, the customer is updated and read from the API again. So now we are not only creating something new and expecting WireMock to handle it, but also updating something. If you know [CRUD][crud], you've probably already guessed what comes next: In lines 37-47, the new customer is deleted and we expect a subsequent read request for this customer to fail. Again, we change something in the backend and expect WireMock to handle it correctly.

In total, we are requesting the same information from the backend three times with `await bcIntegration.GetCustomerAsync(companies.First().Id, newCustomer.Id);` (lines 25, 34 and 42) and WireMock has to react differently each time. We'll see how that works in a second, but let's start with an explanation of the easy part, returning static content. WireMock has a concept called [stubbing][stubbing] and in it's most trivial form, it looks like this:

{% highlight json linenos %}
{
  "request": {
    "method": "GET",
    "url": "/some/thing"
  },

  "response": {
    "status": 200,
    "body": "Hello, world!",
    "headers": {
        "Content-Type": "text/plain"
    }
  }
}
{% endhighlight %}

If you put a file with this content into the `mappings` folder, you will make WireMock respond with `Hello, world!` when you call `http://localhost:8080/some/thing`. Lines 2-5 define that it will respond to a `GET` request to `/some/thing` and lines 7-13 define that it will respnd with an HTTP status of `200` (which is `OK`), a `body` of `Hello, world!` and a `Content-Type` header of `text-plan`. Of course, this isn't something needed for mocking the BC API, so we'll have to use something slightly more sophisticated for that. But if we take a simple example like the list of companies in a BC environment, it is actually quite similar:

{% highlight json linenos %}
{
    "request": {
        "method": "GET",
        "url": "/companies"
    },
    "response": {
        "status": 200,
        "headers": {
            "Content-Type": "application/json"
        },
        "jsonBody": {
            "@odata.context": "https://fps-alpaca.westeurope.cloudapp.azure.com/BC/api/v2.0/$metadata#companies",
            "value": [
                {
                    "id": "9ee48135-93e1-ef11-9344-6045bde9ca09",
                    "systemVersion": "25.4.29661.29727",
                    "timestamp": 47433,
                    "name": "CRONUS AG",
                    "displayName": "",
                    "businessProfileId": "",
                    "systemCreatedAt": "2025-02-02T18:26:25.61Z",
                    "systemCreatedBy": "00000000-0000-0000-0000-000000000001",
                    "systemModifiedAt": "2025-02-02T18:26:25.61Z",
                    "systemModifiedBy": "00000000-0000-0000-0000-000000000001"
                }
            ]
        }
    }
}
{% endhighlight %}

The request is defined in lines 2-5 as `GET` to `/companies`. The response has the same `OK` status code (line 7), a `Content-Type` of `application/json` (line 9) and the body is defined in JSON (lines 11-27). I got this response by calling `/api/v2.0/companies` at a BC environment and copying the response. But WireMock doesn't just let you define this content statically, it also allows you to change it. For example, you can create [random values][random] where needed, so the `id` in line 15 could also be defined as `"id": "{{randomValue type='UUID'}}"` and would then return a generated random ID. Or the `systemCreatedAt`in line 21 could be set to the current date minus 7 days with `"systemCreatedAt": "{{now offset='-7 days'}}"` with [date and time helpers][datetime].

Doing all of this manually would be quite tedious though for more than a few requests/responses, but fortunately WireMock has another really cool feature to help.

## The details: Record API calls and replay them later

The feature is called "[Record and Playpack][recpb]" and it allows you to configure a target URL to be addressed through the WireMock server, which in turn records all interactions. In my case, I can access the BC API at `https://fps-alpaca.westeurope.cloudapp.azure.com/f053da92c4a7rest/api/v2.0/`, so I put that in as the target URL. As a result, if I now call `http://localhost:8080/companies`, WireMock will take that request, replace `http://localhost:8080/` with `https://fps-alpaca.westeurope.cloudapp.azure.com/f053da92c4a7rest/api/v2.0/` and call the resulting `https://fps-alpaca.westeurope.cloudapp.azure.com/f053da92c4a7rest/api/v2.0/companies`. It records the request and response in a similar way to what I've shown you above in the JSON configuring the mock for the same `/companies` request. When you then stop recording, it places the recorded files in the mappings folder, where you can manually adjust them if necessary.

You can either configure the target URL and start the recording via the GUI at `http://localhost:8080/__admin/recorder` or you can use an API call to the WireMock admin API. The admin API also allows you to [tweak the recording behaviour][recsettings]. For example, you can ask it to put the actual JSON workload into separate files if it is larger than a configurable threshold. I like this behaviour as I find the resulting files are cleaner and easier to read, so I enable it for all workloads by setting the threshold to 1 byte:

{% highlight http linenos %}
POST http://localhost:8080/__admin/recordings/start
Content-Type: application/json

{
  "targetBaseUrl" : "https://fps-alpaca.westeurope.cloudapp.azure.com/f053da92c4a7rest/api/v2.0/",
  "extractBodyCriteria" : {
    "textSizeThreshold" : "1",
    "binarySizeThreshold" : "1"
  },
  "captureHeaders" : {
    "If-Match" : {}
  }
}
{% endhighlight %}

As you can see in lines 10-12, I also ask it to capture the `If-Match` header as this is important for updates in the BC API. The corresponding call to stop the capture and write the captured files to the filesystem is this

{% highlight http linenos %}
POST http://localhost:8080/__admin/recordings/stop
{% endhighlight %}

The result is a record file like the following for reading all customers

{% highlight json linenos %}
{
  "id": "1a0d1352-65a5-4243-95d7-a7ddffd63e6b",
  "name": "companies9ee48135-93e1-ef11-9344-6045bde9ca09_customers",
  "request": {
    "url": "/companies(9ee48135-93e1-ef11-9344-6045bde9ca09)/customers",
    "method": "GET"
  },
  "response": {
    "status": 200,
    "bodyFileName": "get all customers.json",
    "headers": {
      "Strict-Transport-Security": "max-age=15724800; includeSubDomains",
      "Access-Control-Expose-Headers": "Date, Content-Length, Server, OData-Version",
      "Cache-Control": "no-cache, no-store",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Credentials": "true",
      "OData-Version": "4.0",
      "request-id": "c150e2eb-cf35-4a10-854e-de3a1212dfbf",
      "urls-rewritten-to-public": "false",
      "Date": "Sun, 23 Feb 2025 13:34:15 GMT",
      "Content-Type": "application/json; odata.metadata=minimal; odata.streaming=true"
    }
  },
  "uuid": "1a0d1352-65a5-4243-95d7-a7ddffd63e6b",
  "persistent": true,
  "insertionIndex": 61
}
{% endhighlight %}

It has an ID and a name (lines 2-3) and the already known request definition (lines 4-7). The response is a bit different with the same status as before (line 9), but then the body is just a reference to a file (line 10) and the headers are also included (lines 11-22). The body file contains exactly the response body of the API, so something like this

{% highlight json linenos %}
{
    "@odata.context": "https://fps-alpaca.westeurope.cloudapp.azure.com/BC/api/v2.0/$metadata#companies(9ee48135-93e1-ef11-9344-6045bde9ca09)/customers",
    "value": [
        {
            "@odata.etag": "W/\"JzIwOzEwMDkzMjczMDY1MjU0NTY2NDQzMTswMDsn\"",
            "id": "37fe3458-93e1-ef11-9344-6045bde9ca09",
            "number": "01121212",
            "displayName": "Spotsmeyer's Furnishings",
            "type": "Company",
            "addressLine1": "612 South Sunset Drive",
            "addressLine2": "",
            "city": "Miami",
            "state": "FL",
            "country": "US",
            "postalCode": "FL 37125",
            "phoneNumber": "",
            "email": "",
            "website": "",
            "salespersonCode": "HS",
            "balanceDue": 0,
            "creditLimit": 0,
            "taxLiable": false,
            "taxAreaId": "73f63458-93e1-ef11-9344-6045bde9ca09",
            "taxAreaDisplayName": "Sonstige Debitoren und Kreditoren (nicht EU)",
            "taxRegistrationNumber": "",
            "currencyId": "9f253c52-93e1-ef11-9344-6045bde9ca09",
            "currencyCode": "USD",
            "paymentTermsId": "40253c52-93e1-ef11-9344-6045bde9ca09",
            "shipmentMethodId": "24283c52-93e1-ef11-9344-6045bde9ca09",
            "paymentMethodId": "00000000-0000-0000-0000-000000000000",
            "blocked": "_x0020_",
            "lastModifiedDateTime": "2025-02-02T18:28:34.057Z"
        },
        ...
    ]
}
{% endhighlight %}

The recorder makes it very easy to just set it up, make the calls to the API you want to mock and then work with the recordings. The filenames are generated and I renamed them to something that made sense to me, but those were easy fixes and overall certainly a lot faster than creating these request/response pairs by hand. You can also tweak the responses using the mechanisms mentioned above and much more in the WireMock feature set, but that might be a topic for another blog post.

As you may know, Business Central only accepts update / `PATCH` requests if you set the `If-Match` header correctly to the current `eTag` of the last entity, see e.g. [here][ifmatch] in the documentation for updating customers cia the API. To also simulate this behaviour, we can tell WireMock to only accept the update request with the correct header like this

{% highlight json linenos %}
{
    ...
    "request": {
        "url": "/companies(9ee48135-93e1-ef11-9344-6045bde9ca09)/customers(b37406e8-eaf1-ef11-9b20-d99fd2b71a0f)",
        "method": "PATCH",
        "headers": {
            "If-Match": {
                "equalTo": "W/\"JzE4Ozg5MDM2MzYwNDgyMzQ1NjE0MjE7MDA7Jw==\""
            }
        },
        ...
    }
...
}
{% endhighlight %}

Because of the `captureHeaders` setting defined at capture startup as explained above, this is automatically created as part of the capture. I didn't do this for my scenario, but we could also set the correct response to say that the header is not correct for all other `If-Match` headers being sent.

Now the last missing piece is how to get WireMock to send different responses for the same request, as explained above.

## The details: Stateful behaviour in WireMock

WireMock supports what they call [Stateful Behaviour][state]. With this feature, you can define a [state machine][statemachine] with "scenarios" that allow you to define request/response configurations based on the state of the scenario. As an example, let's look at what we need for our customer example above, when we create a new customer and later modify it:

- While the create / `POST` call has not happened, a request for the new customer should fail
- As soon as the customer exists, it should be returned
- When the modify / `PATCH` call has happened, the modified customer should be returned
- When the delete / `DELETE` call has happened, it should now not be returned

To make this happen, I defined a scenario `CRUD customer`. Let's go through the states step by step: Once the create has happened, it goes into the state `CRUD customer - created` and only in that state will the new customer be returned. To achieve this, the create stub looks like this

{% highlight json linenos %}
{
  ...
  "request": {
    "url": "/companies(9ee48135-93e1-ef11-9344-6045bde9ca09)/customers",
    "method": "POST",
    "bodyPatterns": [
      {
        "equalToJson": "{\n    \"displayName\": \"Ulm Falcons\",\n    \"type\": \"Company\"\n}",
        "ignoreArrayOrder": true,
        "ignoreExtraElements": true
      }
    ]
  },
  "response": {
    ...
  },
  ...
  "scenarioName": "CRUD customer",
  "newScenarioState": "CRUD customer - created",
  ...
}
{% endhighlight %}

Line 18 marks it as part of the `CRUD customer` scenario and with line 19 the state transition into `CRUD customer - created` happens after the request. Therefore, the request to read the new customer is defined as follows

{% highlight json linenos %}
{
  ...
  "request": {
    "url": "/companies(9ee48135-93e1-ef11-9344-6045bde9ca09)/customers(b37406e8-eaf1-ef11-9b20-d99fd2b71a0f)",
    "method": "GET"
  },
  "response": {
    ...
    "bodyFileName": "get created customer.json",
    ...
  },
  ...
  "scenarioName": "CRUD customer",
  "requiredScenarioState": "CRUD customer - created",
  ...
}
{% endhighlight %}

Line 13 also marks it as part of the `CRUD customer` scenario, but this time, line 14 requires it to be in the `CRUD customer - created` state. Otherwise, the response wouldn't be triggered, so a call would return with a `404 - Not found` response. Also note that there is no `newScenarioState` configuration, because this request doesn't change the state of the scenario.

Now let's look at the update request

{% highlight json linenos %}
{
  ...
  "request": {
    "url": "/companies(9ee48135-93e1-ef11-9344-6045bde9ca09)/customers(b37406e8-eaf1-ef11-9b20-d99fd2b71a0f)",
    "method": "PATCH",
    ...
    "bodyPatterns": [
      {
        "equalToJson": "{\n    \"displayName\": \"TSG Söflingen\",\n    \"type\": \"Company\"\n}",
        "ignoreArrayOrder": true,
        "ignoreExtraElements": true
      }
    ]
  },
  "response": {
    ...
  },
  ...
  "scenarioName": "CRUD customer",
  "requiredScenarioState": "CRUD customer - created",
  "newScenarioState": "CRUD customer - updated",
  ...
}
{% endhighlight %}

In line 19, we also mark it as part of the `CRUD customer` scenario. Line 20 tells it to only respond in the `CRUD customer - created` state, because we can only modify it once it exists. But in line 21 we now also tell it to bring the state to `CRUD customer - updated`, because now the customer has changed. For that reason, we also need a new mapping to get the customer, which is basically the same as before, but points to a different `bodyFileName`, because the customer now has a different `displayName`

{% highlight json linenos %}
{
  ...
  "request": {
    "url": "/companies(9ee48135-93e1-ef11-9344-6045bde9ca09)/customers(b37406e8-eaf1-ef11-9b20-d99fd2b71a0f)",
    "method": "GET"
  },
  "response": {
    ...
    "bodyFileName": "get updated customer.json",
    ...
  },
  ...
  "scenarioName": "CRUD customer",
  "requiredScenarioState": "CRUD customer - updated",
  ...
}
{% endhighlight %}

Note the different `bodyFileName` in line 9 and the different required state in line 14. Again, we don't change the state based on this request because simply reading data doesn't change the state in BC. Now the last step is the delete. The stub for this looks like this

{% highlight json linenos %}
{
  ...
  "request": {
    "url": "/companies(9ee48135-93e1-ef11-9344-6045bde9ca09)/customers(b37406e8-eaf1-ef11-9b20-d99fd2b71a0f)",
    "method": "DELETE"
  },
  "response": {
    ...
  },
  ...
  "scenarioName": "CRUD customer",
  "requiredScenarioState": "CRUD customer - updated",
  "newScenarioState": "CRUD customer - deleted",
  ...
}
{% endhighlight %}

Note that it requires the `CRUD customer - updated` state in line 12 and moves to the `CRUD customer - deleted` state in line 13. Therefore, the request to read the customer as defined above will fail, and a `404 - Not found` will be returned as expected. With this, the flow of the application as shared initially works: The customer can be created, queried, updated, queried again with a different result, deleted and finally not queried anymore. However, I also created automated tests and one of them is to create and delete a customer and make sure that it is really gone afterwards.

{% highlight csharp linenos %}
[Fact]
public async Task DeleteCustomerAsync_RemovesCustomer_WhenApiCallSucceeds()
{
    // Arrange
    var bcIntegration = new BCIntegration();
    var newCustomer = new CustomerRequest
    {
        DisplayName = "Ulm Falcons",
        Type = "Company"
    };
    var createdCustomer = await bcIntegration.CreateCustomerAsync(_companyId, newCustomer);

    // Act
    await bcIntegration.DeleteCustomerAsync(_companyId, createdCustomer.Id);

    // Assert
    // Verify customer no longer exists
    var exception = await Assert.ThrowsAsync<ApplicationException>(() =>
        bcIntegration.GetCustomerAsync(_companyId, createdCustomer.Id));
    Assert.Contains("Failed to fetch backend content", exception.Message);
}
{% endhighlight %}

If we only worked with the above setup, this would not work, because the create call in line 11 would only move the `CRUD customer` scenario to the `CRUD customer - created` state, but the delete call so far requires the `CRUD customer - updated` state, so it would fail in line 14. I couldn't find an elegant solution to this, so I had to duplicate the stub and only change the required state as you can see in line 12

{% highlight json linenos %}
{
  ...
  "request": {
    "url": "/companies(9ee48135-93e1-ef11-9344-6045bde9ca09)/customers(b37406e8-eaf1-ef11-9b20-d99fd2b71a0f)",
    "method": "DELETE"
  },
  "response": {
    ...
  },
  ...
  "scenarioName": "CRUD customer",
  "requiredScenarioState": "CRUD customer - created",
  "newScenarioState": "CRUD customer - deleted",
  ...
}
{% endhighlight %}

In line 13, we go to the same `CRUD customer - deleted` state as before, so the logic works after that. If anyone knows of a better way to implement this instead of duplicating the stub, please let me know.

As an aside, the scenario and state logic was almost completely covered by the recording that generated those elements as well. The only problem for me was that it understandably uses generated IDs, so I had to go through the files and replace the scenario and state fields with meaningful names to be able to maintain them later.

## The details: Resetting scenarios and mappings

Also worth mentioning: When working with scenarios and mappings, you will sometimes need to reset them, e.g. when adding new mappings, changing existing mappings or starting your scenario from scratch. This can be done with the following calls to the REST API

{% highlight http linenos %}
POST http://localhost:8080/__admin/mappings/reset
{% endhighlight %}

{% highlight http linenos %}
POST http://localhost:8080/__admin/scenarios/reset
{% endhighlight %}

You can also see where you are in your scenarios with this call

{% highlight http linenos %}
GET http://localhost:8080/__admin/scenarios
{% endhighlight %}

I hope this post gave you some inspiration for API mocking and how smoothly it can work with devcontainers and Docker Desktop. I have only scratched the surface of WireMock's features, so please let me know if you liked this post and would like me to dive into more parts of it.

[^1]: If you want to learn more about `docker compose`, check the [official docs][compose]
[wm]: https://wiremock.org/
[devc]: https://code.visualstudio.com/docs/devcontainers/containers]
[devcex]: https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers
[compose]: https://docs.docker.com/compose/
[stubbing]: https://wiremock.org/docs/stubbing/
[crud]: https://en.wikipedia.org/wiki/Create,_read,_update_and_delete
[random]: https://wiremock.org/docs/response-templating/#random-value-helper
[datetime]: https://wiremock.org/docs/response-templating/#date-and-time-helpers
[recpb]: https://wiremock.org/docs/record-playback/
[recsettings]: https://wiremock.org/docs/record-playback/#customising-your-recordings
[ifmatch]: https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/api-reference/v2.0/api/dynamics_customer_update#request-headers
[state]: https://wiremock.org/docs/stateful-behaviour/
[statemachine]: https://en.wikipedia.org/wiki/Finite-state_machine