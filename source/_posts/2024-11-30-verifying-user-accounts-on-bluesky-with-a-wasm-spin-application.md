---
layout: post
title: "Verifying user accounts on Bluesky with a Wasm (spin) application"
permalink: verifying-user-accounts-on-bluesky-with-a-wasm-spin-application
date: 2024-11-30 09:55:17
comments: false
description: "Verifying user accounts on Bluesky with a Wasm (spin) application"
keywords: ""
image: /images/bluesky-spin.png
categories:

tags:

---

[Bluesky][bluesky] is a relatively new Social network. I joined about a year ago, but it hasn't seen much action until very recently. Now a lot of people in the tech bubble I'm interested in have moved there and it's an extremely nice experience without all the hate, bots and abysmal content on Twitter, but with a lot more interaction. Do you still remember the days when Twitter was nice? That is what Bluesky is now. And probably most pleasingly from a technical / development perspective, it has an open [API][api]. I used this for a little tool to enable verification of user accounts and took the opportunity to use [Fermyon][fermyon] [Spin][spin] again.

## The TL;DR
If you are a [Microsoft MVP][mvp], [Microsoft Regional Director][rd] or [GitHub Star][star], you can use [the tool][vsky] to add your Bluesky handle and your ID to one of the aforementioned sites. The tool will check if your Bluesky profile exists, if the ID on the program exists and if there is a link on the program site to the Bluesky profile. If yes, it accepts the user as verified and adds the profile to a [Bluesky list][list] and a [Bluesky starter pack][sp] based on the verification source. Microsoft RDs and GitHub Stars are not further separated, so they only have one of each, e.g. the [list of Verified Microsoft RDs][rd-list] or the [GitHub Stars starter pack][ghs-sp]. Microsoft MVPs are separated by category (e.g. "Azure" or "Business Applications") and technology area (e.g. "Application PaaS" or "Business Central") and the tool places MVPs in the appropriate lists and starter packs, e.g. the [list of Azure MVPs][az-list] or the [starter pack of Business Central MVPs][bc-sp]. It also adds [Bluesky labels][labels] to the users. To see them, other users need to subscribe to the [Bluesky labeler][labeler]. The result looks like this

![screenshot of a Bluesky account showing labels for Microsoft MVP and GitHub Star](images/verified.png)
{: .centered}

The lists, starter packs and labeler are all hosted on [this Bluesky account][account]. If you want to see the code, it lives at [github.com/tfenster/verified-bluesky][repo].

I am in contact with people to potentially add Docker Captains, AWS Heroes and Google Developer Experts. I am also toying with the idea of adding conference speakers. If you have any other ideas for possible verification sources, please let me know. The requirement is that it's a publicly visible website or web service, I don't want any kind of manual interaction, confirmation emails or anything like that.

## The details: The technology base Fermyon Spin and Fermyon Cloud

This little project gave me a great excuse to work with [Fermyon Spin][spin] again. I started with the verification backend, which is a perfect fit for Spin: It has no state other than a persisted key and value, it should start very quickly and run securely. I went with the [Go][go]-based template although I am really not a Go expert. So between [GitHub Copilot][copilot] and me, a collection of code lines came into existence which an experienced Go developer would probably find offensive. Therefore, I am not showing any code parts here, but you can find it at [github.com/tfenster/verified-bluesky][repo] as mentioned above. Apart from my Go struggles, the development experience was great. I coded in a [VS Code devcontainer][devcontainer] and used the [Spin CLI][spin-cli], which made it very easy to get started and work with it. 

Besides the Go components for verification and one for some admin tasks, I have two more: One builds on the [static file server for Spin applications][file-server] and serves only two HTML files (one for the self-verification and one for the overview of existing lists and starter packs) and a CSS. To make this work, all I need are a few lines in the `spin.toml` manifest. It defines the component `frontend` as listening on the `/...` route in lines 1-3 and declares that the Wasm file for it should be fetched from GitHub (line 6). The files to serve are to be read from the `static` subfolder (line 7):

