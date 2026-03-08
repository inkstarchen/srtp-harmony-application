//
// Created on 2026/2/5.
//
// Node APIs are not fully supported. To solve the compilation error of the interface cannot be found,
// please include "napi/native_api.h".

#ifndef DAYNOTE_COLLISION_H
#define DAYNOTE_COLLISION_H
#pragma once
#include <cstdint>
#include "shape.h"
#include "contact.h"

class PhysicsSystem;
typedef bool (*CollisionFunc)(const PhysicsSystem&, const uint32_t, const uint32_t);
typedef void (*ContactFunc)(const PhysicsSystem&, uint32_t, uint32_t, Contact&);

class ContactDispatch
{
public:
    static ContactFunc table[SHAPE_COUNT][SHAPE_COUNT];
    
    static void dispatch(const PhysicsSystem& physics, uint32_t A, uint32_t B, Contact& c);
        
private:
    struct Initializer {
        Initializer() {
            ContactDispatch::initContactDispatch();
        }
    };
    
    static Initializer _initializer;
    static void initContactDispatch();
};

class CollisionDispatch
{
public:
    static CollisionFunc table[SHAPE_COUNT][SHAPE_COUNT];
    
    static bool dispatch(const PhysicsSystem& physics, const uint32_t A, const uint32_t B);
    
private:
    struct Initializer {
        Initializer() {
            CollisionDispatch::initCollisionDispatch();
        }
    };
    
    static Initializer _initializer;
    static void initCollisionDispatch();
};

#endif //DAYNOTE_COLLISION_H
