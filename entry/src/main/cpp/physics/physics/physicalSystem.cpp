//
// Created on 2026/2/4.
//
// Node APIs are not fully supported. To solve the compilation error of the interface cannot be found,
// please include "napi/native_api.h".
#include <cassert>
#include <cstdint>
#include <hilog/log.h>
#include <string>
#include "Inertial.h"
#include "physicalSystem.h"
#include "buffer.h"
#include "collision.h"
#include "napi_helpers.h"
#include "vec.h"

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

    ALLOC_FLOAT(angVel_x)
    ALLOC_FLOAT(angVel_y)
    ALLOC_FLOAT(angVel_z)

    ALLOC_FLOAT(force_x)
    ALLOC_FLOAT(force_y)
    ALLOC_FLOAT(force_z)

    ALLOC_FLOAT(torque_x)
    ALLOC_FLOAT(torque_y)
    ALLOC_FLOAT(torque_z)

    ALLOC_FLOAT(impulse_x)
    ALLOC_FLOAT(impulse_y)
    ALLOC_FLOAT(impulse_z)

    ALLOC_FLOAT(invInertial_xx)
    ALLOC_FLOAT(invInertial_yy)
    ALLOC_FLOAT(invInertial_zz)

    ALLOC_FLOAT(scale_x)
    ALLOC_FLOAT(scale_y)
    ALLOC_FLOAT(scale_z)
    // bounds
    ALLOC_FLOAT(extent_x)
    ALLOC_FLOAT(extent_y)
    ALLOC_FLOAT(extent_z)

    // material
    ALLOC_FLOAT(invMass)
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
    if(m < 1e-6) {
        invMass[id] = INFINITY;
    }else {
        invMass[id] = 1 / m;
    }
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
    return 1 / invMass[id];
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

napi_value PhysicsSystem::RayCast(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1];
    napi_value jsThis;
    napi_get_cb_info(env, info, &argc, argv, &jsThis, nullptr);
    
    napi_value touch_pos_val = argv[0];
    Vector2 touch_pos = napi_helpers::parse_vector2(env, touch_pos_val);
    
    Vector3 cameraPos = Vector3(0.0,0.0,-4.0);
    Vector3 front = Vector3(0.0,0.0,1.0);
    Vector3 up = Vector3(0.0,1.0,0.0);
    Vector3 right = Vector3(1.0,0.0,0.0);
    Vector3 virtual_pos = (up * touch_pos.y + right * touch_pos.x) * (- cameraPos.z);
    Vector3 dir = (virtual_pos - cameraPos).normalized();
    
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
    detectCollisions();

    buildContacts();

    solveContacts();

    integrateVelocity(dt);

    positionalCorrection();

    integratePosition(dt);
}

