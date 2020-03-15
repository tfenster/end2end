---
layout: post
title: "Interfaces in AL and why that matters"
permalink: interfaces-in-al-and-why-that-matters
date: 2020-02-01 21:59:56
comments: false
description: "Interfaces in AL and why that matters"
keywords: ""
categories:
image: /images/interfaces.jpg

tags:

---

While NAV TechDays 2019 was an amazing conference with a lot of highlights and interesting news, one to me clearly stood out: The [announcement][techdays] that Business Central will get interfaces as part of the AL programming language. I was very happy about that, as my immediate reaction shows:

<blockquote class="twitter-tweet" data-partner="tweetdeck"><p lang="en" dir="ltr">INTERFACES! <a href="https://twitter.com/hashtag/msdyn365bc?src=hash&amp;ref_src=twsrc%5Etfw">#msdyn365bc</a> will get INTERFACES. Finally a language construct that allows thinking about an extensible application architecture 🎉 🎉 (sorry to event fans, but events are events, not a reasonable extensibility mechanism) <a href="https://t.co/igp1qNrEVt">pic.twitter.com/igp1qNrEVt</a></p>&mdash; Tobias Fenster (@tobiasfenster) <a href="https://twitter.com/tobiasfenster/status/1197449630813999104?ref_src=twsrc%5Etfw">November 21, 2019</a></blockquote>
<script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

## What does it look like?
While this was in the "From the lab" part of the keynote delivered by Vincent Nicolas, which always comes with the disclaimer that the content might actually not make it into the product, it now also is in the [2020 Release Wave 1 release notes][release-notes], so it chances are good that we actually will see this appear in the product. And indeed, if you have access to the insider Docker images of Business Central, you can already give it a try, e.g. like this:

