#ifndef DAYNOTE_LAYOUT_SYSTEM_H
#define DAYNOTE_LAYOUT_SYSTEM_H

#include <cstdint>
#include <vector>
#include "vec.h"

enum class LayoutType : uint8_t {
    GRID = 0,       // 网格布局
    CIRCLE = 1,     // 圆形布局（未来扩展）
    HEXAGON = 2     // 六边形布局（未来扩展）
};

enum FillOrder : uint8_t {
    ROW_MAJOR,          // 从左到右，从上到下（默认）
    COL_MAJOR           // 从上到下，从左到右
};

struct LayoutConfig {
    LayoutType type;
    
    // 网格布局参数
    uint32_t rows;
    uint32_t cols;
    float cellWidth;
    float cellHeight;
    float cellDepth;        // 物体厚度
    float spacingX;
    float spacingY;
    Vector3 origin;         // 网格原点
    float zPosition;        // 固定 Z 坐标
    
    // 填充顺序
    FillOrder fillOrder;
};

class LayoutSystem {
public:
    LayoutSystem();
    ~LayoutSystem();
    
    // 初始化布局配置
    void init(const LayoutConfig& config);
    
    // 获取下一个可用格子的世界坐标
    bool getNextPosition(Vector3& outPos);
    
    // 获取指定格子索引的世界坐标
    bool getPositionAt(uint32_t cellIndex, Vector3& outPos) const;
    
    // 占用格子
    bool occupyCell(uint32_t cellIndex);
    
    // 释放格子
    void releaseCell(uint32_t cellIndex);
    
    // 重置所有格子占用状态
    void reset();
    
    // 是否还有空位
    bool hasSpace() const;
    
    // 获取剩余空格数
    uint32_t getRemainingCells() const;
    
    // 获取总格子数
    uint32_t getTotalCells() const;
    
    // 获取配置
    const LayoutConfig& getConfig() const { return config; }

private:
    LayoutConfig config;
    std::vector<bool> occupied;
    uint32_t nextIndex;
    
    // 计算格子位置
    Vector3 computePosition(uint32_t cellIndex) const;
};

#endif // DAYNOTE_LAYOUT_SYSTEM_H