void PhysicsSystem::detectCollisions() {
    possiblePairs.clear();
    for(uint32_t i = 0 ; i < count; ++i){
        for(uint32_t j = i + 1 ; j < count; ++j){
            if(isStatic[i] && isStatic[j]) continue;
            if(testCollision(i, j)){
                OH_LOG_INFO(LOG_APP, "YES");
                possiblePairs.emplace_back(i,j);
            }
        }
    }
}
void PhysicsSystem::buildContacts() {
    contact.clear();
    for(auto& pair : possiblePairs)
    {
        uint32_t idA = pair.first;
        uint32_t idB = pair.second;
        Contact c;
        c.a = idA;
        c.b = idB;
        ContactDispatch::dispatch(*this, idA, idB,c);
        contact.emplace_back(c);
    }
}
void PhysicsSystem::solveContacts() {
    for(const auto&c : contact){
        uint32_t a = c.a;
        uint32_t b = c.b;
        
        // 法向冲量
        float nx = c.normal.x;
        float ny = c.normal.y;
        float nz = c.normal.z;
        
        // 相对位置 r = contactPoint - pos
        float rax = c.point.x - pos_x[a];
        float ray = c.point.y - pos_y[a];
        float raz = c.point.z - pos_z[a];

        float rbx = c.point.x - pos_x[b];
        float rby = c.point.y - pos_y[b];
        float rbz = c.point.z - pos_z[b];
        
         // 速度差 v_rel = (v_b + ω_b × r_b) - (v_a + ω_a × r_a)
        float cross_ax = angVel_y[a]*raz - angVel_z[a]*ray;
        float cross_ay = angVel_z[a]*rax - angVel_x[a]*raz;
        float cross_az = angVel_x[a]*ray - angVel_y[a]*rax;

        float va_rel_x = vel_x[b] + (angVel_y[b]*rbz - angVel_z[b]*rby) - (vel_x[a] + cross_ax);
        float va_rel_y = vel_y[b] + (angVel_z[b]*rbx - angVel_x[b]*rbz) - (vel_y[a] + cross_ay);
        float va_rel_z = vel_z[b] + (angVel_x[b]*rby - angVel_y[b]*rbx) - (vel_z[a] + cross_az);

        // 冲量大小 j = -(1 + e) * (v_rel ⋅ n) / (1/m_a + 1/m_b + ...旋转项略)
        float relVelAlongNormal = va_rel_x*nx + va_rel_y*ny + va_rel_z*nz;
        float e = std::min(restitution[a], restitution[b]);
        float invMassSum = invMass[a] + invMass[b]; // 这里暂时忽略角动量的转动影响
        float j = -(1.0f + e) * relVelAlongNormal / invMassSum;

        // 线性冲量累加
        float impulseX = j * nx;
        float impulseY = j * ny;
        float impulseZ = j * nz;

        impulse_x[a] -= impulseX;
        impulse_y[a] -= impulseY;
        impulse_z[a] -= impulseZ;

        impulse_x[b] += impulseX;
        impulse_y[b] += impulseY;
        impulse_z[b] += impulseZ;

        // 角冲量累加: τ = r × J
        torque_x[a] -= ray*impulseZ - raz*impulseY;
        torque_y[a] -= raz*impulseX - rax*impulseZ;
        torque_z[a] -= rax*impulseY - ray*impulseX;

        torque_x[b] += rby*impulseZ - rbz*impulseY;
        torque_y[b] += rbz*impulseX - rbx*impulseZ;
        torque_z[b] += rbx*impulseY - rby*impulseX;
    }
}
void PhysicsSystem::integrateVelocity(float dt) {
    for (uint32_t i = 0; i < count; ++i)
    {
        if (isStatic[i]){
            vel_x[i] = 0.0f;
            vel_y[i] = 0.0f;
            vel_z[i] = 0.0f;

            angVel_x[i] = 0.0f;
            angVel_y[i] = 0.0f;
            angVel_z[i] = 0.0f;
            continue;
        }
        
        // --- 线性冲量积分 ---
        impulse_x[i] += force_x[i] * dt;
        impulse_y[i] += force_y[i] * dt;
        impulse_z[i] += force_z[i] * dt;

        vel_x[i] += impulse_x[i] * invMass[i];
        vel_y[i] += impulse_y[i] * invMass[i];
        vel_z[i] += impulse_z[i] * invMass[i];
    
//        OH_LOG_INFO(LOG_APP, 
//            "i=%{public}u vel=(%{public}.3f, %{public}.3f, %{public}.3f) impulse=(%{public}.3f, %{public}.3f, %{public}.3f) "
//            "force=(%{public}.3f, %{public}.3f, %{public}.3f)",
//            i,
//            vel_x[i], vel_y[i], vel_z[i],
//            impulse_x[i], impulse_y[i], impulse_z[i],
//            force_x[i], force_y[i], force_z[i]
//        );
        // --- 线性阻尼 ---
        float linearDamp = std::max(0.0f, 1.0f - friction[i] * dt);
        vel_x[i] *= linearDamp;
        vel_y[i] *= linearDamp;
        vel_z[i] *= linearDamp;

        // --- 角冲量积分 ---
        angVel_x[i] += torque_x[i] * invInertial_xx[i] * dt;
        angVel_y[i] += torque_y[i] * invInertial_yy[i] * dt;
        angVel_z[i] += torque_z[i] * invInertial_zz[i] * dt;

        // --- 角阻尼 ---
        float angularDamp = std::max(0.0f, 1.0f - friction[i] * dt);
        angVel_x[i] *= angularDamp;
        angVel_y[i] *= angularDamp;
        angVel_z[i] *= angularDamp;
    }

    clearForceAll();
}
void PhysicsSystem::positionalCorrection(){
    const float k_slop = 0.01f;      // 容差，防止 jitter
    const float percent = 0.8f;      // 修正比例，0~1

    for (const auto& c : contact)
    {
        uint32_t a = c.a;
        uint32_t b = c.b;

        if (isStatic[a] && isStatic[b])
            continue; // 两个静态物体不修正

        // 修正量 = penetration - 容差
        float penetration = std::max(c.penetration - k_slop, 0.0f);
        if (penetration <= 0.0f)
            continue;

        // 质量比例分配
        float invMassA = isStatic[a] ? 0.0f : invMass[a];
        float invMassB = isStatic[b] ? 0.0f : invMass[b];
        float invMassSum = invMassA + invMassB;
        if (invMassSum == 0.0f) 
            continue;

        float correction = (penetration / invMassSum) * percent;

        float dx = c.normal.x * correction;
        float dy = c.normal.y * correction;
        float dz = c.normal.z * correction;

        // 应用到物体位置
        if (!isStatic[a])
        {
            pos_x[a] -= dx * invMassA;
            pos_y[a] -= dy * invMassA;
            pos_z[a] -= dz * invMassA;
        }

        if (!isStatic[b])
        {
            pos_x[b] += dx * invMassB;
            pos_y[b] += dy * invMassB;
            pos_z[b] += dz * invMassB;
        }
    }
}
void PhysicsSystem::integratePosition(float dt)
{
    for (uint32_t i = 0; i < count; ++i)
    {
        if (isStatic[i])
            continue;

        // --- 1. 更新位置 ---
        pos_x[i] += vel_x[i] * dt;
        pos_y[i] += vel_y[i] * dt;
        pos_z[i] += vel_z[i] * dt;

        // --- 2. 更新旋转（四元数） ---
        // 构造角速度四元数 ω_quat = (0, ωx, ωy, ωz)
        float wx = angVel_x[i];
        float wy = angVel_y[i];
        float wz = angVel_z[i];

        float qx = rot_x[i];
        float qy = rot_y[i];
        float qz = rot_z[i];
        float qw = rot_w[i];

        // 四元数更新公式: q_new = q + 0.5 * dt * ω_quat * q
        float half_dt = 0.5f * dt;

        float nx =  half_dt * ( wx*qw + wy*qz - wz*qy );
        float ny =  half_dt * (-wx*qz + wy*qw + wz*qx );
        float nz =  half_dt * ( wx*qy - wy*qx + wz*qw );
        float nw =  half_dt * (-wx*qx - wy*qy - wz*qz );

        qx += nx;
        qy += ny;
        qz += nz;
        qw += nw;

        // 归一化四元数
        float norm = std::sqrt(qx*qx + qy*qy + qz*qz + qw*qw);
        rot_x[i] = qx / norm;
        rot_y[i] = qy / norm;
        rot_z[i] = qz / norm;
        rot_w[i] = qw / norm;
    }
}

