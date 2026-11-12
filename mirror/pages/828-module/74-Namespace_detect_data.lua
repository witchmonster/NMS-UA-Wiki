-- This Module is used for making templates based in the Lua language.
-- See more details about Lua in [[w:Help:Lua]].
-- The Fandom Developer's Wiki hosts Global Lua Modules that can be imported and locally overridden.
-- The next line imports from the [[w:c:dev:Global Lua Modules]].
local nsData = require('Dev:Namespace_detect/data')
-- See more details about this module at [[w:c:dev:Global_Lua_Modules/Namespace_detect]]
 
-- The imported Module is overwritten locally to include default configuration.
-- For a more flexible experience, delete the page import 
-- and paste (and modify as you like) its contents into this page
-- https://dev.fandom.com/wiki/Module:Namespace_detect/data

-- The last line produces the output for the template
return nsData