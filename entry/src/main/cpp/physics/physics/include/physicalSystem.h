//
// Created on 2026/2/4.
//
// Node APIs are not fully supported. To solve the compilation error of the interface cannot be found,
// please include "napi/native_api.h".

#ifndef DAYNOTE_NODEPROXY_H
#define DAYNOTE_NODEPROXY_H
#include "body.h"
#include <hilog/log.h>
#pragma once
#include <cstdint>
#include <vector>
#include <atomic>
#include "contact.h"
#include "matrix.h"
#include "quaternion.h"
#include "vec.h"
#include "napi/native_api.h"
#include "../../event_queue/include/event_queue.h"

class PhysicsSystem {
public:
    PhysicsSystem(size_t capacity);
    ~PhysicsSystem();

    static napi_value AddNode(napi_env env, napi_callback_info info);
    static napi_value Update(napi_env env, napi_callback_info info);
    static napi_value Release(napi_env env, napi_callback_info info);
    void processEventQueueFromJS(const std::vector<std::vector<EventCommand>> &events);

    void removeNode(uint32_t id);

    size_t getCount() const;
    size_t getCapacity() const;

    static napi_value Init(napi_env env, napi_value exports);
    static void Destructor(napi_env env, void* nativeObject, void* finalize_hint);
    using HandlerFunc = void (PhysicsSystem::*)(const EventCommand&);
    std::array<HandlerFunc, 256> handlers; 
    size_t capacity; // 对齐后
    size_t count;
    std::vector<Contact> contact;

    std::vector<std::pair<uint32_t, uint32_t>> possiblePairs;
    std::vector<uint32_t> free_list;
    std::vector<EventResult> eventResults;

    void clearEventResults() {
        eventResults.clear();
    }
    Vector2 touchDown;
    Vector2 touchLast;
    Vector2 touchCur;
    Vector3 cameraPos;
    float fov;
    float ratio;
    
    // === SoA pointers ===
    Vector3 gravity;
    float *pos_x, *pos_y, *pos_z;
    float *rot_x, *rot_y, *rot_z, *rot_w;
    float *vel_x, *vel_y, *vel_z;
    float *angVel_x, *angVel_y, *angVel_z;
    float *force_x, *force_y, *force_z;
    float *torque_x, *torque_y, *torque_z;
    float *impulse_x, *impulse_y, *impulse_z;
    float *invInertial_xx, *invInertial_yy, *invInertial_zz;
    float *scale_x, *scale_y, *scale_z;
    float *extent_x, *extent_y, *extent_z;
    
    float *invMass, *restitution, *friction;
    
