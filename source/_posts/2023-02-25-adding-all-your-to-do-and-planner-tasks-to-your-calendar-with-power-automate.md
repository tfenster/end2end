---
layout: post
title: "Adding all your To-Do and Planner tasks to your calendar with Power Automate"
permalink: adding-all-your-to-do-and-planner-tasks-to-your-calendar-with-power-automate
date: 2023-02-25 15:41:59
comments: false
description: "Adding all your To-Do and Planner tasks to your calendar with Power Automate"
keywords: ""
image: /images/planner-todo-outlook-automate.png
categories:

tags:

---

I am a bit (ok, probably a lot) of a task management fanatic. At the end of the week, I usually like to have an idea of my tasks for the next week and how they fit into my agenda. And task management actually works well in the Microsoft portfolio, for me mostly with [To-Do][todo] (my own stuff) and [Planner][planner] (company, team, projects). But what is currently a bit of a struggle is the integration with the [Microsoft 365][o365] (f.k.a. Office 365) calendar: There is a "My Day" / To Do view in the calendar - not that well documented, but you can find small pieces of it e.g. [here][my-day] - and you can [add your Planner tasks][planner-ics] to your calendar, but both integrations have severe issues as I explain below if you're interested. So for quite some time, I only planned the tasks for a specific day, but not directly in my calendar, but a colleague who asked me about the topic prompted me to try to fix it. Here is what I did:

## The TL;DR

I created a [Power Automate][automate] flow that collects all of my To-Do tasks and all of the Planner tasks assigned to me, checks to see if they are in a given timespan (e.g. "next week") and puts calendar entries into my calendar. They are scheduled early in the morning and for one hour, so I have to manually go through the week to set it up exactly how I want it with respect to whatever else is on my agenda, but since I am doing a "planning" session for the upcoming week anyway, this works well for me.

![tasks in the outlook calendar after importing with the flow](/images/tasks-in-calendar.png)
{: .centered}

If you want to use it for yourself, you can clone my GitHub repo [Task2Calendar][t2c], set up the required settings and publish the solution containing the flow into your environment manually or with the [Power Platform CLI][pac].

## The details: Why

There are two aspects to why: Why am I doing it, and why am I not using the options already available in the products?

I do it because, as I said, I am a task management fanatic, but for a long time I have struggled to find time for all the tasks I want to do in a week, even if I have planned which day to do it in advance. I usually think I can do more than I can... I am also very bad at [time-boxing][tb], but I am in the same boat as probably many others: I usually don't have enough time to do everything I want to - and need to - do, so to stay at least somewhat in control, I have to make sure I don't spend too much (more) time on any given task[^1]. What has helped me is to have a clear idea of a) how much time I want to spend on something and b) what else I won't be able to do if I spend more time on it. Last but not least, I sometimes put long blockers on my agenda to make sure I have time to work on different tasks. But when they are all more or less equally important (and interesting), I sometimes struggle to choose the first or next task. Putting my tasks into calendar items at least helps with all these problems.

So why don't I use the built-in features? In "classic" Outlook, there was an option to see your To-Do (and native Outlook) tasks below the days in the calendar, but that didn't include Planner tasks, and I haven't used classic Outlook in years. In modern Outlook, we have the aforementioned "My Day" flyout, but that again doesn't include Planner tasks. Also since recently, To-Do (finally) automatically shows tasks that are due on the current day in the "My day" list in To-Do, which is a great improvement for the way I work, but the "My day" view in Outlook doesn't show them. Somewhat similar is the Outlook integration for Planner, which almost works, but unfortunately not completely for me. As mentioned above, you can display your Planner tasks as an additional calendar on your Outlook calendar, but this has a big problem that makes it unusable for me: They're all-day events, so I can't really plan when and how much time I want to spend on them. And because it's a read-only calendar, I can't change it manually.

