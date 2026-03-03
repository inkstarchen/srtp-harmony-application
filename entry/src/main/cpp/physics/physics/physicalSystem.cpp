//
// Created on 2026/2/4.
//
// Node APIs are not fully supported. To solve the compilation error of the interface cannot be found,
// please include "napi/native_api.h".

#include "collision.h"
#include "physicalSystem.h"
#include "napi_helpers.h"
#include "vec.h"
#include <cassert>
#include <cstdint>


// 对齐到64空间
static size_t alignCapacity(size_t v) {
    return (v + 63) & ~63; //对齐到 64
}

// 结构体新建入口
napi_value PhysicsSystem::New(napi_env env, napi_callback_info info) 
{
    OH_LOG_INFO(LOG_APP, "PhysicsSystem::New called");
    
    napi_value newTarget;
    napi_get_new_target(env, info, &newTarget);
    if (newTarget != nullptr) {
        size_t argc = 1;
        napi_value args[1];
        napi_value jsThis;
        napi_get_cb_info(env, info, &argc, args, &jsThis, nullptr);
        
        uint32_t value = 0;
        size_t capacity = 0;
        napi_valuetype valuetype;
        napi_typeof(env, args[0], &valuetype);
        if (valuetype != napi_undefined) {
            napi_get_value_uint32(env, args[0], &value);
            capacity = static_cast<size_t>(value);
        }
        if(capacity < 0){
            capacity = 128;
        }
        PhysicsSystem* obj = new PhysicsSystem(capacity);
        
        obj->env_ = env;
        
        napi_status status = napi_wrap(env, jsThis, reinterpret_cast<void*>(obj), PhysicsSystem::Destructor, nullptr, &obj->wrapper_);
        
        if (status != napi_ok) {
            OH_LOG_INFO(LOG_APP, "Failed to bind native object to js object"
                        ", reutrn code: %{public}d", status);
            delete obj;
            return jsThis;
        }
        
        uint32_t refCount = 0;
        napi_reference_unref(env, obj->wrapper_, &refCount);
        
        return jsThis;
    } else {
        size_t argc = 1;
        napi_value args[1];
        napi_value jsThis = nullptr;
        napi_get_cb_info(env, info, &argc, args, &jsThis, nullptr);
        
        napi_value cons;
        const char* constructorName = "PhysicsSystem";
        napi_get_named_property(env, jsThis, constructorName, &cons);
        napi_value instance;
        napi_new_instance(env, cons, argc, args, &instance);
        
        return instance;
    }
}

// 初始化获取足够的内存空间
PhysicsSystem::PhysicsSystem(size_t cap)
    : count(0), env_(nullptr), wrapper_(nullptr) 
{
    
    capacity = alignCapacity(cap);
    free_list.reserve(capacity);
    
    // 计算 float / int / byte 数量
    const size_t floatCount = 
        3 + 4 + 3 + 3 + 3 + 6 + 3;
    // pos + rot + vel + acc + force + bounds + material
    
    size_t bytes = 
        capacity * (
            floatCount * sizeof(float) +
            sizeof(int32_t) +   // shapeType
            sizeof(uint8_t)     // isStatic
        );
    
    base_ptr = malloc(bytes);
    assert(base_ptr && "PhysicsSystem allocation failed");
    
    uint8_t * cursor = static_cast<uint8_t*>(base_ptr);

#define ALLOC_FLOAT(ptr) \
    ptr = reinterpret_cast<float*>(cursor); \
    cursor += capacity * sizeof(float);
    
#define ALLOC_INT(ptr) \
    ptr = reinterpret_cast<int32_t*>(cursor); \
    cursor += capacity * sizeof(int32_t);
    
#define ALLOC_BYTE(ptr) \
    ptr = reinterpret_cast<uint8_t*>(cursor); \
    cursor += capacity * sizeof(uint8_t);
    
        // position
    ALLOC_FLOAT(pos_x)
    ALLOC_FLOAT(pos_y)
    ALLOC_FLOAT(pos_z)

    // rotation
    ALLOC_FLOAT(rot_x)
    ALLOC_FLOAT(rot_y)
    ALLOC_FLOAT(rot_z)
    ALLOC_FLOAT(rot_w)

    // velocity / acc / force
    ALLOC_FLOAT(vel_x)
    ALLOC_FLOAT(vel_y)
    ALLOC_FLOAT(vel_z)

    ALLOC_FLOAT(acc_x)
    ALLOC_FLOAT(acc_y)
    ALLOC_FLOAT(acc_z)

    ALLOC_FLOAT(force_x)
    ALLOC_FLOAT(force_y)
    ALLOC_FLOAT(force_z)

    ALLOC_FLOAT(scale_x)
    ALLOC_FLOAT(scale_y)
    ALLOC_FLOAT(scale_z)
    // bounds
    ALLOC_FLOAT(extent_x)
    ALLOC_FLOAT(extent_y)
    ALLOC_FLOAT(extent_z)

    // material
    ALLOC_FLOAT(mass)
    ALLOC_FLOAT(restitution)
    ALLOC_FLOAT(friction)

    // flags
    ALLOC_INT(shapeType)
    ALLOC_BYTE(isStatic)
    
#undef ALLOC_FLOAT
#undef ALLOC_INT
#undef ALLOC_BYTE
    
    std::memset(base_ptr, 0, bytes);
}



