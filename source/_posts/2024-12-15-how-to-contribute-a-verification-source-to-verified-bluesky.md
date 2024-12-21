---
layout: post
title: "How to contribute a verification source to Verified Bluesky"
permalink: how-to-contribute-a-verification-source-to-verified-bluesky
date: 2024-12-21 14:32:11
comments: false
description: "How to contribute a verification source to Verified Bluesky"
keywords: ""
image: /images/verified-bluesky-contribute.png
categories:

tags:

---

As I shared [here][prev-post], I created a little tool to verify Bluesky accounts based on external sources in the IT/Tech industry. It has seen a fair bit of adoption (515 verified profiles through 6 different sources as of 21.12.2024) and I get feedback and comments about new verification sources. I am happy to implement those as that takes me less than an hour by now, but I think it actually is fairly easy to do for anyone else too, so this blog post will be about how to do that.

## The TL;DR

The steps to add the connection to a new verification source are those:

- First you need to set up a development environment. The easiest way is to use the [devcontainer][devc] configuration in the [repo][repo].
- Then you need to implement the integration with the new verification source. For one of the simplest examples, check the [Microsoft Regional Director integration][rd]. You will see that you need to set up some naming and documentation, but mostly a way how to verify that the Bluesky profile is indeed connected to the profile on the verification source. In this case, it is as simple as getting a JSON file from a backend and verifying that the Bluesky profile is in there. You also need to extend the frontend to make the new source available. In the end, you create a Pull Request to let me know that you want to add your new verification source to the tool. To give you an idea what this means, [this PR][ace-pr] added [Oracle ACEs][aces] as verification source.
- The last step is to let me know to extend the [labeler][labeler]. As explained in the previous post, this is the component which can put labels on accounts. As this is a manual step that needs admin permissions on my labeler, only I can do this at the moment. In the highly unlikely scenario that this little tool really takes off and requires more work than I can do, I would also be happy to have other admins, but let's cross that bridge when we get there.

If you can't or don't want to code, you can also fill in a [New verification source request][new-req] on Github.

## The details: Setting up the development environment

As I am a big fan of devcontainers, this repo also comes with a devcontainer configuration:

{% highlight json linenos %}
{
	"name": "Go",
	"image": "mcr.microsoft.com/devcontainers/go:1-1.23-bookworm",
	"features": {
		"ghcr.io/lee-orr/rusty-dev-containers/fermyon-spin:0": {}
	},
	"postCreateCommand": "wget https://github.com/tinygo-org/tinygo/releases/download/v0.34.0/tinygo_0.34.0_arm64.deb && sudo dpkg -i tinygo_0.34.0_arm64.deb && rm tinygo*.deb",
	"customizations": {
		"vscode": {
			"extensions": [
				"humao.rest-client",
				"tamasfe.even-better-toml",
				"eamodio.gitlens",
				"github.vscode-github-actions"
			]
		}
	}
}
{% endhighlight %}

Line 3 shows that it uses the standard Go devcontainer image. Line 5 then uses the devcontainer feature for [Fermyon Spin][spin] and line 7 installs [Tinygo][tinygo] because the corresponding devcontainer feature didn't work for me (and I didn't get feedback on my bug report). Because of this configuration, you only need to have the [VS Code Dev Containers extension][devc-vsc] installed in your VS Code and then you can run the "Dev Containers: Clone Repository in Container Volume" action. Create a [fork][fork] of [my repo][repo], enter the URL to your fork and VS Code will clone it into a container volume, create a container according to the configuration and after waiting for a couple of minutes, you are ready to go!

I assume that you can also install the different parts manually and it should work, but I haven't tried that. Devcontainers are just so much easier :)

To test whether everything works, you need to run a couple of commands:

First, you need to set up a number of [configuration variables][vars] for the application to work. You can find them in the `remember` file:

