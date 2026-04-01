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

#ifndef FILESYSTEM_TEST_H
#define FILESYSTEM_TEST_H

#include <string>
#include <vector>
#include <cstdint>

// Forward declaration for IFileManager
namespace CORE_NS {
class IFileManager;
class IDirectory;
}

namespace FileSystemTest {

/**
 * @brief Test result structure returned by individual test methods
 */
struct TestResult {
    bool success;
    std::string message;
    std::string data;  // For returning file content or additional info
};

/**
 * @brief Entry information from GetEntry test
 */
struct EntryInfo {
    bool success;
    std::string type;      // "file", "directory", "unknown"
    std::string name;
    uint64_t timestamp;
};

/**
 * @brief Batch test result from RunAllTests
 */
struct BatchTestResult {
    int32_t passed;
    int32_t failed;
    std::vector<std::string> results;
};

/**
 * @brief FileSystemTest class provides testing functionality for FileManager operations
 *
 * This class wraps FileManager operations and provides test methods that can be
 * called from ArkTS through NAPI bindings.
 */
class FileSystemTest {
public:
    FileSystemTest();
    ~FileSystemTest();

    /**
     * @brief Set the FileManager instance for testing
     * @param fileManager Pointer to IFileManager instance
     */
    void SetFileManager(CORE_NS::IFileManager* fileManager);

    /**
     * @brief Check if FileManager is properly initialized
     * @return true if FileManager is available
     */
    bool IsInitialized() const;

    // ========== File Operations ==========

    /**
     * @brief Test opening an existing file
     * @param uri File URI to open
     * @return TestResult with success status and message
     */
    TestResult TestOpenFile(const std::string& uri);

    /**
     * @brief Test creating a new file
     * @param uri File URI to create
     * @return TestResult with success status and message
     */
    TestResult TestCreateFile(const std::string& uri);

    /**
     * @brief Test checking if a file exists
     * @param uri File URI to check
     * @return TestResult with success status
     */
    TestResult TestFileExists(const std::string& uri);

    /**
     * @brief Test deleting a file
     * @param uri File URI to delete
     * @return TestResult with success status
     */
    TestResult TestDeleteFile(const std::string& uri);

    /**
     * @brief Test reading file content
     * @param uri File URI to read
     * @return TestResult with file content in data field
     */
    TestResult TestReadFile(const std::string& uri);

    /**
     * @brief Test writing content to a file
     * @param uri File URI to write
     * @param content Content to write
     * @return TestResult with success status
     */
    TestResult TestWriteFile(const std::string& uri, const std::string& content);

    // ========== Directory Operations ==========

    /**
     * @brief Test creating a directory
     * @param uri Directory URI to create
     * @return TestResult with success status
     */
    TestResult TestCreateDirectory(const std::string& uri);

    /**
     * @brief Test checking if a directory exists
     * @param uri Directory URI to check
     * @return TestResult with success status
     */
    TestResult TestDirectoryExists(const std::string& uri);

    /**
     * @brief Test deleting a directory
     * @param uri Directory URI to delete
     * @return TestResult with success status
     */
    TestResult TestDeleteDirectory(const std::string& uri);

    /**
     * @brief Test getting entry information
     * @param uri URI to get entry info for
     * @return EntryInfo with type, name, and timestamp
     */
    EntryInfo TestGetEntry(const std::string& uri);

    // ========== Path Registration ==========

    /**
     * @brief Test registering a path
     * @param protocol Protocol name (e.g., "test")
     * @param pathUri URI to map to the protocol
     * @param prepend Add to front of search list
     * @return TestResult with success status
     */
    TestResult TestRegisterPath(const std::string& protocol,
                                const std::string& pathUri,
                                bool prepend);

    // ========== Rename Operation ==========

    /**
     * @brief Test renaming a file or directory
     * @param fromUri Source URI
     * @param toUri Destination URI
     * @return TestResult with success status
     */
    TestResult TestRename(const std::string& fromUri, const std::string& toUri);

    // ========== Batch Test ==========

    /**
     * @brief Run all tests in sequence
     * @param testBasePath Base path for test operations (e.g., "/data/test/")
     * @return BatchTestResult with passed/failed counts and detailed results
     */
    BatchTestResult RunAllTests(const std::string& testBasePath);

private:
    CORE_NS::IFileManager* fileManager_;

    /**
     * @brief Convert IDirectory::Entry::Type to string
     */
    std::string EntryTypeToString(uint8_t type);

    /**
     * @brief Generate unique test URI
     */
    std::string GenerateTestUri(const std::string& basePath, const std::string& name);
};

} // namespace FileSystemTest

#endif // FILESYSTEM_TEST_H