// 销毁删除结构体
PhysicsSystem::~PhysicsSystem()
{
    free(base_ptr);
    napi_delete_reference(env_, wrapper_);
    napi_delete_reference(env_, buffer_ref_);
}

// 申请新的ID
uint32_t PhysicsSystem::newNode()
{
    uint32_t id;
    if(!free_list.empty()) {
        id = free_list.back();
        free_list.pop_back();
    } else {
        id = count++;
        assert(id < capacity && "Exceed capacity");
    }
    return id;
}

// 结构体销毁入口
void PhysicsSystem::Destructor(napi_env env, void *nativeObject, [[maybe_unused]] void *finalize_hint)
{
    OH_LOG_INFO(LOG_APP,"PhysicsSystem::Destructor called");
    delete reinterpret_cast<PhysicsSystem*>(nativeObject);
}

// buffer数据销毁的入口
void FinalizeCallback(napi_env env, void *finalize_data, void *finalize_hint)
{
    FloatBuffer *bufferData = static_cast<FloatBuffer *>(finalize_hint);
    delete bufferData;
}

// 设置属性函数
napi_value PhysicsSystem::SetPosition(napi_env env, napi_callback_info info) 
{  
    size_t argc = 2;
    napi_value argv[2];
    napi_value jsThis;
    napi_get_cb_info(env, info, &argc, argv, &jsThis, nullptr);

    napi_value id_val = argv[0];
    napi_value position_val = argv[1];
    uint32_t id;
    Vector3 position;
    napi_get_value_uint32(env, id_val, &id);
    position = napi_helpers::parse_vector3(env, position_val);
    
    PhysicsSystem* obj;
    napi_unwrap(env, jsThis, reinterpret_cast<void**>(&obj));
    
    obj->setPosition(id, position);
    return nullptr;
}

napi_value PhysicsSystem::SetRotation(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value argv[2], jsThis;
    napi_get_cb_info(env, info, &argc, argv, &jsThis, nullptr);

    uint32_t id;
    Vector4 rotation;

    napi_get_value_uint32(env, argv[0], &id);
    rotation = napi_helpers::parse_vector4(env, argv[1]);

    PhysicsSystem* obj;
    napi_unwrap(env, jsThis, reinterpret_cast<void**>(&obj));
    obj->setRotation(id, rotation);
    return nullptr;
}

napi_value PhysicsSystem::SetVelocity(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value argv[2], jsThis;
    napi_get_cb_info(env, info, &argc, argv, &jsThis, nullptr);

    uint32_t id;
    Vector3 velocity;

    napi_get_value_uint32(env, argv[0], &id);
    velocity = napi_helpers::parse_vector3(env, argv[1]);

    PhysicsSystem* obj;
    napi_unwrap(env, jsThis, reinterpret_cast<void**>(&obj));
    obj->setVelocity(id, velocity);
    return nullptr;
}

napi_value PhysicsSystem::SetAcceleration(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value argv[2], jsThis;
    napi_get_cb_info(env, info, &argc, argv, &jsThis, nullptr);

    uint32_t id;
    Vector3 acc;

    napi_get_value_uint32(env, argv[0], &id);
    acc = napi_helpers::parse_vector3(env, argv[1]);

    PhysicsSystem* obj;
    napi_unwrap(env, jsThis, reinterpret_cast<void**>(&obj));
    obj->setAcceleration(id, acc);
    return nullptr;
}

napi_value PhysicsSystem::SetForce(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value argv[2], jsThis;
    napi_get_cb_info(env, info, &argc, argv, &jsThis, nullptr);

    uint32_t id;
    Vector3 force;

    napi_get_value_uint32(env, argv[0], &id);
    force = napi_helpers::parse_vector3(env, argv[1]);

    PhysicsSystem* obj;
    napi_unwrap(env, jsThis, reinterpret_cast<void**>(&obj));
    obj->setForce(id, force);
    return nullptr;
}

