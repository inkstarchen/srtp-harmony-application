// 事件类型枚举（必须与 C++ 端 EventType 一致）
export enum EventType {

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
}

// 事件优先级（必须与 C++ 端 EventPriority 一致）
export enum EventPriority {
  HIGH = 0,    // Touch 输入事件
  NORMAL = 1,  // 普通事件
  LOW = 2      // 动画、脚本事件
}

// 事件命令结构（必须与 C++ 端 EventCommand 对应）
export interface EventCommand {
  type: EventType
  priority: number
  nodeId: number
  timestamp: number
  data: number[]
}

// 默认优先级映射
export function getDefaultPriority(type: EventType): EventPriority {
  switch (type) {
    case EventType.TOUCH_DOWN:
    case EventType.TOUCH_MOVE:
    case EventType.TOUCH_UP:
    case EventType.BUTTON_TRIGGER:
    case EventType.SET_PROPERTY_REQUEST:
      return EventPriority.HIGH;

    case EventType.RAYCAST_REQUEST:
    case EventType.ROTATE_REQUEST:
    case EventType.PAN_REQUEST:
    case EventType.SCALE_REQUEST:
      return EventPriority.NORMAL;
    case EventType.RESET_GRAVITY:
    default:
      return EventPriority.LOW;
  }
}

export enum Property{
  // Base Property 1-49
  POS = 1,
  ROTATION = 2,
  VELOCITY = 3,
  ANGLE_VELOCITY = 4,
  SCALE = 5,
  MASS = 6,
  RESTITUTION = 7,
  FRICTION = 8,
  STATIC = 9,
  IMPULSE = 10,
  // System Property 50-99
  CAMERA = 50,
}

export interface  EventResult {
  type:EventType;
  nodeId:number;
  timestamp:number;
  status:number;
  data:number[];
};

export interface ReturnData{
  bufferData: ArrayBuffer;
  results: EventResult[];
}