{% highlight c# linenos %}
interface ISportsEvaluation
{
    procedure GetEvaluation(): Text;
}

codeunit 50100 Basketball implements ISportsEvaluation
{
    procedure GetEvaluation(): Text;
    begin
        exit('Basketball is cool');
    end;
}

codeunit 50101 Tennis implements ISportsEvaluation
{
    procedure GetEvaluation(): Text;
    begin
        exit('Tennis is fun');
    end;
}

codeunit 50102 Soccer implements ISportsEvaluation
{
    procedure GetEvaluation(): Text;
    begin
        exit('Soccer sucks');
    end;
}

codeunit 50103 Evaluation
{
    local procedure Evaluate(var se: interface ISportsEvaluation)
    begin
        se.GetEvaluation();
    end;
}
{% endhighlight %}

As you can see, in the beginning a new interface `ISportsEvaluation` is defined and it has a single procedure `GetEvaluation` (lines 1-4). Note that only the name, parameters, return type and visibility of the procedure is defined, but not the actual code. Then three codeunits are defined which implement `ISportsEvaluation` (lines 6-28), which means they need to add actual code for the `GetEvaluation` procedure. And then in the end you see an additional codeunit which defines a procedure that gets a `ISportsEvaluation` as parameter (lines 30-36). Using that, it can contain code that just calls the `GetEvaluation` method and will get the right implementation, depending on the codeunit that was passed in. The interface construct in AL also supports implementing multiple interface, e.g. like this:

{% highlight c# linenos %}
interface ISportsEvaluation
{
    procedure GetEvaluation(): Text;
}

interface IBallColorIdentifier
{
    procedure GetBallColor(): Text;
}

codeunit 50100 Basketball implements ISportsEvaluation, IBallColorIdentifier
{
    procedure GetEvaluation(): Text;
    begin
        exit('Basketball is cool');
    end;

    procedure GetBallColor(): Text;
    begin
        exit('orange/brown');
    end;
}

codeunit 50101 Tennis implements ISportsEvaluation, IBallColorIdentifier
{
    procedure GetEvaluation(): Text;
    begin
        exit('Tennis is fun');
    end;

    procedure GetBallColor(): Text;
    begin
        exit('yellow');
    end;
}

codeunit 50102 Soccer implements ISportsEvaluation, IBallColorIdentifier
{
    procedure GetEvaluation(): Text;
    begin
        exit('Soccer sucks');
    end;

    procedure GetBallColor(): Text;
    begin
        exit('black/white');
    end;
}

codeunit 50103 Evaluation
{
    local procedure Evaluate(var se: interface ISportsEvaluation)
    begin
        se.GetEvaluation();
    end;

    local procedure GetBallColor(var bc: interface IBallColorIdentifier)
    begin
        bc.GetBallColor();
    end;
}
{% endhighlight %}
Now there is a new interface `IBallColorIdentifier` (lines 6-9) which defines the procedure `GetBallColor` and is implemented by all `ISportsEvaluation` codeunits as well. 

## Extendable enumerations, powered by interfaces
Pretty nice, but why does it actually matter? Microsoft has already provided one scenario and that is an extendable enumeration. Let's assume that we have an enum for ball colors:

{% highlight c# linenos %}
enum 50100 BallColors
{
    value(0; Tennis)
    {
    }

    value(1; Basketball)
    {
    }

    value(2; Soccer)
    {
    }
}
{% endhighlight %}

Usually this results in case statements like this:

{% highlight c# linenos %}
local procedure IdentifyBallColor(var ballColor: enum BallColors): Text
var
    colorText: Text;
begin
    case ballColor of
        BallColors::Tennis:
            colorText := 'yellow';
        BallColors::Basketball:
            colorText := 'orange/brown';
        BallColors::Soccer:
            colorText := 'black/white';
        else
            colorText := 'unknown';
    end;

    exit(colorText);
end;
{% endhighlight %}

This is a) ugly and b) very problematic if you want to add additional ball colors in another extension because the `IdentifyBallColor` procedure will always return "unknown" for anything other than Tennis, Basketball and Soccer. The idea introduced at TechDays now is to make an enum extensible and defining which interface the enum elements need to implement. So to make use of our `IBallColorIdentifier` interface and the codeunits we already have in place, we would do something like this:

{% highlight c# linenos %}
enum 50100 BallColors implements IBallColorIdentifier
{
    Extensible = true;
    value(0; Tennis)
    {
        Implementation = IBallColorIdentifier = Tennis;
    }

    value(1; Basketball)
    {
        Implementation = IBallColorIdentifier = Basketball;
    }

    value(2; Soccer)
    {
        Implementation = IBallColorIdentifier = Soccer;
    }
}
{% endhighlight %}

You can see the definition of the implementing codeunits for every enum element in lines 6, 11 and 16. As a result we can rewrite the `IdentifyBallColor` procedure in a much better way:

{% highlight c# linenos %}
local procedure IdentifyBallColor(var ballColor: enum BallColors): Text
var
    colorText: Text;
    identifier: interface IBallColorIdentifier;
begin
    identifier := ballColor;
    exit(identifier.GetBallColor());
end;
{% endhighlight %}

In my opinion it would be nice if we wouldn't need to do the cast-like thing in line 6, but still it is a dramatic improvement. It follows the strategy design pattern, one of the patterns introduced in the "bible" of design patterns, a book simply called "Design Patterns" from the early nineties authored by the "Gang of Four"[^2]. I am old enough to have read this book while it was quite new, but I think it still is an extremely valuable read for any developer and very good to see BC / AL taking up more of the principles from that book. But how does this help with extending the enum? The following sample shows you how you can just add a new enum element in a different extension, including the implementation for the interface and our fantastic new `IdentifyBallColor` procedure will continue to work:

{% highlight c# linenos %}
enumextension 50100 FootballColor extends BallColors
{
    value(3; Football)
    {
        Implementation = IBallColorIdentifier = Football;
    }
}

codeunit 50100 Football implements IBallColorIdentifier
{
    procedure GetBallColorIdentifier(): Text;
    begin
        exit('brown');
    end;
}
{% endhighlight %}

Also note how this allows to extend the enum but not actually modify the behavior (or strategy) of the existing enum elements. That also is a design principle which helps to build trust but I am curious to see whether Microsoft will provide additional mechanisms to overcome that limitation (if you consider it a limitation) as well.

## Is that all?
We've heard Microsoft talk a lot about "componentization" of the base app. I think that makes a ton sense and if you look outside of the BC universe, it is very clear that old-school monoliths are not the best way to go[^1]. Principles like separation of concerns can be followed a lot easier if you have a solid component model. However in order to componentize your code base, you need to have a good, stable and reliable mechanism to define and use a component. While there are different ways to tackle that problem, it is one of the basic principles that a component is something with a clearly defined interface, i.e. the functions or procedures of a component are defined including their input parameters and return value. If you look at the way AL interfaces are constructed, that works fine. E.g. a component for using a number sequence could have an interface `INumberSequence` like this (you can see where this comes from, just a bit simplified)

{% highlight c# linenos %}
interface INumberSequence
{
    procedure Current(Name: String): BigInteger;
    procedure Next(Name: String): BigInteger;
}
{% endhighlight %}

This actually is way more important to me than the extendable enums! While those are sure interesting and solve real life problems, the introduction of a real componentization model has a lot broader consequences because as already mentioned now you can really start to componentize and think about application architecture and then the next step is the ability to replace components, which also is a very important point when discussing the future of Business Central. While the existing extension model solves a lot of problems, it clearly has limitations in other areas, like the inability to replace code. I know there is the "handled" pattern, but it relies on the existence of the right events and more importantly it relies on developers adhering to the conventions of that pattern with no real way to enforce it. I don't like that approach even if you have all developers inside of the same company, but when you start to think of 3rd-party extensions running side by side in one tenant, I really doubt that it will work reliably. Fortunately with interfaces we now have the beginnings of a better way to handle that.

The substitution of components can happen either at design time or at runtime. For design time in the Business Central world that could mean that you remove a codeunit which implements an interface and provide another codeunit implementing the same interface. While that is interesting and could be helpful when you think about redesigning or changing your solution, it still won't solve the problem to replace base code. However it could also happen dynamically during runtime. Currently I haven't seen anything how that might work, but if I let my imagination run wild, I could see something in the app.json file which defines the interfaces an extension wants to implement. Then maybe there could also be something to define whether implementation is mandatory and needs to replace other implementations or is optional and the extension would also work with other implementations. That could then also be considered by the Business Central server as a factor whether an extension can be installed or not. Again, just me imagining things, but lets assume we have a our `INumberSequence` interface, then an extension could maybe do something like this to replace the current implementation:

{% highlight json linenos %}
{
  "id": "3c43035b-3f7e-4b42-b293-c8cf80d1cf98",
  "name": "MyExtension",
  ...
  "dependencies": [
    ...
  ],
  "interfaces": [
    {
      "name": "INumberSequence",
      "implementationMode": "mandatory"  
    }
  ]
}
{% endhighlight %}

Now if some code wants to get a number sequence, it would just ask the platform for the current implementation of the `INumberSequence` interface and use that. If the default is still in place, that is used and if some extension has replaced it, the replacement is used. This would also require some kind of dependency injection mechanism, but that also is something that becomes possible now that we have interfaces! Maybe it could be something like this:

{% highlight c# linenos %}
local procedure CreateInvoice()
var
    numberSequence: inject interface INumberSequence;
    nextNumber: BigInteger;
begin
    ...
    nextNumber := numberSequence.Next('mySequence');
    ...
end;
{% endhighlight %}

Overall, I am still very happy to once again see Microsoft invest into the future of Business Central, in this case by making AL a stronger language that allows us to build better software. I can't wait to see how far and in which direction they take interfaces and the various scenarios that are now enabled.

[^1]: There is a bit of a pushback for microservice architectures as some have found it difficult to handle the added complexity in some scenarios, but all successful modern programming languages have some kind of a component model
[^2]: including Erich Gamma, on of the persons responsible for VS Code

[techdays]: https://www.youtube.com/watch?v=pl0LAvep6WE&list=PLI1l3dMI8xlCkFC0S4q8VxPiBt30VQ4w0&index=2&t=4644s
[release-notes]: https://docs.microsoft.com/en-us/dynamics365-release-plan/2020wave1/dynamics365-business-central/al-interfaces