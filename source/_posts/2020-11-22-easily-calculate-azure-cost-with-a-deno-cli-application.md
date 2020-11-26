---
layout: post
title: "Easily calculate Azure cost with a Deno CLI application, developed in a VS Code dev container"
permalink: easily-calculate-azure-cost-with-a-deno-cli-application
date: 2020-11-26 00:06:54
comments: false
description: "Easily calculate Azure cost with a Deno CLI application, developed in a VS Code dev container"
keywords: ""
categories:
image: /images/azure-cost-deno.png

tags:
---

For an upcoming service offering I had to calculate the expected cost for the Azure services we are going to use and I wanted to give [Deno][deno] a try for quite some time as well as developing in a [VS Code dev container][dev-container] with WSL2. Therefore this will be a two-part blog post with the first part about the Azure pricing API, technically not very interesting, but my lessons learned are maybe useful if you want to get started on it quickly. The second part will cover the implementation of my tool in Deno. If you are only interested in the latter, you still might want to read the TL;DR for the first part (see immediately below) and then skip to the [second part](#the-tldr-for-part-two-developing-a-deno-cli-application-in-a-vs-code-dev-container).

## The TL;DR for part one: The Azure pricing REST API

Using the [Azure pricing calculator][calculator] for a single of very view configurations is fine, but if you want to calculate a lot of configurations (in my case 8) in different variations (in my case 24) it becomes cumbersome very quick and if you need to make changes, it's quite annoying and error prone, at least for me. Fortunately the [Retail Rates Prices API][prices-api] was released in September 2020 which allows you to automate the queries. You get first results very quickly but the following four topics had me struggling:

- You can query for regular consumption ("prod" pay-as-you-go pricing), dev/test consumption and reserved instances for prod. But you can't query for reserved instances for prod. Instead you have to get the virtual machine price and add the license to it.
- On a related topic, some (most?) resources are available only in consumption as there is no dedicated reservation pricing.
- And then you have resources which have a "global" region like IP addresses, which makes some sense but is a bit difficult to use, but because you need to know that this is the case. Even more, some have an empty region like Windows Server license cost which at least IMHO is not very consistent.
- If you don't know the exact product name, the best way that I have found is to look at meter names or service names with filters like `$filter=startswith(tolower(meterName), 'static public')`. It's not directly documented on the API page, but those standard OData filter operations work and make it easier to find what you are looking for.
- The prices are always in USD and Microsoft uses fixed exchange rates for other currencies which seem to be updated once pre month. You can get an overview [here][exchange].

## The details for part one: The Azure pricing REST API

The basic usage is quite easy and well explained in the [documentation][prices-api]. You do something like

{% highlight http linenos %}
GET https://prices.azure.com/api/retail/prices?$filter=productName eq 'Virtual Machines Edsv4 Series' and skuName eq 'E4ds v4'
{% endhighlight %}

to get prices for the E4ds v4 VM size. As you can see, the API allows anonymous requests and you need to use standard OData filters to get the results you want, in this case prices for VMs in the Edsv4 series and particularly the E4ds v4 size. If the `skuName` is unique, you could also remove the `productName` filter, but during my tests I often good more results than expected with only the `skuName`, so I would say it is a good practice to always keep the `productName` filter as well. To further narrow it down to you region and pricing model, you could do something like this

{% highlight http linenos %}
GET https://prices.azure.com/api/retail/prices?$filter=productName eq 'Virtual Machines Edsv4 Series' and skuName eq 'E4ds v4' and armRegionName eq 'westeurope' and priceType eq 'Consumption'
{% endhighlight %}

This results in an answer like this

{% highlight json linenos %}
{
    "BillingCurrency": "USD",
    "CustomerEntityId": "Default",
    "CustomerEntityType": "Retail",
    "Items": [
        {
            "currencyCode": "USD",
            "tierMinimumUnits": 0.0,
            "retailPrice": 0.346,
            "unitPrice": 0.346,
            "armRegionName": "westeurope",
            "location": "EU West",
            "effectiveStartDate": "2020-06-01T00:00:00Z",
            "meterId": "fa405127-11f9-5d0d-ac47-53511c8d2888",
            "meterName": "E4ds v4",
            "productId": "DZH318Z0CSHK",
            "skuId": "DZH318Z0CSHK/00JW",
            "productName": "Virtual Machines Edsv4 Series",
            "skuName": "E4ds v4",
            "serviceName": "Virtual Machines",
            "serviceId": "DZH313Z7MMC8",
            "serviceFamily": "Compute",
            "unitOfMeasure": "1 Hour",
            "type": "Consumption",
            "isPrimaryMeterRegion": true,
            "armSkuName": "Standard_E4ds_v4"
        }
    ],
    "NextPageLink": null,
    "Count": 1
}
{% endhighlight %}

As you can see, it gives you exactly one price, which is in this case the cost per hour (line 23) and always in USD, so you need to calculate the cost e.g. for a month by multiplying with 730 for the hours and then with the exchange rate of your local currency if needed. You can use the link in the TL;DR above to get the current value for that. If you now want to compare this with the price for a reserved instance, you change the `priceType` to `reservation` and also need to add the reservation term (1 year or 3 years):

{% highlight http linenos %}
GET https://prices.azure.com/api/retail/prices?$filter=productName eq 'Virtual Machines Edsv4 Series' and skuName eq 'E4ds v4' and armRegionName eq 'westeurope' and priceType eq 'Reservation' and reservationTerm eq '1 Year'
{% endhighlight %}

The result looks very similar:

{% highlight json linenos %}
{
    "BillingCurrency": "USD",
    "CustomerEntityId": "Default",
    "CustomerEntityType": "Retail",
    "Items": [
        {
        "currencyCode": "USD",
        "tierMinimumUnits": 0.0,
        "reservationTerm": "1 Year",
        "retailPrice": 1788.0,
        "unitPrice": 1788.0,
        "armRegionName": "westeurope",
        "location": "EU West",
        "effectiveStartDate": "2020-06-01T00:00:00Z",
        "meterId": "fa405127-11f9-5d0d-ac47-53511c8d2888",
        "meterName": "E4ds v4",
        "productId": "DZH318Z0CSHK",
        "skuId": "DZH318Z0CSHK/02WV",
        "productName": "Virtual Machines Edsv4 Series",
        "skuName": "E4ds v4",
        "serviceName": "Virtual Machines",
        "serviceId": "DZH313Z7MMC8",
        "serviceFamily": "Compute",
        "unitOfMeasure": "1 Hour",
        "type": "Reservation",
        "isPrimaryMeterRegion": true,
        "armSkuName": "Standard_E4ds_v4"
        }
    ],
    "NextPageLink": null,
    "Count": 1
}
{% endhighlight %}

The big difference are lines 9-11: You can see that this is for a 1 year reservation term, and consequently you get the price for 1 year. So if you want to compare to the consumption price above, you need to divide or multiply accordingly. Now to the last `priceType`, dev/test consumption: The "intuitive" (as far as intuitiveness goes for a REST API) option in my opinion would be to just change the `priceType` to `DevTestConsumption`:

{% highlight http linenos %}
GET https://prices.azure.com/api/retail/prices?$filter=productName eq 'Virtual Machines Edsv4 Series' and skuName eq 'E4ds v4' and armRegionName eq 'westeurope' and priceType eq 'DevTestConsumption'
{% endhighlight %}

However the answer looks like this

{% highlight json linenos %}
{
    "BillingCurrency": "USD",
    "CustomerEntityId": "Default",
    "CustomerEntityType": "Retail",
    "Items": [],
    "NextPageLink": null,
    "Count": 0
}
{% endhighlight %}

The reason for that is (I assume) that there is no different price just for the VM. Instead you need to change the product name to `Virtual Machines Edsv4 Series Windows` where there actually is a difference between `Consumption` and `DevTestConsumption`: You either pay for the license or you don't. But as I mentioned before, there is no option `DevTestReservation`, so for that scenario you need to take a different approach: You get the price for the VM with reservation as seen above and then you add the license cost. If you find out that the product name for that is `Windows Server` and the SKU name e.g. `4 vCPU VM`, then you would probably create a request like this:

{% highlight http linenos %}
GET https://prices.azure.com/api/retail/prices?$filter=productName eq 'Windows Server' and skuName eq '4 vCPU VM' and armRegionName eq 'westeurope' and priceType eq 'Reservation'
{% endhighlight %}

But again, you get an empty response for that. This time, there are actually two reasons: 

1. The license is only available with the `Consumption` price type, probably for the reason that you actually can't create a reservation for most resources including the license.
2. The license also is only available if you don't add the `armRegionName` or leave it empty. So we can e.g. do it like this to make it work:

{% highlight http linenos %}
GET https://prices.azure.com/api/retail/prices?$filter=productName eq 'Windows Server' and skuName eq '4 vCPU VM' and armRegionName eq '' and priceType eq 'Consumption'
{% endhighlight %}

With that we get an answer:

{% highlight json linenos %}
{
    "BillingCurrency": "USD",
    "CustomerEntityId": "Default",
    "CustomerEntityType": "Retail",
    "Items": [
        {
            "currencyCode": "USD",
            "tierMinimumUnits": 0.0,
            "retailPrice": 0.184,
            "unitPrice": 0.184,
            "armRegionName": "",
            "location": "",
            "effectiveStartDate": "2017-08-01T00:00:00Z",
            "meterId": "1cb88381-0905-4843-9ba2-7914066aabe5",
            "meterName": "4 vCPU VM License",
            "productId": "DZH318Z0BJS5",
            "skuId": "DZH318Z0BJS5/0009",
            "productName": "Windows Server",
            "skuName": "4 vCPU VM",
            "serviceName": "Virtual Machines Licenses",
            "serviceId": "DZH317WPTGV0",
            "serviceFamily": "Compute",
            "unitOfMeasure": "1 Hour",
            "type": "Consumption",
            "isPrimaryMeterRegion": true,
            "armSkuName": ""
        }
    ],
    "NextPageLink": null,
    "Count": 1
}
{% endhighlight %}

The same issue with the `armRegionName` is true e.g. for the Public IP Addresses which need to be queried with an `armRegionName eq 'Global'` filter. I don't have a clue why there are resources with `Global` and resources with empty `armRegionName`, I just found that out with trial and error. 

One last thing, useful if you are not sure what the exact product name and sku are for a resource: You can query using OData filter expressions like `startswith` or `tolower` if you don't know the spelling exactly. E.g. when I was looking for the IP addresses I used this to narrow it down:

{% highlight http linenos %}
GET https://prices.azure.com/api/retail/prices?$filter=startswith(tolower(meterName), 'static public')
{% endhighlight %}

This gave me a list of results, but it at least showed me the correct `productName` (line 18), `skuName` (line 19) and `armRegionName` (line 11) so that I could then narrow it down further:

{% highlight json linenos %}
{
    "BillingCurrency": "USD",
    "CustomerEntityId": "Default",
    "CustomerEntityType": "Retail",
    "Items": [
        {
            "currencyCode": "USD",
            "tierMinimumUnits": 0.0,
            "retailPrice": 0.0036,
            "unitPrice": 0.0036,
            "armRegionName": "Global",
            "location": "Global",
            "effectiveStartDate": "2014-08-01T00:00:00Z",
            "meterId": "26ce34b7-67b3-480d-9d1b-54a7fb80f67a",
            "meterName": "Static Public IP",
            "productId": "DZH318Z0BNXN",
            "skuId": "DZH318Z0BNXN/0032",
            "productName": "IP Addresses",
            "skuName": "Basic",
            "serviceName": "Virtual Network",
            "serviceId": "DZH314HC0WV9",
            "serviceFamily": "Networking",
            "unitOfMeasure": "1 Hour",
            "type": "DevTestConsumption",
            "isPrimaryMeterRegion": true,
            "armSkuName": ""
        },
        ...
    ],
    "NextPageLink": null,
    "Count": 3
}
{% endhighlight %}

This should hopefully give you a better idea how the pricing API works and allow you to skip the problems I had in the beginning. I then proceeded to make a small little tool to be more efficient working with the API:

## The TL;DR for part two: Developing a Deno CLI application in a VS Code dev container
The tool allows you to specify the resources and configurations that you want in a fairly easy JSON file[^1]. You describe the configuration like price type, region and reservation term. Then you describe the resource configs with their resources and those have properties like product name, sku name, amount or meter name. To give you an idea, an example could look like this:

{% highlight json linenos %}
{
    "priceConfigs": [
        {
            "priceType": "Reservation",
            "reservationTerm": "1 Year",
            "description": "Reserved",
            "armRegionName": "westeurope"
        },
        {
            "priceType": "Consumption",
            "description": "pay as you go",
            "armRegionName": "westeurope"
        }
    ],
    "hourFactor": 730,
    "exchangeRate": 0.843,
    "resourceConfigs": [
        {
            "description": "VMs",
            "resources": [
                {
                    "productName": "Virtual Machines Edsv4 Series",
                    "skuName": "E4ds v4",
                    "amount": 2,
                    "description": "Base scale set"
                },
                {
                    "productName": "Premium SSD Managed Disks",
                    "skuName": "P10 LRS",
                    "amount": 2,
                    "meterName": "P10 Disks",
                    "priceType": "Consumption",
                    "description": "OS Disks"
                },
                {
                    "productName": "Premium SSD Managed Disks",
                    "skuName": "P20 LRS",
                    "amount": 2,
                    "meterName": "P20 Disks",
                    "priceType": "Consumption",
                    "description": "Data Disk"
                },
                {
                    "productName": "Windows Server",
                    "skuName": "4 vCPU VM",
                    "amount": 2,
                    "optional": true,
                    "priceType": "Consumption",
                    "armRegionName": "",
                    "description": "Windows License"
                }
            ]
        },
        {
            "description": "Storage and Public IP",
            "resources": [
                {
                    "productName": "Standard HDD Managed Disks",
                    "skuName": "S10 LRS",
                    "amount": 1,
                    "meterName": "S10 Disks",
                    "priceType": "Consumption",
                    "description": "Shared Storage"
                },
                {
                    "productName": "IP Addresses",
                    "skuName": "Basic",
                    "armRegionName": "Global",
                    "amount": 1,
                    "priceType": "Consumption",
                    "meterName": "Static Public IP",
                    "description": "Public IP"
                }
            ]
        }
    ]
}
{% endhighlight %}

If you run the tool against this config, it will read and parse the data, make the necessary calls against the Pricing API and then output a file containing the different resource configuration with the different price configurations and to make it easy to compare, everything with monthly pricing. As we have two pricing configs and two resource configs, we get four result objects, containing a description, the resources with prices and totals including and excluding optional resources. You can then bring this into Excel, transform it with Power Query and with that you have all the data you might need from the Pricing API and can get to start on it. It's Excel, so it will never actually be beautiful, but you can work with it :)

![calc](/images/calc.png)
{: .centered}

With this running perfectly fine on Linux and my WSL2 subsystem working good as well, I also decided to develop this in a [dev container][dev-container]. For that I can only say that it is extremely easy to set up and works rock solid, simply a pleasure.

## The details for part two: Developing a Deno CLI application in a VS Code dev container
With the knowledge how the Pricing API works, I was able to make the decision on my tool. I expected to mostly move JSON-based data around, so JavaScript was the clear favorite and because I sometimes fall into the trap of lazyness when programming, a typed language is always my first choice, so I went with TypeScript. Since the launch of [Deno][deno], I always wanted to give it a try and I took the opportunity. I won't bore you with a "is Deno better than Node" comparison because there are enough of them out there and instead just show you what I have created: I have [deps.ts][dep] for my dependencies (I only use https://deno.land/std/flags/mod.ts) and [types.d.ts][types] / [classes.ts][classes] for my types and classes. Then I have [api.ts][api] for the actual API calls and [mod.ts][mod] for main functionality. The code itself is quite trivial, so if you want to understand how it works, you should very quickly be able to do so by looking at api.ts and mod.ts. The only small "design decision" that I made was to create no magic transformation for the special cases above in the code, but instead make sure that I could configure it as you will see below. In my experience that kind of magic works well and is convenient in the beginning, but if you get in touch with your code months or even years later, it is incredibly hard to understand or remember how and where you implemented that.

The configuration files have some minor wrinkles in addition to the base structure explained in the TL;DR which I want to point out: As I mentioned above, there are some special cases like resources that are only available in a global region or in consumption pricing, so I have some options to override the "defaults" in the price configs with more specific values in the resource configs. Take for example the IP Addresses: They are only available in consumption and the global region, so while I have different options in the price configs (lines 4 and 7), those two properties are overridden in the resource configs (lines 22 and 24).

{% highlight json linenos %}
{
    "priceConfigs": [
        {
            "priceType": "Reservation",
            "reservationTerm": "1 Year",
            "description": "Reserved",
            "armRegionName": "westeurope"
        },
        ...
    ],
    "hourFactor": 730,
    "exchangeRate": 0.843,
    "resourceConfigs": [
        ...
        {
            "description": "Storage and Public IP",
            "resources": [
                ...
                {
                    "productName": "IP Addresses",
                    "skuName": "Basic",
                    "armRegionName": "Global",
                    "amount": 1,
                    "priceType": "Consumption",
                    "meterName": "Static Public IP",
                    "description": "Public IP"
                }
            ]
        }
    ]
}
{% endhighlight %}

You can also see in line 12 which allows you to convert the USD prices to your local currency. And we have optional resources like the Windows Server licenses (see line 12 below) because as I mentioned above, calculating the license cost separately and adding it only where needed is in my opinion the only good way to get to reserved dev/test pricing:

{% highlight json linenos %}
{
    ...
    "resourceConfigs": [
        {
            "description": "VMs",
            "resources": [
                ...
                {
                    "productName": "Windows Server",
                    "skuName": "4 vCPU VM",
                    "amount": 2,
                    "optional": true,
                    "priceType": "Consumption",
                    "armRegionName": "",
                    "description": "Windows License"
                }
            ]
        },
        ...
    ]
}
{% endhighlight %}

The Excel conversion very much depends on your need and preferences, so I only want to mention that you use the Data > Get Data > From File > From JSON action to start the import. The rest was a bit of guessing, but you will probably get the idea quickly if you give it a try. The article that helped me to get started is [here][excelweb] and the [official documentation][https://support.microsoft.com/en-us/office/import-data-from-external-data-sources-power-query-be4330b3-5356-486c-a168-b68e9e616f5a?ui=en-us&rs=en-us&ad=us] is also quite good and comprehensive.

The last part to mention is the [dev-container][dev-container] that I used. My devcontainer.json file which describes the container itself and the VC Code extensions to install in it is pretty close to the Deno standard:

{% highlight json linenos %}
{
    "name": "Deno",
    "dockerFile": "Dockerfile",
    // Set *default* container specific settings.json values on container create.
    "settings": {
        "terminal.integrated.shell.linux": "/bin/bash"
    },
    // Add the IDs of extensions you want installed when the container is created.
    "extensions": [
        "denoland.vscode-deno",
        "eamodio.gitlens",
        "humao.rest-client"
    ],
    // Use 'forwardPorts' to make a list of ports inside the container available locally.
    // "forwardPorts": [],
    // Uncomment to use the Docker CLI from inside the container. See https://aka.ms/vscode-remote/samples/docker-from-docker.
    // "mounts": [ "source=/var/run/docker.sock,target=/var/run/docker.sock,type=bind" ],
    // Comment out connect as root instead. More info: https://aka.ms/vscode-remote/containers/non-root.
    "remoteUser": "vscode"
}
{% endhighlight %}

I have only added [GitLens][gitlens] because it simply is amazing and the [REST Client][restclient] because I tried to call the Pricing APi directly before writing code for it quite often. The Dockerfile which describes how the dev-container should be built is also quite straight-forward and unchanged from the standard template provided by Microsoft:

{% highlight Dockerfile linenos %}
FROM mcr.microsoft.com/vscode/devcontainers/base:debian-10

ENV DENO_INSTALL=/deno
RUN mkdir -p /deno \
    && curl -fsSL https://deno.land/x/install/install.sh | sh \
    && chown -R vscode /deno

ENV PATH=${DENO_INSTALL}/bin:${PATH} \
    DENO_DIR=${DENO_INSTALL}/.cache/deno
{% endhighlight %}

The amazing part there was, how easy it was to set up and how quick it starts and then performs very well. I will probably be using that a lot more in the future[^2].

If you want to take a look at all of this, please check [https://github.com/cosmoconsult/azure-calculator][main]. The easiest way to get started probably is to just clone it in Visual Studio Code and hit F5. That will run (actually debug) the sample configuration found in the configs folder. If that works, you can start adjusting the configuration to your needs and also create new configurations. Have fun with it and as always, let me know if you have ideas for improvement.

[deno]: https://deno.land
[dev-container]: https://code.visualstudio.com/docs/remote/containers
[calculator]: https://azure.microsoft.com/en-us/pricing/calculator/
[prices-api]: https://docs.microsoft.com/en-us/rest/api/cost-management/retail-prices/azure-retail-prices
[exchange]: https://azureprice.net/Exchange
[api]: https://github.com/cosmoconsult/azure-calculator/blob/main/api.ts
[mod]: https://github.com/cosmoconsult/azure-calculator/blob/main/mod.ts
[types]: https://github.com/cosmoconsult/azure-calculator/blob/main/types.d.ts
[classes]: https://github.com/cosmoconsult/azure-calculator/blob/main/classes.ts
[dep]: https://github.com/cosmoconsult/azure-calculator/blob/main/dep.ts
[excelweb]: https://theexcelclub.com/how-to-parse-custom-json-data-using-excel/
[gitlens]: https://marketplace.visualstudio.com/items?itemName=eamodio.gitlens
[restclient]: https://marketplace.visualstudio.com/items?itemName=humao.rest-client
[main]: https://github.com/cosmoconsult/azure-calculator
[^1]: At least I find it intuitive. But I always find my stuff intuitive while others for unknown reasons sometimes tend to disagree ;)
[^2]: Especially when Windows support comes along