;Description
This template allows you to clear the left side, right side, or both sides of the page. Clearing means that the content following the template will not be displayed until the existing content on the specified sides (for example, "hanging" or floating images or blocks) is displayed completely. This template is often used so that the text does not flow around unrelated images.

The template adds the following code to the page: <code><nowiki><div style="clear:left/right/both;"></div></nowiki></code> (the value after <code>clear</code> depends on the parameters). This code affects elements with the CSS property <code>float</code>, including files floated to the side (for example, <code><nowiki>[[File:Image.png|right]]</nowiki></code>).

;Syntax
* To clear both sides of the page, add the code {{t|Clear}}.
* To clear only the left side of the page, add the code {{t|Clear|left}}.
* To clear only the right side of the page, add the code {{t|Clear|right}}.

You can also use {{t|-}} instead of {{t|Clear}} as a shorthand call for this template.
__NOTOC__
;Example 
<pre style="display:table">

=== Section 1 ===
[[File:Example.jpg|200px|right]]
Section 1 text.

=== Section 2 ===
Section 2 text.
{{Clear|right}}

=== Section 3 ===
Section 3 text.
</pre>

This code produces the following result:

----

=== Section 1 ===
[[File:Example.jpg|200px|right]]
Section 1 text.

=== Section 2 ===
Section 2 text.
{{Clear|right}}

=== Section 3 ===
Section 3 text.

----

As you can see above, the example image added in section 1 is displayed to the right and extends down through section 2, while the {{t|Clear}} template is called at the end of the second section, resulting in the example image not being next to section 3. Thus, one use of the {{t|Clear}} template is to control which elements are displayed next to which other elements.

== See also ==
* [https://developer.mozilla.org/en-US/docs/Web/CSS/clear CSS property <code>clear</code> on MDN]
* [https://developer.mozilla.org/en-US/docs/Web/CSS/float CSS property <code>float</code> on MDN]

<includeonly>[[Category:General wiki templates]]</includeonly><noinclude>[[Category:Template documentation]]</noinclude>