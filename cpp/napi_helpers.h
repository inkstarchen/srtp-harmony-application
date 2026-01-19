//
// Created on 2026/1/19.
//
// Node APIs are not fully supported. To solve the compilation error of the interface cannot be found,
// please include "napi/native_api.h".

#ifndef DAYNOTE_NAPI_HELPERS_H
#define DAYNOTE_NAPI_HELPERS_H

#include <napi/native_api.h>
#include "vec.h"
#include "node.h"

namespace napi_helpers {
    // 从napi_value解析Vector3
    Vector3 parse_vector3(napi_env env, napi_value vector_obj);
    
    // 创建Vector3的napi_value
    napi_value create_vector3(napi_env env, const Vector3& vec);
    
    // 从napi_value解析PhysicsNode
    PhysicsNode parse_physics_node(napi_env env, napi_value node_obj);
    
    // 创建PhysicsNode的napi_value
    napi_value create_physics_node(napi_env env, const PhysicsNode& node);
    
    // 解析PhysicsNode数组
    std::vector<PhysicsNode> parse_physics_node_array(napi_env env, napi_value array_obj);
    
    // 创建PhysicsNode数组的napi_value
    napi_value create_physics_node_array(napi_env env, const std::vector<PhysicsNode>& nodes);
    
    // 通用错误处理
    napi_value create_error(napi_env env, const char* message);
    bool check_args_count(napi_env env, size_t argc, size_t expected);
}


#endif //DAYNOTE_NAPI_HELPERS_H
