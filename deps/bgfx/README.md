# Updating bgfx

1) In `common/bgfx`, remove the folders `bgfx`, `bimg`, and `bx` and all their content.
This is to ensure that any deleted file in the latest commit is also deleted on our end

2) Download latest commit and put them back in `common/bgfx`
- bgfx: https://github.com/bkaradzic/bgfx
- bimg: https://github.com/bkaradzic/bimg
- bx:   https://github.com/bkaradzic/bx

3) If necessary, to look at how the new project files are generated, use `make` in `bgfx/`
Doc: https://bkaradzic.github.io/bgfx/build.html

# Particubes patches

The following are PRs re-applying the patches necessary at their time:
https://github.com/voxowl/particubes-private/pull/991
https://github.com/voxowl/particubes-private/pull/1228
https://github.com/voxowl/particubes-private/pull/2414
https://github.com/voxowl/particubes-private/pull/2932
https://github.com/voxowl/particubes-private/pull/3991

## Bgfx-imgui context

These are necessary as long as we still use the bgfx-imgui context

### View declaration patch

To manage view ordering, `VXGameRenderer` declares all the views including the one used
for rendering UI. Therefore it is necessary to disable the view declaration in the
bgfx-imgui context

In `bgfx/examples/common/imgui/imgui.cpp ~l.74`, comment out anything related to declaring the view, for example:
```c
//// CUBZH: let VXGameRenderer declare that view so that it can work with sort order
/*
bgfx::setViewName(m_viewId, "ImGui");
bgfx::setViewMode(m_viewId, bgfx::ViewMode::Sequential);

const bgfx::Caps* caps = bgfx::getCaps();
{
	float ortho[16];
	bx::mtxOrtho(ortho, 0.0f, width, height, 0.0f, 0.0f, 1000.0f, 0.0f, caps->homogeneousDepth);
	bgfx::setViewTransform(m_viewId, nullptr, ortho);
	bgfx::setViewRect(m_viewId, 0, 0, uint16_t(width), uint16_t(height) );
}
*/
```

### Font injection patch

We want to inject our own font in the bgfx-imgui context

In `bgfx/examples/common/imgui/imgui.cpp ~l.359`, add the following line and comment out anything related to loading font that isn't necessary
```c
#include "VXFont.hpp"

...

//// CUBZH: inject font
vx::Font::shared()->loadFonts(&data, &width, &height);
```

### Mousewheel value

Check that `io.MouseWheel` receives a float directly, and not a delta

In `bgfx/examples/common/imgui/imgui.cpp ~l.538`, make sure the `imguiBeginFrame` signature takes a float for the `_scroll` parameter as well as `beginFrame`

In `bgfx/examples/common/imgui/imgui.cpp ~l.404`, make sure to set the `_scroll` value directly, instead of passing a delta
```c
io.MouseWheel = _scroll;
```

The `m_lastScroll` variable can be removed

### Delta time value

Make sure that `io.DeltaTime` is always strictly positive, since some asserts in dear-imgui/imgui.cpp check this value

In `bgfx/examples/common/imgui/imgui.cpp ~l.464`, after setting delta time:
```c
//// CUBZH: asserts in dear-imgui/imgui.cpp:ErrorCheckNewFrameSanityChecks() require a strictly positive dt
if (io.DeltaTime <= 0) {
	io.DeltaTime = .001f;
}
```

### Point sampler mode

In `bgfx/examples/common/imgui/imgui.cpp ~l.393`, make sure that `m_texture` is created using flags
`BGFX_TEXTURE_NONE|BGFX_SAMPLER_MIN_POINT|BGFX_SAMPLER_MAG_POINT`

### Custom glyphs parameters

Original PR adding 'colored' & 'scale' glyph parameters: https://github.com/voxowl/particubes-private/pull/4677

In `common/bgfx/bgfx/3rdparty/dear-imgui/imgui.h` and `common/bgfx/bgfx/3rdparty/dear-imgui/imgui_draw.cpp`,
- add 'float scale', 'bool colored' parameters to struct ImFontAtlasCustomRect
- add these parameters (default 1.0f & false) to AddCustomRectFontGlyph and ImFont.AddGlyph functions
- apply parameters inside AddGlyph function (scale x0/y0/x1/y1/advance_x)

### MVS compilation fix

Rename the bgfx backend for dear-imgui from `imgui.h/cpp` to `bgfx-imgui.h/cpp` to avoid conflicts when building with MVS with a file of the same name in dear-imgui.

## Bgfx tools makefile

Current tools makefile logic tries to automatically set the OS variable and it doesn't work correctly. In `bgfx/scripts/tools.mk`, comment out that logic entirely and replace it with:
```
# CUBZH: stuff above doesn't work. We just define mkdir/rmdir commands and
# we'll set platform explicitely by doing: eg. export OS=windows before building shaders
# See readme with shaders
CMD_MKDIR=mkdir -p "$(1)"
CMD_RMDIR=rm -r "$(1)"
```

