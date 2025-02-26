# Cubzh modules

The documentation for modules is generated from module script annotations and published here: https://docs.cu.bzh/modules

## Check code format

```sh
stylua --check --glob *.lua
if [ $? -eq 0 ]; then
    echo "✅ Code formatting is correct"
else
    echo "❌ Code formatting issues found - please run 'stylua --glob *.lua' to fix"
fi
```

## Perform code formatting

```sh
stylua --glob *.lua
```