napi_value PhysicsSystem::SetScale(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value argv[2], jsThis;
    napi_get_cb_info(env, info, &argc, argv, &jsThis, nullptr);

    uint32_t id;
    Vector3 scale;

    napi_get_value_uint32(env, argv[0], &id);
    scale = napi_helpers::parse_vector3(env, argv[1]);

    PhysicsSystem* obj;
    napi_unwrap(env, jsThis, reinterpret_cast<void**>(&obj));
    obj->setScale(id, scale);
    return nullptr;
}

napi_value PhysicsSystem::SetExtent(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value argv[2], jsThis;
    napi_get_cb_info(env, info, &argc, argv, &jsThis, nullptr);

    uint32_t id;
    Vector3 extent;

    napi_get_value_uint32(env, argv[0], &id);
    extent = napi_helpers::parse_vector3(env, argv[1]);

    PhysicsSystem* obj;
    napi_unwrap(env, jsThis, reinterpret_cast<void**>(&obj));
    obj->setExtent(id, extent);
    return nullptr;
}

napi_value PhysicsSystem::SetMass(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value argv[2], jsThis;
    napi_get_cb_info(env, info, &argc, argv, &jsThis, nullptr);

    uint32_t id;
    double mass;

    napi_get_value_uint32(env, argv[0], &id);
    napi_get_value_double(env, argv[1], &mass);

    PhysicsSystem* obj;
    napi_unwrap(env, jsThis, reinterpret_cast<void**>(&obj));
    obj->setMass(id, static_cast<float>(mass));
    return nullptr;
}

napi_value PhysicsSystem::SetRestitution(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value argv[2], jsThis;
    napi_get_cb_info(env, info, &argc, argv, &jsThis, nullptr);

    uint32_t id;
    double r;

    napi_get_value_uint32(env, argv[0], &id);
    napi_get_value_double(env, argv[1], &r);

    PhysicsSystem* obj;
    napi_unwrap(env, jsThis, reinterpret_cast<void**>(&obj));
    obj->setRestitution(id, static_cast<float>(r));
    return nullptr;
}

napi_value PhysicsSystem::SetFriction(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value argv[2], jsThis;
    napi_get_cb_info(env, info, &argc, argv, &jsThis, nullptr);

    uint32_t id;
    double f;

    napi_get_value_uint32(env, argv[0], &id);
    napi_get_value_double(env, argv[1], &f);

    PhysicsSystem* obj;
    napi_unwrap(env, jsThis, reinterpret_cast<void**>(&obj));
    obj->setFriction(id, static_cast<float>(f));
    return nullptr;
}

napi_value PhysicsSystem::SetShapeType(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value argv[2], jsThis;
    napi_get_cb_info(env, info, &argc, argv, &jsThis, nullptr);

    uint32_t id;
    int32_t type;

    napi_get_value_uint32(env, argv[0], &id);
    napi_get_value_int32(env, argv[1], &type);

    PhysicsSystem* obj;
    napi_unwrap(env, jsThis, reinterpret_cast<void**>(&obj));
    obj->setShapeType(id, type);
    return nullptr;
}

napi_value PhysicsSystem::SetIsStatic(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value argv[2], jsThis;
    napi_get_cb_info(env, info, &argc, argv, &jsThis, nullptr);

    uint32_t id;
    uint32_t isStatic;

    napi_get_value_uint32(env, argv[0], &id);
    napi_get_value_uint32(env, argv[1], &isStatic);

    PhysicsSystem* obj;
    napi_unwrap(env, jsThis, reinterpret_cast<void**>(&obj));
    obj->setIsStatic(id, static_cast<uint8_t>(isStatic));
    return nullptr;
}


void PhysicsSystem::setPosition(uint32_t id, Vector3 position)
{
    pos_x[id] = position.x;
    pos_y[id] = position.y;
    pos_z[id] = position.z;
}

void PhysicsSystem::setRotation(uint32_t id, Vector4 rotation)
{
    rot_x[id] = rotation.x;
    rot_y[id] = rotation.y;
    rot_z[id] = rotation.z;
    rot_w[id] = rotation.w;
}

void PhysicsSystem::setScale(uint32_t id, Vector3 scale)
{
    scale_x[id] = scale.x;
    scale_y[id] = scale.y;
    scale_z[id] = scale.z;
}

// ================= Motion =================

void PhysicsSystem::setVelocity(uint32_t id, Vector3 velocity)
{
    vel_x[id] = velocity.x;
    vel_y[id] = velocity.y;
    vel_z[id] = velocity.z;
}

void PhysicsSystem::setAcceleration(uint32_t id, Vector3 acceleration)
{
    acc_x[id] = acceleration.x;
    acc_y[id] = acceleration.y;
    acc_z[id] = acceleration.z;
}

void PhysicsSystem::setForce(uint32_t id, Vector3 force)
{
    force_x[id] = force.x;
    force_y[id] = force.y;
    force_z[id] = force.z;
}

