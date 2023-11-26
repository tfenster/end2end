---
layout: post
title: "More Power to you: About equality in PowerShell and finding next Monday in Power Automate"
permalink: about-equality-and-finding-next-monday
date: 2023-11-26 15:32:43
comments: false
description: "More Power to you: About equality in PowerShell and finding next Monday in Power Automate"
keywords: ""
image: /images/power.png
categories:

tags:

---

Just two quick lessons I learned in the last few weeks:

## Lesson 1: Equal isn't equal in PowerShell when it comes to environment variables

This was an issue a colleague and I struggled with a while back when we couldn't figure out why a certain piece of conditional code wasn't running as we expected. The answer in the end was that a  `$null` equality check behaves differently between normal variables and environment variables. First consider this, which is what at least for me is the expected behavior:

{% highlight PowerShell linenos %}
PWSH C:\Users\tfenster> $test = ""
PWSH C:\Users\tfenster> $null -eq $test
False
{% endhighlight %}

But if we now do the same thing with an env variable, the behavior is different:

{% highlight PowerShell linenos %}
PWSH C:\Users\tfenster> $env:test = ""
PWSH C:\Users\tfenster> $null -eq $env:test
True
{% endhighlight %}

Of course, this also means that `if ($null -eq $test) ...` behaves differently than `if ($null -eq $env:test)`. Probably a lot of readers will say "dude, that's obvious", but it wasn't for me, and it took us a while to figure it out, so I wanted to share it.

## Lesson 2: Finding next Monday is not that hard (or ugly)

On the second topic, I had to figure out how to get to "next Monday" (and "next Friday", but that is obvious when you have next Monday) in a Power Automate flow. As explained [here][task], I typically schedule the tasks of a week in advance, somewhere between Friday afternoon and Sunday evening. For this, I have a Power Automate flow that looks at my Planner and To-Do tasks for the next week and puts them in a calendar dedicated for tasks. I could do this by just manually setting "next Monday" as the start and "next Friday" as the end, but I really have a very low frustration tolerance for repetitive tasks, so I wanted it to be fully automated. But that meant I had to figure out how to get "next Monday" in a Power Automate flow. A little online searching led me to solutions like the following ([source][sample]):

{% highlight none linenos %}
if(equals(dayOfWeek(utcNow()),1),addDays(utcNow(),7),if(equals(dayOfWeek(utcNow()),2),addDays(utcNow(),6),if(equals(dayOfWeek(utcNow()),3),addDays(utcNow(),5),if(equals(dayOfWeek(utcNow()),4),addDays(utcNow(),4),if(equals(dayOfWeek(utcNow()),5),addDays(utcNow(),3),if(equals(dayOfWeek(utcNow()),6),addDays(utcNow(),2),if(equals(dayOfWeek(utcNow()),0),addDays(utcNow(),1),null)))))))
{% endhighlight %}

I'm usually fine with pragmatic solutions to development problems, but this really didn't seem acceptable, so I started thinking about it for a bit. What is the problem? We have the `addDays` function as documented [here][addDays] to add days to a date, `dayOfWeek` as documented [here][dayOfWeek] to get the current day of the week, `utcNow` as documented [here][utcNow] to get the current date and `sub` as documented [here][sub] to subtract two values. Theoretically, this is easy: On Monday, we need to add 7, on Tuesday we need to add 6 and so on until Sunday, where we need to add 1. Unfortunately, `dayOfWeek` returns 0 to 6 for Sunday to Saturday, not 0 to 6 for Monday to Sunday like other languages. If the latter were true, I could just do something like `addDays(utcNow(), sub(7,dayOfWeek(utcNow())))` which first subtracts the number of the current day of the week from 7 and adds that to the current date. For most days, we could do something similar, because we need something that translates 1 (Monday) to 7, 2 (Tuesday) to 6 and so on until we get to 6 (Saturday) to 2. This is also easy, `addDays(utcNow(), sub(8, dayOfWeek(utcNow())))`. Works fine, but Sunday = 0 needs to be translated to 1, which doesn't work here. 

Fortunately, we have another helper, the `mod` function as documented [here][mod]. It returns the remainder of the division of two numbers, so `mod(6,7)` returns 7 while `mod(7,7)` returns 0. This means that if we do `mod(sub(7,dayOfWeek(utcNow())),7)`, we get e.g. on Monday `mod(sub(7,1),7)`, which is `mod(6,7)` = 6. On Sunday, we have `mod(sub(7,0),7)`, which is `mod(7,7)`, which is 0. Remember, we needed Monday to translate to 7 all the way to Sunday to translate to 1. Now we have something to translate Monday to 6 all the way to translating Sunday to 0. This is an easy fix, we just need to add 1, so we end up with this beauty

{% highlight none linenos %}
add(mod(sub(7,dayOfWeek(utcNow())),7),1)
{% endhighlight %}

Maybe not exactly easier to understand than the endless if-else thing above, but I like it a lot more :)


[sample]: https://powerusers.microsoft.com/t5/Building-Flows/Take-current-date-and-display-date-of-forthcoming-Monday/m-p/196567/highlight/true#M20357
[task]: https://www.youtube.com/watch?t=1445&v=eoWS-0Fgo8w&feature=youtu.be
[addDays]: https://learn.microsoft.com/en-us/azure/logic-apps/workflow-definition-language-functions-reference#addDays
[dayOfWeek]: https://learn.microsoft.com/en-us/azure/logic-apps/workflow-definition-language-functions-reference#dayOfWeek
[utcNow]: https://learn.microsoft.com/en-us/azure/logic-apps/workflow-definition-language-functions-reference#utcNow
[sub]: https://learn.microsoft.com/en-us/azure/logic-apps/workflow-definition-language-functions-reference#sub
[mod]: https://learn.microsoft.com/en-us/azure/logic-apps/workflow-definition-language-functions-reference#mod