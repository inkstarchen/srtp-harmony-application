## 3D

### 画面有暗圈

> 需要设置后处理的曝光度

```ts
this.cameraManager.cam.postProcess = {
	toneMapping:{  
	  exposure:1,  
	  type:ToneMappingType.ACES  
}};
```