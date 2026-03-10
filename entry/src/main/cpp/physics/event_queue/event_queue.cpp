//
// Created on 2026/3/9.
//
// Node APIs are not fully supported. To solve the compilation error of the interface cannot be found,
// please include "napi/native_api.h".

// 转 JS EventCommand -> C++ EventCommand
#include "include/event_queue.h"
#include <hilog/log.h>
EventCommand parseEventCommand(napi_env env, napi_value jsCmd) {
    EventCommand cmd;

    napi_value val;

    // type
    napi_get_named_property(env, jsCmd, "type", &val);
    int32_t t;
    napi_get_value_int32(env, val, &t);
    cmd.type = static_cast<EventType>(t);

    // priority
    napi_get_named_property(env, jsCmd, "priority", &val);
    int32_t p;
    napi_get_value_int32(env, val, &p);
    cmd.priority = static_cast<EventPriority>(p);

    // nodeId
    napi_get_named_property(env, jsCmd, "nodeId", &val);
    uint32_t nid;
    napi_get_value_uint32(env, val, &nid);
    cmd.nodeId = nid;

    // timestamp
    napi_get_named_property(env, jsCmd, "timestamp", &val);
    double ts;
    napi_get_value_double(env, val, &ts);
    cmd.timestamp = static_cast<uint64_t>(ts);

    // data[]
    napi_get_named_property(env, jsCmd, "data", &val);
    bool isArray;
    napi_is_array(env, val, &isArray);
    if (isArray) {
        uint32_t len;
        napi_get_array_length(env, val, &len);
        cmd.data.resize(len);
        for (uint32_t i = 0; i < len; i++) {
            napi_value elem;
            napi_get_element(env, val, i, &elem);
            double num;
            napi_get_value_double(env, elem, &num);
            if (i == 0) {
                cmd.data[0] = static_cast<uint64_t>(static_cast<int64_t>(num));
            } else {
                double  d = static_cast<double>(num);
                uint64_t raw;
                std::memcpy(&raw, &d, sizeof(double ));
                cmd.data[i] = raw;
            }
        }
    }

    return cmd;
}

// 解析 EventCommand[][]
std::vector<std::vector<EventCommand>> parseEventQueue(napi_env env, napi_value jsQueue) {
    std::vector<std::vector<EventCommand>> queue;

    bool isArray;
    napi_is_array(env, jsQueue, &isArray);
    if (!isArray) return queue;

    uint32_t outerLen;
    napi_get_array_length(env, jsQueue, &outerLen);
//    OH_LOG_INFO(LOG_APP,"EVENTCOMMAND| OUTER %{public}d", outerLen);
    queue.resize(outerLen);
    for (uint32_t i = 0; i < outerLen; i++) {
        napi_value innerArray;
        napi_get_element(env, jsQueue, i, &innerArray);

        bool innerIsArray;
        napi_is_array(env, innerArray, &innerIsArray);
        if (!innerIsArray) continue;

        uint32_t innerLen;
        napi_get_array_length(env, innerArray, &innerLen);
//        OH_LOG_INFO(LOG_APP,"EVENTCOMMAND| INNER %{public}d", innerLen);
        queue[i].reserve(innerLen);
        for (uint32_t j = 0; j < innerLen; j++) {
            napi_value jsCmd;
            napi_get_element(env, innerArray, j, &jsCmd);
            queue[i].push_back(parseEventCommand(env, jsCmd));
        }
    }

    return queue;
}

napi_value toJsEventResult(napi_env env, const EventResult& res)
{
    napi_value obj;
    napi_create_object(env, &obj);

    napi_value val;

    // type
    napi_create_int32(env, static_cast<int32_t>(res.type), &val);
    napi_set_named_property(env, obj, "type", val);

    // nodeId
    napi_create_uint32(env, res.nodeId, &val);
    napi_set_named_property(env, obj, "nodeId", val);

    // timestamp
    napi_create_double(env, static_cast<double>(res.timestamp), &val);
    napi_set_named_property(env, obj, "timestamp", val);

    // status
    napi_create_uint32(env, res.status, &val);
    napi_set_named_property(env, obj, "status", val);

    // data[]
    napi_value arr;
    napi_create_array_with_length(env, res.data.size(), &arr);

    for (size_t i = 0; i < res.data.size(); i++) {
        double d;

        if (i == 0) {
            d = static_cast<double>(static_cast<int64_t>(res.data[i]));
        } else {
            uint64_t raw = res.data[i];
            std::memcpy(&d, &raw, sizeof(double));
        }

        napi_value num;
        napi_create_double(env, d, &num);
        napi_set_element(env, arr, i, num);
    }

    napi_set_named_property(env, obj, "data", arr);

    return obj;
}

napi_value toJsEventResults(napi_env env, const std::vector<EventResult>& results)
{
    napi_value arr;
    napi_create_array_with_length(env, results.size(), &arr);

    for (size_t i = 0; i < results.size(); i++) {
        napi_value jsRes = toJsEventResult(env, results[i]);
        napi_set_element(env, arr, i, jsRes);
    }

    return arr;
}
