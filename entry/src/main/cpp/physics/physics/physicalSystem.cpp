//
// Created on 2026/2/4.
//
// Node APIs are not fully supported. To solve the compilation error of the interface cannot be found,
// please include "napi/native_api.h".
#include <cassert>
#include <cstdint>
#include <hilog/log.h>
#include <string>
#include <cmath>
#include <algorithm>
#include "Inertial.h"
#include "physicalSystem.h"
#include "buffer.h"
#include "collision.h"
#include "napi_helpers.h"
#include "vec.h"
#include "shape.h"

// 对齐到64空间
static size_t alignCapacity(size_t v) {
    return (v + 63) & ~63; //对齐到 64
}

// 结构体新建入口
napi_value PhysicsSystem::New(napi_env env, napi_callback_info info) 
{
    OH_LOG_INFO(LOG_APP, "PhysicsSystem::New called");
    
    napi_value newTarget;
    // 用于判断是否使用了 new 来进行构造
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
        // 判断是否传入了容量初始化值
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

napi_value PhysicsSystem::Release(napi_env env, napi_callback_info info){
    OH_LOG_INFO(LOG_APP,"NAPI RELEASE");
    size_t argc = 0;
    napi_value jsThis;
    napi_get_cb_info(env, info, &argc, nullptr, &jsThis, nullptr);
    
    PhysicsSystem* obj;
    napi_unwrap(env, jsThis, reinterpret_cast<void**>(&obj));

    obj->ReleaseScene();
    return nullptr;
}

// 初始化获取足够的内存空间
PhysicsSystem::PhysicsSystem(size_t cap)
    : count(0), env_(nullptr), wrapper_(nullptr), gravity(Vector3(0.0f,0.0f,0.0f)), cameraPos(Vector3(0.0f,0.0f,-6.0f)), fov(1.57f),ratio(1.0f)
{
    initHandlers();
    capacity = alignCapacity(cap);
    free_list.reserve(capacity);
    for (int32_t i = capacity-1; i >= 0; i--) {
        free_list.push_back(static_cast<uint32_t>(i));
    }
    
    // 计算 float / int / byte 数量
    const size_t floatCount =
        3  +  4  +  3  +   3    +   3   +   3
    // pos + rot + vel + angVel + force + torque
    +   3  +  3 +  + 3 + 3 + 3  +  3 + 3
    // impulse + invInertial + scale + scale + extent + base_extent + material
    +   4  +  2; // restRot(4) + rotSpringK/D(2)

    size_t bytes =
        capacity * (
            floatCount * sizeof(float) +
            sizeof(int32_t) +   // shapeType
            sizeof(uint8_t) +   // isStatic
            sizeof(uint8_t)     // canRotate
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

    ALLOC_FLOAT(scale_x)
    ALLOC_FLOAT(scale_y)
    ALLOC_FLOAT(scale_z)

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


    // bounds
    ALLOC_FLOAT(extent_x)
    ALLOC_FLOAT(extent_y)
    ALLOC_FLOAT(extent_z)

    // base bounds
    ALLOC_FLOAT(base_extent_x)
    ALLOC_FLOAT(base_extent_y)
    ALLOC_FLOAT(base_extent_z)

    // material
    ALLOC_FLOAT(invMass)
    ALLOC_FLOAT(restitution)
    ALLOC_FLOAT(friction)

    // flags
    ALLOC_INT(shapeType)
    ALLOC_BYTE(isStatic)
    ALLOC_BYTE(canRotate)
    
    // 旋转弹簧系统
    ALLOC_FLOAT(restRot_x)
    ALLOC_FLOAT(restRot_y)
    ALLOC_FLOAT(restRot_z)
    ALLOC_FLOAT(restRot_w)
    ALLOC_FLOAT(rotSpringK)
    ALLOC_FLOAT(rotSpringD)
    
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
        occupyList[id] = true;
        valid_list.push_back(id);
        free_list.pop_back();
        count++;
    } else {
        assert("Exceed capacity");
    }
    return id;
}

bool PhysicsSystem::removeNodeId(uint32_t id) {
    if(!occupyList.count(id) || !occupyList[id]) return false;
    occupyList[id] = false;
    auto it = std::find(valid_list.begin(), valid_list.end(), id);
    if(it != valid_list.end()){
        valid_list.erase(it);
    }
    free_list.push_back(id);
    count--;
    return true;
}

// 结构体销毁入口
void PhysicsSystem::Destructor(napi_env env, void *nativeObject, [[maybe_unused]] void *finalize_hint)
{
    OH_LOG_INFO(LOG_APP,"PhysicsSystem::Destructor called");
            // 清理布局系统
    PhysicsSystem* obj = reinterpret_cast<PhysicsSystem*>(nativeObject);
    if (obj->layoutManager) {
        delete obj->layoutManager;
        obj->layoutManager = nullptr;
    }
    delete obj;
}

// buffer数据销毁的入口
void FinalizeCallback(napi_env env, void *finalize_data, void *finalize_hint)
{
    FloatBuffer *bufferData = static_cast<FloatBuffer *>(finalize_hint);
    delete bufferData;
}

// 步进模拟函数
napi_value PhysicsSystem::Update(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value argv[2];
    napi_value jsThis;
    napi_get_cb_info(env, info, &argc, argv, &jsThis, nullptr);
    
    auto eventQueue = parseEventQueue(env, argv[0]);
    
    napi_value time_val = argv[1];
    double d;
    napi_get_value_double(env, time_val, &d);
    
    PhysicsSystem* obj;
    napi_unwrap(env, jsThis, reinterpret_cast<void**>(&obj));
    obj->clearEventResults();
    obj->processEventQueueFromJS(eventQueue);
    obj->step(static_cast<float>(d));
    napi_value bufferData = obj->update(env, info);
    napi_value eventResult_v = obj->getEventResults(env);
        // 创建返回对象
    napi_value returnObj;
    napi_create_object(env, &returnObj);

    // bufferData
    napi_set_named_property(env, returnObj, "bufferData", bufferData);

    // results
    napi_set_named_property(env, returnObj, "results", eventResult_v);

    return returnObj;
}



// 处理 ArkTS 传递的事件队列
void PhysicsSystem::processEventQueueFromJS(const std::vector<std::vector<EventCommand>> &events) {
//    OH_LOG_INFO(LOG_APP,"EVENTCOMMAND | START %{public}d", events.size());
    // 按优先级处理事件（HIGH → NORMAL → LOW）
    for (const auto& queue : events) {       // 外层队列
//        OH_LOG_INFO(LOG_APP,"EVENTCOMMAND | MID %{public}d", queue.size());
        for (const auto& event : queue) {    // 内层事件
            auto func = handlers[static_cast<uint8_t>(event.type)];
            if (func) {
//                OH_LOG_INFO(LOG_APP,"EVENTCOMMAND | %{public}d",static_cast<uint8_t>(event.type));
                if(static_cast<uint8_t>(event.type) == 103){
                    const double * values = reinterpret_cast<const double *>(event.data.data());
//                    OH_LOG_INFO(LOG_APP,"ANGLE C++ IS %{public}.3f, %{public}.3f, %{public}.3f",values[0], values[1],values[2]);
                }
                (this->*func)(event);
            }
        }
    }
}

// 射线-AABB 相交测试（slab 方法）
inline bool raycastAABB(
    const Vector3& origin,
    const Vector3& dir,
    const Vector3& center,
    const Vector3& halfExtent,
    double& tmin,
    double& tmax
) {
    tmin = 0.0;
    tmax = FLT_MAX;

    Vector3 bmin(center.x - halfExtent.x, center.y - halfExtent.y, center.z - halfExtent.z);
    Vector3 bmax(center.x + halfExtent.x, center.y + halfExtent.y, center.z + halfExtent.z);

    for (int i = 0; i < 3; i++) {
        double o = origin[i];
        double d = dir[i];

        if (std::abs(d) < 1e-8) {
            // 射线平行于 slab
            if (o < bmin[i] || o > bmax[i]) {
                return false;
            }
        } else {
            double t1 = (bmin[i] - o) / d;
            double t2 = (bmax[i] - o) / d;

            if (t1 > t2) std::swap(t1, t2);

            tmin = std::max(tmin, t1);
            tmax = std::min(tmax, t2);

            if (tmin > tmax) {
                return false;
            }
        }
    }

    return true;
}

// 获取 OBB 的三个轴（从四元数旋转）
inline void getOBBAxis(
    const Quaternion& rot,
    Vector3 axis[3])
{
    float xx = rot.x * rot.x;
    float yy = rot.y * rot.y;
    float zz = rot.z * rot.z;

    float xy = rot.x * rot.y;
    float xz = rot.x * rot.z;
    float yz = rot.y * rot.z;

    float wx = rot.w * rot.x;
    float wy = rot.w * rot.y;
    float wz = rot.w * rot.z;

    axis[0] = Vector3(
        1.0f - 2.0f * (yy + zz),
        2.0f * (xy + wz),
        2.0f * (xz - wy)
    );

    axis[1] = Vector3(
        2.0f * (xy - wz),
        1.0f - 2.0f * (xx + zz),
        2.0f * (yz + wx)
    );

    axis[2] = Vector3(
        2.0f * (xz + wy),
        2.0f * (yz - wx),
        1.0f - 2.0f * (xx + yy)
    );
}

// 射线 - 球体相交测试
inline bool raycastSphere(
    const Vector3& origin,
    const Vector3& dir,
    const Vector3& center,
    float radius,
    double& t)
{
    Vector3 oc = origin - center;
    double a = dir.dot(dir);
    double b = 2.0 * oc.dot(dir);
    double c = oc.dot(oc) - static_cast<double>(radius) * static_cast<double>(radius);

    double discriminant = b * b - 4.0 * a * c;
    if (discriminant < 0) return false;

    double sqrtDisc = std::sqrt(discriminant);
    double t0 = (-b - sqrtDisc) / (2.0 * a);
    double t1 = (-b + sqrtDisc) / (2.0 * a);

    if (t0 > 0) { t = t0; return true; }
    if (t1 > 0) { t = t1; return true; }
    return false;
}

// 射线-OBB 相交测试（变换到局部空间后用 slab 方法）
inline bool raycastOBB(
    const Vector3& origin,
    const Vector3& dir,
    const Vector3& center,
    const Quaternion& rotation,
    const Vector3& halfExtent,
    double& t)
{
    // 计算 OBB 的三个轴
    Vector3 axis[3];
    getOBBAxis(rotation, axis);

    // 将射线变换到 OBB 局部空间
    Vector3 p = origin - center;
    Vector3 localOrigin;
    localOrigin.x = p.dot(axis[0]);
    localOrigin.y = p.dot(axis[1]);
    localOrigin.z = p.dot(axis[2]);

    Vector3 localDir;
    localDir.x = dir.dot(axis[0]);
    localDir.y = dir.dot(axis[1]);
    localDir.z = dir.dot(axis[2]);

    // 使用 slab 方法在局部空间进行射线-AABB 测试
    double tmin = 0.0, tmax = FLT_MAX;

    for (int i = 0; i < 3; i++) {
        double o = localOrigin[i];
        double d = localDir[i];
        float e = static_cast<float>(halfExtent[i]);

        if (std::abs(d) < 1e-8) {
            // 射线平行于 slab
            if (o < -e || o > e) return false;
        } else {
            double t1 = (-e - o) / d;
            double t2 = (e - o) / d;
            if (t1 > t2) std::swap(t1, t2);
            tmin = std::max(tmin, t1);
            tmax = std::min(tmax, t2);
            if (tmin > tmax) return false;
        }
    }
    OH_LOG_INFO(LOG_APP,"T_CHECK %{public}.3f %{public}.3f",tmin, tmax);
    t = tmin;
    return tmin >= 0;
}

// 处理 Raycast 请求 - 根据 shapeType 选择精确的射线检测
void PhysicsSystem::processRaycast(float touchX, float touchY) {
    Vector3 up = Vector3(0.0, 1.0, 0.0);
    Vector3 right = Vector3(-1.0, 0.0, 0.0);

    // 将屏幕坐标转换为世界空间射线方向
    Vector3 virtual_pos = (up * touchY + right * touchX * ratio) * (-cameraPos.z * std::tan(fov / 2));
    OH_LOG_INFO(LOG_APP,"tan fov is %{public}.3f fov is %{public}.3f ratio is %{public}", std::tan(fov / 2),fov / 2, ratio);
    Vector3 rayDir = (virtual_pos - cameraPos).normalized();
    
    uint32_t closestId = capacity;
    double closestT = FLT_MAX;
//    setPosition(6, 2 * rayDir + cameraPos);
//    OH_LOG_INFO(LOG_APP,"RAYTEST | POS %{public}.3f %{public}.3f", virtual_pos.y, virtual_pos.x);
    // 遍历所有物体
    for (uint32_t k = 0; k < count; ++k) {
        uint32_t i = valid_list[k];
//        if (isStatic[i]) continue;

        if(i == 6) continue;
        Vector3 center(pos_x[i], pos_y[i], pos_z[i]);
        double t_2;
        bool hit = false;

        // 根据 shapeType 选择检测函数
        switch (shapeType[i]) {
            case SHAPE_SPHERE: {
                // 球体：使用 extent_x 作为半径
                float radius = extent_x[i];
                OH_LOG_INFO(LOG_APP, "Raycast hit test | cameraPos:%{public}.3f , %{public}.3f, %{public}.3f \n rayDir : %{public}.3f, %{public}.3f, %{public}.3f, \n center: %{public}.3f,%{public}.3f,%{public}.3f "
                            , cameraPos.x, cameraPos.y, cameraPos.z, rayDir.x, rayDir.y, rayDir.z, center.x, center.y, center.z);
                hit = raycastSphere(cameraPos, rayDir, center, radius, t_2);
                break;
            }
            case SHAPE_BOX: {
                // OBB：使用旋转和半长轴
                double t = (-1.0 - cameraPos.z) / rayDir.z;
                Vector3 result;    
                result.x = cameraPos.x + t * rayDir.x;
                result.y = cameraPos.y + t * rayDir.y;
                result.z = -1.0;
//                pos_x[2] = result.x;
//                pos_y[2] = result.y;
//                pos_z[2] = result.z;
                Vector3 halfExtent(extent_x[i], extent_y[i], extent_z[i]);
                Quaternion rot(rot_x[i], rot_y[i], rot_z[i], rot_w[i]);
                OH_LOG_INFO(LOG_APP, "Raycast hit test | cameraPos:%{public}.3f , %{public}.3f, %{public}.3f \n rayDir : %{public}.3f, %{public}.3f, %{public}.3f, \n center: %{public}.3f,%{public}.3f,%{public}.3f \n broad: %{public}.3f,%{public}.3f,%{public}.3f \n result: %{public}.3f,%{public}.3f,%{public}.3f "
                , cameraPos.x, cameraPos.y, cameraPos.z, rayDir.x, rayDir.y, rayDir.z, center.x , center.y, center.z, halfExtent.x, halfExtent.y, halfExtent.z,result.x,result.y,result.z);
                hit = raycastOBB(cameraPos, rayDir, center, rot, halfExtent, t_2);
                break;
            }
            default:
                break;
        }

        if (hit && t_2 > 0 && t_2 < closestT) {
//            OH_LOG_INFO(LOG_APP,"HIT ID:%{public}d %{public}.3f %{public}.3f", i,t_2,closestT);
            closestT = t_2;
            closestId = i;
        }
    }

    // 保存选中的节点 ID
//    selectedNodeId_ = closestId;

    if (closestId != capacity) {

        OH_LOG_INFO(LOG_APP,
        "Raycast hit node id=%{public}u at t=%{public}f",
        closestId, closestT);

        EventResult result;

        result.type = EventType::RAYCAST_REQUEST;
        result.nodeId = closestId;
        result.timestamp = 0; // 你自己的函数
        result.status = 1;

        result.data.reserve(4);

        // data[0] nodeId
        result.data.push_back(static_cast<uint64_t>(closestId));

        // data[1] distance
        uint64_t raw;
        double d = closestT;
        std::memcpy(&raw, &d, sizeof(double));
        result.data.push_back(raw);

        // data[2..4] hit position
        Vector3 hitPos = cameraPos + rayDir * closestT;

        double v;

        v = hitPos.x;
        std::memcpy(&raw, &v, sizeof(double));
        result.data.push_back(raw);

        v = hitPos.y;
        std::memcpy(&raw, &v, sizeof(double));
        result.data.push_back(raw);

        v = hitPos.z;
        std::memcpy(&raw, &v, sizeof(double));
        result.data.push_back(raw);

        eventResults.push_back(result);

    } else {

        OH_LOG_INFO(LOG_APP, "Raycast hit test miss");

    }
}

// 处理 Rotate 请求 - 旋转选中的节点
//void PhysicsSystem::processRotate(float deltaX, float deltaY) {
//    if (selectedNodeId_ == 0) return;
//
//    const float ROTATE_SPEED = 0.05f;
//
//    // 获取当前旋转（四元数）
//    float qx = rot_x[selectedNodeId_];
//    float qy = rot_y[selectedNodeId_];
//    float qz = rot_z[selectedNodeId_];
//    float qw = rot_w[selectedNodeId_];
//
//    // 根据 deltaX 创建绕 Y 轴的旋转（Yaw）
//    float yawAngle = deltaX * ROTATE_SPEED;
//    float yawHalf = yawAngle * 0.5f;
//    float yawSin = std::sin(yawHalf);
//    float yawCos = std::cos(yawHalf);
//
//    Quaternion deltaYaw(0.0f, yawSin, 0.0f, yawCos);
//
//    // 根据 deltaY 创建绕 X 轴的旋转（Pitch）
//    float pitchAngle = deltaY * ROTATE_SPEED;
//    float pitchHalf = pitchAngle * 0.5f;
//    float pitchSin = std::sin(pitchHalf);
//    float pitchCos = std::cos(pitchHalf);
//
//    Quaternion deltaPitch(pitchSin, 0.0f, 0.0f, pitchCos);
//
//    // 组合旋转：delta = deltaPitch * deltaYaw
//    Quaternion deltaRot;
//    deltaRot.w = deltaPitch.w * deltaYaw.w - deltaPitch.x * deltaYaw.x -
//                 deltaPitch.y * deltaYaw.y - deltaPitch.z * deltaYaw.z;
//    deltaRot.x = deltaPitch.w * deltaYaw.x + deltaPitch.x * deltaYaw.w +
//                 deltaPitch.y * deltaYaw.z - deltaPitch.z * deltaYaw.y;
//    deltaRot.y = deltaPitch.w * deltaYaw.y - deltaPitch.x * deltaYaw.z +
//                 deltaPitch.y * deltaYaw.w + deltaPitch.z * deltaYaw.x;
//    deltaRot.z = deltaPitch.w * deltaYaw.z + deltaPitch.x * deltaYaw.y -
//                 deltaPitch.y * deltaYaw.x + deltaPitch.z * deltaYaw.w;
//
//    // 新旋转 = deltaRot × 当前旋转
//    float newQx = deltaRot.w * qx + deltaRot.x * qw + deltaRot.y * qz - deltaRot.z * qy;
//    float newQy = deltaRot.w * qy - deltaRot.x * qz + deltaRot.y * qw + deltaRot.z * qx;
//    float newQz = deltaRot.w * qz + deltaRot.x * qy - deltaRot.y * qx + deltaRot.z * qw;
//    float newQw = deltaRot.w * qw - deltaRot.x * qx - deltaRot.y * qy - deltaRot.z * qz;
//
//    // 归一化
//    float norm = std::sqrt(newQx * newQx + newQy * newQy + newQz * newQz + newQw * newQw);
//    if (norm > 1e-6f) {
//        rot_x[selectedNodeId_] = newQx / norm;
//        rot_y[selectedNodeId_] = newQy / norm;
//        rot_z[selectedNodeId_] = newQz / norm;
//        rot_w[selectedNodeId_] = newQw / norm;
//    }
//
//    OH_LOG_INFO(LOG_APP, "Rotate node %{public}u by (%{public}f, %{public}f)",
//                selectedNodeId_, deltaX, deltaY);
//}

napi_value PhysicsSystem::update(napi_env env, napi_callback_info info) 
{
    napi_value result = nullptr;
    
    if(buffer_ref_ != nullptr){
        napi_get_reference_value(env, buffer_ref_, &result);
        return result;
    }
    
    FloatBuffer *bufferData = new FloatBuffer{pos_x, capacity * 10};

    napi_value arrayBuffer;
    napi_status status =
        napi_create_external_arraybuffer(env, pos_x, capacity * 10 * sizeof(float), FinalizeCallback, bufferData, &result);
    if(status != napi_ok) {
        napi_throw_error(env, nullptr, "Node-API napi_create_external_arraybuffer fail");
        return nullptr;
    }

    napi_value outputArray;
    status = napi_create_typedarray(env, napi_float32_array, capacity * 10, result, 0, &outputArray);

    if(status != napi_ok) {
        napi_throw_error(env, nullptr, "Node-API napi_create_typedarray fail");
        return nullptr;
    }

    napi_create_reference(env, outputArray, 1, &buffer_ref_);
    return outputArray;
}

void PhysicsSystem::step(float dt)
{
    // === 自适应子步长 ===
//    int subSteps = computeSubSteps(dt);
    int subSteps = 1;
    float subDt = dt / subSteps;

    for (int i = 0; i < subSteps; ++i)
    {
        // 1. 碰撞检测
        detectCollisions();

        // 2. 构建接触点
        buildContacts();

        // 3. 解算接触点
        solveContacts();

        // 3.5 应用旋转弹簧力矩
        applyRotationSprings(subDt);

        // 4. 速度积分
        integrateVelocity(subDt);

        // 5. 速度限制（防止穿透）
        clampVelocity(subDt);

        // 6. 位置修正
        positionalCorrection();

        // 7. 位置积分
        integratePosition(subDt);
    }
}

// 计算需要的子步数
int PhysicsSystem::computeSubSteps(float dt)
{
    const int MAX_SUB_STEPS = 8;       // 最大子步数限制
    const float SAFETY_FACTOR = 0.4f;  // 安全系数：最大位移 = minExtent * SAFETY_FACTOR

    int maxNeeded = 1;

    for (uint32_t k = 0; k < count; ++k)
    {
        uint32_t i = valid_list[k];
        if (isStatic[i]) continue;

        // 计算速度
        float speed = sqrtf(vel_x[i]*vel_x[i] + vel_y[i]*vel_y[i] + vel_z[i]*vel_z[i]);

        if (speed < 1e-6f) continue;

        // 计算物体最小尺寸
        float minExtent = std::min({extent_x[i], extent_y[i], extent_z[i]});

        // 最大允许位移 = 最小尺寸 * 安全系数
        float maxMove = minExtent * SAFETY_FACTOR;
        if (maxMove < 1e-6f) maxMove = 0.01f;  // 防止太薄的物体

        // 需要的子步数 = ceil(位移 / 最大位移)
        float move = speed * dt;
        int needed = static_cast<int>(ceilf(move / maxMove));

        maxNeeded = std::max(maxNeeded, needed);
    }

    return std::min(maxNeeded, MAX_SUB_STEPS);
}

// 限制速度，防止穿透
void PhysicsSystem::clampVelocity(float dt)
{
    const float SAFETY_FACTOR = 0.4f;

    for (uint32_t k = 0; k < count; ++k)
    {
        uint32_t i = valid_list[k];
        if (isStatic[i]) continue;

        float speed = sqrtf(vel_x[i]*vel_x[i] + vel_y[i]*vel_y[i] + vel_z[i]*vel_z[i]);

        if (speed < 1e-6f) continue;

        // 计算最小尺寸
        float minExtent = std::min({extent_x[i], extent_y[i], extent_z[i]});
        float maxMove = minExtent * SAFETY_FACTOR;
        if (maxMove < 1e-6f) maxMove = 0.01f;

        // 最大允许速度
        float maxSpeed = maxMove / dt;

        if (speed > maxSpeed)
        {
            float scale = maxSpeed / speed;
            vel_x[i] *= scale;
            vel_y[i] *= scale;
            vel_z[i] *= scale;

            OH_LOG_INFO(LOG_APP,
                "Velocity clamped: id=%{public}u, oldSpeed=%{public}.3f, newSpeed=%{public}.3f, minExtent=%{public}.3f",
                i, speed, maxSpeed, minExtent);
        }
    }
}

void PhysicsSystem::detectCollisions() {
    possiblePairs.clear();
    for(uint32_t k = 0 ; k < count; ++k){
        uint32_t i = valid_list[k];
        for(uint32_t l = i + 1 ; l < count; ++l){
            uint32_t j = valid_list[l];
            if(isStatic[i] && isStatic[j]) continue;
            
            // 调试日志：输出每个物体的位置和尺寸
            OH_LOG_INFO(LOG_APP, 
                "Debug: i=%{public}u pos=(%{public}.3f,%{public}.3f,%{public}.3f) extent=(%{public}.3f,%{public}.3f,%{public}.3f) shape=%{public}d static=%{public}d, vel:%{public}.3f %{public}.3f %{public}.3f",
                i, pos_x[i], pos_y[i], pos_z[i], extent_x[i], extent_y[i], extent_z[i], shapeType[i], isStatic[i], vel_x[i], vel_y[i], vel_z[i]);
            OH_LOG_INFO(LOG_APP, 
                "Debug: j=%{public}u pos=(%{public}.3f,%{public}.3f,%{public}.3f) extent=(%{public}.3f,%{public}.3f,%{public}.3f) shape=%{public}d static=%{public}d, vel:%{public}.3f %{public}.3f %{public}.3f",
                j, pos_x[j], pos_y[j], pos_z[j], extent_x[j], extent_y[j], extent_z[j], shapeType[j], isStatic[j], vel_x[j], vel_y[j], vel_z[j]);
            
            if(testCollision(i, j)){
                OH_LOG_INFO(LOG_APP, "CollisionTest: A=%{public}u B=%{public}u",i,j);
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
        OH_LOG_INFO(LOG_APP,"CollisionTest: Contact | A=%{public}u, B=%{public}u, penetration=%{public}f, normalx=%{public}f,normaly=%{public}f,normalz=%{public}f,pointx=%{public}f,pointy=%{public}f,pointz=%{public}f,res=%{public}f",
        idA,idB,c.penetration,c.normal.x,c.normal.y,c.normal.z,c.point.x,c.point.y,c.point.z,c.restitution);
        contact.emplace_back(c);
    }
}
void PhysicsSystem::solveContacts() {
    for(const auto&c : contact){
        uint32_t a = c.a;
        uint32_t b = c.b;

        // 法向
        float nx = c.normal.x;
        float ny = c.normal.y;
        float nz = c.normal.z;

        // 接触点相对位置
        float rax = c.point.x - pos_x[a];
        float ray = c.point.y - pos_y[a];
        float raz = c.point.z - pos_z[a];

        float rbx = c.point.x - pos_x[b];
        float rby = c.point.y - pos_y[b];
        float rbz = c.point.z - pos_z[b];

        // 角速度叉乘 r：ω × r
        float cross_ax = angVel_y[a]*raz - angVel_z[a]*ray;
        float cross_ay = angVel_z[a]*rax - angVel_x[a]*raz;
        float cross_az = angVel_x[a]*ray - angVel_y[a]*rax;

        float cross_bx = angVel_y[b]*rbz - angVel_z[b]*rby;
        float cross_by = angVel_z[b]*rbx - angVel_x[b]*rbz;
        float cross_bz = angVel_x[b]*rby - angVel_y[b]*rbx;

        // 相对速度 v_rel = vA + ωA×rA - (vB + ωB×rB)
        float va_rel_x = (vel_x[a] + cross_ax) - (vel_x[b] + cross_bx);
        float va_rel_y = (vel_y[a] + cross_ay) - (vel_y[b] + cross_by);
        float va_rel_z = (vel_z[a] + cross_az) - (vel_z[b] + cross_bz);

        // 法向相对速度
        float relVelAlongNormal = va_rel_x*nx + va_rel_y*ny + va_rel_z*nz;

        // 法线指向 A，relVelAlongNormal > 0 表示 A 正在远离 B（分离），跳过
        if (relVelAlongNormal > 0.0f) {
            continue;
        }

        float e = std::min(restitution[a], restitution[b]);

        float invMassA = isStatic[a] ? 0.0f : invMass[a];
        float invMassB = isStatic[b] ? 0.0f : invMass[b];

        // 简化惯性张量（假设物体绕主轴旋转）
        float invInertiaA_xx = isStatic[a] ? 0.0f : invInertial_xx[a];
        float invInertiaA_yy = isStatic[a] ? 0.0f : invInertial_yy[a];
        float invInertiaA_zz = isStatic[a] ? 0.0f : invInertial_zz[a];

        float invInertiaB_xx = isStatic[b] ? 0.0f : invInertial_xx[b];
        float invInertiaB_yy = isStatic[b] ? 0.0f : invInertial_yy[b];
        float invInertiaB_zz = isStatic[b] ? 0.0f : invInertial_zz[b];

        // r × n
        float rn_ax = ray*nz - raz*ny;
        float rn_ay = raz*nx - rax*nz;
        float rn_az = rax*ny - ray*nx;

        float rn_bx = rby*nz - rbz*ny;
        float rn_by = rbz*nx - rbx*nz;
        float rn_bz = rbx*ny - rby*nx;

        // 角动量贡献（简化版：假设惯性张量对角）
        float angularTerm_a = invInertiaA_xx*rn_ax*rn_ax
                             + invInertiaA_yy*rn_ay*rn_ay
                             + invInertiaA_zz*rn_az*rn_az;

        float angularTerm_b = invInertiaB_xx*rn_bx*rn_bx
                             + invInertiaB_yy*rn_by*rn_by
                             + invInertiaB_zz*rn_bz*rn_bz;

        float invMassSum = invMassA + invMassB + angularTerm_a + angularTerm_b;

        const float EPSILON = 1e-6f;
        if (invMassSum < EPSILON) continue;

        // 法向冲量
        float j = -(1.0f + e) * relVelAlongNormal / invMassSum;

        // 防止冲量过大
        const float MAX_IMPULSE = 1e6f;
        if (std::abs(j) > MAX_IMPULSE) {
            j = (j > 0 ? MAX_IMPULSE : -MAX_IMPULSE);
        }

        // 切向摩擦冲量
        float tx = va_rel_x - relVelAlongNormal * nx;
        float ty = va_rel_y - relVelAlongNormal * ny;
        float tz = va_rel_z - relVelAlongNormal * nz;
        float tLen = sqrtf(tx*tx + ty*ty + tz*tz);
        
        float frictionImpulse = 0.0f;
        float frictionCoeff = (friction[a] + friction[b]) * 0.5f;
        
        if (tLen > EPSILON) {
            // 切向单位向量
            tx /= tLen;
            ty /= tLen;
            tz /= tLen;

            // 切向相对速度
            float relVelTangent = va_rel_x*tx + va_rel_y*ty + va_rel_z*tz;

            // 计算切向冲量（与法向类似）
            float rn_t_ax = ray*tz - raz*ty;
            float rn_t_ay = raz*tx - rax*tz;
            float rn_t_az = rax*ty - ray*tx;

            float rn_t_bx = rby*tz - rbz*ty;
            float rn_t_by = rbz*tx - rbx*tz;
            float rn_t_bz = rbx*ty - rby*tx;

            float angularTerm_t_a = invInertiaA_xx*rn_t_ax*rn_t_ax
                                   + invInertiaA_yy*rn_t_ay*rn_t_ay
                                   + invInertiaA_zz*rn_t_az*rn_t_az;

            float angularTerm_t_b = invInertiaB_xx*rn_t_bx*rn_t_bx
                                   + invInertiaB_yy*rn_t_by*rn_t_by
                                   + invInertiaB_zz*rn_t_bz*rn_t_bz;

            float invMassSum_t = invMassA + invMassB + angularTerm_t_a + angularTerm_t_b;

            if (invMassSum_t > EPSILON) {
                float jt = -relVelTangent / invMassSum_t;
                
                // Coulomb 摩擦定律：摩擦冲量 ≤ 法向冲量 * 摩擦系数
                float maxFriction = std::abs(j) * frictionCoeff;
                // 手动实现 clamp 兼容 C++14 及以下标准
                frictionImpulse = jt < -maxFriction ? -maxFriction : (jt > maxFriction ? maxFriction : jt);
            }
        }

        // 法向冲量施加
        float impulseX = j * nx;
        float impulseY = j * ny;
        float impulseZ = j * nz;

        // 切向冲量施加
        impulseX += frictionImpulse * tx;
        impulseY += frictionImpulse * ty;
        impulseZ += frictionImpulse * tz;

        // A 受到正冲量（法线指向 A）
        if (!isStatic[a]) {
            vel_x[a] += impulseX * invMassA;
            vel_y[a] += impulseY * invMassA;
            vel_z[a] += impulseZ * invMassA;

            // 角冲量：r × impulse
            angVel_x[a] += (ray*impulseZ - raz*impulseY) * invInertiaA_xx;
            angVel_y[a] += (raz*impulseX - rax*impulseZ) * invInertiaA_yy;
            angVel_z[a] += (rax*impulseY - ray*impulseX) * invInertiaA_zz;
        }

        // B 受到负冲量
        if (!isStatic[b]) {
            vel_x[b] -= impulseX * invMassB;
            vel_y[b] -= impulseY * invMassB;
            vel_z[b] -= impulseZ * invMassB;

            angVel_x[b] -= (rby*impulseZ - rbz*impulseY) * invInertiaB_xx;
            angVel_y[b] -= (rbz*impulseX - rbx*impulseZ) * invInertiaB_yy;
            angVel_z[b] -= (rbx*impulseY - rby*impulseX) * invInertiaB_zz;
        }
    }
}
void PhysicsSystem::integrateVelocity(float dt) {
    for (uint32_t k = 0; k < count; ++k) {
        uint32_t i = valid_list[k];
        if (isStatic[i]) {
            vel_x[i] = vel_y[i] = vel_z[i] = 0.0f;
            // 修改：如果允许旋转，则不清零角速度，允许弹簧力矩驱动
            if (!canRotate[i]) {
                angVel_x[i] = angVel_y[i] = angVel_z[i] = 0.0f;
                continue;
            }
//            OH_LOG_INFO(LOG_APP, "integrateVelocity: id=%{public}u is static but canRotate, processing angular velocity", i);
        }

        // 1. 线性速度积分（外力 + 重力）
        vel_x[i] += (force_x[i] * invMass[i] + gravity.x) * dt;
        vel_y[i] += (force_y[i] * invMass[i] + gravity.y) * dt;
//        vel_z[i] += (force_z[i] * invMass[i] + gravity.z) * dt;
        vel_z[i] += 0;

        // 2. 角速度积分（简化版：忽略陀螺项，适用于低速/主轴对齐物体）
        float oldAngVelX = angVel_x[i];
        angVel_x[i] += torque_x[i] * invInertial_xx[i] * dt;
        angVel_y[i] += torque_y[i] * invInertial_yy[i] * dt;
        angVel_z[i] += torque_z[i] * invInertial_zz[i] * dt;

        // Debug: 打印显著的角速度变化
        if (std::abs(torque_x[i]) > 0.01f || std::abs(torque_y[i]) > 0.01f || std::abs(torque_z[i]) > 0.01f) {
            OH_LOG_INFO(LOG_APP, "integrateVelocity: id=%{public}u torque=(%{public}f, %{public}f, %{public}f) invI=(%{public}f, %{public}f, %{public}f) angVel changed from (%{public}f, ...) to (%{public}f, ...)", 
                        i, torque_x[i], torque_y[i], torque_z[i], invInertial_xx[i], invInertial_yy[i], invInertial_zz[i], oldAngVelX, angVel_x[i]);
        }

        // 3. 指数衰减阻尼（替代错误的 friction 用法，帧率无关且数值稳定）
        // 若需每物体独立配置，可替换为 linearDamping[i] / angularDamping[i]
        const float LIN_DAMP_COEFF = 0.02f;
        const float ANG_DAMP_COEFF = 0.05f;
        float linDamp = expf(-LIN_DAMP_COEFF * dt);
        float angDamp = expf(-ANG_DAMP_COEFF * dt);
        vel_x[i] *= linDamp; vel_y[i] *= linDamp; vel_z[i] *= linDamp;
        angVel_x[i] *= angDamp; angVel_y[i] *= angDamp; angVel_z[i] *= angDamp;

        // 4. NaN/Inf 防护（统一检查线速度与角速度）
        if (std::isinf(vel_x[i]) || std::isnan(vel_x[i]) ||
            std::isinf(vel_y[i]) || std::isnan(vel_y[i]) ||
            std::isinf(vel_z[i]) || std::isnan(vel_z[i])) {
            OH_LOG_INFO(LOG_APP, "NaN/Inf in linear velocity at id=%{public}u, resetting", i);
            vel_x[i] = vel_y[i] = vel_z[i] = 0.0f;
        }
        if (std::isinf(angVel_x[i]) || std::isnan(angVel_x[i]) ||
            std::isinf(angVel_y[i]) || std::isnan(angVel_y[i]) ||
            std::isinf(angVel_z[i]) || std::isnan(angVel_z[i])) {
            OH_LOG_INFO(LOG_APP, "NaN/Inf in angular velocity at id=%{public}u, resetting", i);
            angVel_x[i] = angVel_y[i] = angVel_z[i] = 0.0f;
        }
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

        // 法线指向 A，所以 A 沿法线正方向移，B 沿法线负方向移
        if (!isStatic[a])
        {
            pos_x[a] += dx * invMassA;
            pos_y[a] += dy * invMassA;
//            pos_z[a] += dz * invMassA;
            pos_z[a] += 0;
        }

        if (!isStatic[b])
        {
            pos_x[b] -= dx * invMassB;
            pos_y[b] -= dy * invMassB;
//            pos_z[b] -= dz * invMassB;
            pos_z[b] -= 0;
        }
    }
}
void PhysicsSystem::integratePosition(float dt)
{
    for (uint32_t k = 0; k < count; ++k)
    {
        uint32_t i = valid_list[k];
        // 静态物体默认跳过位置更新，但如果允许旋转，则仍需更新旋转
        bool isStaticObj = isStatic[i];
        bool canRot = canRotate[i];
        
        if (isStaticObj && !canRot) continue;

        // --- 1. 更新位置 (静态物体不更新位置) ---
        if (!isStaticObj) {
            pos_x[i] += vel_x[i] * dt;
            pos_y[i] += vel_y[i] * dt;
            pos_z[i] += vel_z[i] * dt;
        }

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
    for(uint32_t k = 0 ; k < count; k++){
        uint32_t i = valid_list[k];
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
    
    // ===== extent =====
    {
        napi_value extent_value;
        Vector3 extent;
        napi_get_named_property(env, data_value, "extent", &extent_value);
        extent = napi_helpers::parse_vector3(env, extent_value);
        obj->setExtent(id, extent);
    }

        // ===== scale =====
    {
        napi_value scale_value;
        Vector3 scale;
        napi_get_named_property(env, data_value, "scale", &scale_value);
        scale = napi_helpers::parse_vector3(env, scale_value);
        obj->setScale(id, scale);
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
        obj->setIsStatic(id, isStatic);
        OH_LOG_INFO(LOG_APP, "AddNode: id=%{public}u isStatic=%{public}u", id, isStatic);
    }
    
    // ===== restitution =====
    {
        obj->setRestitution(id, 0.8);
    }

    // setMass 必须在 setIsStatic 之后调用，确保 invMass 正确设置
    obj->setMass(id, 1.0f);
    // ===== 布局系统覆盖 =====

    OH_LOG_INFO(LOG_APP, "AddNode: id=%{public}u invMass=%{public}f", id, obj->invMass[id]);

    napi_value id_val;
    napi_create_int32(env, id, &id_val);
    
    return id_val;
}

napi_value PhysicsSystem::RemoveNode(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1];
    napi_value jsThis;
    napi_get_cb_info(env, info, &argc, argv, &jsThis, nullptr);
    
    PhysicsSystem* obj;
    napi_unwrap(env, jsThis, reinterpret_cast<void**>(&obj));
    uint32_t id;
    napi_value data_value = argv[0];
    napi_get_value_uint32(env, data_value, &id);
    bool status = obj->removeNodeId(id);
    napi_value result;
    napi_get_boolean(env, status, &result);
    return result;
}

napi_value PhysicsSystem::AddNodeInLayoutSys(napi_env env, napi_callback_info info) {
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
    
    // ===== extent =====
    {
        napi_value extent_value;
        Vector3 extent;
        napi_get_named_property(env, data_value, "extent", &extent_value);
        extent = napi_helpers::parse_vector3(env, extent_value);
        obj->setExtent(id, extent);
    }

        // ===== scale =====
    {
        napi_value scale_value;
        Vector3 scale;
        napi_get_named_property(env, data_value, "scale", &scale_value);
        scale = napi_helpers::parse_vector3(env, scale_value);
        obj->setScale(id, scale);
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
        obj->setIsStatic(id, isStatic);
        OH_LOG_INFO(LOG_APP, "AddNode: id=%{public}u isStatic=%{public}u", id, isStatic);
    }

    // setMass 必须在 setIsStatic 之后调用，确保 invMass 正确设置
    obj->setMass(id, 1.0f);
    // ===== 布局系统覆盖 =====
    if (obj->layoutManager) {
        Vector3 layoutPos;
        uint32_t cell_id = obj->layoutManager->getNextPosition(layoutPos);
        if (cell_id != -1) {
            // 用布局位置覆盖 JS 传入的 position
            obj->setPosition(id, layoutPos);

            // 用格子尺寸覆盖 JS 传入的 extent（取半长轴）
            const auto& cfg = obj->layoutManager->getConfig();
            Vector3 layoutScale(cfg.cellWidth, cfg.cellHeight, 1.0);
            obj->setScale(id, layoutScale);

            // 标记格子已占用
            obj->layoutManager->occupyCell(cell_id);

            OH_LOG_INFO(LOG_APP,
                "AddNode: id=%{public}u overridden by layout at (%{public}f, %{public}f, %{public}f)",
                id, layoutPos.x, layoutPos.y, layoutPos.z);
        } else {
            OH_LOG_WARN(LOG_APP, "AddNode: layout full, using JS-provided position for id=%{public}u", id);
        }

        // 启用旋转弹簧：设置默认 K/D 参数，并将当前旋转作为复位目标
        obj->setRotationSpring(id, 5.0f, 2.0f);
        obj->setRestRotation(id, Vector4(
            obj->rot_x[id], obj->rot_y[id], obj->rot_z[id], obj->rot_w[id]
        ));
        OH_LOG_INFO(LOG_APP, "AddNode: id=%{public}u rotation spring enabled (K=5.0, D=2.0), restRot=(%{public}f, %{public}f, %{public}f, %{public}f)", 
                    id, obj->restRot_x[id], obj->restRot_y[id], obj->restRot_z[id], obj->restRot_w[id]);
    }
    OH_LOG_INFO(LOG_APP, "AddNode: id=%{public}u invMass=%{public}f", id, obj->invMass[id]);

    napi_value id_val;
    napi_create_int32(env, id, &id_val);
    
    return id_val;
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
//    return false;
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
        { "addNodeInLayoutSys", nullptr, AddNodeInLayoutSys, nullptr, nullptr, nullptr, napi_default, nullptr},
        { "addNode", nullptr, AddNode, nullptr, nullptr, nullptr, napi_default, nullptr},
        { "removeNode", nullptr, RemoveNode, nullptr, nullptr, nullptr, napi_default, nullptr},
        { "update", nullptr, Update, nullptr, nullptr, nullptr, napi_default, nullptr},
        { "release", nullptr, PhysicsSystem::Release, nullptr, nullptr, nullptr, napi_default, nullptr},
        { "enableLayout", nullptr, PhysicsSystem::EnableLayout, nullptr, nullptr, nullptr, napi_default,nullptr}
    };

    napi_value cons;
    napi_define_class(env, "PhysicsSystem", NAPI_AUTO_LENGTH, New, nullptr, 5, properties, &cons);

    napi_set_named_property(env, exports, "PhysicsSystem", cons);
    return exports;
}


// ========= 布局系统 ============
// 启用布局系统
napi_value PhysicsSystem::EnableLayout(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1];
    napi_value jsThis;
    napi_get_cb_info(env, info, &argc, argv, &jsThis, nullptr);
    PhysicsSystem* obj;
    napi_unwrap(env, jsThis, reinterpret_cast<void**>(&obj));

    LayoutConfig config = napi_helpers::parse_layout_config(env, argv[0]);
    obj->enableLayout(config);
    return nullptr;
}

void PhysicsSystem::enableLayout(const LayoutConfig& config){
    if (layoutManager) {
        delete layoutManager;
    }
    layoutManager = new LayoutSystem();
    layoutManager->init(config);
}
// 禁用布局系统
void PhysicsSystem::disableLayout() {
    delete layoutManager;
    layoutManager = nullptr;
}


// ================= 旋转弹簧系统实现 =================

void PhysicsSystem::setRestRotation(uint32_t id, Vector4 rot) {
    restRot_x[id] = rot.x;
    restRot_y[id] = rot.y;
    restRot_z[id] = rot.z;
    restRot_w[id] = rot.w;
}

void PhysicsSystem::setRotationSpring(uint32_t id, float k, float d) {
    rotSpringK[id] = k;
    rotSpringD[id] = d;
}

void PhysicsSystem::applyRotationSprings(float dt) {
    // 仅在布局系统启用时应用旋转弹簧
    if (layoutManager == nullptr) return;

    for (uint32_t z = 0; z < count; ++z) {
        uint32_t i = valid_list[z];
        // 核心条件：只对允许旋转的物体生效（无论是否静态）
        if (!canRotate[i]) continue;

        // 安全检查：如果惯性为 0 则重新计算，否则力矩无效
        if (invInertial_xx[i] < 1e-6f) {
            updateInvInertia(i);
        }

        // 当前四元数
        Quaternion q_curr(rot_x[i], rot_y[i], rot_z[i], rot_w[i]);
        // 目标四元数（复位目标）
        Quaternion q_rest(restRot_x[i], restRot_y[i], restRot_z[i], restRot_w[i]);

        // 计算误差四元数：deltaQ = q_rest * q_curr.conjugate()
        Quaternion q_conj(-rot_x[i], -rot_y[i], -rot_z[i], rot_w[i]);
        Quaternion deltaQ = q_rest * q_conj;

        // 误差向量 (虚部) 近似表示旋转轴 * sin(theta/2)
        Vector3 error(deltaQ.x, deltaQ.y, deltaQ.z);

        // 弹簧力矩: T = K * error - D * angVel
        float k = rotSpringK[i];
        float d = rotSpringD[i];

        float tx = 2.0f * k * error.x - d * angVel_x[i];
        float ty = 2.0f * k * error.y - d * angVel_y[i];
        float tz = 2.0f * k * error.z - d * angVel_z[i];

        // 累加到当前力矩
        torque_x[i] += tx;
        torque_y[i] += ty;
        torque_z[i] += tz;

        // Debug: 打印显著的力矩
        if (std::abs(tx) > 0.01f || std::abs(ty) > 0.01f || std::abs(tz) > 0.01f) {
            OH_LOG_INFO(LOG_APP, "applyRotationSprings: id=%{public}u torque=(%{public}f, %{public}f, %{public}f) angVel=(%{public}f, %{public}f, %{public}f) error=(%{public}f, %{public}f, %{public}f)", 
                        i, tx, ty, tz, angVel_x[i], angVel_y[i], angVel_z[i], error.x, error.y, error.z);
        }
    }
}