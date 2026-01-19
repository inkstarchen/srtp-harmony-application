// napi_init.cpp
#include "napi/native_api.h"
#include "hilog/log.h"

#include "simulator.h"
#include "napi_helpers.h"

napi_value create_vector3(napi_env env, double x, double y, double z);
// C++物理引擎保持不变，但接收ArkTS适配的数据
napi_value CalculateCollisions(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value argv[2];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    
    napi_value physics_data_array = argv[0];
    napi_value delta_time_value = argv[1];
    
    double deltaTime;
    napi_get_value_double(env, delta_time_value, &deltaTime);
    
    // 清空模拟器
    static PhysicsSimulator physicsSimulator;
    
    // 解析ArkTS传过来的物理数据
    uint32_t data_count;
    napi_get_array_length(env, physics_data_array, &data_count);
    
    // 解析每个PhysicsData对象
    physicsSimulator.setNodes(napi_helpers::parse_physics_node_array(env, physics_data_array));
    // 运行物理模拟
    physicsSimulator.update(deltaTime);
    
    // 创建结果数组
    napi_value result_array;
    napi_create_array_with_length(env, data_count, &result_array);
    
    // 返回更新后的物理数据
    const auto& updated_nodes = physicsSimulator.getNodes();

    for (uint32_t i = 0; i < data_count; i++) {
        const PhysicsNode& node = updated_nodes[i];

        // 创建物理数据对象
        napi_value result_data;
        napi_create_object(env, &result_data);

        // 设置id
        napi_value name_value;
        napi_create_string_utf8(env, node.name.c_str(), node.name.length(), &name_value);
        napi_set_named_property(env, result_data, "name", name_value);

        // 设置新位置
        napi_value position_obj = create_vector3(env, node.position.x, 
                                                node.position.y, node.position.z);
        napi_set_named_property(env, result_data, "position", position_obj);

        // 设置新速度
        napi_value velocity_obj = create_vector3(env, node.velocity.x,
                                                node.velocity.y, node.velocity.z);
        napi_set_named_property(env, result_data, "velocity", velocity_obj);

        // 设置其他属性
        napi_value mass_value, radius_value, is_static_value;
        napi_create_double(env, node.mass, &mass_value);
        napi_create_double(env, node.radius, &radius_value);
        napi_get_boolean(env, node.isStatic, &is_static_value);

        napi_set_named_property(env, result_data, "mass", mass_value);
        napi_set_named_property(env, result_data, "radius", radius_value);
        napi_set_named_property(env, result_data, "isStatic", is_static_value);

        // 添加到结果数组
        napi_set_element(env, result_array, i, result_data);
    }
    
    return result_array;
}

// 辅助函数：创建Vector3对象
napi_value create_vector3(napi_env env, double x, double y, double z) {
    napi_value obj;
    napi_create_object(env, &obj);

    napi_value x_val, y_val, z_val;
    napi_create_double(env, x, &x_val);
    napi_create_double(env, y, &y_val);
    napi_create_double(env, z, &z_val);

    napi_set_named_property(env, obj, "x", x_val);
    napi_set_named_property(env, obj, "y", y_val);
    napi_set_named_property(env, obj, "z", z_val);

    return obj;
}

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports)
{
    napi_property_descriptor desc[] = {
        {"calculateCollisions", nullptr, CalculateCollisions, nullptr, nullptr, nullptr, napi_default, nullptr}
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}
EXTERN_C_END

static napi_module nativeModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "entry",
    .nm_priv = nullptr,
    .reserved = { 0 },
};

extern "C" __attribute__((constructor)) void RegisterObjectWrapModule()
{
    napi_module_register(&nativeModule);
}