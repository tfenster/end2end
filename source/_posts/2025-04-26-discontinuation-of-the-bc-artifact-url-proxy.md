---
layout: post
title: "Discontinuation of the BC artifact URL proxy"
permalink: discontinuation-of-the-bc-artifact-url-proxy
date: 2025-04-26 10:07:18
comments: false
description: "Discontinuation of the BC artifact URL proxy"
keywords: ""
image: /images/bca-function.png
categories:

tags:

---

This is just a little "service announcement": About [three years ago][initial] I created the BC artifact URL proxy, a little tool to access BC artifact URLs without the need for PowerShell and some caching to make it faster. It has seen [some improvements][improvements] and even a corresponding [Azure DevOps extension][azdo-ext], all thanks to a lot of great work by [Arthur van de Vondervoort][avdv]. However, Microsoft has made the responses when retrieving artifact URLs through BCContainerHelper much faster, so that the slower responses that could take minutes in the past now return in a few seconds. This removes a major pain point tht my proxy addressed and I can already see the usage numbers dropping significantly.

Therefore, I will be shutting down the URL proxy and archiving the repository by the end of June 2025. If you are using it, you can still get the code and spin up your own instance, or even fork the repo and make improvements, but I will stop the publicly available service and any work on it.

[initial]: /get-your-bc-artifact-urls-without-powershell
[improvements]: /getting-bc-insider-artifacts-without-powershell-or-a-token-and-the-bc-community-is-great
[azdo-ext]: https://github.com/Arthurvdv/bcartifacturl-proxy-vss/blob/main/overview.md
[avdv]: https://bsky.app/profile/arthurvdv.bsky.social