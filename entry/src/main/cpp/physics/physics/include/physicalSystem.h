//
// Created on 2026/2/4.
//
// Node APIs are not fully supported. To solve the compilation error of the interface cannot be found,
// please include "napi/native_api.h".

#ifndef DAYNOTE_NODEPROXY_H
#define DAYNOTE_NODEPROXY_H
#include "body.h"
#pragma once
#include <cstdint>
#include <vector>
#include "contact.h"
#include "matrix.h"
#include "quteration.h"
#include "vec.h"
#include "napi/native_api.h"

class PhysicsSystem {
public:
    PhysicsSystem(size_t capacity);
    ~PhysicsSystem();

    static napi_value GetNormal(napi_env env, napi_callback_info info);
    static napi_value AddNode(napi_env env, napi_callback_info info);
    static napi_value Update(napi_env env, napi_callback_info info);
    static napi_value SetPosition(napi_env env, napi_callback_info info);
    static napi_value SetRotation(napi_env env, napi_callback_info info);
    static napi_value SetVelocity(napi_env env, napi_callback_info info);
    static napi_value SetAcceleration(napi_env env, napi_callback_info info);
    static napi_value SetForce(napi_env env, napi_callback_info info);
    static napi_value SetScale(napi_env env, napi_callback_info info);
    static napi_value SetExtent(napi_env env, napi_callback_info info);
    static napi_value SetMass(napi_env env, napi_callback_info info);
    static napi_value SetRestitution(napi_env env, napi_callback_info info);
    static napi_value SetFriction(napi_env env, napi_callback_info info);
    static napi_value SetShapeType(napi_env env, napi_callback_info info);
    static napi_value SetIsStatic(napi_env env, napi_callback_info info);
    
    static napi_value GetMass(napi_env env, napi_callback_info info);
    static napi_value GetVel(napi_env env, napi_callback_info info);
    static napi_value GetAcc(napi_env env, napi_callback_info info);
    static napi_value GetFric(napi_env env, napi_callback_info info);
    static napi_value RayCast(napi_env env, napi_callback_info info);
    void removeNode(uint32_t id);

    size_t getCount() const;
    size_t getCapacity() const;

    static napi_value Init(napi_env env, napi_value exports);
    static void Destructor(napi_env env, void* nativeObject, void* finalize_hint);
    
    size_t capacity; // 对齐后
    size_t count;
    std::vector<Contact> contact;

    std::vector<std::pair<uint32_t, uint32_t>> possiblePairs;
    std::vector<uint32_t> free_list;
    
    // === SoA pointers ===
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
    uint32_t newNode();
    napi_value update(napi_env env, napi_callback_info info);
    void setPosition(uint32_t id, Vector3 position);
    void setRotation(uint32_t id, Vector4 rotation);
    void setVelocity(uint32_t id, Vector3 velocity);
    void setAcceleration(uint32_t id, Vector3 acceleration);
    void setForce(uint32_t id, Vector3 force);
    void setScale(uint32_t id, Vector3 scale);
    void setExtent(uint32_t id, Vector3 extent);
    void setMass(uint32_t id, float mass);
    void setRestitution(uint32_t id, float restitution);
    void setFriction(uint32_t id, float friction);
    void setShapeType(uint32_t id, int32_t shapeType);
    void setIsStatic(uint32_t id, uint8_t isStatic);
    void setGravity(Vector3 gravity);
    
    Body getBody(uint32_t id);
    
    void clearForce(uint32_t id);
    void clearForceAll();
    float getMass(uint32_t id);
    Vector3 getVel(uint32_t id);
    Vector3 getAcc(uint32_t id);
    float getFric(uint32_t id);
    
    // 碰撞相关函数
    void detectCollisions();
    bool testCollision(uint32_t a, uint32_t b);
    void buildContacts();
    void solveContacts();
    void integrateVelocity(float dt);
    void positionalCorrection();
    void integratePosition(float dt);
    
    void step(float dt);
    void* base_ptr;   // 用于 free
    static napi_value New(napi_env env, napi_callback_info info);
    napi_ref buffer_ref_ = nullptr;
    napi_env env_;
    napi_ref wrapper_;
};



#endif //DAYNOTE_NODEPROXY_H
