---
layout: post
title: "An update on AL interfaces: implementation details"
permalink: an-update-on-al-interfaces-implementation-details
date: 2020-03-30 20:24:09
comments: false
description: "An update on AL interfaces: implementation details"
keywords: ""
categories:
image: /images/interfaces.gif

tags:

---

I recently [wrote update the new AL language feature interfaces][old-blog], coming with Business Central 2020 release wave 1 (a.k.a. BC 16). While I really liked what I saw at that point, I had to guess a bit about the actual implementation and usage of that new feature. Fortunately Stefano Demiliani pointed out in a [recent blog post][stefano] that Microsoft is using interfaces in their re-implementation of the price calculation in BC 16, so I went and looked at how it is done and then updated my sample. 

## The TL;DR
The important basics are:
- You don't call the Codeunits with the actual code directly, but instead you use a variable of the interface type. A management Codeunit has to make the decision which implementation is used, based e.g. on some logic, data or external influences. Assuming that we have a "blue" and a "red" implementation, the flow could look like this where the caller asks the management Codeunit for the implementation, in that case get's blue as answer and then calls the actual code through the interface:
![interface-flow](/images/interfaces.gif)
{: .centered}
- In order to add a new implementation, you extend the enum which is backing the implementation selection and make sure that the management Codeunit is able to select your implementation. The easiest way to achieve that could be a setup table as seen in my sample below.

Microsoft has started to use interfaces and I hope they'll spread this across the base application and maybe even add more of the programming constructs of object-oriented languages (I was rooting for something like interfaces [for a long time][issue]). BC for sure is in a very good place right now with a very good SaaS offering, a strong hybrid story and a modern toolset, so hopefully Microsoft builds on that rock solid foundation and improves it even further!

## The details: Implementing and using the interface
You can find the full sources as multi-root workspace [here][github], but let's walk quickly through the more interesting parts: The interface itself and the code in the base implementation look very similar to what I had in my previous post on that topic ([InterfaceAndImpl.al][InterfaceAndImpl]):

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
{% endhighlight %}

The handler enum stores the implementations and a setup table with a trivial page holds the currently active one. Again, the selection could be something a lot more complicated, but for demo purposes, I think this should be enough to get the idea ([InterfaceAndImpl.al][InterfaceAndImpl]):

{% highlight c# linenos %}
enum 50100 "SportsEvaluation Handler" implements ISportsEvaluation
{
    Extensible = true;
    value(0; Basketball)
    {
        Implementation = ISportsEvaluation = Basketball;
    }
    value(1; Tennis)
    {
        Implementation = ISportsEvaluation = Tennis;
    }
}

table 50100 "SportsEvaluation Setup"
{
    DataClassification = CustomerContent;

    fields
    {
        field(1; Implementation; Enum "SportsEvaluation Handler")
        {
            DataClassification = CustomerContent;

        }
    }
}

page 50100 "SportsEvaluation Setup"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "SportsEvaluation Setup";

    layout
    {
        area(Content)
        {
            group("Implementation Setup")
            {
                field(Implementation; Implementation)
                {
                    ApplicationArea = All;

                }
            }
        }
    }
}
{% endhighlight %}

As I mentioned before, with interfaces we no longer directly call the implementing Codeunits but instead have a management Codeunit with a `GetHandler` procedure which gets a var of the interface and selects the right implementing Codeunit. In my case, it just checks the setup table and defines Basketball as fallback if nothing is defined. Of course, this could also throw an error to make sure that something is set up, but if I can help anyone to make a decision for Basketball (the greatest indoor sport), I don't want to miss that opportunity ([InterfaceAndImpl.al][InterfaceAndImpl]):