// ================= Collision =================

void PhysicsSystem::setExtent(uint32_t id, Vector3 extent)
{
    extent_x[id] = extent.x;
    extent_y[id] = extent.y;
    extent_z[id] = extent.z;
}

void PhysicsSystem::setShapeType(uint32_t id, int32_t type)
{
    shapeType[id] = type;
}

// ================= Physical Params =================

void PhysicsSystem::setMass(uint32_t id, float m)
{
    mass[id] = m;
}


void PhysicsSystem::setRestitution(uint32_t id, float r)
{
    restitution[id] = r;
}

void PhysicsSystem::setFriction(uint32_t id, float f)
{
    friction[id] = f;
}

// ================= Flags =================

void PhysicsSystem::setIsStatic(uint32_t id, uint8_t value)
{
    isStatic[id] = value;
}

void PhysicsSystem::setGravity(Vector3 gravity) 
{
    for(uint32_t i = 0; i < count; i++){
        force_y[i] = gravity.y;
        force_x[i] = gravity.x;
        force_z[i] = -gravity.z;
    }
}

// 获取属性函数

napi_value PhysicsSystem::GetMass(napi_env env, napi_callback_info info){

    size_t argc = 1;
    napi_value argv[1], jsThis;
    napi_get_cb_info(env, info, &argc, argv, &jsThis, nullptr);

    napi_value id_val = argv[0];
    uint32_t id;
    napi_get_value_uint32(env, id_val, &id);

    PhysicsSystem* obj;
    napi_unwrap(env, jsThis, reinterpret_cast<void**>(&obj));
    float m = obj->getMass(id);
    napi_value mass_val;
    double mass = static_cast<float >(m);
    napi_status status = napi_create_double(env, mass, &mass_val);
    if(status != napi_ok){
        napi_throw_error(env, nullptr, "create double fail");
    }
    return mass_val;
}
napi_value PhysicsSystem::GetVel(napi_env env, napi_callback_info info){

    size_t argc = 1;
    napi_value argv[1], jsThis;
    napi_get_cb_info(env, info, &argc, argv, &jsThis, nullptr);

    napi_value id_val = argv[0];
    uint32_t id;
    napi_get_value_uint32(env, id_val, &id);

    PhysicsSystem* obj;
    napi_unwrap(env, jsThis, reinterpret_cast<void**>(&obj));
    Vector3 vel = obj->getVel(id);
    napi_value vel_val;
    
    vel_val = napi_helpers::create_vector3(env, vel);
    return vel_val;
}
napi_value PhysicsSystem::GetAcc(napi_env env, napi_callback_info info){

    size_t argc = 1;
    napi_value argv[1], jsThis;
    napi_get_cb_info(env, info, &argc, argv, &jsThis, nullptr);

    napi_value id_val = argv[0];
    uint32_t id;
    napi_get_value_uint32(env, id_val, &id);

    PhysicsSystem* obj;
    napi_unwrap(env, jsThis, reinterpret_cast<void**>(&obj));
    Vector3 acc = obj->getAcc(id);
    napi_value acc_val;
    
    acc_val = napi_helpers::create_vector3(env, acc);
    return acc_val;
}
napi_value PhysicsSystem::GetFric(napi_env env, napi_callback_info info){

    size_t argc = 1;
    napi_value argv[1], jsThis;
    napi_get_cb_info(env, info, &argc, argv, &jsThis, nullptr);

    napi_value id_val = argv[0];
    uint32_t id;
    napi_get_value_uint32(env, id_val, &id);

    PhysicsSystem* obj;
    napi_unwrap(env, jsThis, reinterpret_cast<void**>(&obj));
    float f = obj->getFric(id);
    napi_value f_val;
    double friction = static_cast<float >(f);
    napi_status status = napi_create_double(env, friction, &f_val);
    if(status != napi_ok){
        napi_throw_error(env, nullptr, "create double fail");
    }
    return f_val;
}
float PhysicsSystem::getMass(uint32_t id){
    return mass[id];
}
Vector3 PhysicsSystem::getAcc(uint32_t id){
    return Vector3(acc_x[id],acc_y[id], acc_z[id]);
}
Vector3 PhysicsSystem::getVel(uint32_t id){
    return Vector3(vel_x[id],vel_y[id], vel_z[id]);
}
float PhysicsSystem::getFric(uint32_t id){
    
    return friction[id];
}