With my approach, I get all the tasks with direct links in the body of my calendar and I can move them around, plan the duration, etc. If I need someone else to help me with the task, I can invite them. By default, the tasks are marked as private (I really want to share my calendar with everyone in the company, but not necessarily all of my tasks) and they are marked as "free", so if someone is looking for a free slot in my agenda, these "task times" won't block it unless I manually choose to do so. The latter is especially important to me because I already don't have as much time as I'd like to talk to my colleagues, so anything that can make my calendar look less full is great. This might mean that a colleague sends a meeting request at a time when I had planned to work on an important task, but most likely it is more important to spend time with a colleague anyway, and if not, I still see it in my calendar and can suggest another time slot.

## The details: How it works
I must preface this with the fact that I am by no means a Power Automate expert. I have been using it more or less regularly over the past few years, but I may be doing things too complicated or circuitous. If you have ideas for improvements, please share them with me!

Here is what I did first, but the actual flow now already contains some optimizations for the issues mentioned in the next section:

- The flow is manually triggered and has three parameters: A start date, an end date, and a bool to remove existing task calendar entries.
- If existing calendar entries are to be deleted, the flow first gets all entries with a specific category, filters those in the given date range, and deletes them. The task calendar entries are automatically configured with this category and I don't use it manually, so the flow is sure to clean up all the right events.
- Then the flow gets all the todo lists and all the tasks in them, checks if they are in the given date range, and if so, creates a calendar entry with the name of the task as subject, marked as private, and marked as free. Since the category can't be set directly, I added another HTTP request to set the category for the created task. This wasn't my idea at all, but I found it in the great Power Automate Community Forum [here][pacf], shared by [Marco Marconetti][marco].
- Parallel to working on the to-do lists, the flow also gets all Planner tasks assigned to me, checks again if they are in the given date range and if so, also creates a calendar entry with the name of the task as subject, marked as private and marked as free. And as before, an additional HTTP request sets the category.

All of this went quite smoothly, except for some problems picking "body" or "value" from some of the generated responses. But overall, pretty good. As an aside, I think it would have taken me about the same amount of time to build the flow in C#, but that's probably just because I kind of know what I'm doing in C# and not in Automate.

## The details: Issues that came up, especially when I wanted to share with another tenant
After this initial state, I had a few issues:

