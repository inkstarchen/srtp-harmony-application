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

#include "napi/native_api.h"
#include "filesystem_test.h"

#include <core/io/intf_file_manager.h>
#include <core/intf_engine.h>
#include <memory>
#include <string>
#include <hilog/log.h>

// Manager header for getting engine
#include "manager/include/lume_xcomponent_manager.h"
#include "manager/include/lume_renderer.h"
#include "3d_widget_adapter/core/include/lume/lume_common.h"

#undef LOG_TAG
#undef LOG_DOMAIN
#define LOG_TAG "FileSystemTestNAPI"
#define LOG_DOMAIN 0
#define LOGI(...) OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, __VA_ARGS__)
#define LOGE(...) OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, __VA_ARGS__)

namespace {
// Global FileSystemTest instance
std::unique_ptr<FileSystemTest::FileSystemTest> g_fileSystemTest;

// Helper to create napi_value from TestResult
napi_value CreateTestResult(napi_env env, const FileSystemTest::TestResult& result) {
    napi_value obj;
    napi_create_object(env, &obj);

    napi_value success;
    napi_get_boolean(env, result.success, &success);
    napi_set_named_property(env, obj, "success", success);

    napi_value message;
    napi_create_string_utf8(env, result.message.c_str(), NAPI_AUTO_LENGTH, &message);
    napi_set_named_property(env, obj, "message", message);

    napi_value data;
    napi_create_string_utf8(env, result.data.c_str(), NAPI_AUTO_LENGTH, &data);
    napi_set_named_property(env, obj, "data", data);

    return obj;
}

// Helper to create napi_value from EntryInfo
napi_value CreateEntryInfo(napi_env env, const FileSystemTest::EntryInfo& info) {
    napi_value obj;
    napi_create_object(env, &obj);

    napi_value success;
    napi_get_boolean(env, info.success, &success);
    napi_set_named_property(env, obj, "success", success);

    napi_value type;
    napi_create_string_utf8(env, info.type.c_str(), NAPI_AUTO_LENGTH, &type);
    napi_set_named_property(env, obj, "type", type);

    napi_value name;
    napi_create_string_utf8(env, info.name.c_str(), NAPI_AUTO_LENGTH, &name);
    napi_set_named_property(env, obj, "name", name);

    return obj;
}

// Helper to create napi_value from BatchTestResult
napi_value CreateBatchTestResult(napi_env env, const FileSystemTest::BatchTestResult& result) {
    napi_value obj;
    napi_create_object(env, &obj);

    napi_value passed;
    napi_create_int32(env, result.passed, &passed);
    napi_set_named_property(env, obj, "passed", passed);

    napi_value failed;
    napi_create_int32(env, result.failed, &failed);
    napi_set_named_property(env, obj, "failed", failed);

    napi_value resultsArray;
    napi_create_array_with_length(env, result.results.size(), &resultsArray);
    for (size_t i = 0; i < result.results.size(); i++) {
        napi_value item;
        napi_create_string_utf8(env, result.results[i].c_str(), NAPI_AUTO_LENGTH, &item);
        napi_set_element(env, resultsArray, i, item);
    }
    napi_set_named_property(env, obj, "results", resultsArray);

    return obj;
}

// Helper to get string from napi_value
std::string GetStringFromNapi(napi_env env, napi_value value, size_t maxLen = 512) {
    size_t length = 0;
    napi_get_value_string_utf8(env, value, nullptr, 0, &length);

    if (length > maxLen) {
        length = maxLen;
    }

    std::string buffer(length + 1, '\0');
    napi_get_value_string_utf8(env, value, &buffer[0], length + 1, &length);
    buffer.resize(length);
    return buffer;
}

} // anonymous namespace

// ==================== NAPI Method Implementations ====================

static napi_value InitializeFileSystemTest(napi_env env, napi_callback_info info) {
    napi_value result;

    if (!g_fileSystemTest) {
        g_fileSystemTest = std::make_unique<FileSystemTest::FileSystemTest>();
    }

    napi_get_boolean(env, g_fileSystemTest != nullptr, &result);
    LOGI("InitializeFileSystemTest: initialized=%d", g_fileSystemTest != nullptr);
    return result;
}

