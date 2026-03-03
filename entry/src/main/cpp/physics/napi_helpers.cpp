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

Vector2 parse_vector2(napi_env env, napi_value vector_obj) {
    napi_value x_val, y_val;

    napi_get_named_property(env, vector_obj, "x", &x_val);
    napi_get_named_property(env, vector_obj, "y", &y_val);

    double x, y;
    napi_get_value_double(env, x_val, &x);
    napi_get_value_double(env, y_val, &y);

    return Vector2(x, y);
}

napi_value create_vector2(napi_env env, const Vector2& vec) {
    napi_value obj;
    napi_create_object(env, &obj);

    napi_value x, y;
    napi_create_double(env, vec.x, &x);
    napi_create_double(env, vec.y, &y);

    napi_set_named_property(env, obj, "x", x);
    napi_set_named_property(env, obj, "y", y);

    return obj;
}

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

Vector4 parse_vector4(napi_env env, napi_value vector_obj) {
    napi_value x_val, y_val, z_val, w_val;

    napi_get_named_property(env, vector_obj, "x", &x_val);
    napi_get_named_property(env, vector_obj, "y", &y_val);
    napi_get_named_property(env, vector_obj, "z", &z_val);
    napi_get_named_property(env, vector_obj, "w", &w_val);

    double x, y, z, w;
    napi_get_value_double(env, x_val, &x);
    napi_get_value_double(env, y_val, &y);
    napi_get_value_double(env, z_val, &z);
    napi_get_value_double(env, w_val, &w);

    return Vector4(x, y, z, w);
}

napi_value create_vector4(napi_env env, const Vector4& vec) {
    napi_value obj;
    napi_create_object(env, &obj);

    napi_value x, y, z, w;
    napi_create_double(env, vec.x, &x);
    napi_create_double(env, vec.y, &y);
    napi_create_double(env, vec.z, &z);
    napi_create_double(env, vec.w, &w);

    napi_set_named_property(env, obj, "x", x);
    napi_set_named_property(env, obj, "y", y);
    napi_set_named_property(env, obj, "z", z);
    napi_set_named_property(env, obj, "w", w);

    return obj;
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