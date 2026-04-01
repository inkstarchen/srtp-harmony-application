/*
 * Copyright (c) 2022 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "ohos_file.h"
#include "base/namespace.h"

#include <cerrno>
#include <cstdint>
#include <cstring>

#include <climits>
#define CORE_MAX_PATH PATH_MAX

#include <base/containers/string.h>
#include <base/containers/string_view.h>
#include <core/io/intf_file.h>
#include <core/log.h>
#include <core/namespace.h>
#include <hilog/log.h>

#undef LOG_TAG
#undef LOG_DOMAIN
#define LOG_TAG "Lume_Common"
#define LOG_DOMAIN 0
#define LOGI(...) OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, __VA_ARGS__)
#define LOGE(...) OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, __VA_ARGS__)
#define LOGD(...) OH_LOG_Print(LOG_APP, LOG_DEBUG, LOG_DOMAIN, LOG_TAG, __VA_ARGS__)

CORE_BEGIN_NAMESPACE()
using BASE_NS::CloneData;
using BASE_NS::string;
using BASE_NS::string_view;

void OhosResMgr::UpdateResManager(const PlatformHapInfo& hapInfo)
{
    // 直接使用传入的 NativeResourceManager，不再创建新的
    if (hapInfo.resourceManager != nullptr) {
        resourceManager_ = hapInfo.resourceManager;
        CORE_LOG_D("resource manager initialized from external");
    }
}

NativeResourceManager* OhosResMgr::GetResMgr() const
{
    return resourceManager_;
}

OhosFileDirectory::OhosFileDirectory(BASE_NS::refcnt_ptr<OhosResMgr> resMgr) : dirResMgr_(resMgr) {}

OhosFileDirectory::~OhosFileDirectory()
{
    Close();
}

void OhosFileDirectory::Close()
{
    if (dir_) {
        dir_.reset();
    }
}

bool OhosFileDirectory::IsDir(BASE_NS::string_view path, BASE_NS::vector<BASE_NS::string>& fileList) const
{
    NativeResourceManager* resMgr = dirResMgr_->GetResMgr();
    if (!resMgr) {
        LOGE("ResourceManager is null");
        return false;
    }

    RawDir* rawDir = OH_ResourceManager_OpenRawDir(resMgr, path.data());
    if (!rawDir) {
        LOGE("OpenRawDir failed, path:%s", path.data());
        return false;
    }

    int count = OH_ResourceManager_GetRawFileCount(rawDir);
    for (int i = 0; i < count; i++) {
        const char* name = OH_ResourceManager_GetRawFileName(rawDir, i);
        if (name) {
            fileList.push_back(name);
        }
    }
    OH_ResourceManager_CloseRawDir(rawDir);

    if (fileList.empty()) {
        LOGE("GetRawFileList empty, path:%s", path.data());
        return false;
    }
    return true;
}

bool OhosFileDirectory::IsFile(BASE_NS::string_view path) const
{
    NativeResourceManager* resMgr = dirResMgr_->GetResMgr();
    if (!resMgr) {
        return false;
    }

    RawFile* rawFile = OH_ResourceManager_OpenRawFile(resMgr, path.data());
    if (rawFile) {
        OH_ResourceManager_CloseRawFile(rawFile);
        return true;
    }
    return false;
}

bool OhosFileDirectory::Open(const BASE_NS::string_view pathIn)
{
    auto path = pathIn;
    if (path.back() == '/') {
        path.remove_suffix(1);
    }
    if (path.front() == '/') {
        path.remove_prefix(1);
    }
    BASE_NS::vector<BASE_NS::string> fileList;
    if (IsDir(path, fileList)) {
        dir_ = BASE_NS::make_unique<OhosDirImpl>(path, fileList);
        return true;
    }
    return false;
}

BASE_NS::vector<IDirectory::Entry> OhosFileDirectory::GetEntries() const
{
    CORE_ASSERT_MSG(dir_, "Dir not open");
    BASE_NS::vector<IDirectory::Entry> result;
    if (dir_) {
        for (int i = 0; i < static_cast<int>(dir_->fileList_.size()); i++) {
            auto path = dir_->path_ + "/" + BASE_NS::string(dir_->fileList_[i].c_str());
            auto entry = GetEntry(path);
            entry.timestamp = static_cast<uint32_t>(i);
            entry.name = dir_->fileList_[i].c_str();
            result.emplace_back(entry);
        }
    }
    return result;
}

IDirectory::Entry OhosFileDirectory::GetEntry(BASE_NS::string_view uriIn) const
{
    if (!uriIn.empty()) {
        IDirectory::Entry::Type type;
        BASE_NS::vector<BASE_NS::string> fileList;
        if (IsFile(uriIn)) {
            type = IDirectory::Entry::FILE;
        } else if (IsDir(uriIn, fileList)) {
            type = IDirectory::Entry::DIRECTORY;
        } else {
            type = IDirectory::Entry::UNKNOWN;
        }
        uint64_t timestamp = 0;
        BASE_NS::string entryName { uriIn };
        return IDirectory::Entry { type, entryName, timestamp };
    }
    return {};
}

OhosFile::OhosFile(BASE_NS::refcnt_ptr<OhosResMgr> resMgr) : fileResMgr_(resMgr)
{
    buffer_ = std::make_shared<OhosFileStorage>(nullptr);
}

void OhosFile::UpdateStorage(std::shared_ptr<OhosFileStorage> buffer)
{

    buffer_ = BASE_NS::move(buffer);
}

IFile::Mode OhosFile::GetMode() const
{
    return IFile::Mode::READ_ONLY;
}

void OhosFile::Close() {}

uint64_t OhosFile::Read(void* buffer, uint64_t count)
{
    uint64_t toRead = count;
    uint64_t sum = index_ + toRead;
    if (sum < index_) {
        return 0;
    }
    if (sum > buffer_->Size()) {
        toRead = buffer_->Size() - index_;
    }
    if (toRead <= 0) {
        return toRead;
    }
    if (toRead > SIZE_MAX) {
        CORE_ASSERT_MSG(false, "Unable to read chunks bigger than (SIZE_MAX) bytes.");
        return 0;
    }
    if (CloneData(buffer, static_cast<size_t>(count), &(buffer_->GetStorage()[index_]), static_cast<size_t>(toRead))) {
        index_ += toRead;
    }
    return toRead;
}

uint64_t OhosFile::Write(const void* buffer, uint64_t count)
{
    return 0;
}

uint64_t OhosFile::Append(const void* buffer, uint64_t count, uint64_t flushSize)
{
    return 0;
}

uint64_t OhosFile::GetLength() const
{
    return buffer_->Size();
}

bool OhosFile::Seek(uint64_t aOffset)
{
    if (aOffset < buffer_->Size()) {
        index_ = aOffset;
        return true;
    }
    return false;
}

uint64_t OhosFile::GetPosition() const
{
    return index_;
}

std::shared_ptr<OhosFileStorage> OhosFile::Open(BASE_NS::string_view rawFile)
{
    BASE_NS::unique_ptr<uint8_t[]> data;
    size_t dataLen = 0;
    LOGI("OpenRawFile start, filename:%{public}s", rawFile.data());
    if (OpenRawFile(rawFile, dataLen, data)) {
        buffer_->SetBuffer(BASE_NS::move(data), static_cast<uint64_t>(dataLen));
        LOGI("OpenRawFile success, filename:%{public}s, datalenth:%{public}zu", rawFile.data(), dataLen);
        return buffer_;
    }
    return nullptr;
}

bool OhosFile::OpenRawFile(BASE_NS::string_view uriIn, size_t& dataLen, BASE_NS::unique_ptr<uint8_t[]>& dest)
{
    NativeResourceManager* resMgr = fileResMgr_->GetResMgr();
    if (!resMgr) {
        LOGE("ResourceManager is null");
        return false;
    }

    // 处理路径：移除前导斜杠
    const char* path = uriIn.data();
    while (*path == '/') {
        path++;
    }

    RawFile* rawFile = OH_ResourceManager_OpenRawFile(resMgr, path);
    if (!rawFile) {
        LOGE("OpenRawFile failed, path:%s", path);
        return false;
    }

    dataLen = static_cast<size_t>(OH_ResourceManager_GetRawFileSize(rawFile));
    if (dataLen == 0) {
        LOGE("RawFile size is 0, path:%s", path);
        OH_ResourceManager_CloseRawFile(rawFile);
        return false;
    }

    dest = BASE_NS::make_unique<uint8_t[]>(dataLen);
    int readLen = OH_ResourceManager_ReadRawFile(rawFile, dest.get(), dataLen);
    OH_ResourceManager_CloseRawFile(rawFile);

    if (readLen != static_cast<int>(dataLen)) {
        LOGE("ReadRawFile failed, expected:%zu, actual:%d, path:%s", dataLen, readLen, path);
        dest.reset();
        dataLen = 0;
        return false;
    }

    return true;
}
CORE_END_NAMESPACE()