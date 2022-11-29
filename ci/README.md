# Go commands
In order to use the following go commands Docker must be running and Go must be installed on the machine (later, we'll provide commands for full docker-contained execution).

## unit_tests
```bash
cd ci/core_unit_tests
go run main.go
```
Runs Core tests defined in `core/tests`.

## format
```bash
cd ci/format
go run main.go
```
Checks the format of the code for Core and its tests following the format rules in `core/.clangformat`.

```bash
cd ci/format
go run main.go --apply-changes
```
Modifies the code so it complies with the format rules.
