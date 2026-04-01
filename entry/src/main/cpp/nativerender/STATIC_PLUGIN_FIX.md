# Static Plugin Registration Fix

## Problem
`__attribute__((constructor))` functions in static libraries don't execute when linked via `$<TARGET_OBJECTS:...>` into a shared library in NDK environment.

Additionally, `constexpr` variables have internal linkage by default, and anonymous namespaces force internal linkage regardless of other attributes.

## Solution
Convert `registry_data.cpp` from being `#include`d into `static_plugin.cpp` to being compiled as a separate file. Define plugin data and registration functions directly without macros.

### Changes Made

#### 1. `LumeRender/src/plugin/registry_data.cpp` and `Lume_3D/src/plugin/registry_data.cpp`
Changed from using macros inside anonymous namespace to direct definitions:

```cpp
// Before: using macros inside anonymous namespace (internal linkage)
namespace {
extern "C" {
PLUGIN_DATA(AGPRender) { ... };  // constexpr has internal linkage
DEFINE_STATIC_PLUGIN(AGPRender);  // constructor attribute doesn't work
}
} // namespace

// After: direct definitions with external linkage
extern "C" const CORE_NS::IPlugin AGPRender_pluginData = { ... };

extern "C" void AGPRender_RegisterStaticPlugin()
{
    CORE_NS::StaticPluginRegistry::RegisterStaticPlugin(AGPRender_pluginData);
}
```

#### 2. `LumeRender/CMakeLists.txt` and `Lume_3D/CMakeLists.txt`
Added `registry_data.cpp` to source files:

```cmake
# plugin
src/plugin/static_plugin.cpp
src/plugin/static_registry.cpp
src/plugin/registry_data.cpp  # Now compiled separately
```

#### 3. `LumeRender/src/plugin/static_plugin.cpp` and `Lume_3D/src/plugin/static_plugin.cpp`
Removed `#include "registry_data.cpp"` - now compiled separately.

#### 4. `LumeRender/src/plugin/static_registry.cpp` and `Lume_3D/src/plugin/static_registry.cpp`
Uses `extern` declaration to access plugin data:

```cpp
extern "C" const CORE_NS::IPlugin AGPRender_pluginData;

extern "C" void InitRegistry(CORE_NS::IPluginRegister& pluginRegistry)
{
    CORE_NS::StaticPluginRegistry::RegisterStaticPlugin(AGPRender_pluginData);
}
```

#### 5. `3d_widget_adapter/core/src/lume/lume_common.cpp`
Calls registration functions at global scope:

```cpp
extern "C" void AGPRender_RegisterStaticPlugin();
extern "C" void AGP3D_RegisterStaticPlugin();

// In CreateRenderContext():
AGPRender_RegisterStaticPlugin();
AGP3D_RegisterStaticPlugin();
```

### Key Points

1. **`extern "C" const`** - external linkage, visible across compilation units
2. **No anonymous namespace** - anonymous namespace forces internal linkage
3. **Separate compilation** - registry_data.cpp is now in CMakeLists.txt sources
4. **Manual registration** - call `AGPRender_RegisterStaticPlugin()` and `AGP3D_RegisterStaticPlugin()` before `LoadPlugins()`

### Symbol Flow
```
registry_data.cpp (compiled separately)
    -> AGPRender_pluginData (extern "C" const - external linkage)
    -> AGPRender_RegisterStaticPlugin() (extern "C" function)

static_registry.cpp (compiled separately)
    -> extern declaration of AGPRender_pluginData
    -> InitRegistry() uses AGPRender_pluginData

lume_common.cpp
    -> calls AGPRender_RegisterStaticPlugin()
    -> calls AGP3D_RegisterStaticPlugin()
```

### Verification
Check logs for:
```
CreateRenderContext: Calling AGPRender_RegisterStaticPlugin()
CreateRenderContext: AGPRender plugin registered
CreateRenderContext: Calling AGP3D_RegisterStaticPlugin()
CreateRenderContext: AGP3D plugin registered
```

---

## Additional Fix: GL Function Pointer Null Check

### Problem
Program crashes when calling `glBufferStorageEXT` in `gpu_buffer_gles.cpp:127`.

**Root Cause:**
1. `gl_functions.h:50` declares function pointer `glBufferStorageEXT` via macro
2. `egl_state.cpp:67-70` defines function pointers initialized to `nullptr`
3. `egl_state.cpp:870` loads function pointers via `eglGetProcAddress()`
4. `eglGetProcAddress("glBufferStorageEXT")` may return `nullptr` even if `GL_EXT_buffer_storage` extension string exists
5. Original code only checked extension string, not function pointer:
   ```cpp
   if (const bool hasBufferStorageEXT = device_.HasExtension("GL_EXT_buffer_storage"); hasBufferStorageEXT) {
       glBufferStorageEXT(...);  // CRASH if null!
   }
   ```

### Solution
Add null pointer check in `LumeRender/src/gles/gpu_buffer_gles.cpp`:

```cpp
// Before:
if (const bool hasBufferStorageEXT = device_.HasExtension("GL_EXT_buffer_storage"); hasBufferStorageEXT) {

// After:
const bool hasBufferStorageEXT = device_.HasExtension("GL_EXT_buffer_storage") && (glBufferStorageEXT != nullptr);
if (hasBufferStorageEXT) {
```

### Key Points
1. **Extension string existence ≠ function pointer availability**
2. **Always check function pointer before calling GL extension functions**
3. **Check logs for `Missing glBufferStorageEXT` warning** - indicates `eglGetProcAddress` returned null

### Additional Fix: Missing Type Definition

**Problem:** `PFNGLBUFFERSTORAGEEXTPROC` type may not be defined if `GL_EXT_buffer_storage` constant was already defined elsewhere.

In `GLES2/gl2ext.h`:
```c
#ifndef GL_EXT_buffer_storage
#define GL_EXT_buffer_storage 1
typedef void (GL_APIENTRYP PFNGLBUFFERSTORAGEEXTPROC) (...);
#endif
```

If `GL_EXT_buffer_storage` is already defined, the `typedef` is skipped, causing compilation error.

**Solution in `gl_functions.h`:**
```cpp
// Always include GLES headers first to get type definitions
#include <GLES3/gl3.h>
#include <GLES3/gl31.h>
#include <GLES3/gl32.h>
#include <GLES2/gl2ext.h>

// Define missing GL extension types if not provided by headers
// These are needed when gl_functions.h is re-included in GlInitialize()
#ifndef PFNGLBUFFERSTORAGEEXTPROC
typedef void (GL_APIENTRYP PFNGLBUFFERSTORAGEEXTPROC)(GLenum target, GLsizeiptr size, const void *data, GLbitfield flags);
#endif
// ... other typedefs ...

#ifndef declare
#define declare(a, b) \
    extern "C" {      \
    extern a b;       \
    }
#endif
```

### Why This Fix Works

The original `gl_functions.h` structure:
```cpp
#ifndef declare
#include <GLES2/gl2ext.h>  // Only included if 'declare' not defined
#define declare(a, b) ...
#endif
```

When `GlInitialize()` re-includes the header:
1. `#undef GLES_FUNCTIONS_H` removes header guard
2. `#include "gles/gl_functions.h"` re-includes
3. But `declare` is already defined as `getter`
4. So `#ifndef declare` block is skipped
5. **GLES headers NOT included → types undefined → crash!**

The fix moves GLES includes and type definitions outside the `#ifndef declare` block.