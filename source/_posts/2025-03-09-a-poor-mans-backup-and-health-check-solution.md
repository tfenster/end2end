---
layout: post
title: "A poor man's backup and health check solution using Power Automate flows"
permalink: a-poor-mans-backup-and-health-check-solution
date: 2025-03-09 10:35:29
comments: false
description: "A poor man's backup and health check solution using Power Automate flows"
keywords: ""
image: /images/verifiedbsky-power-automate.png
categories:

tags:

---

If you run a service online, no matter how small, you probably have two challenges: How to make sure you know when your service goes down, and how to make sure your data is backed up. Of course, there are very sophisticated solutions to these problems, but maybe your needs aren't that sophisticated, so you might be happy with a simpler approach. This blog post will explain what I do for [https://verifiedbsky.net/][verifiedbsky], a Bluesky account verification tool. If you are interested, I explained a bit more about it [here][verifiesbskypost]. 

## The TL;DR

I use scheduled [Power Automate flows][flows]:
- One calls a specific endpoint of my application every hour to make sure it is still responding as expected. If not, it sends me an email letting me know that something is wrong.
- The other is to retrieve my application's persistent data every 12 hours and upload it to a file in [OneDrive][onedrive].

That's about it. I'll explain exactly how I do this in the following paragraphs, but if you have a basic knowledge of Power Automate, you could probably do this yourself.

## The details: The health check flow

Here is the total overview of the flow

![shows a Power Automate flow with a "Recurrence" step, an "HTTP" step and a "Send an email" step](images/verifiedbsky-healthcheck.png)
{: .centered}

Doesn't get much simpler than that you might say? Wait for the backup flow... 😊 But the details for the steps: The "Recurrence" step is set to hourly, so the `Interval` is `1` and the `Frequency` is `Hour`. The "HTTP" call gets the statistics from my application, which is accessible via `https://verifiedbsky.net/stats`. The advantage of this is that it is available without authentication because the website needs it and it makes a call to the persistence layer, so I know that one works as well. To achieve this, the `URI` in the step is set to `https://verifiedbsky.net/stats` and the `Method` is set to `GET`. 

Now for the only slightly complicated thing: If the previous steps work, I want nothing to happen. But if the HTTP call runs into some kind of problem, I want an email notification. I used the "Send an email (V2)" action for this, configuring it with my email as `To` and a simple `Subject` and `Body` to let me know that something happened. To make sure this only happens in case of problems, I configured it like this

![a screenshot showing that the Send an email step will only run in case of a timeout, skip or failure of the HTTP step](images/verifiedbsky-http-issues.png)
{: .centered}

With this configuration, I get an email if something goes wrong, but not otherwise.

## The details: The data backup flow

The data backup flow is even simpler

![shows a Power Automate flow with a "Recurrence" step and an "Uplodad file from URL" step](images/verifiedbsky-backup.png)
{: .centered}

The "Recurrence" step this time has an `Interval` of `12` and a `Frequency` of `Hour`, so this runs twice a day. I set the `Start time` to `2025-01-19T09:00:00.000Z`, so this ran at 9 am on Jan 19 2025 for the first time. The "Upload file from URL" step is linked to OneDrive. The `Source URL` is something like `https://verifiedbsky.net/admin/data/superSecretKey` with `superSecretKey` of course being more complicated in reality. The data persisted in my application is actually just a collection of information that is publicly available anyway, but I still wanted to protect it a bit. The `Destination File Path` is set to a folder and file on my OneDrive account and the `Advanced parameter` `Overwrite` is set to `Yes` so that I always push the latest to OneDrive. Because of OneDrive's version history, I can also go back to an earlier version in case anything goes wrong.

As I mentioned at the beginning, all of this is pretty simple, but I'm pretty happy with how it solved both of my problems, and I wanted to share it in case anyone out there is facing a similar challenge.

[verifiedbsky]: https://verifiedbsky.net/
[verifiedbskypost]: https://tobiasfenster.io/verifying-user-accounts-on-bluesky-with-a-wasm-spin-application
[flows]: https://learn.microsoft.com/en-us/power-automate/overview-cloud
[onedrive]: https://learn.microsoft.com/en-us/sharepoint/onedrive-overview