{% highlight bash linenos %}
export SPIN_VARIABLE_BSKY_HANDLE="verifiedsky.bsky.social"
export SPIN_VARIABLE_BSKY_DID="did:plc:px34esz3zqocesnhjoyllu7q"
export SPIN_VARIABLE_BSKY_LABELER_DID="did:plc:ar7c4by46qjdydhdevvrndac"
export SPIN_VARIABLE_KV_EXPLORER_USER="tfenster"
export SPIN_VARIABLE_KV_EXPLORER_PASSWORD="abc123"
export SPIN_VARIABLE_VERIFY_ONLY="true"
export SPIN_VARIABLE_BSKY_PASSWORD="..."
{% endhighlight %}

Put the handle of your Bluesky account in the first line, instead of `"verifiedsky.bsky.social"`. Corresponding to this, put the password in line 7, preferrably an [app password][app-pwd]. You also need to set the ID of your user account in line 2, instead of `"did:plc:px34esz3zqocesnhjoyllu7q"`. The easiest way to find that is by going to https://bsky.social/xrpc/com.atproto.identity.resolveHandle?handle=&lt;your handle&gt;, of course with `your handle` replaced with your handle. This will give you a response like this where you can copy the ID

```
{"did":"did:plc:e6dbkqufnaoml54hrimf4arc"}
```