void PhysicsSystem::clearForceAll() {
    for(uint32_t i = 0 ; i < count; i++){
        force_x[i] = 0.0f;
        force_y[i] = 0.0f;
        force_z[i] = 0.0f;
        
        impulse_x[i] = 0.0f;
        impulse_y[i] = 0.0f;
        impulse_z[i] = 0.0f;
        
        torque_x[i] = 0.0f;
        torque_y[i] = 0.0f;
        torque_z[i] = 0.0f;
        
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

Body PhysicsSystem::getBody(uint32_t id) {
    Body b;
    b.type = static_cast<ShapeType>(shapeType[id]);
    b.pos = {pos_x[id], pos_y[id], pos_z[id]};
    b.extent = {extent_x[id],extent_y[id],extent_z[id]};
    b.rot = {rot_x[id], rot_y[id], rot_z[id], rot_w[id]};
    b.vel = {vel_x[id], vel_y[id], vel_z[id]};
    b.angVel = {angVel_x[id], angVel_y[id], angVel_z[id]};
    b.extent = {extent_x[id], extent_y[id], extent_z[id]};
    b.invMass = invMass[id];
    b.invInertia = Matrix3(
        invInertial_xx[id],0,0,
        0,invInertial_yy[id],0,
        0,0,invInertial_zz[id]
    );
    b.invInertialWorld = computeInvInertiaWorld(b.invInertia, b.rot);
    return b;
}

bool PhysicsSystem::testCollision(uint32_t a, uint32_t b)
{
    return CollisionDispatch::dispatch(*this,a, b);
}

// 辅助函数
void PhysicsSystem::clearForce(uint32_t id) 
{
    force_x[id] = 0;
    force_y[id] = 0;
    force_z[id] = 0;
    torque_x[id] = 0;
    torque_y[id] = 0;
    torque_z[id] = 0;
    impulse_x[id] = 0;
    impulse_y[id] = 0;
    impulse_z[id] = 0;
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
        { "getFric", nullptr, PhysicsSystem::GetFric, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "getNormal", nullptr, PhysicsSystem::GetNormal, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    
    napi_value cons;
    napi_define_class(env, "PhysicsSystem", NAPI_AUTO_LENGTH, New, nullptr, 17, properties, &cons);

    napi_set_named_property(env, exports, "PhysicsSystem", cons);
    return exports;
}