{% highlight c# linenos %}
codeunit 50102 "SportsEvaluation Mgmt"
{
    procedure GetHandler(var SportsEvaluation: Interface ISportsEvaluation)
    var
        SportsEvaluationSetup: Record "SportsEvaluation Setup";
        SportsEvaluationHandler: Enum "SportsEvaluation Handler";
    begin
        SportsEvaluationSetup.Reset();
        if (SportsEvaluationSetup.FindFirst()) then
            SportsEvaluation := SportsEvaluationSetup.Implementation
        else
            SportsEvaluation := SportsEvaluationHandler::Basketball;
    end;
}
{% endhighlight %}

With that in place, the actual usage gets very easy: We just get the right implementation through the `GetHandler` procedure and then call the actual code through the interface variable, in this case `SportsEvaluation.GetEvaluation()`. So where we previously might have had some switch statement with all implementing Codeunits as variables, it now is as easy as lines 16 and 17 ([Usage.al][Usage]):

{% highlight c# linenos %}
pageextension 50100 CustPageExt extends "Customer List"
{
    actions
    {
        addfirst(General)
        {
            action(SportsEvaluation)
            {
                ApplicationArea = All;
                Promoted = true;
                PromotedOnly = true;
                PromotedIsBig = true;

                trigger OnAction()
                begin
                    SportsEvaluationMgmt.GetHandler(SportsEvaluation);
                    Message(SportsEvaluation.GetEvaluation());
                end;
            }
        }
    }

    var
        SportsEvaluation: Interface ISportsEvaluation;
        SportsEvaluationMgmt: Codeunit "SportsEvaluation Mgmt";
}
{% endhighlight %}

If you want to give it a try, just deploy the base implementation app, select the sport you want to use on the setup page and then call the action on the Customer list. Depending on your setup, it will show the right sport

![interface-base](/images/interface-base.gif)
{: .centered}

## The details: Adding an additional implementation
Now what if we want to add an additional implementation? That actually is quite elegant and very easy. Of course our new app needs to take a dependency on the existing app in app.json, so that it know about the interface and the handler enum ([second app.json][app2])

{% highlight json linenos %}
{
  ...
  "dependencies": [
    ...
    {
      "id": "ce467c0a-f59b-4b42-b07e-a17140a300af",
      "name": "SportsEvaluation",
      "publisher": "COSMO CONSULT - Tobias Fenster",
      "version": "1.0.0.0"
    }
  ],
  ...
}
{% endhighlight %}

The rest is straight forward: We define a new Codeunit which adds one more implementation of our interface and we extend the handler enum so that it knows about the new Codeunit ([AdditionalImpl.al][AdditionalImpl]). 

{% highlight c# linenos %}
codeunit 50103 Soccer implements ISportsEvaluation
{
    procedure GetEvaluation(): Text;
    begin
        exit('Soccer sucks');
    end;
}

enumextension 50110 AddSoccer extends "SportsEvaluation Handler"
{
    value(50110; Soccer)
    {
        Implementation = ISportsEvaluation = Soccer;
    }
}
{% endhighlight %}

As our setup page shows the enum, we can directly select the new implementation. Therefore, directly after deploying the `Additional Implementation` app, you should see the new option appear on the setup page and when you select it, the action uses the new code:

![interface-additional](/images/interface-additional.gif)
{: .centered}

While you might disagree with my taste in sports, I hope you agree that this indeed is a very big step forward towards a programming language that allows to think about architecture and structure in much better ways and also to adjust the behavior of the application in a much more stable way. Keep the new features coming, Microsoft!

[old-blog]: https://tobiasfenster.io/interfaces-in-al-and-why-that-matters
[stefano]: https://demiliani.com/2020/02/28/dynamics-365-business-central-2020-wave-1-price-management-with-interfaces/
[issue]: https://github.com/microsoft/AL/issues/1735
[github]: https://github.com/cosmoconsult/bc16-interface-sample
[AdditionalImpl]: https://github.com/cosmoconsult/bc16-interface-sample/blob/master/AdditionalImpl/AdditionalImpl.al
[app2]: https://github.com/cosmoconsult/bc16-interface-sample/blob/master/AdditionalImpl/app.json
[Usage]: https://github.com/cosmoconsult/bc16-interface-sample/blob/master/BaseImpl/Usage.al
[InterfaceAndImpl]: https://github.com/cosmoconsult/bc16-interface-sample/blob/master/BaseImpl/InterfaceAndImpl.al