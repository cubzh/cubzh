# Build instructions

Note: this is a work in progress.

## C++ compilation

### Warnings

Clang is the main C/C++ compiler used in the project. 

We use the following warning flags with the C++ compiler:

- `-Wall`: Enable all common warnings
- `-Wshadow`: Warn when a variable declaration shadows another
- `-Wdouble-promotion`: Warn about implicit conversions from float to double
- `-Wundef`: Warn if an undefined macro is used in an #if directive
- `-Wconversion`: Warn about implicit type conversions

In the CI, we treat all warnings as errors, using the `-Werror` flag.

Clang reference doc for warnings flags: https://releases.llvm.org/18.1.4/tools/clang/docs/DiagnosticsReference.html