{% highlight toml linenos %}
[[trigger.http]]
route = "/..."
component = "frontend"

[component.frontend]
source = { url = "https://github.com/fermyon/spin-fileserver/releases/download/v0.3.0/spin_static_fs.wasm", digest = "sha256:ef88708817e107bf49985c7cefe4dd1f199bf26f6727819183d5c996baa3d148" }
files = [{ source = "static", destination = "/" }]
{% endhighlight %}

The other one is the [Spin key/value store explorer][kv-exp], which is for administration users only. It also only needs a name and a route (lines 1-3), a file (line 6) and the configuration which key/value store to access:

{% highlight toml linenos %}
[[trigger.http]]
component = "kv-explorer"
route = "/internal/kv-explorer/..."

[component.kv-explorer]
source = { url = "https://github.com/fermyon/spin-kv-explorer/releases/download/v0.10.0/spin-kv-explorer.wasm", digest = "sha256:65bc286f8315746d1beecd2430e178f539fa487ebf6520099daae09a35dbce1d" }
allowed_outbound_hosts = ["redis://*:*", "mysql://*:*", "postgres://*:*"]
key_value_stores = ["default"]
{% endhighlight %}

Local testing is also very smooth with a running application just a `spin up` (to run already built code) or `spin build --up` (to build and then run) away. And deployment is just as easy using `spin cloud deploy` to bring your application to the [Fermyon Cloud][cloud] to make it publicly available. But of course, I also wanted to set up Continuous Integration and Continuous Delivery. Thanks to the recently announced [Spin GitHub plugin][spin-gh], all I had to do was `spin gh create-action` to get a working GitHub action for CI that installs the prerequisites and runs the build:

{% highlight yaml linenos %}
name: "Continuous Integration"
on:
  push:
    branches:
      - "main"
env:
  GO_VERSION: "1.23.2"
  TINYGO_VERSION: "v0.34.0"
  SPIN_VERSION: ""
jobs:
  spin:
    runs-on: "ubuntu-latest"
    name: Build Spin App
    steps:
      - uses: actions/checkout@v4
      - name: Install Go
        uses: actions/setup-go@v5
        with:
          go-version: "${{ env.GO_VERSION }}"
      - name: Install TinyGo
        uses: rajatjindal/setup-actions/tinygo@v0.0.1
        with:
          version: "${{ env.TINYGO_VERSION }}"
      - name: Install Spin
        uses: fermyon/actions/spin/setup@v1
        with:
          plugins: 
      - name: Build verified-bluesky
        run: spin build
        working-directory: .
{% endhighlight %}

The CD action looks very similar. Worth nothing is the trigger in line 4/5 to make sure it only runs when I set a tag like `v0.7.0` and lines 28-31 to not only run a build, but also a deployment to the Fermyon Cloud:

{% highlight yaml linenos %}
name: "Continuous Deployment"
on:
  push:
    tags:
    - 'v*' 
env:
  GO_VERSION: "1.23.2"
  TINYGO_VERSION: "v0.34.0"
  SPIN_VERSION: ""
jobs:
  spin:
    runs-on: "ubuntu-latest"
    name: Build Spin App
    steps:
      - uses: actions/checkout@v4
      - name: Install Go
        uses: actions/setup-go@v5
        with:
          go-version: "${{ env.GO_VERSION }}"
      - name: Install TinyGo
        uses: rajatjindal/setup-actions/tinygo@v0.0.1
        with:
          version: "${{ env.TINYGO_VERSION }}"
      - name: Install Spin
        uses: fermyon/actions/spin/setup@v1
        with:
          plugins: 
      - name: Build and deploy verified-bluesky
        uses: fermyon/actions/spin/deploy@v1
        with:
          fermyon_token: ${{ secrets.FERMYON_CLOUD_TOKEN }}
{% endhighlight %}