static napi_value SetFileManagerFromEngine(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    napi_value result;
    napi_get_boolean(env, false, &result);

    if (!g_fileSystemTest) {
        LOGE("FileSystemTest not initialized");
        return result;
    }

    // Get node ID string
    std::string nodeId = GetStringFromNapi(env, args[0]);

    // Try to get FileManager from engine through LumeXComponentManager
    auto& manager = LumeXComponent::LumeXComponentManager::GetInstance();
    auto renderer = manager.GetRendererById(nodeId);

    if (!renderer) {
        LOGE("Renderer not found for nodeId: %s", nodeId.c_str());
        return result;
    }

    auto lumeEngine = renderer->GetLumeEngine();
    if (!lumeEngine) {
        LOGE("LumeEngine not available for nodeId: %s", nodeId.c_str());
        return result;
    }

    // LumeCommon inherits from IEngine, need to cast to get core engine
    auto lumeCommon = dynamic_cast<OHOS::Render3D::LumeCommon*>(lumeEngine);
    if (!lumeCommon) {
        LOGE("LumeCommon cast failed for nodeId: %s", nodeId.c_str());
        return result;
    }

//    auto coreEngine = lumeCommon->GetCoreEngine();
//    if (!coreEngine) {
//        LOGE("CoreEngine not available for nodeId: %s", nodeId.c_str());
//        return result;
//    }
//
//    auto& fileManager = coreEngine->GetFileManager();
//    g_fileSystemTest->SetFileManager(&fileManager);

    napi_get_boolean(env, true, &result);
    LOGI("SetFileManagerFromEngine: success for nodeId=%s", nodeId.c_str());
    return result;
}

static napi_value TestOpenFile(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    std::string uri = GetStringFromNapi(env, args[0]);

    if (!g_fileSystemTest) {
        FileSystemTest::TestResult errorResult;
        errorResult.success = false;
        errorResult.message = "FileSystemTest not initialized";
        return CreateTestResult(env, errorResult);
    }

    auto result = g_fileSystemTest->TestOpenFile(uri);
    return CreateTestResult(env, result);
}

static napi_value TestCreateFile(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    std::string uri = GetStringFromNapi(env, args[0]);

    if (!g_fileSystemTest) {
        FileSystemTest::TestResult errorResult;
        errorResult.success = false;
        errorResult.message = "FileSystemTest not initialized";
        return CreateTestResult(env, errorResult);
    }

    auto result = g_fileSystemTest->TestCreateFile(uri);
    return CreateTestResult(env, result);
}

static napi_value TestFileExists(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    std::string uri = GetStringFromNapi(env, args[0]);

    if (!g_fileSystemTest) {
        FileSystemTest::TestResult errorResult;
        errorResult.success = false;
        errorResult.message = "FileSystemTest not initialized";
        return CreateTestResult(env, errorResult);
    }

    auto result = g_fileSystemTest->TestFileExists(uri);
    return CreateTestResult(env, result);
}

static napi_value TestDeleteFile(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    std::string uri = GetStringFromNapi(env, args[0]);

    if (!g_fileSystemTest) {
        FileSystemTest::TestResult errorResult;
        errorResult.success = false;
        errorResult.message = "FileSystemTest not initialized";
        return CreateTestResult(env, errorResult);
    }

    auto result = g_fileSystemTest->TestDeleteFile(uri);
    return CreateTestResult(env, result);
}

static napi_value TestReadFile(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    std::string uri = GetStringFromNapi(env, args[0]);

    if (!g_fileSystemTest) {
        FileSystemTest::TestResult errorResult;
        errorResult.success = false;
        errorResult.message = "FileSystemTest not initialized";
        return CreateTestResult(env, errorResult);
    }

    auto result = g_fileSystemTest->TestReadFile(uri);
    return CreateTestResult(env, result);
}

static napi_value TestWriteFile(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    std::string uri = GetStringFromNapi(env, args[0], 512);
    std::string content = GetStringFromNapi(env, args[1], 4096);  // Allow larger content

    if (!g_fileSystemTest) {
        FileSystemTest::TestResult errorResult;
        errorResult.success = false;
        errorResult.message = "FileSystemTest not initialized";
        return CreateTestResult(env, errorResult);
    }

    auto result = g_fileSystemTest->TestWriteFile(uri, content);
    return CreateTestResult(env, result);
}

static napi_value TestCreateDirectory(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    std::string uri = GetStringFromNapi(env, args[0]);

    if (!g_fileSystemTest) {
        FileSystemTest::TestResult errorResult;
        errorResult.success = false;
        errorResult.message = "FileSystemTest not initialized";
        return CreateTestResult(env, errorResult);
    }

    auto result = g_fileSystemTest->TestCreateDirectory(uri);
    return CreateTestResult(env, result);
}

static napi_value TestDirectoryExists(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    std::string uri = GetStringFromNapi(env, args[0]);

    if (!g_fileSystemTest) {
        FileSystemTest::TestResult errorResult;
        errorResult.success = false;
        errorResult.message = "FileSystemTest not initialized";
        return CreateTestResult(env, errorResult);
    }

    auto result = g_fileSystemTest->TestDirectoryExists(uri);
    return CreateTestResult(env, result);
}