// 步进模拟函数
napi_value PhysicsSystem::Update(napi_env env, napi_callback_info info)
{
    size_t argc = 1;
    napi_value argv[1];
    napi_value jsThis;
    napi_get_cb_info(env, info, &argc, argv, &jsThis, nullptr);
    
    napi_value time_val = argv[0];
    double d;
    napi_get_value_double(env, time_val, &d);
    
    PhysicsSystem* obj;
    
    napi_unwrap(env, jsThis, reinterpret_cast<void**>(&obj));
    obj->step(static_cast<float>(d));
    return obj->update(env, info);
}
napi_value PhysicsSystem::update(napi_env env, napi_callback_info info) 
{
    napi_value result = nullptr;
    
    if(buffer_ref_ != nullptr){
        napi_get_reference_value(env, buffer_ref_, &result);
        return result;
    }
    
    FloatBuffer *bufferData = new FloatBuffer{pos_x, capacity * 7};

    napi_value arrayBuffer;
    napi_status status = 
        napi_create_external_arraybuffer(env, pos_x, capacity * 7 * sizeof(float), FinalizeCallback, bufferData, &result);
    if(status != napi_ok) {
        napi_throw_error(env, nullptr, "Node-API napi_create_external_arraybuffer fail");
        return nullptr;
    }

    napi_value outputArray;
    status = napi_create_typedarray(env, napi_float32_array, capacity * 7, result, 0, &outputArray);

    if(status != napi_ok) {
        napi_throw_error(env, nullptr, "Node-API napi_create_typedarray fail");
        return nullptr;
    }

    napi_create_reference(env, outputArray, 1, &buffer_ref_);
    return outputArray;
}
void PhysicsSystem::step(float dt)
{
    // 位置预测
    for (uint32_t i = 0; i < count; ++i)
    {
        if (isStatic[i]){
            vel_x[i] = 0.0;
            vel_y[i] = 0.0;
            vel_z[i] = 0.0;
            clearForce(i);
            continue;
        }

        // --- 1. 合力 -> 加速度 ---
        float invMass = (mass[i] > 0.0f) ? 1.0f / mass[i] : 0.0f;
//        OH_LOG_INFO(LOG_APP,"PhysicsSystem::Step id:%{public}u invMass:%{public}f, force:%{public}f, friction:%{public}f",i,invMass,force_y[i],friction[i]);
        acc_x[i] = force_x[i] * invMass;
        acc_y[i] = force_y[i] * invMass;
        acc_z[i] = force_z[i] * invMass;

        // --- 2. 更新速度 ---
        vel_x[i] += acc_x[i] * dt;
        vel_y[i] += acc_y[i] * dt;
        vel_z[i] += acc_z[i] * dt;

        // --- 3. 线性阻尼（friction） ---
        float damping = std::max(0.0f, 1.0f - friction[i] * dt);
        vel_x[i] *= damping;
        vel_y[i] *= damping;
        vel_z[i] *= damping;
        // --- 4. 更新位置 ---
        pos_x[i] += vel_x[i] * dt;
        pos_y[i] += vel_y[i] * dt;
        pos_z[i] += vel_z[i] * dt;

        // --- 5. 清空力（非常重要） ---
        clearForce(i);
    }
    
    // 计算碰撞
    for (uint32_t i = 0; i < count; ++i) {
        for (uint32_t j = i + 1; j < count; ++j) {
            if(isStatic[i] && isStatic[j]) continue;
            if (testCollision(i, j)) {
                ResolveCollision(i, j);
            }
        }
    }

}

napi_value PhysicsSystem::AddNode(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1];
    napi_value jsThis;
    napi_get_cb_info(env, info, &argc, argv, &jsThis, nullptr);
    
    PhysicsSystem* obj;
    napi_unwrap(env, jsThis, reinterpret_cast<void**>(&obj));
    uint32_t id = obj->newNode();
    
    napi_value data_value = argv[0];
    
        // ===== position =====
    {
        napi_value position_value;
        Vector3 position;
        napi_get_named_property(env, data_value, "position", &position_value);
        position = napi_helpers::parse_vector3(env, position_value);
        OH_LOG_INFO(LOG_APP, "POSITION ACCEPT:%{public}f", position.y);
        obj->setPosition(id, position);
    }
    
    // ===== rotation =====
    {
        napi_value rotation_value;
        Vector4 rotation;
        napi_get_named_property(env, data_value, "rotation", &rotation_value);
        rotation = napi_helpers::parse_vector4(env, rotation_value);
        obj->setRotation(id, rotation);
    }
    
    // ===== scale =====
    {
        napi_value scale_value;
        Vector3 scale;
        napi_get_named_property(env, data_value, "scale", &scale_value);
        scale = napi_helpers::parse_vector3(env, scale_value);
        obj->setScale(id, scale);
    }
    
    // ===== extent =====
    {
        napi_value extent_value;
        Vector3 extent;
        napi_get_named_property(env, data_value, "extent", &extent_value);
        extent = napi_helpers::parse_vector3(env, extent_value);
        obj->setExtent(id, extent);
    }
    
    // ===== shapeType =====
    {
        napi_value shape_type_value;
        int32_t shapeType;
        napi_get_named_property(env, data_value, "shapeType", &shape_type_value);
        napi_get_value_int32(env, shape_type_value, &shapeType);
        obj->setShapeType(id, shapeType);
    }
    
    // ===== isStatic =====
    {
        napi_value is_static_value;
        uint32_t isStatic;
        napi_get_named_property(env, data_value, "isStatic", &is_static_value);
        napi_get_value_uint32(env, is_static_value, &isStatic);
        obj->setIsStatic(id, static_cast<uint8_t>(isStatic));
    }
    
    obj->setMass(id, 1.0f);

    napi_value id_val;
    napi_create_int32(env, id, &id_val);
    
    return id_val;
}

