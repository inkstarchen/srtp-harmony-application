//
// Created on 2026/1/19.
//
// Node APIs are not fully supported. To solve the compilation error of the interface cannot be found,
// please include "napi/native_api.h".

#ifndef DAYNOTE_NAPI_HELPERS_H
#define DAYNOTE_NAPI_HELPERS_H

#include <napi/native_api.h>
#include "core/include/vec.h"



namespace napi_helpers {
    // 从 napi_value 解析 Vector2
    Vector2 parse_vector2(napi_env env, napi_value vector_obj);
    
    // 创建 Vector2 的 napi_value
    napi_value create_vector2(napi_env env, const Vector2& vec);

    // 从napi_value解析Vector3
    Vector3 parse_vector3(napi_env env, napi_value vector_obj);
    
    // 创建Vector3的napi_value
    napi_value create_vector3(napi_env env, const Vector3& vec);
    
    // 从 napi_value 解析 Vector4
    Vector4 parse_vector4(napi_env env, napi_value vector_obj);
    
    // 创建 Vector4 的 napi_value
    napi_value create_vector4(napi_env env, const Vector4& vec);

    // 通用错误处理
    napi_value create_error(napi_env env, const char* message);
    bool check_args_count(napi_env env, size_t argc, size_t expected);
}


#endif //DAYNOTE_NAPI_HELPERS_H
