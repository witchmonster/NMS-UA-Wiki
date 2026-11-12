<includeonly><infobox>
    <title source="name"><default>{{PAGENAME}}</default></title>
    <image source="image"><caption source="caption" /></image>
    <data><label>Born</label>
        <default>{{#if: {{{birthname|}}} | {{{birthname|}}} }}{{#if: {{{birthdate|}}} | {{#if: {{{birthname|}}} | <br />}}{{{birthdate|}}}{{#if: {{{birthplace|}}} | <br />}} }}{{#if: {{{birthplace|}}} | {{#if: {{{birthdate|}}} || {{#if: {{{birthname|}}}|<br />}} }}{{{birthplace|}}} }}</default>
    </data>
    <data><label>Died</label>
        <default>{{#if: {{{deathdate|}}} | {{{deathdate|}}} }}{{#if: {{{deathplace|}}} | {{#if: {{{deathdate|}}} | <br />}}{{{deathplace|}}} }}</default>
    </data>
    <data source="gender"><label>Gender</label></data>
    <data source="height"><label>Height</label></data>
    <data source="occupation"><label>Occupation</label></data>
    <data source="appears in"><label>Appears in</label></data>
    <data source="portrays"><label>Portrays</label></data>
</infobox>{{Namespace|main=[[Category:Cast]]<!--

-->{{#if: {{#pos:{{{appears in|}}} | TITLE}} | [[Category:TITLE cast]] }}<!--

-->}}</includeonly><noinclude>{{documentation}}</noinclude>