// 根据手机姿态设置重力的函数
napi_value PhysicsSystem::GetNormal(napi_env env, napi_callback_info info)
{
    size_t arc = 1;
    napi_value argv[1];
    napi_value jsThis;
    napi_get_cb_info(env, info, &arc, argv, &jsThis, nullptr);
    
    PhysicsSystem* obj;
    
    napi_unwrap(env, jsThis, reinterpret_cast<void**>(&obj));
    
    Vector3 angle = napi_helpers::parse_vector3(env, argv[0]);
    Vector3 normal = Vector3(0.0, 0.0, -1.0);
    angle = angle / 180.0 * 3.141592;
    normal = Vector3::RotateAroundAxis(normal, Vector3(0.0,1.0,0.0), -angle.y);
    normal = Vector3::RotateAroundAxis(normal, Vector3(1.0,0.0,0.0), angle.x);
    Vector3 g = Vector3(0.0, 0.0, -1.0);
    Vector3 g_l = g - normal * g.dot(normal);
    obj->setGravity(normal);
    return nullptr;
}


// ============= 碰撞解算函数 ===================

bool PhysicsSystem::testCollision(uint32_t a, uint32_t b)
{
    ShapeType typeA = static_cast<ShapeType>(shapeType[a]);
    ShapeType typeB = static_cast<ShapeType>(shapeType[b]);

    Vector3 posA = { pos_x[a], pos_y[a], pos_z[a] };
    Vector3 posB = { pos_x[b], pos_y[b], pos_z[b] };

    Vector3 extA = { extent_x[a], extent_y[a], extent_z[a] };
    Vector3 extB = { extent_x[b], extent_y[b], extent_z[b] };

    if (typeA == SHAPE_AABB && typeB == SHAPE_AABB)
        return Collision::AABBvsAABB(posA, extA, posB, extB);

    if (typeA == SHAPE_AABB && typeB == SHAPE_SPHERE)
        return Collision::AABBvsSphere(posA, extA, posB, extB.x);

    if (typeA == SHAPE_SPHERE && typeB == SHAPE_AABB)
        return Collision::AABBvsSphere(posB, extB, posA, extA.x);

    return false;
}

void PhysicsSystem::ResolveCollision(uint32_t a, uint32_t b)
{
    float nx, ny, nz;
    float penetration;
    
    ComputeMTV(a, b, nx, ny, nz, penetration);
    if (penetration <= 0.0f) return;
    
    PositionalCorrection(a, b, nx, ny, nz, penetration);
//    
    ResolveVelocity(a, b, nx, ny, nz);
}

