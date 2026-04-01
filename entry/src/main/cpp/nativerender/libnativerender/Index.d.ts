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

import { NodeContent } from '@ohos.arkui.node';
import { resourceManager } from "@kit.LocalizationKit";
type XComponentContextStatus = {
  hasDraw: boolean,
  hasChangeColor: boolean
};

// ==================== XComponent Methods ====================

export const createNativeNode: (content: NodeContent, tag: string) => void;
export const getStatus: () => XComponentContextStatus;
export const drawPattern: () => void;
export const bindNode: (id: string, node: object, resMgr: resourceManager.ResourceManager) => void;
export const unbindNode: (id: string) => void;
export const setFrameRate: (id: string, min: number, max: number, expected: number) => void;
export const setNeedSoftKeyboard: (id: string, needSoftKeyborad: boolean) => void;
export const initialize: (id: string) => void;
export const finalize: (id: string) => void;
export const drawStar: (id: string) => void;
/**
 * Load a GLTF scene
 * @param id - Renderer instance identifier
 * @param gltfPath - Path to the GLTF file
 */
export const loadScene: (id: string, gltfPath: string) => void;

// ==================== FileSystem Test Types ====================

/**
 * Test result object returned by individual test methods
 */
export interface TestResult {
    /** Whether the test operation succeeded */
    success: boolean;
    /** Human-readable message describing the result */
    message: string;
    /** Additional data (e.g., file content from read operations) */
    data: string;
}

/**
 * Entry information from GetEntry test
 */
export interface EntryInfo {
    /** Whether the operation succeeded */
    success: boolean;
    /** Type of the entry: "file", "directory", or "unknown" */
    type: "file" | "directory" | "unknown";
    /** Name of the file or directory */
    name: string;
}

/**
 * Batch test result from RunAllTests
 */
export interface BatchTestResult {
    /** Number of tests that passed */
    passed: number;
    /** Number of tests that failed */
    failed: number;
    /** Detailed results for each test */
    results: string[];
}

// ==================== FileSystem Test Initialization ====================

/**
 * Initialize the FileSystem test module
 * Must be called before using other test methods
 * @returns true if initialization succeeded
 */
export const initializeFileSystemTest: () => boolean;

/**
 * Set FileManager from an existing engine instance
 * Call this after the 3D engine is initialized
 * @param nodeId - The renderer instance identifier
 * @returns true if FileManager was set successfully
 */
export const setFileManagerFromEngine: (nodeId: string) => boolean;

// ==================== File Operations ====================

/**
 * Test opening an existing file
 * @param uri - File URI (e.g., "file:///data/test/file.txt")
 * @returns TestResult with file size information
 */
export const testOpenFile: (uri: string) => TestResult;

/**
 * Test creating a new file
 * @param uri - File URI to create
 * @returns TestResult indicating success or failure
 */
export const testCreateFile: (uri: string) => TestResult;

/**
 * Test checking if a file exists
 * @param uri - File URI to check
 * @returns TestResult with existence status in data field ("true"/"false")
 */
export const testFileExists: (uri: string) => TestResult;

/**
 * Test deleting a file
 * @param uri - File URI to delete
 * @returns TestResult indicating success or failure
 */
export const testDeleteFile: (uri: string) => TestResult;

/**
 * Test reading file content
 * @param uri - File URI to read
 * @returns TestResult with file content in data field
 */
export const testReadFile: (uri: string) => TestResult;

/**
 * Test writing content to a file
 * @param uri - File URI to write
 * @param content - Content string to write
 * @returns TestResult indicating success or failure
 */
export const testWriteFile: (uri: string, content: string) => TestResult;

// ==================== Directory Operations ====================

/**
 * Test creating a directory
 * @param uri - Directory URI to create
 * @returns TestResult indicating success or failure
 */
export const testCreateDirectory: (uri: string) => TestResult;

/**
 * Test checking if a directory exists
 * @param uri - Directory URI to check
 * @returns TestResult with existence status in data field
 */
export const testDirectoryExists: (uri: string) => TestResult;

/**
 * Test deleting a directory
 * @param uri - Directory URI to delete
 * @returns TestResult indicating success or failure
 */
export const testDeleteDirectory: (uri: string) => TestResult;

/**
 * Test getting entry information
 * @param uri - URI to get entry info for
 * @returns EntryInfo with type, name, and timestamp
 */
export const testGetEntry: (uri: string) => EntryInfo;

// ==================== Path Registration ====================

/**
 * Test registering a protocol path
 * @param protocol - Protocol name (e.g., "test")
 * @param pathUri - URI to map to the protocol
 * @param prepend - Add to front of search list
 * @returns TestResult indicating success or failure
 */
export const testRegisterPath: (protocol: string, pathUri: string, prepend: boolean) => TestResult;

/**
 * Test renaming a file or directory
 * @param fromUri - Source URI
 * @param toUri - Destination URI
 * @returns TestResult indicating success or failure
 */
export const testRename: (fromUri: string, toUri: string) => TestResult;

// ==================== Batch Test ====================

/**
 * Run all FileSystem tests in sequence
 * Tests: createDirectory, directoryExists, createFile, writeFile,
 *        readFile, fileExists, getEntry, rename, deleteFile, deleteDirectory
 * @param testBasePath - Base path for test operations (e.g., "/data/test/")
 * @returns BatchTestResult with passed/failed counts and detailed results
 */
export const runAllTests: (testBasePath: string) => BatchTestResult;

