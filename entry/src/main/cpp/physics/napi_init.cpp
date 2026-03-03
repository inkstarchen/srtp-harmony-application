// napi_init.cpp
#include "napi/native_api.h"
#include "physicalSystem.h"
#include "napi_helpers.h"

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports)
{
    napi_property_descriptor desc[] = {
//        {"calculateCollisions", nullptr, CalculateCollisions, nullptr, nullptr, nullptr, napi_default, nullptr}
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    PhysicsSystem::Init(env, exports);
    return exports;
}
EXTERN_C_END

static napi_module nativeModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "physics",
    .nm_priv = nullptr,
    .reserved = { 0 },
};

extern "C" __attribute__((constructor)) void RegisterObjectWrapModule()
{
    napi_module_register(&nativeModule);
}