- What if I wanted to run this automatically every Sunday, but maybe trigger it manually later? This is where the one and only [M365 Princess Luise Freese][luise] (owner of one of the greatest domain names, "raeuberleiterin.de", which unfortunately doesn't translate very well, but is hilarious in German) came to the rescue and introduced me to a concept called [child flows][child-flows]. With this you can have a "parent flow" that is scheduled to run every Sunday, in my case. But the flow doesn't actually do anything other than call the "child flow", which is the one I described above. This way, I can run the scheduled parent flow every Sunday, but also run the manual child flow whenever I need it.
- The O365 connector hard-coded the calendar ID, so when I tried to share it with the company tenant, it didn't work. Of course, I could fix it manually, but assuming I would be making more changes in the future, that would get pretty annoying pretty quickly. The first attempt to fix this was an environment variable, but then I also had to find the ID of the calendar and put it in manually, which didn't feel right either. But then I found out that you can send a `GET` request to `https://graph.microsoft.com/v1.0/me/calendar` to get your default calendar. In the result there is an `id` attribute, which I put into a variable `calendar-id` and just used it wherever the calendar ID is needed.

![Screenshot of getting the calendar id with a graph API call and storing it in a variable](/images/calendar-id.png)
{: .centered}

- The other issue when sharing with another tenant/environment was that the connections had unique IDs. Again, something that could be fixed manually, but again, very annoying. Once more, Luise helped me out by pointing me to two great blog posts by [Benedikt Bergmann][bb]: ["Connections and connection references explained"][bb1] and ["Setting connection references and environment variables in pipelines"][bb2]. With this information, I was able to set it up so that I could automate or at least script deployments to other tenants and environments.

Which leads right into:

## The details: Deployment to your tenant and environment
Here is what you need to do if you want to use the flow for yourself or just check how it is built:

- Clone my [repo][t2c]
- Get the [Power Platform Tools][ppt] VS Code extension and set up an auth profile
- Copy the `settings.json` file into something like `settings_<your environment>.json`
- Fill in the missing IDs of the connections in lines 6, 11 and 16 as explained in the [blog post mentioned above][bb2]
- Create an import task similar to the ones called "import to ars solvendi" and "import to 4PS" in `.vscode/tasks.json`, but make sure to use the names of your auth profile, environment and settings file. Assuming that your auth profile is called "CONTOSO", your environment is called "CONTOSO test" and the file is called "settings_contoso.json", this would look something like this
{% highlight json linenos %}
{
    "label": "import to Contoso",
    "type": "shell",
    "command": "pac auth select -n 'CONTOSO'; pac org select --environment 'CONTOSO test'; pac solution import -p Task2Calendarpublisher.zip --settings-file settings_contoso.json",
    "problemMatcher": []
},
{% endhighlight %}
- Run the task that you just created. The output should look something like
{% highlight bash linenos %}
*  Executing task: pac auth select -n 'ars solvendi'; pac org select --environment 'ars solvendi'; pac solution import -p Task2Calendarpublisher.zip --settings-file settings_ars-solvendi.json 

New default profile:
    * UNIVERSAL ars solvendi                   https://org737c47c4.crm4.dynamics.com/   : tobias.fenster@arssolvendi.onmicrosoft.com Public

Looking for environment 'ars solvendi'
Selected org 'ars solvendi (default)' 'https://org737c47c4.crm4.dynamics.com' for current authentication profile.
Connected to... ars solvendi (default)
Connected as tobias.fenster@arssolvendi.onmicrosoft.com
 
Solution Importing...

Solution Imported successfully.
{% endhighlight %}

Now you should have a new solution called "Task2Calendar publisher", including the scheduled parent flow and the manual child flow that you can just run directly.

I hope this helps some of you, either because you just want to use it or because you have the same issues I had.

[todo]: https://www.microsoft.com/en-us/microsoft-365/microsoft-to-do-list-app?rtc=1
[planner]: https://www.microsoft.com/en-us/microsoft-365/business/task-management-software
[o365]: https://www.microsoft.com/en-us/microsoft-365
[my-day]: https://support.microsoft.com/en-us/office/use-my-day-in-outlook-com-and-outlook-1ca75cf8-6bfb-4ccb-8efc-7ee5831aef8d
[planner-ics]: https://support.microsoft.com/en-us/office/see-your-planner-schedule-in-outlook-calendar-9f0eb699-cf2b-45be-a464-83f005d82547
[flow]: https://powerautomate.microsoft.com/en-us/
[t2c]: https://github.com/tfenster/Task2Calendar
[pac]: https://learn.microsoft.com/en-us/power-platform/developer/cli/introduction
[tb]: https://en.wikipedia.org/wiki/Timeboxing
[pacf]: https://powerusers.microsoft.com/t5/Building-Flows/Is-it-possible-to-set-Outlook-event-categories/m-p/1683742#M186730,
[marco]: https://powerusers.microsoft.com/t5/user/viewprofilepage/user-id/401725
[child-flows]: https://learn.microsoft.com/en-us/power-automate/create-child-flows
[luise]: https://www.m365princess.com/
[rl]: https://raeuberleiterin.de/
[bb]: https://benediktbergmann.eu
[bb1]: https://benediktbergmann.eu/2022/02/08/connections-and-connection-references-explained/
[bb2]: https://benediktbergmann.eu/2021/12/02/set-connection-references-and-environment-variables-in-pipelines/
[ppt]: https://marketplace.visualstudio.com/items?itemName=microsoft-IsvExpTools.powerplatform-vscode

[^1]: Not sure if this is a thing outside of Germany, but we do have "last words" jokes like "Last words of a butcher: Throw me the knife". Not very funny, I know, but the point is that the joke for developers is "Last words of a developer: I am almost done". This is unfortunately very true for me, sometimes I am almost physically unable to stop working on something until I think it is properly finished. Especially if it is an interesting technical topic...