With this set up, my development workflow typically consists of some work on a feature branch, a merge to main and a tag, and the rest works automatically. More details can be found in the [official docs][spin-docs].

Overall, a really nice dev and deployment experience and I can only encourage everyone to give it a try if you have a suitable use case.

## The details: Interacting with the Bluesky API
The Bluesky REST API is somewhat [well documented][bluesky-api], but in my opinion lacks some examples. Therefore, here are some of the most important interactions with the API that tool implements:

Assuming that you have a variable `username` and a variable `password` with obvious purposes, a login works like this

{% highlight http linenos %}
POST https://bsky.social/xrpc/com.atproto.server.createSession
Content-Type: application/json

{
  "identifier": "{{username}}",
  "password": "{{pwd}}"
}
{% endhighlight %}

The response gives you among others your unique ID, a JWT access token, a refresh token and a service endpoint that you can use for further API calls

{% highlight JSON linenos %}
{
    "did": "did:plc:px34esz3zqocesnhjoyllu7q",
    "didDoc": {
        ...
        "service": [
            {
                "id": "#atproto_pds",
                "type": "AtprotoPersonalDataServer",
                "serviceEndpoint": "https://panthercap.us-east.host.bsky.network"
            },
            ...
        ]
    },
    ...
    "accessJwt": "...",
    "refreshJwt": "..."
}
{% endhighlight %}

Now let's read a profile. Assuming you have a variable `actorToRead` containing a Bluesky handle like `tobiasfenster.io` and a variable `baseurl` containing the service endpoint mentioned above, you can it read it as follows:

{% highlight http linenos %}
GET {{baseUrl}}/xrpc/app.bsky.actor.getProfile?actor={{actorToRead}}
Authorization: Bearer {{jwt}}
{% endhighlight %}

This returns detailed information about the user. 

Creating a list is a simple call as well. You create a record of type `app.bsky.graph.list` (line 13) with a purpose `app.bsky.graph.defs#curatelist` (line 12) and give it a name (line 9) and a description (line 10). The `repo` (line 7) is the Bluesky profile under which the list will be created.

{% highlight http linenos %}
POST {{baseUrl}}/xrpc/com.atproto.repo.createRecord
Authorization: Bearer {{jwt}}
Content-Type: application/json

{
    "collection": "app.bsky.graph.list",
    "repo": "{{did}}",
    "record": {
        "name": "test title from REST (50 max)",
        "description": "Test description via REST",
        "createdAt": "2024-11-11T18:28:20.213Z",
        "purpose": "app.bsky.graph.defs#curatelist",
        "$type": "app.bsky.graph.list"
    }
}
{% endhighlight %}

Creating a starter pack is a bit more complicated, because you first need to create a list similar to the one above,, but with purpose `app.bsky.graph.defs#referencelist` (line 12)

{% highlight http linenos %}
POST {{baseUrl}}/xrpc/com.atproto.repo.createRecord
Authorization: Bearer {{jwt}}
Content-Type: application/json

{
    "collection": "app.bsky.graph.list",
    "repo": "{{did}}",
    "record": {
        "name": "test title from REST (50 max)",
        "description": "Test description via REST",
        "createdAt": "2024-11-11T18:28:20.213Z",
        "purpose": "app.bsky.graph.defs#referencelist",
        "$type": "app.bsky.graph.list"
    }
}
{% endhighlight %}

To make this available as a starter pack, we need to create another record, this time of type `app.bsky.graph.starterpack` (line 14), pointing to the list we just created (line 11)

{% highlight http linenos %}
POST {{baseUrl}}/xrpc/com.atproto.repo.createRecord
Authorization: Bearer {{jwt}}
Content-Type: application/json

{
    "collection": "app.bsky.graph.starterpack",
    "repo": "did:plc:e6dbkqufnaoml54hrimf4arc",
    "record": {
        "name": "test title from REST (50 max)",
        "description": "Test description via REST",
        "list": "at://did:plc:e6dbkqufnaoml54hrimf4arc/app.bsky.graph.list/3lb6ezvokkl26",
        "feeds": [],
        "createdAt": "2024-11-11T18:28:20.670Z",
        "$type": "app.bsky.graph.starterpack"
    }
}
{% endhighlight %}

