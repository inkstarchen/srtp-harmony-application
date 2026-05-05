#include "layoutSystem.h"
#include <algorithm>

LayoutSystem::LayoutSystem() : nextIndex(0) {}

LayoutSystem::~LayoutSystem() {}

void LayoutSystem::init(const LayoutConfig& cfg) {
    config = cfg;
    occupied.assign(config.rows * config.cols, false);
    nextIndex = 0;
}

Vector3 LayoutSystem::computePosition(uint32_t cellIndex) const {
    uint32_t row, col;
    
    if (config.fillOrder == FillOrder::ROW_MAJOR) {
        // 行优先：从左到右，换行
        row = cellIndex / config.cols;
        col = cellIndex % config.cols;
    } else {
        // 列优先：从上到下，换列
        col = cellIndex / config.rows;
        row = cellIndex % config.rows;
    }

    // 计算坐标
    // 假设 Y 轴向上，行号越大 Y 越小（从上到下）
    float x = config.origin.x + col * (config.cellWidth + config.spacingX);
    float y = config.origin.y - row * (config.cellHeight + config.spacingY);
    float z = config.zPosition;

    return Vector3(x, y, z);
}

bool LayoutSystem::getNextPosition(Vector3& outPos) {
    if (!hasSpace()) return false;

    // 从 nextIndex 开始查找
    for (uint32_t i = nextIndex; i < occupied.size(); ++i) {
        if (!occupied[i]) {
            nextIndex = i + 1;
            outPos = computePosition(i);
            return true;
        }
    }

    // 如果没找到，从头查找（处理中间有空位的情况）
    for (uint32_t i = 0; i < nextIndex; ++i) {
        if (!occupied[i]) {
            nextIndex = i + 1;
            outPos = computePosition(i);
            return true;
        }
    }

    return false;
}

bool LayoutSystem::getPositionAt(uint32_t cellIndex, Vector3& outPos) const {
    if (cellIndex >= occupied.size()) return false;
    outPos = computePosition(cellIndex);
    return true;
}

bool LayoutSystem::occupyCell(uint32_t cellIndex) {
    if (cellIndex >= occupied.size() || occupied[cellIndex]) return false;
    occupied[cellIndex] = true;
    return true;
}

void LayoutSystem::releaseCell(uint32_t cellIndex) {
    if (cellIndex < occupied.size()) {
        occupied[cellIndex] = false;
        if (cellIndex < nextIndex) {
            nextIndex = cellIndex;
        }
    }
}

void LayoutSystem::reset() {
    std::fill(occupied.begin(), occupied.end(), false);
    nextIndex = 0;
}

bool LayoutSystem::hasSpace() const {
    return getRemainingCells() > 0;
}

uint32_t LayoutSystem::getRemainingCells() const {
    uint32_t count = 0;
    for (bool occ : occupied) {
        if (!occ) count++;
    }
    return count;
}

uint32_t LayoutSystem::getTotalCells() const {
    return static_cast<uint32_t>(occupied.size());
}