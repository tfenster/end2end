---
layout: post
title: "Vacation everywhere - how to keep track"
permalink: vacation-everywhere---how-to-keep-track
date: 2023-07-22 12:41:51
comments: false
description: "Vacation everywhere - how to keep track"
keywords: ""
image: /images/vacay.png
categories:

tags:

---

It's vacation time in Germany, so this will be a short, but topical blog post: How to keep track of the planned vacation of your team?

## The TL;DR

A manually maintained spreadsheet is a bit 2000s, and even a full-blown HR system can struggle here, especially if the people you are interested in don't necessarily follow the organizational structure of your company. In my case, it's our German organization, but also key people from our international organization. But we are all part of a team in Microsoft Teams, so I decided to use that to figure out who should be considered and also to use the calendar of that team to store the information. If you want to use it, you need an app registration with the right permissions and then you can use the code from [https://github.com/tfenster/vacation-calendar](https://github.com/tfenster/vacation-calendar). All you need to change is the app registration id, tenant id and group name in [Program.cs][prog]

{% highlight csharp linenos %}
var groupName = "4PS Deutschland";
...
var clientId = "bc6a5c42-f082-4b55-9a87-e765f30a1ba4";
var tenantId = "92f4dd01-f0ea-4b5f-97f2-505c2945189c";
{% endhighlight %}

Then you can just run it. It will ask you for authentication, get the group and all group members. Then it will go through the calendars of all group members, identify vacation entries by looking at the subjects and put copies into the calendar of the group.

## The details: Auth

To get authentication and authorization right, you need an [app registration][appreg]. You can either do that manually or use the great [CLI for Microsoft 365][m365-cli] and just run

{% highlight bash linenos %}
m365 aad app add --name 'Vacation calendar' --redirectUris 'http://localhost/' --platform publicClient \
--apisDelegated 'https://graph.microsoft.com/Group.ReadWrite.All,https://graph.microsoft.com/Calendars.ReadWrite.Shared,https://graph.microsoft.com/User.Read,https://graph.microsoft.com/User.Read.All,https://graph.microsoft.com/MailboxSettings.Read'
{% endhighlight %}

If you run the code natively on your laptop, a browser window should pop up, asking you to sign in. But if you run this in a [Github Codespace][gh-cs], this is isn't possible, so you will get a code that you can use in the devicelogin flow instead.

## The details: Interacting with M365

The interaction with Microsoft 365 was fairly straight forward, made even easier with the usage of the [Microsoft Graph client][graph]. It allows you to write code like this to create an event

{% highlight csharp linenos %}
await graphClient.Groups[groupId].Calendar.Events.PostAsync(new Event()
{
    Subject = $"{newEvent.Subject} ({newEvent.Organizer?.EmailAddress?.Name})",
    Start = newEvent.Start,
    End = newEvent.End,
});
{% endhighlight %}

or like this to get events one month back until six months in the future

{% highlight csharp linenos %}
var userEvents = await graphClient.Users[userId].Calendar.CalendarView.GetAsync(requestConfiguration =>
{
    requestConfiguration.QueryParameters.StartDateTime = DateTime.Now.AddMonths(-1).ToUniversalTime()
            .ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'");
    requestConfiguration.QueryParameters.EndDateTime = DateTime.Now.AddMonths(6).ToUniversalTime()
            .ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'");
    requestConfiguration.QueryParameters.Filter = vacationFilter;
});
{% endhighlight %}

You might have noticed the `vacationFilter` variable and I have hardcoded the German, English and Dutch words for vacation, which was good enough for me, but could easily be extended to a more flexible solution, maybe even including a call to a translation service

{% highlight csharp linenos %}
const string vacationFilter = "contains(subject,'Urlaub') or contains(subject,'Vacation') or contains(subject,'Vakatie') or contains(subject,'urlaub') or contains(subject,'vacation') or contains(subject,'vakatie')";
{% endhighlight %}

Overall, really not a very complicated piece of code, and not even a well-optimized piece of code, but it works well for us and provides great transparency into the planned vacations of the team members without anyone having to track and update anything. All the team members need to do is put an entry with the right subject into their calendar!

[prog]: https://github.com/tfenster/vacation-calendar/blob/main/Program.cs
[appreg]: https://learn.microsoft.com/en-us/azure/active-directory/develop/application-model
[m365-cli]: https://pnp.github.io/cli-microsoft365/
[gh-cs]: https://github.com/features/codespaces
[graph]: https://www.nuget.org/packages/Microsoft.Graph