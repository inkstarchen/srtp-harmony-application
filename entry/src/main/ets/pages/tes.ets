import { SceneProxy } from '../core/scene3D/SceneProxy'
import { Geometry, Image, MaterialType, SceneResourceParameters, ShaderMaterial, Vec4 } from '@kit.ArkGraphics3D';
import { NodeUtil } from '../core/scene3D/Utils';
import { AnimatorOptions, AnimatorResult } from '@kit.ArkUI';

const  ANIMATION_OPTION: AnimatorOptions = {
  duration: 2000,
  easing: 'ease',
  delay: 0,
  fill: 'none',
  direction: 'normal',
  iterations: -1,
  begin: 100,
  end: 200
};

@Entry
@ComponentV2
struct Graphics{
  @Local sceneProxy: SceneProxy = new SceneProxy(this.getUIContext());
  @Local backAnimator: AnimatorResult | undefined;
  step: number = 0;
  material: ShaderMaterial | null = null;
  aboutToAppear(): void {
    this.sceneProxy.loadScene('test')
    this.backAnimator = this.getUIContext().createAnimator(ANIMATION_OPTION);
    this.backAnimator.onFrame = () => {
      this.step++;
      if (this.material && this.material.colorShader) {
        // Just give a random effect.
        (this.material.colorShader.inputs['vec_1'] as Vec4) = {
          x: Math.abs(Math.sin(this.step) + 0.5),
          y: Math.abs(Math.sin(this.step * 0.86) + 0.5),
          z: Math.abs(Math.sin(this.step * 0.91) + 0.5),
          w: 1.0
        };
        (this.material.colorShader.inputs['time'] as number) = this.step;
      }
    };
  }

  aboutToDisappear(): void {
    this.sceneProxy.release();
  }
  build(){
    Stack({alignContent:Alignment.Center}){
      if(this.sceneProxy.options){
        Component3D(this.sceneProxy.options)
          .renderWidth('100%')
          .renderHeight('100%')

      }
    }
    .onClick(async () => {
      let node = this.sceneProxy.getNode("Cube");
      if(node){
        let geom = node as Geometry;
        let originalMat = NodeUtil.getMaterial(node);
        let factory = this.sceneProxy.scene?.getResourceFactory();
        if(factory){
          let tempdir = this.getUIContext().getHostContext()?.tempDir;


          let sceneImageParameter:SceneResourceParameters = {
            name: 'image',
            uri: tempdir + '/temp.png'
          };



          let image = await factory.createImage(sceneImageParameter);

          let shader = await factory.createShader({
            name: 'Myshader',
            uri: $rawfile('shaders/Myshader/myshader.shader')
          });
          this.material = await factory?.createMaterial({ name: 'imageMat' }, MaterialType.SHADER) as ShaderMaterial;

          this.material.colorShader = shader;
          if(image){
            this.material.colorShader.inputs['BASE_COLOR_Image'] = image;
          }

          geom.mesh.materialOverride = undefined;
          geom.mesh.subMeshes[0].material = this.material;
          this.backAnimator?.play();

        }
      }
      this.sceneProxy.update();
    })
    .width('100%')
    .height('100%')

  }
}