Then proceed to build the tools following the instructions in common/shaders/README

## GL renderer

### 3D texture patch

It is necessary to patch back the tex3D extension lod function

In `bgfx/src/renderer_gl.cpp ~l.6734`, add the line at the beginning
```c
bx::write(&writer
         //// CUBZH: this first line was added to patch back texture3DLod
         , "#define texture3DLodEXT texture3DLod\n"

           "#define texture2DLod    textureLod\n"
           "#define texture3DLod    textureLod\n"
           "#define textureCubeLod  textureLod\n"
           "#define texture2DGrad   textureGrad\n"
           "#define texture3DGrad   textureGrad\n"
           "#define textureCubeGrad textureGrad\n"
);
```

### MRT patch
## Note: not necessary anymore as of PR 2414

MRT are available starting from GLES30, but bgfx reports that GLES31 is necessary, which is incorrect

In `bgfx/src/renderer_gl.cpp ~l.6627`, change the version number from 31 to 30
```c
//// CUBZH: changed GLES condition here from 31 to 30, MRT are supported starting from 30
if (BX_ENABLED(BGFX_CONFIG_RENDERER_OPENGL || BGFX_CONFIG_RENDERER_OPENGLES >= 30) )
```

### Compute patch

We need to specify compute shaders ESSL (GLES shading language) version when using GLES

In `bgfx/src/renderer_gl.cpp ~l.6862`, add a conditional block to replace the version header as follows,
```c
int32_t verLen = 0;
if (BX_ENABLED(BGFX_CONFIG_RENDERER_OPENGLES)) {
	bx::write(&writer
			, "#version 310 es\n"
			  "#define texture2DLod             textureLod\n"
			  "#define texture2DLodOffset       textureLodOffset\n"
			  "#define texture2DArrayLod        textureLod\n"
			  "#define texture2DArrayLodOffset  textureLodOffset\n"
			  "#define texture3DLod             textureLod\n"
			  "#define textureCubeLod           textureLod\n"
			  "#define texture2DGrad            textureGrad\n"
			  "#define texture3DGrad            textureGrad\n"
			  "#define textureCubeGrad          textureGrad\n"
			, &err
	);
	verLen = bx::strLen("#version 310 es\n");
} else {
	bx::write(&writer
			, "#version 430\n"
			  "#define texture2DLod             textureLod\n"
			  "#define texture2DLodOffset       textureLodOffset\n"
			  "#define texture2DArrayLod        textureLod\n"
			  "#define texture2DArrayLodOffset  textureLodOffset\n"
			  "#define texture3DLod             textureLod\n"
			  "#define textureCubeLod           textureLod\n"
			  "#define texture2DGrad            textureGrad\n"
			  "#define texture3DGrad            textureGrad\n"
			  "#define textureCubeGrad          textureGrad\n"
			, &err
	);
	verLen = bx::strLen("#version 430\n");
}

//int32_t verLen = bx::strLen("#version 430\n");
bx::write(&writer, code.getPtr()+verLen, codeLen-verLen, &err);
bx::write(&writer, '\0', &err);
```

### Read back emulation patch

We enable read back emulation on our Android project, therefore renderer_gl/readTexture() will perform a readPixels if read back isn't supported. However, bgfx::readTexture contains an early test that needs to be patched as follows
```c
//// CUBZH: disabling this check if we enable BGFX_GL_CONFIG_TEXTURE_READ_BACK_EMULATION,
//// since readTexture can still perform using a readPixels instead, check renderer_gl readTexture()
#ifndef BGFX_GL_CONFIG_TEXTURE_READ_BACK_EMULATION
BGFX_CHECK_CAPS(BGFX_CAPS_TEXTURE_READ_BACK, "Texture read-back is not supported!");
#endif
```

### Shadow sampler patch

In `bgfx/scripts/shader.mk`, although we don't use yet glsl shaders, change the following in order to compile them.
```
ifeq ($(TARGET), 4)
# CUBZH: issue w/ bgfxShadow2D and level -p 120
VS_FLAGS=--platform linux
FS_FLAGS=--platform linux
CS_FLAGS=--platform linux -p 430
SHADER_PATH=shaders/glsl
else
```

## MTL renderer

### iOS < 16 & MacOS < 13 support

If still an issue, fix can be found here,
https://github.com/voxowl/particubes-private/pull/4008/commits/91240851c4a66b7f9428dd3c692e79e2fd229f08

# Building

## Mac/iOS

### Xcode bgfx libs - iOS deployment target

Make sure the iOS deployment target is "9.0" and not "8.0" in all bgfx Xcode projects (for iOS) :
- bgfx
- bx
- bimg_decode
- bimg

If target is "8.0" you can have the following compilation error in "bimg_decode" project: 
```
"thread_local" is not supported for the selected target
```

### Xcode bgfx libs - Skip install YES

For each bgfx library target (bgfx, bx, bimg_decode, bimg), 
in "Build Settings,
make sure the option `Skip Install` is set to `Yes`.