With that in place, you can run `spin build --up`. After it has finished, open [http://localhost:3000](http://localhost:3000) and you have the verification UI up and running. Notice that this is now running in "verification only" mode, which means that it will only verify if the connection between the Bluesky handle and the verification ID for verification source can be made. It will not add a user to the starter packs and lists and it will also not put any labels on accounts, because all of that requires permissions of the host account which you won't have. But it allows you to test the verification process, so this is enough to contribute a new verification source.

## The details: Implementing an integration with a new verification source

Each of the integrations with a verification source is a dedicated component. Therefore, to create a new integration, you need to create a new component. Let's assume you would want to implement the integration against a list of professional Basketball players, the command could look like this `spin new -t http-go validate-bballplayer`. The `-t http-go` param tells spin to use the Go-based HTTP template and the name of the new component is `validate-bballplayer`. I know `validate` is not what you probably would have expected given that I always talk about "verify", but that is a bit of a mess I created early and will need to clean up at some point. For now, please bear with me... The `spin new` wizard will ask a couple of question where you can just accept the defaults (sorry Abel!) with one exception: The URL should be the same as the component name, so in our example it would be `/validate-bballplayer/...`.

This will now give you a new folder `validate-bballplayer` with a number of files and it will adjust the `spin.toml` file in the root folder with references to the new component. Now the real work starts and we'll take a look step by step:

In `spin.toml`, we first bump the version in line 5. I always bump the minor when I add a new verification source, so please do that as well. Currently, we are at `0.10.3`, so we would bump it to `0.11.0`. Then we need to allow our component to talk to Bluesky and our verification source. Assuming the we get the required data from the fictional https://www.bballplayers.com, we would add this as `allowed_outbound_hosts`:

{% highlight toml linenos %}
allowed_outbound_hosts = [
    "https://bsky.social",
    "https://*.bsky.network",
    "https://www.bballplayers.com",
]
{% endhighlight %}

As the tool keeps a list of key/value pairs where the key is a combination of the ID of the verification source and the verification ID, we also need to give the component access to that key/value store by adding the following line:

{% highlight toml linenos %}
key_value_stores = ["default"]
{% endhighlight %}

The last thing in `spin.toml` is access to variables we need for authentication and configuration. We do that by adding the following section:

{% highlight toml linenos %}
[component.validate-bballplayer.variables]
{% raw %}bsky_handle = "{{ bsky_handle }}"
bsky_password = "{{ bsky_password }}"
bsky_did = "{{ bsky_did }}"
bsky_labeler_did = "{{ bsky_labeler_did }}"
verify_only = "{{ verify_only }}"
{% endraw %}
{% endhighlight %}

In total, the component definition of our new component should look something like this

{% highlight toml linenos %}
{% raw %}[[trigger.http]]
route = "/validate-bballplayer/..."
component = "validate-bballplayer"

[component.validate-bballplayer]
source = "validate-bballplayer/main.wasm"
allowed_outbound_hosts = [
    "https://bsky.social",
    "https://*.bsky.network",
    "https://www.bballplayers.com",
]
key_value_stores = ["default"]
[component.validate-bballplayer.variables]
bsky_handle = "{{ bsky_handle }}"
bsky_password = "{{ bsky_password }}"
bsky_did = "{{ bsky_did }}"
bsky_labeler_did = "{{ bsky_labeler_did }}"
verify_only = "{{ verify_only }}"
[component.validate-bballplayer.build]
command = "tinygo build -target=wasi -gc=leaking -no-debug -o main.wasm main.go"
workdir = "validate-bballplayer"
watch = ["**/*.go", "go.mod"]
{% endraw %}
{% endhighlight %}

The next step is to add our new verification source to the frontend. For that, go to `static/index.html` and add a new `<option>` to the select starting at approx. line 40. In our example, we would add something like

{% highlight html linenos %}
<option value="bballplayer">Professional Basketball Player</option>
{% endhighlight %}

This adds a new option to the dropdown on the homepage of the tool where you select the verification source. The same needs to be added in `static/overview.html`, at approx. line 35.

The last step is to add the actual structure and verification logic in `main.go`. Let's assume on our fictional site of professional Basketball players, every player has a dedicated page. On that page, we need to look for the link to the Bluesky profile. An implementation could then look like this:

{% highlight go linenos %}
package main

import (
	"fmt"

	"github.com/antchfx/htmlquery"
	spinhttp "github.com/fermyon/spin/sdk/go/v2/http"
	"github.com/shared"
)

func init() {
	moduleSpecifics := shared.ModuleSpecifics{
		ModuleKey:            "bballplayer",
		ModuleName:           "Professional Basketball Players",
		ModuleNameShortened:  "Pro Ballers",
		ModuleLabel:          "bballplayer",
		ExplanationText:      "This is your ID in the Professional Basketball Players list. If you open your profile, it is the last part of the URL after https://www.bballplayers.com/players?p=. For this to work, you need to have the link to your Bluesky profile in the social links on your Professional Basketball Player profile.",
		FirstAndSecondLevel:  make(map[string][]string),
		Level1TranslationMap: make(map[string]string),
		Level2TranslationMap: make(map[string]string),
		VerificationFunc: func(verificationId string, bskyHandle string) (bool, error) {
			fmt.Println("Validating Professional Basketball Player with ID: " + verificationId)
			url := "https://www.bballplayers.com/players?p=" + verificationId

			resp, err := shared.SendGet(url, "")
			if err != nil {
				fmt.Println("Error fetching the URL: " + err.Error())
				return false, fmt.Errorf("Error fetching the Professional Basketball Player profile: "+err.Error())
			}
			defer resp.Body.Close()

			doc, err := htmlquery.Parse(resp.Body)
			if err != nil {
				fmt.Println("Error parsing HTML:", err)
				return false, fmt.Errorf("Error parsing the Professional Basketball Player profile: "+err.Error())
			}

			xpathQuery := fmt.Sprintf("//a[@href='https://bsky.app/profile/%s']", verificationId, bskyHandle)
			fmt.Println("XPath query: " + xpathQuery)
			nodes, err := htmlquery.QueryAll(doc, xpathQuery)
			if err != nil {
				fmt.Println("Error performing XPath query: %v", err)
				return false, fmt.Errorf("Could not find Bluesky URL https://bsky.app/profile/" + bskyHandle + " on the Professional Basketball Player profile of " + verificationId + ": "+err.Error())
			}
			
			if (len(nodes) == 0) {
				fmt.Println("Could not find Bluesky URL https://bsky.app/profile/" + bskyHandle + " on the Professional Basketball Player profile of " + verificationId)
				return false, fmt.Errorf("Could not find Bluesky URL https://bsky.app/profile/" + bskyHandle + " on the Professional Basketball Player profile of " + verificationId)
			}
			return true, nil
		},
		NamingFunc: func(m shared.ModuleSpecifics, _ string) (shared.Naming, error) {
			return shared.SetupNamingStructure(m)
		},
	}

	spinhttp.Handle(moduleSpecifics.Handle)
}

func main() {}
{% endhighlight %}

In lines 13-17, we define the specific internal and external names of our verification module: First the technical internal key, then the publicly visible name as well as a shortened name, which is used when we hit the 50 character limit of Starter Pack names on Bluesky. Lastly, the technical name of the label to be put on verified accounts. Lines 18-20 are only relevant if the verification source has multiple levels, more on that later. Starting from line 21, we then define the code to be run when a verification is requested:

- In lines 23-29, we get the profile page from the verification source and make sure that we can fetch it with the verification ID entered by the user. Of course, this would be different for your verification source.
- In lines 32-36, we parse the HTML content. Of course, this could also be something else like YAML or JSON. For a JSON-based verification, check the [Regional Directors implementation][rd-json]. For a YAML-based verification, check the [Java Champions implementation][javachamps-yaml].
- In lines 38-50, we check whether the profile in the verification source contains the link to the Bluesky profile. Again, this would be different for your verification source.

This would do the trick if the verification source has only one big pool like Microsoft Regional Directors or Java Champions. But some have multiple levels and we can handle that as well. E.g. Oracle ACEs have one level: "Associate", "Pro" and "Director". Microsoft MVPs have multiple categories like "Azure" or "Business Applications" and below that multiple technology areas like "Azure --> Cloud native" or "Business Applications --> Business Central". This has implications for verification and naming, but is quite specific to the verification source. To get an idea if you have the same issue, check the [MVP][mvp] and [ACE][ace] implementations.

With that, we can verify the profile in the verification source and make sure the expected Bluesky profile appears on the verification source profile. If that is verified, the user is automatically put in the right lists and starter packs and the right label is put on the Bluesky profile. If you made it to this place, run `spin build --up` again and test your verification code. If it works, commit and push your code, [create a Pull Request][create-pr] and I will take a look.

But to make that work completely, the labeler also has to be configured.

## The details: The labeler configuration

The labeler configuration is centered around a JSON file which looks like this

{% highlight json linenos %}
{
  "labelValues": [
    "ms-mvp",
    ...
  ],
  "labelValueDefinitions": [
    {
      "blurs": "none",
      "locales": [
        {
          "lang": "en",
          "name": "Microsoft MVP",
          "description": "Microsoft Most Valuable Professional (see https://mvp.microsoft.com)"
        }
      ],
      "severity": "inform",
      "adultOnly": false,
      "identifier": "ms-mvp",
      "defaultSetting": "ignore"
    },
    ...
  ]
}
{% endhighlight %}

As you can see, not too complicated: First, we define the internal name of the label, which references the `ModuleLabel` in our `main.go` file. Then we define an externally visible `name` and a `description`. As mentioned above, only someone with admin privileges on the labeler can change that, so I will need to do that.

I hope this gave you an idea how easy it is to contribute an integration for a new verification source and I look forward to your Pull Requests!

[prev-post]: /verifying-user-accounts-on-bluesky-with-a-wasm-spin-application
[devc]: https://code.visualstudio.com/docs/devcontainers/containers
[repo]: https://github.com/tfenster/verified-bluesky
[rd]: https://github.com/tfenster/verified-bluesky/blob/main/validate-rd/main.go
[ace-pr]: https://github.com/tfenster/verified-bluesky/pull/27
[aces]: https://ace.oracle.com
[spin]: https://www.fermyon.com/spin
[tinygo]: https://tinygo.org/
[devc-vsc]: https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers
[vars]: https://developer.fermyon.com/cloud/variables
[app-pwd]: https://lifehacker.com/tech/why-you-should-be-using-bluesky-app-passwords
[fork]: https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/fork-a-repo
[rd-json]: https://github.com/tfenster/verified-bluesky/blob/main/validate-rd/main.go#L56-L61
[javachamps-yaml]: https://github.com/tfenster/verified-bluesky/blob/main/validate-javachamps/main.go#L64-L69
[mvp]: https://github.com/tfenster/verified-bluesky/blob/main/validate-mvp/main.go
[ace]: https://github.com/tfenster/verified-bluesky/blob/main/validate-oracleace/main.go
[new-req]: https://github.com/tfenster/verified-bluesky/issues/new?assignees=&labels=&projects=&template=new-verification-source-request.md&title=
[create-pr]: https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request
[labeler]: https://docs.bsky.app/docs/advanced-guides/moderation#labelers