void PhysicsSystem::ResolveVelocity(
    uint32_t a, uint32_t b,
    float nx, float ny, float nz)
{
    float invMassA = isStatic[a] ? 0.0f : 1.0f / mass[a];
    float invMassB = isStatic[b] ? 0.0f : 1.0f / mass[b];
    if (invMassA + invMassB == 0.0f) return;

    // 相对速度
    float rvx = vel_x[a] - vel_x[b];
    float rvy = vel_y[a] - vel_y[b];
    float rvz = vel_z[a] - vel_z[b];

    // 法向速度分量
    float velAlongNormal = rvx * nx + rvy * ny + rvz * nz;


    OH_LOG_INFO(LOG_APP, "分离速度:%{public}f 分离方向:%{public}f, 相对速度:%{public}f, apos:%{public}f, bpos:%{public}f,avel:%{public}f, bvel:%{public}f", velAlongNormal,ny,rvy,pos_y[a], pos_y[b],vel_y[a],vel_y[b]);
    
    // 正在分离，不需要修正
    if (velAlongNormal > 0.0f) return;

    // --- 法向冲量 ---
    float e = std::min(restitution[a], restitution[b]);
    OH_LOG_INFO(LOG_APP, "物理检索:弹性限度：a:%{public}f b:%{public}f", restitution[a], restitution[b]);
    float j = -(1.0f + e) * velAlongNormal;
    j /= (invMassA + invMassB);
    OH_LOG_INFO(LOG_APP, "物理检索:J IS %{public}f", j);

    float impulseX = j * nx;
    float impulseY = j * ny;
    float impulseZ = j * nz;
    OH_LOG_INFO(LOG_APP,"物理检索:物体A,碰撞前速度%{public}f", vel_y[a]);
    vel_x[a] += impulseX * invMassA;
    vel_y[a] += impulseY * invMassA;
    vel_z[a] += impulseZ * invMassA;
    OH_LOG_INFO(LOG_APP,"物理检索:物体A,碰撞后速度%{public}f", vel_y[a]); 
    OH_LOG_INFO(LOG_APP,"物理检索:物体B,碰撞前速度%{public}f", vel_y[b]);
    vel_x[b] -= impulseX * invMassB;
    vel_y[b] -= impulseY * invMassB;
    vel_z[b] -= impulseZ * invMassB;
    OH_LOG_INFO(LOG_APP,"物理检索:物体B,碰撞后速度%{public}f", vel_y[b]);

    // --- 摩擦冲量 ---
    // 切向速度
//    float tx = rvx - velAlongNormal * nx;
//    float ty = rvy - velAlongNormal * ny;
//    float tz = rvz - velAlongNormal * nz;
//
//    float len = sqrt(tx * tx + ty * ty + tz * tz);
//    if (len < 1e-6f) return;
//
//    tx /= len;
//    ty /= len;
//    tz /= len;
//
//    float jt = -(rvx * tx + rvy * ty + rvz * tz);
//    jt /= (invMassA + invMassB);
//
//    float mu = sqrt(friction[a] * friction[b]);
//
//    float fx, fy, fz;
//    if (fabs(jt) < j * mu) {
//        fx = jt * tx;
//        fy = jt * ty;
//        fz = jt * tz;
//    } else {
//        fx = -j * tx * mu;
//        fy = -j * ty * mu;
//        fz = -j * tz * mu;
//    }
//
//    vel_x[a] -= fx * invMassA;
//    vel_y[a] -= fy * invMassA;
//    vel_z[a] -= fz * invMassA;
//
//    vel_x[b] += fx * invMassB;
//    vel_y[b] += fy * invMassB;
//    vel_z[b] += fz * invMassB;
}

void PhysicsSystem::ComputeMTV(
    uint32_t a, uint32_t b,
    float &nx, float &ny, float &nz,
    float &penetration) 
{ 
    ShapeType typeA = static_cast<ShapeType>(shapeType[a]);
    ShapeType typeB = static_cast<ShapeType>(shapeType[b]);

    if(typeA == SHAPE_AABB && typeB == SHAPE_AABB){
        ComputeMTV_BoxBox(a, b, nx, ny, nz, penetration);
    }
    if(typeA == SHAPE_SPHERE && typeB == SHAPE_SPHERE){
        ComputeMTV_SphereSphere(a, b, nx, ny, nz, penetration);
    }
    if(typeA == SHAPE_SPHERE && typeB == SHAPE_AABB){
        ComputeMTV_SphereBox(a, b, nx, ny, nz, penetration);
    }
    if(typeA == SHAPE_AABB && typeB == SHAPE_SPHERE){
        ComputeMTV_SphereBox(b, a, nx, ny, nz, penetration);
        nx = -nx;
        ny = -ny;
        nz = -nz;
    }
}


void PhysicsSystem::ComputeMTV_BoxBox(
    uint32_t a, uint32_t b,
    float& nx, float& ny, float& nz,
    float& penetration)
{
    float dx = pos_x[a] - pos_x[b];
    float px = (extent_x[a] + extent_x[b]) - fabs(dx);

    float dy = pos_y[a] - pos_y[b];
    float py = (extent_y[a] + extent_y[b]) - fabs(dy);

    float dz = pos_z[a] - pos_z[b];
    float pz = (extent_z[a] + extent_z[b]) - fabs(dz);

    penetration = px;
    nx = (dx > 0.0f) ? 1.0f : -1.0f;
    ny = nz = 0.0f;

    if (py < penetration) {
        penetration = py;
        nx = nz = 0.0f;
        ny = (dy > 0.0f) ? 1.0f : -1.0f;
    }

    if (pz < penetration) {
        penetration = pz;
        nx = ny = 0.0f;
        nz = (dz > 0.0f) ? 1.0f : -1.0f;
    }
}