    int32_t *shapeType;
    uint8_t *isStatic;

private:
    void initHandlers() {
        handlers.fill(nullptr);
        handlers[static_cast<uint8_t>(EventType::TOUCH_DOWN)] = &PhysicsSystem::handleTouchDown;
        handlers[static_cast<uint8_t>(EventType::TOUCH_MOVE)] = &PhysicsSystem::handleTouchMove;
        handlers[static_cast<uint8_t>(EventType::TOUCH_UP)] = &PhysicsSystem::handleTouchUp;
        handlers[static_cast<uint8_t>(EventType::ROTATE_REQUEST)] = &PhysicsSystem::handleRotateRequest;
        handlers[static_cast<uint8_t>(EventType::SET_PROPERTY_REQUEST)] = &PhysicsSystem::handleSetProperty;
        handlers[static_cast<uint8_t>(EventType::RESET_GRAVITY)] = &PhysicsSystem::handleResetGravity;
        handlers[static_cast<uint8_t>(EventType::RAYCAST_REQUEST)] = &PhysicsSystem::handleRayCast;
    }
    uint32_t newNode();
    napi_value update(napi_env env, napi_callback_info info);
    napi_value getEventResults(napi_env env){
        return toJsEventResults(env,eventResults);
    }
    void ReleaseScene(){
        count = 0;
        OH_LOG_INFO(LOG_APP,"Release Scene %{public}d", count);
        free_list.clear(); // 清空原有元素
        for (int32_t i = capacity-1; i >= 0; i--) {
            free_list.push_back(static_cast<uint32_t>(i));
        }
        
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
        std::memset(base_ptr, 0, bytes);
    }
    void setGravity(Vector3 g){
        gravity = g;
    }
    void setPosition(uint32_t id, Vector3 position){
        pos_x[id] = position.x;
        pos_y[id] = position.y;
        pos_z[id] = position.z;
    }
    void setVelocity(uint32_t id, Vector3 vel){
        vel_x[id] = vel.x;
        vel_y[id] = vel.y;
        vel_z[id] = vel.z;
    }
    void setAngularVelocity(uint32_t id, Vector3 angVel){
        angVel_x[id] = angVel.x;
        angVel_y[id] = angVel.y;
        angVel_z[id] = angVel.z;
    }
    void setRotation(uint32_t id, Vector4 rotation){
        rot_x[id] = rotation.x;
        rot_y[id] = rotation.y;
        rot_z[id] = rotation.z;
        rot_w[id] = rotation.w;
    }
    void setScale(uint32_t id, Vector3 scale){
        scale_x[id] = scale.x;
        scale_y[id] = scale.y;
        scale_z[id] = scale.z;
    }
    void setMass(uint32_t id, float m){
        if(m < 1e-6) {
            invMass[id] = INFINITY;
        }else {
            invMass[id] = 1 / m;
        }
    }
    void setExtent(uint32_t id, Vector3 extent){
        extent_x[id] = extent.x;
        extent_y[id] = extent.y;
        extent_z[id] = extent.z;
    }
    void setRestitution(uint32_t id, float r){
        restitution[id] = r;
    }
    void setFriction(uint32_t id, float f){
        friction[id] = f;
    }
    void setShapeType(uint32_t id, int32_t type){
            shapeType[id] = type;
    }
    void setIsStatic(uint32_t id, uint8_t value){
        isStatic[id] = value;
    }
    void applyImpulse(uint32_t id, Vector3 impulse){
        impulse_x[id] = impulse.x;
        impulse_y[id] = impulse.y;
        impulse_z[id] = impulse.z;
    }
    void setCamera(Vector3 pos, float fov_v, float ratio_v){
        cameraPos = pos;
        fov = fov_v;
        ratio = ratio_v;
    }
    
    Body getBody(uint32_t id);
    
    void clearForce(uint32_t id);
    void clearForceAll();
    
    float getMass(uint32_t id){ 
        return 1 / invMass[id];
    }
    Vector3 getVel(uint32_t id){
        return Vector3(vel_x[id],vel_y[id], vel_z[id]);
    }
    Vector3 getAcc(uint32_t id);
    float getFric(uint32_t id){
        return friction[id];
    }
    
    // 碰撞相关函数
    void detectCollisions();
    bool testCollision(uint32_t a, uint32_t b);
    void buildContacts();
    void solveContacts();
    void integrateVelocity(float dt);
    void positionalCorrection();
    void integratePosition(float dt);

    // 事件处理方法
    void handleTouchDown(const EventCommand& e) {
        int id = static_cast<int64_t>(e.data[0]);

        const double* values = reinterpret_cast<const double*>(e.data.data() + 1);
        touchDown.x = values[0];
        touchDown.y = values[1];
        touchLast.x = values[0];
        touchLast.y = values[1];
        OH_LOG_INFO(LOG_APP,"TOUCHEVENT DOWN Pos:%{public}.3f %{public}.3f",touchDown.x, touchDown.y);
        // floats[0], floats[1], floats[2] ... 可以直接访问
        // TODO: 实际处理逻辑
    }

    void handleTouchMove(const EventCommand& e) {
        int id = static_cast<int64_t>(e.data[0]);

        const double* values = reinterpret_cast<const double*>(e.data.data() + 1);
        touchCur.x = values[0];
        touchCur.y = values[1];
        OH_LOG_INFO(LOG_APP,"TOUCHEVENT MOVE Pos:%{public}.3f %{public}.3f",touchCur.x, touchCur.y);
        // TODO: 处理 TouchMove
    }
    
    void handleTouchUp(const EventCommand& e) {
        OH_LOG_INFO(LOG_APP,"TOUCHEVENT UP");
    }
    
    void handleRayCast(const EventCommand& e) {
        int id = static_cast<int64_t>(e.data[0]);
        const double* values = reinterpret_cast<const double*>(e.data.data() + 1);
        processRaycast(values[0], values[1]);
    }