Adding users to a list works through the `applyWrites` endpoint. Assuming you have the unique ID of the user to be added in a variable `didToAdd`, the list in a variable `list` and the owner of the list in a variable `did`, you do this:

{% highlight http linenos %}
POST {{baseUrl}}/xrpc/com.atproto.repo.applyWrites
Authorization: Bearer {{jwt}}
Content-Type: application/json

{
    "repo": "{{did}}",
    "writes": [
        {
            "$type": "com.atproto.repo.applyWrites#create",
            "collection": "app.bsky.graph.listitem",
            "value": {
                "$type": "app.bsky.graph.listitem",
                "subject": "{{didToAdd}}",
                "list": "{{list}}",
                "createdAt": "2024-11-11T16:04:13.156Z"
            }
        }
    ]
}
{% endhighlight %}

I hope this gives you some idea of how to interact with the Bluesky API. As I said, the documentation is not bad, but lacks actual examples. I overcame this by simply doing what I wanted to automate via the Bluesky website and watching the traffic through my browser's development tools. That way it is relatively straightforward what to do.

## The details: The labeler
The last part of the story is the [labeler][labeler] to make the labels visible on Bluesky profiles and posts. Fortunately Bluesky has made [Ozone][ozone] available for everyone to use. So all I had to do was follow the [hosting instructions][hosting] to set it up.

At the end of this post I would like to ask you again to get in touch if you have any ideas of other verification backends I could use. I would prefer something or someone else involved, like community programs or speakers at events. Something like a LinkedIn profile would be a bit pointless because you could just open a LinkedIn profile and use that to "verify" your Bluesky profile. But anything else I would be happy to look into.

[bluesky]: https://bsky.app
[api]: https://docs.bsky.app
[fermyon]: https://www.fermyon.com
[spin]: https://www.fermyon.com/spin
[cloud]: https://www.fermyon.com/cloud
[mvp]: https://mvp.microsoft.com
[rd]: https://rd.microsoft.com
[star]: https://stars.github.com
[vsky]: https://verified-bluesky-rpu7w3bv.fermyon.app/
[list]: https://docs.bsky.app/docs/tutorials/user-lists
[sp]: https://bsky.social/about/blog/06-26-2024-starter-packs
[labels]: https://docs.bsky.app/docs/advanced-guides/moderation
[labeler]: https://docs.bsky.app/docs/advanced-guides/moderation#labelers
[account]: https://bsky.app/profile/verifiedsky.bsky.social
[rd-list]: https://bsky.app/profile/verifiedsky.bsky.social/lists/3lbpw4eka2c2i
[ghs-sp]: https://bsky.app/starter-pack/verifiedsky.bsky.social/3lc62iw7mch2h
[az-list]: https://bsky.app/profile/verifiedsky.bsky.social/lists/3lbl5aoa7zn24
[bc-sp]: https://bsky.app/starter-pack/verifiedsky.bsky.social/3lbl5agad4323
[go]: https://go.dev/
[copilot]: https://github.com/features/copilot
[repo]: https://github.com/tfenster/verified-bluesky
[devcontainer]: https://code.visualstudio.com/docs/devcontainers/containers
[spin-cli]: https://developer.fermyon.com/spin/v2/cli-reference
[spin-gh]: https://github.com/fermyon/spin-gh-plugin
[spin-docs]: https://developer.fermyon.com/cloud/github-actions
[file-server]: https://github.com/fermyon/spin-fileserver
[kv-exp]: https://github.com/fermyon/spin-kv-explorer
[ozone]: https://github.com/bluesky-social/ozone
[hosting]: https://github.com/bluesky-social/ozone/blob/main/HOSTING.md
[bluesky-api]: https://docs.bsky.app/docs/category/http-reference