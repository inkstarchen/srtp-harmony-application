# 3d_widget_adapter Header Dependency Fix

## Problem Description

When compiling the `render`, `manager` modules and the main `nativerender` library, the following header file dependency errors occurred:

```
fatal error: 'lume_common.h' file not found
fatal error: '3d_widget_adapter_log.h' file not found
```

These errors appeared in:
- `nativerender/render/CMakeFiles/render.dir/plugin_render.cpp.o`
- `nativerender/manager/CMakeFiles/manager.dir/src/lume_xcomponent_manager.cpp.o`
- `nativerender/manager/CMakeFiles/manager.dir/src/lume_renderer.cpp.o`
- `nativerender/CMakeFiles/nativerender.dir/napi_init.cpp.o`

### Error Chain Analysis

The dependency chain is as follows:

```
lume_renderer.h
  └─> lume.h (3d_widget_adapter/core/include/lume/ohos/lume.h)
       └─> lume_common.h (same directory, lume/lume_common.h)
            └─> lume_custom_render.h (lume/custom/lume_custom_render.h)
                 └─> 3d_widget_adapter_log.h (3d_widget_adapter/include/ohos/)
```

### Header File Locations

| Header File | Location |
|-------------|----------|
| `lume.h` | `3d_widget_adapter/core/include/lume/ohos/` |
| `lume_common.h` | `3d_widget_adapter/core/include/lume/` |
| `lume_custom_render.h` | `3d_widget_adapter/core/include/lume/custom/` |
| `3d_widget_adapter_log.h` | `3d_widget_adapter/include/ohos/` |

## Root Cause

The CMakeLists.txt files for `render`, `manager` modules and the main `nativerender` library did not include all necessary header directories for the `3d_widget_adapter` module.

### Missing Include Directories

**render/CMakeLists.txt** was missing:
- `3d_widget_adapter/include`
- `3d_widget_adapter/include/ohos`
- `3d_widget_adapter/core/include`
- `3d_widget_adapter/core/include/lume`
- `3d_widget_adapter/core/include/lume/custom`
- `3d_widget_adapter/core/include/lume/ohos`

**manager/CMakeLists.txt** was missing:
- `3d_widget_adapter/include/ohos`
- `3d_widget_adapter/core/include/lume/custom`

**nativerender/CMakeLists.txt** (main library) was missing all `3d_widget_adapter` directories:
- `3d_widget_adapter/include`
- `3d_widget_adapter/include/ohos`
- `3d_widget_adapter/core/include`
- `3d_widget_adapter/core/include/lume`
- `3d_widget_adapter/core/include/lume/custom`
- `3d_widget_adapter/core/include/lume/ohos`

## Solution

### Fix 1: render/CMakeLists.txt

Added all required include directories:

```cmake
target_include_directories(render PUBLIC
    ${RENDER_ROOT}
    ${NATIVERENDER_ROOT_PATH}
    ${NATIVERENDER_ROOT_PATH}/manager/include

    # Lume engine headers (required by lume_renderer.h)
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
    ${NATIVERENDER_ROOT_PATH}/LumeRender/api
    ${NATIVERENDER_ROOT_PATH}/Lume_3D/api
    ${NATIVERENDER_ROOT_PATH}/LumeMeta/include
    ${NATIVERENDER_ROOT_PATH}/LumeScene/include

    # 3d_widget_adapter headers (required by lume.h -> lume_common.h -> lume_custom_render.h)
    ${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/include
    ${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/include/ohos
    ${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/core/include
    ${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/core/include/lume
    ${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/core/include/lume/custom
    ${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/core/include/lume/ohos
)
```

### Fix 2: manager/CMakeLists.txt

Added missing include directories:

```cmake
# Adapter headers
${NATIVERENDER_ROOT_PATH}/3d_scene_adapter/include
${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/include
${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/include/ohos          # Added
${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/core/include
${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/core/include/lume
${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/core/include/lume/custom  # Added
${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/core/include/lume/ohos
```

### Fix 3: nativerender/CMakeLists.txt (main)

Added all required include directories for the main `nativerender` library:

```cmake
include_directories(
    ${NATIVERENDER_ROOT_PATH}
    ${NATIVERENDER_ROOT_PATH}/include
    ${NATIVERENDER_ROOT_PATH}/render
    ${NATIVERENDER_ROOT_PATH}/manager/include
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
    ${NATIVERENDER_ROOT_PATH}/LumeRender/api
    ${NATIVERENDER_ROOT_PATH}/securec/include

    # 3d_widget_adapter headers (required for napi_init.cpp -> lume_xcomponent_manager.h -> lume_renderer.h)
    ${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/include
    ${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/include/ohos
    ${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/core/include
    ${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/core/include/lume
    ${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/core/include/lume/custom
    ${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/core/include/lume/ohos
)

## Best Practices for Header Dependencies

### 1. Include Path Strategy

When using headers with `#include <header.h>` syntax (angle brackets), the header must be directly in an include path directory. Use:

```cmake
# For #include <3d_widget_adapter_log.h>
${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/include/ohos
```

### 2. Relative Include Strategy

When using `#include "header.h"` syntax (quotes), the header is searched relative to the current file's directory first. Use:

```cmake
# For #include "lume_common.h" from lume.h
${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/core/include/lume
```

### 3. Complete Include Path List

For modules that depend on `3d_widget_adapter`, always include these directories:

```cmake
${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/include
${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/include/ohos
${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/core/include
${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/core/include/lume
${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/core/include/lume/custom
${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/core/include/lume/ohos
```

## Verification

After applying the fixes, rebuild the project:

```bash
cd entry/src/main/cpp
cmake --build-out-dir build --clean-first
```

The compilation should now succeed without header dependency errors.

## Date

2026-03-29