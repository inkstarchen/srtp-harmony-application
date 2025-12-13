

## ImagePersistenceManager

### 属性

| 名称           | 类型     | 用途                 |
| ------------ | ------ | ------------------ |
| imageQuality | number | 图片保存时的压缩质量，默认为 85  |
| maxImageSize | number | 图片缩放的最大尺寸，默认为 2048 |

### 方法

| 名称  | 参数 | 返回类型 | 功能  |
| --- | --- | --- | --- |
| uriToPixelMapByFd    | `uri: string` – 图片的文件路径                                                   | `Promise<image.PixelMap | null>` | 通过文件描述符读取图片 URI 并创建 PixelMap，返回可编辑的 RGBA_8888 格式 PixelMap，如果失败返回 null                                      |
| uriToPixelMap        | `uri: string` – 图片的文件路径                                                   | `Promise<image.PixelMap | null>` | 直接通过 URI 创建 ImageSource 并生成 PixelMap（使用 `calculateDesiredSize` 计算尺寸），返回可编辑的 RGBA_8888 PixelMap，如果失败返回 null |
| savePixelMapToFile   | `pixelMap: image.PixelMap` – 要保存的 PixelMap<br>`filePath: string` – 保存文件路径 | `Promise<boolean>`               | 将 PixelMap 保存到指定路径，使用 PNG 格式和 `imageQuality`，保存成功返回 true，失败返回 false                                        |
| loadPixelMapFromFile | `filePath: string` – 要加载的图片文件路径                                           | `Promise<image.PixelMap>`        | 从文件路径加载 PixelMap，如果文件不存在或加载失败会抛出错误                                                                         |
| calculateDesiredSize | `originalSize: image.Size` – 原始图片尺寸                                       | `image.Size`                     | 根据 `maxImageSize` 限制原始图片尺寸，保持宽高比，返回调整后的尺寸                                                                  |

## NoteController

### 属性

| --- | --- | --- |
| 名称 | 类型 | 用途 |
| notesDir | string | 当前笔记的父路径|
| tempTitle | string | 用于页面显示，与笔记数据的中介|
| imageManager | ImagePersistenceManager | 