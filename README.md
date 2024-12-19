CMake scripts and patches to build dav1d, libass and other projects used in FFmpeg build script [avbuild](https://github.com/wang-bin/avbuild) and other projects

Build steps can be found in [github actions](https://github.com/wang-bin/devpkgs/actions/workflows/build.yml). harfbuzz hb-ft.h is required by FFmpeg, [more steps are required](https://github.com/wang-bin/devpkgs/actions/workflows/no-lto.yml). Prebuilt binaries can be found in ci artifacts: [static libs w/o LTO](https://nightly.link/wang-bin/devpkgs/workflows/no-lto/main) and [LTO enabled shared libs](https://nightly.link/wang-bin/devpkgs/workflows/build/main)

[libmdk-dep/dep.7z](https://nightly.link/wang-bin/devpkgs/workflows/build/main/libmdk-dep.zip) contains runtime (dynamic) binaries and libs I used to build [libmdk](https://github.com/wang-bin/mdk-sdk). [libmdk-dep/dep-av.7z](https://nightly.link/wang-bin/devpkgs/workflows/no-lto/main) contains some libs used by avbuild

## Cross Build
generate c headers for fribidi first(if not exists)

```
cmake -DFRIBIDI_GENTAB=1 -Bbuild -DCMAKE_BUILD_TYPE=${{ matrix.config }}
cmake --build build -t gen_tab
```

## MSVC ARM64 Build
dav1d and libass requires clang installed by visual studio. clang-cl is used to build arm64 asm
