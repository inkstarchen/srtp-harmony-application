import { hvigor } from '@ohos/hvigor';
import * as fs from 'fs';
import * as path from 'path';

//
// Adding a hvigor task that gathers assets from the ArkGraphics Editor project and adds them as raw files to the
// package. This tasks allows the assets to be referenced in the standard way e.g.:
//   $rawfile('MyEditorProject/assets/default.scene')
//
// How to use in the hvigorfile.ts file of a module:
//    import { getNode } from '@ohos/hvigor';
//    import * as MyEditorProject  from '../MyEditorProject/package-assets';
//    MyEditorProject.packageAssetsToModule(getNode(__filename));
//
export function packageAssetsToModule(moduleNode: HvigorNode) {
    const editorProjectDirName = path.basename(__dirname)
    const assetTaskName = `gather${editorProjectDirName}Assets`

    // Note: the content of this directory will be deleted each time the task is run to make sure previously deleted
    // files are not left lingering.
    const rawFileRoot = `${moduleNode.getNodePath()}/src/main/resources/rawfile/${editorProjectDirName}`;

    hvigor.nodesEvaluated(async () => {
        console.log(`Registering asset packaging task for: ${editorProjectDirName}`);
        moduleNode.registerTask({
            name: assetTaskName,
            postDependencies: ['init', 'default@PackageHap'],
            run() {
                syncAssets(rawFileRoot)
            }
        });
    });

    // Make sure the root resource dir exists already before configuring.
    // (So this location can be used in configuration if wanted)
    if (!fs.existsSync(rawFileRoot)) {
        fs.mkdirSync(rawFileRoot, { recursive: true });
    }
}

//
// Helpers for doing the asset packaging
//

function syncAssets(rawFileRoot: String) {
    // Remove previous asset files.
    fs.rmSync(rawFileRoot, { recursive: true });

    // Copy selected directories and files.
    const filter = (srcFile: string, dstFile: string): boolean => {
        // Filter out files that are not meant to be packaged with the app.
        if (srcFile.endsWith('.metadata')) { return false; }
        if (srcFile.endsWith('.pdb')) { return false; }
        if (srcFile.endsWith('.dll')) { return false; }
        return true;
    }
    copyAssetFiles(rawFileRoot, 'assets/', filter);
    copyAssetFiles(rawFileRoot, 'packages/', filter);
    copyAssetFiles(rawFileRoot, 'default_resources.res', filter);
}

function modulePath(moduleNode :HvigorNode, relativePath: string) : string {
    return path.join(moduleNode.getNodePath(), relativePath);
}

function copyAssetFiles(dstRootPath: string, relativePath: string, filter: Function) {
    const fullSrc = path.resolve(__dirname, relativePath);
    const fullDst = path.join(dstRootPath, relativePath);
    // console.log(`Copy assets:  ${fullSrc} -> ${fullDst}`);
    if (fs.existsSync(fullSrc)) {
        // Copy all files using the given filter.
        !fs.cpSync(fullSrc, fullDst, { recursive: true, filter: filter });
    }
}