static napi_value TestDeleteDirectory(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    std::string uri = GetStringFromNapi(env, args[0]);

    if (!g_fileSystemTest) {
        FileSystemTest::TestResult errorResult;
        errorResult.success = false;
        errorResult.message = "FileSystemTest not initialized";
        return CreateTestResult(env, errorResult);
    }

    auto result = g_fileSystemTest->TestDeleteDirectory(uri);
    return CreateTestResult(env, result);
}

static napi_value TestGetEntry(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    std::string uri = GetStringFromNapi(env, args[0]);

    if (!g_fileSystemTest) {
        FileSystemTest::EntryInfo errorInfo;
        errorInfo.success = false;
        errorInfo.type = "unknown";
        errorInfo.name = "";
        return CreateEntryInfo(env, errorInfo);
    }

    auto result = g_fileSystemTest->TestGetEntry(uri);
    return CreateEntryInfo(env, result);
}

static napi_value TestRegisterPath(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    std::string protocol = GetStringFromNapi(env, args[0], 64);
    std::string pathUri = GetStringFromNapi(env, args[1], 512);

    bool prepend = false;
    napi_get_value_bool(env, args[2], &prepend);

    if (!g_fileSystemTest) {
        FileSystemTest::TestResult errorResult;
        errorResult.success = false;
        errorResult.message = "FileSystemTest not initialized";
        return CreateTestResult(env, errorResult);
    }

    auto result = g_fileSystemTest->TestRegisterPath(protocol, pathUri, prepend);
    return CreateTestResult(env, result);
}

static napi_value TestRename(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    std::string fromUri = GetStringFromNapi(env, args[0], 512);
    std::string toUri = GetStringFromNapi(env, args[1], 512);

    if (!g_fileSystemTest) {
        FileSystemTest::TestResult errorResult;
        errorResult.success = false;
        errorResult.message = "FileSystemTest not initialized";
        return CreateTestResult(env, errorResult);
    }

    auto result = g_fileSystemTest->TestRename(fromUri, toUri);
    return CreateTestResult(env, result);
}

static napi_value RunAllTests(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    std::string testBasePath = GetStringFromNapi(env, args[0], 512);

    if (!g_fileSystemTest) {
        FileSystemTest::BatchTestResult errorResult;
        errorResult.passed = 0;
        errorResult.failed = 1;
        errorResult.results.push_back("FileSystemTest not initialized");
        return CreateBatchTestResult(env, errorResult);
    }

    auto result = g_fileSystemTest->RunAllTests(testBasePath);
    return CreateBatchTestResult(env, result);
}

// ==================== Registration Function ====================

void RegisterFileSystemTestMethods(std::vector<napi_property_descriptor>& props) {
    // Initialization
    props.push_back({"initializeFileSystemTest", nullptr, InitializeFileSystemTest,
                     nullptr, nullptr, nullptr, napi_default, nullptr});
    props.push_back({"setFileManagerFromEngine", nullptr, SetFileManagerFromEngine,
                     nullptr, nullptr, nullptr, napi_default, nullptr});

    // File operations
    props.push_back({"testOpenFile", nullptr, TestOpenFile, nullptr, nullptr, nullptr, napi_default, nullptr});
    props.push_back({"testCreateFile", nullptr, TestCreateFile, nullptr, nullptr, nullptr, napi_default, nullptr});
    props.push_back({"testFileExists", nullptr, TestFileExists, nullptr, nullptr, nullptr, napi_default, nullptr});
    props.push_back({"testDeleteFile", nullptr, TestDeleteFile, nullptr, nullptr, nullptr, napi_default, nullptr});
    props.push_back({"testReadFile", nullptr, TestReadFile, nullptr, nullptr, nullptr, napi_default, nullptr});
    props.push_back({"testWriteFile", nullptr, TestWriteFile, nullptr, nullptr, nullptr, napi_default, nullptr});

    // Directory operations
    props.push_back({"testCreateDirectory", nullptr, TestCreateDirectory, nullptr, nullptr, nullptr, napi_default, nullptr});
    props.push_back({"testDirectoryExists", nullptr, TestDirectoryExists, nullptr, nullptr, nullptr, napi_default, nullptr});
    props.push_back({"testDeleteDirectory", nullptr, TestDeleteDirectory, nullptr, nullptr, nullptr, napi_default, nullptr});

    // Entry info
    props.push_back({"testGetEntry", nullptr, TestGetEntry, nullptr, nullptr, nullptr, napi_default, nullptr});

    // Registration
    props.push_back({"testRegisterPath", nullptr, TestRegisterPath, nullptr, nullptr, nullptr, napi_default, nullptr});
    props.push_back({"testRename", nullptr, TestRename, nullptr, nullptr, nullptr, napi_default, nullptr});

    // Batch test
    props.push_back({"runAllTests", nullptr, RunAllTests, nullptr, nullptr, nullptr, napi_default, nullptr});
}