{{t|Dialogue}} facilitates the writing of dialogue in a standard format.  The template can handle most standard formats of writing dialogue, and can be indented, bulleted or numbered. '''This template ''cannot'' be <code>subst:</code>'d'''.

This template uses the [[w:Help:Lua|Lua templating language]], and more information can be found [[w:c:dev:Global_Lua_Modules/Dialogue|on the Global Lua Module page]]. '''For a traditional wikitext version of this template, see [[w:c:templates:Template:Dialogue/wikitext|Dialogue on Templates Wiki]]'''.

==Syntax==
This is how to write the template in [[w:Help:wikitext|wikitext]] onto your article:

<pre>{{dialogue
|short=full
|short=full
|short=full
...
|Character|Speech
|Character|Speech
|Character|Speech
...
|cite = dialogue description
}}</pre>

These parameters are explained more fully below.

==Parameters==
'''Named parameters specify name shortcuts. They are all optional.''' They are placed at the top of the template call, like this:

<pre>{{dialogue
|short=full
|short=full
|short=full
...</pre>

Name shortcuts apply to your main dialogue text. If you use a shortcut specified here for a character name, then the full name will be replaced for it.

Named parameters of the form "<code>mood1</code>", "<code>mood2</code>", "<code>mood3</code>", etc., up to "<code>mood10</code>", specify moods for the corresponding line number (e.g. "<code>mood1</code>" specifies line 1). They are placed in a line like this:

<pre>...
|Character|Speech|mood1=angry
|Character|Speech|mood2=quiet
|Character|Speech|mood3=ecstatic
...</pre>

Positional parameters form the text of the dialogue (i.e. any line not containing an "<code>=</code>" will be construed as part of the dialogue.

:;<code>Parameter 1</code> ''(required)'' : Character name speaking
:;<code>Parameter 2</code> ''(optional)'' : Line to speak
:;<code>Parameter 3</code> ''(optional)'' : Next character
:;<code>Parameter 4</code> ''(optional)'' : Next line
:;<code>Parameter 5</code> ''(optional)'' : Next character
:;<code>Parameter 6</code> ''(optional)'' : Next line
:;<code>Parameter 7</code> ''(optional)'' : so on...

Note: if any character is called "<code>action</code>" then that line will be construed as an action line. It still counts as a ''line'' nonetheless.

To write a dialogue description/source, use <code>cite =</code>

==Examples==
Here is an example of a full template usage:

<pre>{{dialogue
|harry=Harry Enfield
|bryan=Bryan Adams

|harry|Hello!                |mood1=happy
|bryan|Oh hello there        |mood2=surprised
|harry|How are you?          |mood3=inquisitive
|bryan|Quite fine thank you. |mood4=reserved
|harry|Oh that's spiffing.   |mood5=spiffed
|bryan|It is, isn't it?!     |mood6=multo-spiffed
|harry|Quite so.             |mood7=bored
|bryan|Well, I'm off!        |mood8=joyous
|harry|Ta-ta!                |mood9=relieved
|bryan|Au revoir!            |mood10=sarcastic
}}</pre>

The above would generate:

{{dialogue
|harry=Harry Enfield
|bryan=Bryan Adams

|harry|Hello!                |mood1=happy
|bryan|Oh hello there        |mood2=surprised
|harry|How are you?          |mood3=inquisitive
|bryan|Quite fine thank you. |mood4=reserved
|harry|Oh that's spiffing.   |mood5=spiffed
|bryan|It is, isn't it?!     |mood6=multo-spiffed
|harry|Quite so.             |mood7=bored
|bryan|Well, I'm off!        |mood8=joyous
|harry|Ta-ta!                |mood9=relieved
|bryan|Au revoir!            |mood10=sarcastic
}}

The below code demonstrates examples of extended use:

<pre>{{dialogue
|george=Georgie Boy
|rachel=Rachel

|action|Enter: George and Rachel
|george|Good morrow dearest Rachel!|mood2=happy
|action|Rachel turns to see him
|rachel|Oh, George, it's you!
|george|...
|rachel|Why won't you say anything?!|mood6=worried
|action|Enter: Guards
|Guards|We are announcing George's arrest!
|rachel|Oh my!|mood9=horrified
|action|George is dragged away.
}}</pre>

The above would generate:

{{dialogue
|george=Georgie Boy
|rachel=Rachel

|action|Enter: George and Rachel
|george|Good morrow dearest Rachel!|mood2=happy
|action|Rachel turns to see him
|rachel|Oh, George, it's you!
|george|...
|rachel|Why won't you say anything?!|mood6=worried
|action|Enter: Guards
|Guards|We are announcing George's arrest!
|rachel|Oh my!|mood9=horrified
|action|George is dragged away.
}}

===Notes===

You can number, bullet or indent your dialogue:

<pre>:{{dialogue|Me|Hello|You|Howdido!}}</pre>

:{{dialogue|Me|Hello|You|Howdido!}}

<pre>#{{dialogue|Me|Hello|You|Howdido!}}
#{{dialogue|Them|Good afternoon|Us|What a load of rubbish!}}</pre>

#{{dialogue|Me|Hello|You|Howdido!}}
#{{dialogue|Them|Good afternoon|Us|What a load of rubbish!}}

<pre>*{{dialogue
|angel=Fortitude
|angel|I am an angel!|Crowd|We don't believe you!}}
*{{dialogue
|angel=Fortitude
|angel|But I'm being quite serious!|Crowd|Too bad for you then!}}</pre>

*{{dialogue
|angel=Fortitude
|angel|I am an angel!|Crowd|We don't believe you!}}
*{{dialogue
|angel=Fortitude
|angel|But I'm being quite serious!|Crowd|Too bad for you then!}}

You will get the odd spacing error (e.g. "Speech<code><nowiki><space></nowiki></code>") if you lay out your dialogue on multiple lines.

<includeonly>[[Category:Quote templates]]</includeonly><noinclude>[[Category:Template documentation]]</noinclude>