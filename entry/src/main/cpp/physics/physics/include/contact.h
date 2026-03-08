//
// Created on 2026/3/6.
//
// Node APIs are not fully supported. To solve the compilation error of the interface cannot be found,
// please include "napi/native_api.h".

#ifndef DAYNOTE_CONTACT_H
#define DAYNOTE_CONTACT_H
#include "vec.h"
#include <cstdint>
struct Contact
{
    uint32_t a;
    uint32_t b;
    
    Vector3 normal;
    Vector3 point;
    float penetration;
    float restitution;
};
#endif //DAYNOTE_CONTACT_H