void PhysicsSystem::ComputeMTV_SphereBox(
    uint32_t sphere, uint32_t box,
    float& nx, float& ny, float& nz,
    float& penetration)
{
    float cx = pos_x[sphere];
    float cy = pos_y[sphere];
    float cz = pos_z[sphere];

    float bx = pos_x[box];
    float by = pos_y[box];
    float bz = pos_z[box];

    float hx = extent_x[box];
    float hy = extent_y[box];
    float hz = extent_z[box];

    // 最近点
    float closestX = clamp(cx, bx - hx, bx + hx);
    float closestY = clamp(cy, by - hy, by + hy);
    float closestZ = clamp(cz, bz - hz, bz + hz);

    float dx = cx - closestX;
    float dy = cy - closestY;
    float dz = cz - closestZ;

    float distSq = dx*dx + dy*dy + dz*dz;
    float r = extent_x[sphere];

    if (distSq > r * r) return;

    float dist = sqrt(distSq);
    if (dist > 1e-6f) {
        nx = dx / dist;
        ny = dy / dist;
        nz = dz / dist;
    } else {
        // 球心在盒子内部，退化情况
        nx = 1.0f; ny = nz = 0.0f;
    }

    penetration = r - dist;
}

void PhysicsSystem::ComputeMTV_SphereSphere(
    uint32_t a, uint32_t b,
    float& nx, float& ny, float& nz,
    float& penetration)
{
    float dx = pos_x[a] - pos_x[b];
    float dy = pos_y[a] - pos_y[b];
    float dz = pos_z[a] - pos_z[b];

    float distSq = dx*dx + dy*dy + dz*dz;
    float r = extent_x[a] + extent_x[b];

    if (distSq >= r * r) return;

    float dist = sqrt(distSq);
    if (dist > 1e-6f) {
        nx = dx / dist;
        ny = dy / dist;
        nz = dz / dist;
    } else {
        nx = 1.0f; ny = nz = 0.0f;
    }

    penetration = r - dist;
    return;
}


void PhysicsSystem::PositionalCorrection(
    uint32_t a, uint32_t b,
    float nx, float ny, float nz,
    float penetration)
{
    const float percent = 0.8f;   // 修正比例
    const float slop = 0.01f;     // 容忍穿透

    float invMassA = isStatic[a] ? 0.0f : 1.0f / mass[a];
    float invMassB = isStatic[b] ? 0.0f : 1.0f / mass[b];

    float invMassSum = invMassA + invMassB;
    if (invMassSum == 0.0f) return;

    float correction = fmax(penetration - slop, 0.0f)
                       / invMassSum * percent;
    OH_LOG_INFO(LOG_APP,"PositionCorrection::correction:%{public}f ",correction);
    pos_x[a] += nx * correction * invMassA;
    pos_y[a] += ny * correction * invMassA;
    pos_z[a] += nz * correction * invMassA;
    
    
    pos_x[b] -= nx * correction * invMassB;
    pos_y[b] -= ny * correction * invMassB;
    pos_z[b] -= nz * correction * invMassB;

}

// 辅助函数
void PhysicsSystem::clearForce(uint32_t id) 
{
    force_x[id] = 0;
    force_y[id] = 0;
    force_z[id] = 0;
}

// 注册函数

napi_value PhysicsSystem::Init(napi_env env, napi_value exports) 
{
    napi_property_descriptor properties[] = {
        { "addNode", nullptr, AddNode, nullptr, nullptr, nullptr, napi_default, nullptr},
        { "update", nullptr, Update, nullptr, nullptr, nullptr, napi_default, nullptr},
        { "setPosition", nullptr, SetPosition, nullptr, nullptr, nullptr, napi_default, nullptr},
        { "setRotation", nullptr, PhysicsSystem::SetRotation, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "setVelocity", nullptr, PhysicsSystem::SetVelocity, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "setAcceleration", nullptr, PhysicsSystem::SetAcceleration, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "setForce", nullptr, PhysicsSystem::SetForce, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "setScale", nullptr, PhysicsSystem::SetScale, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "setExtent", nullptr, PhysicsSystem::SetExtent, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "setMass", nullptr, PhysicsSystem::SetMass, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "setRestitution", nullptr, PhysicsSystem::SetRestitution, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "setFriction", nullptr, PhysicsSystem::SetFriction, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "setShapeType", nullptr, PhysicsSystem::SetShapeType, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "setIsStatic", nullptr, PhysicsSystem::SetIsStatic, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "getMass", nullptr, PhysicsSystem::GetMass, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "getVel", nullptr, PhysicsSystem::GetVel, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "getAcc", nullptr, PhysicsSystem::GetAcc, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "getFric", nullptr, PhysicsSystem::GetFric, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "getNormal", nullptr, PhysicsSystem::GetNormal, nullptr, nullptr, nullptr, napi_default, nullptr},
        
    };
    
    napi_value cons;
    napi_define_class(env, "PhysicsSystem", NAPI_AUTO_LENGTH, New, nullptr, 19, properties, &cons);

    napi_set_named_property(env, exports, "PhysicsSystem", cons);
    return exports;
}