    void handleButton(const EventCommand& e) {
        int id = static_cast<int32_t>(e.data[0]);
        // TODO: 处理按钮事件
    }
    
    void handleResetGravity(const  EventCommand& e){
        const double * values = reinterpret_cast<const double *>(e.data.data() + 1);
        Vector3 angle = Vector3(values[0],values[1],values[2]);
//        OH_LOG_INFO(LOG_APP,"ANGLE C++ IS %{public}.3f, %{public}.3f, %{public}.3f",values[0], values[1],values[2]);
        Vector3 normal = Vector3(0.0, 0.0, 1.0);
        angle = angle / 180.0 * 3.141592;
        normal = Vector3::RotateAroundAxis(normal, Vector3(0.0,1.0,0.0), angle.y);
        normal = Vector3::RotateAroundAxis(normal, Vector3(1.0,0.0,0.0), -angle.x);
        Vector3 g = Vector3(0.0f, 0.0f, 9.8f);
        Vector3 g_l = g - normal * g.dot(normal);
        setGravity(normal);
    }
    
    void handleRotateRequest(const EventCommand& e){
        uint32_t id = e.nodeId;
        if(id == capacity) return;
        Vector2 distance = touchCur - touchLast;
        touchLast.x = touchCur.x;
        touchLast.y = touchCur.y;
        Quaternion q = Quaternion::rotationFromTouchDelta(distance.x,distance.y);
        Quaternion cur_q = Quaternion(rot_x[id],rot_y[id],rot_z[id],rot_w[id]);
        Quaternion result_q = (q * cur_q).normalized();
        rot_x[id] = result_q.x;
        rot_y[id] = result_q.y;
        rot_z[id] = result_q.z;
        rot_w[id] = result_q.w;
    }

void handleSetProperty(const EventCommand& e) {
        
    int propId = static_cast<int64_t>(e.data[0]);
    OH_LOG_INFO(LOG_APP,"PROPERTY SET ID %{public}d", propId);
    const double * values = reinterpret_cast<const double *>(e.data.data() + 1);

    switch (propId) {
        case static_cast<int>(Property::POS): {
            // values[0], values[1], values[2] = x, y, z
            setPosition(e.nodeId, Vector3(values[0], values[1], values[2]));
            break;
        }
        case static_cast<int>(Property::ROTATION): {
            setRotation(e.nodeId, Vector4(values[0], values[1], values[2],values[4]));
            break;
        }
        case static_cast<int>(Property::VELOCITY): {
            setVelocity(e.nodeId, Vector3(values[0], values[1], values[2]));
            break;
        }
        case static_cast<int>(Property::ANGLE_VELOCITY): {
            setAngularVelocity(e.nodeId, Vector3(values[0], values[1], values[2]));
            break;
        }
        case static_cast<int>(Property::SCALE): {
            setScale(e.nodeId, Vector3(values[0], values[1], values[2]));
            break;
        }
        case static_cast<int>(Property::MASS): {
            setMass(e.nodeId, values[0]);
            break;
        }
        case static_cast<int>(Property::RESTITUTION): {
            setRestitution(e.nodeId, values[0]);
            break;
        }
        case static_cast<int>(Property::FRICTION): {
            setFriction(e.nodeId, values[0]);
            break;
        }
        case static_cast<int>(Property::STATIC): {
            setIsStatic(e.nodeId, static_cast<bool>(values[0]));
            break;
        }
        case static_cast<int>(Property::IMPULSE): {
            applyImpulse(e.nodeId, Vector3(values[0], values[1], values[2]));
            break;
        }
        case static_cast<int >(Property::CAMERA): {
            setCamera(Vector3(values[0],values[1],values[2]), values[3], values[4]);
            break;
        }
        default:
            // 未知属性，可以打印警告或忽略
            // printf("Unknown Property ID: %d\n", propId);
            break;
    }
}
    void processRaycast(float touchX, float touchY);
    void processRotate(float deltaX, float deltaY);

    void step(float dt);
    void* base_ptr;   // 用于 free
    static napi_value New(napi_env env, napi_callback_info info);
    napi_ref buffer_ref_ = nullptr;
    napi_env env_;
    napi_ref wrapper_;

};



#endif //DAYNOTE_NODEPROXY_H
