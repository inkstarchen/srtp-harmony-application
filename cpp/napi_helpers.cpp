//
// Created on 2026/1/19.
//
// Node APIs are not fully supported. To solve the compilation error of the interface cannot be found,
// please include "napi/native_api.h".

#include "napi/native_api.h"
#include "napi_helpers.h"
#include <vector>
#include <string>

namespace napi_helpers {

Vector3 parse_vector3(napi_env env, napi_value vector_obj) {
    napi_value x_val, y_val, z_val;
    
    napi_get_named_property(env, vector_obj, "x", &x_val);
    napi_get_named_property(env, vector_obj, "y", &y_val);
    napi_get_named_property(env, vector_obj, "z", &z_val);
    
    double x, y, z;
    napi_get_value_double(env, x_val, &x);
    napi_get_value_double(env, y_val, &y);
    napi_get_value_double(env, z_val, &z);
    
    return Vector3(x, y, z);
}

napi_value create_vector3(napi_env env, const Vector3& vec) {
    napi_value obj;
    napi_create_object(env, &obj);
    
    napi_value x, y, z;
    napi_create_double(env, vec.x, &x);
    napi_create_double(env, vec.y, &y);
    napi_create_double(env, vec.z, &z);
    
    napi_set_named_property(env, obj, "x", x);
    napi_set_named_property(env, obj, "y", y);
    napi_set_named_property(env, obj, "z", z);
    
    return obj;
}

PhysicsNode parse_physics_node(napi_env env, napi_value node_obj) {
    PhysicsNode node;
    
    // 解析name
    napi_value name_val;
    napi_get_named_property(env, node_obj, "name", &name_val);
    
    size_t name_len;
    napi_get_value_string_utf8(env, name_val, nullptr, 0, &name_len);
    
    std::string name(name_len, '\0');
    napi_get_value_string_utf8(env, name_val, &name[0], name_len + 1, &name_len);
    node.name = name;
    
    // 解析position
    napi_value pos_val;
    napi_get_named_property(env, node_obj, "position", &pos_val);
    node.position = parse_vector3(env, pos_val);
    
    // 解析velocity
    napi_value vel_val;
    napi_get_named_property(env, node_obj, "velocity", &vel_val);
    node.velocity = parse_vector3(env, vel_val);
    
    // 解析其他属性
    napi_value mass_val, radius_val, is_static_val;
    napi_get_named_property(env, node_obj, "mass", &mass_val);
    napi_get_named_property(env, node_obj, "radius", &radius_val);
    napi_get_named_property(env, node_obj, "isStatic", &is_static_val);
    
    napi_get_value_double(env, mass_val, &node.mass);
    napi_get_value_double(env, radius_val, &node.radius);
    
    bool is_static;
    napi_get_value_bool(env, is_static_val, &is_static);
    node.isStatic = is_static;
    
    return node;
}

napi_value create_physics_node(napi_env env, const PhysicsNode& node) {
    napi_value obj;
    napi_create_object(env, &obj);
    
    // 设置name
    napi_value name;
    napi_create_string_utf8(env, node.name.c_str(), node.name.length(), &name);
    napi_set_named_property(env, obj, "name", name);
    
    // 设置position
    napi_set_named_property(env, obj, "position",
                           create_vector3(env, node.position));
    
    // 设置velocity
    napi_set_named_property(env, obj, "velocity",
                           create_vector3(env, node.velocity));
    
    napi_value mass, radius, isStatic;
    napi_create_double(env, node.mass, &mass);
    napi_create_double(env, node.radius, &radius);
    napi_get_boolean(env, node.isStatic, &isStatic);
    // 设置其他属性
    napi_set_named_property(env, obj, "mass", mass);
    napi_set_named_property(env, obj, "radius", radius);
    napi_set_named_property(env, obj, "isStatic", isStatic);
    
    return obj;
}

std::vector<PhysicsNode> parse_physics_node_array(napi_env env, napi_value array_obj) {
    std::vector<PhysicsNode> nodes;
    
    uint32_t length;
    napi_get_array_length(env, array_obj, &length);
    
    for (uint32_t i = 0; i < length; i++) {
        napi_value item;
        napi_get_element(env, array_obj, i, &item);
        
        nodes.push_back(parse_physics_node(env, item));
    }
    
    return nodes;
}

napi_value create_physics_node_array(napi_env env, const std::vector<PhysicsNode>& nodes) {
    napi_value array;
    napi_create_array_with_length(env, nodes.size(), &array);
    
    for (size_t i = 0; i < nodes.size(); i++) {
        napi_value node_obj = create_physics_node(env, nodes[i]);
        napi_set_element(env, array, i, node_obj);
    }
    
    return array;
}

napi_value create_error(napi_env env, const char* message) {
    napi_value error_obj, error_msg;
    napi_create_string_utf8(env, message, NAPI_AUTO_LENGTH, &error_msg);
    napi_create_error(env, nullptr, error_msg, &error_obj);
    return error_obj;
}

bool check_args_count(napi_env env, size_t argc, size_t expected) {
    if (argc != expected) {
        napi_throw_error(env, nullptr, 
                        ("Expected " + std::to_string(expected) + 
                         " arguments, got " + std::to_string(argc)).c_str());
        return false;
    }
    return true;
}
}