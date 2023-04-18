## Modules

A module is a script that can be loaded with `require` function:

```lua
-- uikit is a module that can be used to build user interfaces.
-- Here's how you can use it to display a button:
uikit = require("uikit")
local btn = uikit:createButton("this is a button")
btn.onRelease = function() print("clicked") end
```

**Modules follow simple rules:**

- When required, a module returns a single table
- Global variables can't be defined within modules (only local ones)
- When a module is required several times, the returned table is always the exact same reference (script is only parsed once)

## Docs

The documentation for modules is generated from module script annotations and published here: https://docs.cu.bzh/modules

## Roadmap

Modules in that directory are bundled with the application, they can be required in any script. 

At some point, we want to introduce community made modules, published from within the app just like items and world scripts. But we still need time to validate the design and define how we want to handle distribution. Modules are very helpful and we would like authors to be properly rewarded their scripts become essential pieces of other programs.

