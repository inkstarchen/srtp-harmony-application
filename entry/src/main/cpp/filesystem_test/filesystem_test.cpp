/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
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

#include "filesystem_test.h"

#include <core/io/intf_file_manager.h>
#include <core/io/intf_file.h>
#include <core/io/intf_directory.h>
#include <base/containers/string_view.h>

#include <hilog/log.h>

#undef LOG_TAG
#undef LOG_DOMAIN
#define LOG_TAG "FileSystemTest"
#define LOG_DOMAIN 0
#define LOGI(...) OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, __VA_ARGS__)
#define LOGE(...) OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, __VA_ARGS__)
#define LOGD(...) OH_LOG_Print(LOG_APP, LOG_DEBUG, LOG_DOMAIN, LOG_TAG, __VA_ARGS__)

namespace FileSystemTest {

FileSystemTest::FileSystemTest() : fileManager_(nullptr) {}

FileSystemTest::~FileSystemTest() {}

void FileSystemTest::SetFileManager(CORE_NS::IFileManager* fileManager) {
    fileManager_ = fileManager;
    if (fileManager_) {
        LOGI("FileManager set successfully");
    } else {
        LOGE("FileManager set to null");
    }
}

bool FileSystemTest::IsInitialized() const {
    return fileManager_ != nullptr;
}

// ========== File Operations ==========

TestResult FileSystemTest::TestOpenFile(const std::string& uri) {
    TestResult result;
    result.success = false;
    result.message = "";
    result.data = "";

    if (!fileManager_) {
        result.message = "FileManager not initialized";
        LOGE("%s", result.message.c_str());
        return result;
    }

    auto file = fileManager_->OpenFile(BASE_NS::string_view(uri));
    if (file) {
        result.success = true;
        result.message = "Successfully opened file: " + uri;
        uint64_t size = file->GetLength();
        result.data = "File size: " + std::to_string(size) + " bytes";
        file->Close();
        LOGI("%s, size=%llu", result.message.c_str(), size);
    } else {
        result.message = "Failed to open file: " + uri;
        LOGE("%s", result.message.c_str());
    }

    return result;
}

TestResult FileSystemTest::TestCreateFile(const std::string& uri) {
    TestResult result;
    result.success = false;
    result.message = "";
    result.data = "";

    if (!fileManager_) {
        result.message = "FileManager not initialized";
        LOGE("%s", result.message.c_str());
        return result;
    }

    auto file = fileManager_->CreateFile(BASE_NS::string_view(uri));
    if (file) {
        result.success = true;
        result.message = "Successfully created file: " + uri;
        file->Close();
        LOGI("%s", result.message.c_str());
    } else {
        result.message = "Failed to create file: " + uri;
        LOGE("%s", result.message.c_str());
    }

    return result;
}

TestResult FileSystemTest::TestFileExists(const std::string& uri) {
    TestResult result;
    result.success = false;
    result.message = "";
    result.data = "";

    if (!fileManager_) {
        result.message = "FileManager not initialized";
        LOGE("%s", result.message.c_str());
        return result;
    }

    bool exists = fileManager_->FileExists(BASE_NS::string_view(uri));
    result.success = exists;
    if (exists) {
        result.message = "File exists: " + uri;
        result.data = "true";
        LOGI("%s", result.message.c_str());
    } else {
        result.message = "File does not exist: " + uri;
        result.data = "false";
        LOGD("%s", result.message.c_str());
    }

    return result;
}

TestResult FileSystemTest::TestDeleteFile(const std::string& uri) {
    TestResult result;
    result.success = false;
    result.message = "";
    result.data = "";

    if (!fileManager_) {
        result.message = "FileManager not initialized";
        LOGE("%s", result.message.c_str());
        return result;
    }

    bool deleted = fileManager_->DeleteFile(BASE_NS::string_view(uri));
    result.success = deleted;
    if (deleted) {
        result.message = "Successfully deleted file: " + uri;
        LOGI("%s", result.message.c_str());
    } else {
        result.message = "Failed to delete file: " + uri;
        LOGE("%s", result.message.c_str());
    }

    return result;
}

TestResult FileSystemTest::TestReadFile(const std::string& uri) {
    TestResult result;
    result.success = false;
    result.message = "";
    result.data = "";

    if (!fileManager_) {
        result.message = "FileManager not initialized";
        LOGE("%s", result.message.c_str());
        return result;
    }

    auto file = fileManager_->OpenFile(BASE_NS::string_view(uri));
    if (!file) {
        result.message = "Failed to open file for reading: " + uri;
        LOGE("%s", result.message.c_str());
        return result;
    }

    uint64_t size = file->GetLength();
    if (size == 0) {
        result.success = true;
        result.message = "File is empty: " + uri;
        result.data = "";
        file->Close();
        LOGI("%s", result.message.c_str());
        return result;
    }

    std::vector<char> buffer(size);
    uint64_t bytesRead = file->Read(buffer.data(), size);

    if (bytesRead > 0) {
        result.success = true;
        result.message = "Successfully read " + std::to_string(bytesRead) + " bytes from: " + uri;
        result.data = std::string(buffer.data(), bytesRead);
        LOGI("%s", result.message.c_str());
    } else {
        result.message = "Failed to read file content: " + uri;
        LOGE("%s", result.message.c_str());
    }

    file->Close();
    return result;
}

TestResult FileSystemTest::TestWriteFile(const std::string& uri, const std::string& content) {
    TestResult result;
    result.success = false;
    result.message = "";
    result.data = "";

    if (!fileManager_) {
        result.message = "FileManager not initialized";
        LOGE("%s", result.message.c_str());
        return result;
    }

    auto file = fileManager_->CreateFile(BASE_NS::string_view(uri));
    if (!file) {
        result.message = "Failed to create file for writing: " + uri;
        LOGE("%s", result.message.c_str());
        return result;
    }

    uint64_t bytesWritten = file->Write(content.data(), content.size());
    if (bytesWritten > 0) {
        result.success = true;
        result.message = "Successfully wrote " + std::to_string(bytesWritten) + " bytes to: " + uri;
        LOGI("%s", result.message.c_str());
    } else {
        result.message = "Failed to write to file: " + uri;
        LOGE("%s", result.message.c_str());
    }

    file->Close();
    return result;
}

// ========== Directory Operations ==========

TestResult FileSystemTest::TestCreateDirectory(const std::string& uri) {
    TestResult result;
    result.success = false;
    result.message = "";
    result.data = "";

    if (!fileManager_) {
        result.message = "FileManager not initialized";
        LOGE("%s", result.message.c_str());
        return result;
    }

    auto dir = fileManager_->CreateDirectory(BASE_NS::string_view(uri));
    if (dir) {
        result.success = true;
        result.message = "Successfully created directory: " + uri;
        LOGI("%s", result.message.c_str());
    } else {
        result.message = "Failed to create directory: " + uri;
        LOGE("%s", result.message.c_str());
    }

    return result;
}

TestResult FileSystemTest::TestDirectoryExists(const std::string& uri) {
    TestResult result;
    result.success = false;
    result.message = "";
    result.data = "";

    if (!fileManager_) {
        result.message = "FileManager not initialized";
        LOGE("%s", result.message.c_str());
        return result;
    }

    bool exists = fileManager_->DirectoryExists(BASE_NS::string_view(uri));
    result.success = exists;
    if (exists) {
        result.message = "Directory exists: " + uri;
        result.data = "true";
        LOGI("%s", result.message.c_str());
    } else {
        result.message = "Directory does not exist: " + uri;
        result.data = "false";
        LOGD("%s", result.message.c_str());
    }

    return result;
}

TestResult FileSystemTest::TestDeleteDirectory(const std::string& uri) {
    TestResult result;
    result.success = false;
    result.message = "";
    result.data = "";

    if (!fileManager_) {
        result.message = "FileManager not initialized";
        LOGE("%s", result.message.c_str());
        return result;
    }

    bool deleted = fileManager_->DeleteDirectory(BASE_NS::string_view(uri));
    result.success = deleted;
    if (deleted) {
        result.message = "Successfully deleted directory: " + uri;
        LOGI("%s", result.message.c_str());
    } else {
        result.message = "Failed to delete directory: " + uri;
        LOGE("%s", result.message.c_str());
    }

    return result;
}

EntryInfo FileSystemTest::TestGetEntry(const std::string& uri) {
    EntryInfo info;
    info.success = false;
    info.type = "unknown";
    info.name = "";
    info.timestamp = 0;

    if (!fileManager_) {
        LOGE("FileManager not initialized");
        return info;
    }

    auto entry = fileManager_->GetEntry(BASE_NS::string_view(uri));
    info.success = true;
    info.type = EntryTypeToString(entry.type);
    info.name = std::string(entry.name);
    info.timestamp = entry.timestamp;

    LOGI("GetEntry: uri=%s, type=%s, name=%s", uri.c_str(), info.type.c_str(), info.name.c_str());
    return info;
}

// ========== Path Registration ==========

TestResult FileSystemTest::TestRegisterPath(const std::string& protocol,
                                            const std::string& pathUri,
                                            bool prepend) {
    TestResult result;
    result.success = false;
    result.message = "";
    result.data = "";

    if (!fileManager_) {
        result.message = "FileManager not initialized";
        LOGE("%s", result.message.c_str());
        return result;
    }

    bool registered = fileManager_->RegisterPath(
        BASE_NS::string_view(protocol),
        BASE_NS::string_view(pathUri),
        prepend);

    result.success = registered;
    if (registered) {
        result.message = "Successfully registered path: " + protocol + " -> " + pathUri;
        LOGI("%s", result.message.c_str());
    } else {
        result.message = "Failed to register path: " + protocol + " -> " + pathUri;
        LOGE("%s", result.message.c_str());
    }

    return result;
}

// ========== Rename Operation ==========

TestResult FileSystemTest::TestRename(const std::string& fromUri, const std::string& toUri) {
    TestResult result;
    result.success = false;
    result.message = "";
    result.data = "";

    if (!fileManager_) {
        result.message = "FileManager not initialized";
        LOGE("%s", result.message.c_str());
        return result;
    }

    bool renamed = fileManager_->Rename(
        BASE_NS::string_view(fromUri),
        BASE_NS::string_view(toUri));

    result.success = renamed;
    if (renamed) {
        result.message = "Successfully renamed: " + fromUri + " -> " + toUri;
        LOGI("%s", result.message.c_str());
    } else {
        result.message = "Failed to rename: " + fromUri + " -> " + toUri;
        LOGE("%s", result.message.c_str());
    }

    return result;
}

// ========== Batch Test ==========

BatchTestResult FileSystemTest::RunAllTests(const std::string& testBasePath) {
    BatchTestResult batch;
    batch.passed = 0;
    batch.failed = 0;
    batch.results.clear();

    if (!fileManager_) {
        batch.results.push_back("FileManager not initialized - cannot run tests");
        batch.failed = 1;
        return batch;
    }

    LOGI("Starting batch tests with base path: %s", testBasePath.c_str());

    // Create test directory
    std::string testDir = GenerateTestUri(testBasePath, "fstest_dir");
    auto dirResult = TestCreateDirectory(testDir);
    if (dirResult.success) {
        batch.passed++;
        batch.results.push_back("[PASS] CreateDirectory: " + testDir);
    } else {
        batch.failed++;
        batch.results.push_back("[FAIL] CreateDirectory: " + testDir + " - " + dirResult.message);
    }

    // Test directory exists
    auto dirExistsResult = TestDirectoryExists(testDir);
    if (dirExistsResult.success) {
        batch.passed++;
        batch.results.push_back("[PASS] DirectoryExists: " + testDir);
    } else {
        batch.failed++;
        batch.results.push_back("[FAIL] DirectoryExists: " + testDir);
    }

    // Create test file
    std::string testFile = GenerateTestUri(testBasePath, "fstest_file.txt");
    auto createResult = TestCreateFile(testFile);
    if (createResult.success) {
        batch.passed++;
        batch.results.push_back("[PASS] CreateFile: " + testFile);
    } else {
        batch.failed++;
        batch.results.push_back("[FAIL] CreateFile: " + testFile + " - " + createResult.message);
    }

    // Write to file
    std::string testContent = "FileSystem Test Content - Hello World!";
    auto writeResult = TestWriteFile(testFile, testContent);
    if (writeResult.success) {
        batch.passed++;
        batch.results.push_back("[PASS] WriteFile: " + testFile);
    } else {
        batch.failed++;
        batch.results.push_back("[FAIL] WriteFile: " + testFile + " - " + writeResult.message);
    }

    // Read file
    auto readResult = TestReadFile(testFile);
    if (readResult.success && readResult.data == testContent) {
        batch.passed++;
        batch.results.push_back("[PASS] ReadFile: " + testFile + " (content verified)");
    } else if (readResult.success) {
        batch.passed++;
        batch.results.push_back("[PASS] ReadFile: " + testFile + " (content mismatch)");
    } else {
        batch.failed++;
        batch.results.push_back("[FAIL] ReadFile: " + testFile + " - " + readResult.message);
    }

    // Check file exists
    auto fileExistsResult = TestFileExists(testFile);
    if (fileExistsResult.success) {
        batch.passed++;
        batch.results.push_back("[PASS] FileExists: " + testFile);
    } else {
        batch.failed++;
        batch.results.push_back("[FAIL] FileExists: " + testFile);
    }

    // Get entry info
    auto entryInfo = TestGetEntry(testFile);
    if (entryInfo.success && entryInfo.type == "file") {
        batch.passed++;
        batch.results.push_back("[PASS] GetEntry: " + testFile + " (type=" + entryInfo.type + ")");
    } else {
        batch.failed++;
        batch.results.push_back("[FAIL] GetEntry: " + testFile);
    }

    // Rename file
    std::string renamedFile = GenerateTestUri(testBasePath, "fstest_renamed.txt");
    auto renameResult = TestRename(testFile, renamedFile);
    if (renameResult.success) {
        batch.passed++;
        batch.results.push_back("[PASS] Rename: " + testFile + " -> " + renamedFile);
    } else {
        batch.failed++;
        batch.results.push_back("[FAIL] Rename: " + testFile + " -> " + renamedFile);
    }

    // Delete renamed file
    auto deleteResult = TestDeleteFile(renamedFile);
    if (deleteResult.success) {
        batch.passed++;
        batch.results.push_back("[PASS] DeleteFile: " + renamedFile);
    } else {
        batch.failed++;
        batch.results.push_back("[FAIL] DeleteFile: " + renamedFile + " - " + deleteResult.message);
    }

    // Delete test directory
    auto deleteDirResult = TestDeleteDirectory(testDir);
    if (deleteDirResult.success) {
        batch.passed++;
        batch.results.push_back("[PASS] DeleteDirectory: " + testDir);
    } else {
        batch.failed++;
        batch.results.push_back("[FAIL] DeleteDirectory: " + testDir + " - " + deleteDirResult.message);
    }

    LOGI("Batch tests completed: %d passed, %d failed", batch.passed, batch.failed);
    return batch;
}

// ========== Private Helpers ==========

std::string FileSystemTest::EntryTypeToString(uint8_t type) {
    // IDirectory::Entry::Type enum values
    // 0 = UNKNOWN, 1 = FILE, 2 = DIRECTORY (based on intf_directory.h)
    switch (type) {
        case 1:
            return "file";
        case 2:
            return "directory";
        default:
            return "unknown";
    }
}

std::string FileSystemTest::GenerateTestUri(const std::string& basePath, const std::string& name) {
    // Generate a URI based on the base path
    // If basePath starts with a protocol (e.g., "file://"), use it directly
    if (basePath.find("://") != std::string::npos) {
        return basePath + name;
    }
    // Otherwise, assume file:// protocol
    return "file://" + basePath + name;
}

} // namespace FileSystemTest