//
// Created on 2026/3/7.
//
// 统一事件队列 - 双缓冲 + 优先级 + 事件合并
//

#ifndef DAYNOTE_EVENT_QUEUE_H
#define DAYNOTE_EVENT_QUEUE_H

#include <js_native_api.h>
#include <js_native_api_types.h>
#include <vector>
#include <mutex>
#include <atomic>
#include <cstdint>
#include <algorithm>
#include <cmath>
#include <cfloat>

// ================= 事件类型 =================
enum class EventType : uint8_t {
  NONE = 0,
  // Input (1-50)
  TOUCH_DOWN = 1,
  TOUCH_MOVE = 2,
  TOUCH_UP = 3,

  // Gesture (50-99)
  PAN_REQUEST = 50,
  SCALE_REQUEST = 51,

  // Engine Request (100-199)
  RAYCAST_REQUEST = 100,
  ROTATE_REQUEST = 101,
  SET_PROPERTY_REQUEST = 102,
  RESET_GRAVITY = 103,

  // UI (200-229)
  BUTTON_TRIGGER = 200,

  // Custom (230-249)
  CUSTOM_ACTION = 230,

  // System (250-269)
  LOAD_RESOURCE = 250,
  SAVE_STATE = 251
};

// ================= 事件优先级 =================
enum class EventPriority : uint8_t {
    HIGH = 0,    // Touch 输入事件
    NORMAL = 1,  // 普通事件
    LOW = 2      // 动画、脚本事件
};

// ================= 事件数据结构 =================
struct EventCommand {
    EventType type;
    EventPriority priority;
    uint32_t nodeId;
    uint64_t timestamp;
    std::vector<uint64_t> data;

    // 默认构造函数
    EventCommand()
        : type(EventType::NONE)
        , priority(EventPriority::NORMAL)
        , nodeId(0)
        , timestamp(0){}
};


// ================= 事件优先级辅助函数 =================
namespace EventPriorityUtils {
    inline EventPriority getDefaultPriority(EventType type) {
        switch (type) {
            case EventType::TOUCH_DOWN:
            case EventType::TOUCH_MOVE:
            case EventType::TOUCH_UP:
            case EventType::BUTTON_TRIGGER:
            case EventType::SET_PROPERTY_REQUEST:
                return EventPriority::HIGH;

            case EventType::RAYCAST_REQUEST:
            case EventType::ROTATE_REQUEST:
            case EventType::PAN_REQUEST:
            case EventType::SCALE_REQUEST:
                return EventPriority::NORMAL;

            case EventType::CUSTOM_ACTION:
            case EventType::LOAD_RESOURCE:
            case EventType::SAVE_STATE:
            case EventType::NONE:
            default:
                return EventPriority::LOW;
        }
    }
}

// 对应 TS 的 Property 枚举
enum class Property : uint8_t {
    POS           = 1,  // 位置
    ROTATION      = 2,  // 旋转
    VELOCITY      = 3,  // 线速度
    ANGLE_VELOCITY= 4,  // 角速度
    SCALE         = 5,  // 缩放
    MASS          = 6,  // 质量
    RESTITUTION   = 7,  // 弹性
    FRICTION      = 8,  // 摩擦
    STATIC        = 9,  // 是否静态
    IMPULSE       = 10  // 冲量
};

// 转 JS EventCommand -> C++ EventCommand
EventCommand parseEventCommand(napi_env env, napi_value jsCmd);

// 解析 EventCommand[][]
std::vector<std::vector<EventCommand>> parseEventQueue(napi_env env, napi_value jsQueue);
#endif // DAYNOTE_EVENT_QUEUE_H
