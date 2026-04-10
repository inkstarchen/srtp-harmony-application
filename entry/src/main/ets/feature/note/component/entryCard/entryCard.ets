import { NoteData } from "../../model/NoteSpanData"
import { AnimatorResult, LengthMetrics, LengthUnit, matrix4, Prompt, SymbolGlyphModifier } from "@kit.ArkUI";
import { clipNum, lerp } from "../../../../core/math/mathUtil";
import { ColorUtil } from "../../../../shared/utils/ColorUtil";
import { NoteInfo } from "../../NoteState";
import { NoteViewModel } from "../../NoteViewModel";
import { ThemeManager, ThemeState } from "../../../../theme/core/ThemeManager";
import { CardState } from "../../../mainDisplay/mainDisplay";

enum State{
  NONE = 0,
  SELECTED = 1,
}
@Preview
@ComponentV2
export struct entryCard{
  @Require @Param cardState:CardState;
  maxTilt: number = 15;
  perspective: number = 2000;
  @Event setCardState: () => void;
  @Local transformMatrix: matrix4.Matrix4Transit = matrix4.identity();
  @Local shadowX: number = 0;
  @Local shadowY: number = 0;
  @Local rotateX: number = 0;
  @Local rotateY: number = 0;
  @Local touched:boolean = false;

  @Event editNote:(noteInfo: NoteInfo) => void;
  @Event deleteNote:(noteInfo: NoteInfo) => void;

  @Local editIconModifier: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.pencil_waveform')).fontSize('24vp');
  @Local trashIconModifier: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.ohos_trash')).fontSize('24vp');
  // @Require @Param data: NoteData;
  @Local opacityAnim: number = 0;
  @Local yAnim: number = 20;
  @Local themeManager:ThemeManager = ThemeManager.getInstance();
  @Local themeState:ThemeState = this.themeManager.getThemeState();
  @Local noteViewModel: NoteViewModel = new NoteViewModel(this.getUIContext().getHostContext());
  private options: RichEditorOptions = { controller: this.noteViewModel.getController() };

  @Require @Param noteInfo: NoteInfo;
  @Event Choose:() => void;
  @Local text:string = "测试文案";
  @Local date:string = "2026-2-3 20:35"
  @Require @Param angle:number;
  @Require @Param depth:number;
  @Local state: State = State.NONE;

  @Builder
  MyMenu(onDelete: () => void, onEdit: () => void) {
    Menu() {
      MenuItem({ symbolStartIcon: this.editIconModifier, content: "编辑" })
        .onChange(() => {
          onEdit();
        })
      MenuItem({ symbolStartIcon: this.trashIconModifier, content: "删除"})
        .onChange(() => {
          Prompt.showToast({message:"delete"})
          onDelete();
        })
    }
  }


  uiShadow(angle:number,baseDepth:number,baseRadius:number,baseAlpha:number) {
    const rad = angle * Math.PI / 180
    const vertical = Math.abs(Math.sin(rad))

    const depth =
      baseDepth *
        1.0 *
      lerp(1.6, 0.8, vertical)

    return {
      offsetX: depth * Math.cos(rad) * 0.6,
      offsetY: depth * Math.sin(rad),
      radius: baseRadius * lerp(1.4, 0.9, vertical),
      color: ColorUtil.fromRGBA(0,0,0,baseAlpha * (1.1 - 0.4 * vertical)),
    } as ShadowOptions;
  }

  removeJsonExtension(fileName: string): string {
    if (fileName.endsWith(".json")) {
      return fileName.slice(0, -5);
    }
    return fileName;
  }

  async aboutToAppear() {
    this.opacityAnim = 1;
    this.yAnim = 0;
    this.noteViewModel.noteState.setDir(this.noteInfo.fileDir);
    this.noteViewModel.noteState.setId(this.removeJsonExtension(this.noteInfo.fileName));
    await this.noteViewModel.loadCurrentNoteMain();
  }

  build(){

      Column() {
        Row(){
          RichEditor(this.options)
            .hitTestBehavior(HitTestMode.None)
            .barState(BarState.Off)
            .maxLines(4)
            .height(80)
            .width('90%')

          if(this.cardState == CardState.SELECTION){
            SymbolGlyph(this.state == State.NONE ? $r("sys.symbol.circle") : $r("sys.symbol.smallcircle_filled_circle"))
              .fontSize(20)
              .fontColor(["#ff51c1ff"])
          }
          // Button({ type: ButtonType.Circle }) {
          //   SymbolGlyph($r("sys.symbol.close_sidebar"))
          //     .fontSize(20)
          //     .fontColor([Color.Black]) //?
          // }

          // .backgroundColor('#00000000')
          // .width(40)
          // .height(40)
        }
        .height(80)
        .width('100%')
        .clip(true)

        Column() {
          Text(this.noteInfo.time)
            .fontSize(10)
            .fontColor(this.themeState.tokens.onPrimaryContainer)
            .margin({ right: 20 })
        }
        .alignItems(HorizontalAlign.End)
        .width("100%")
        .height(20)
      }
      .bindContextMenu(this.MyMenu(() => {
        this.deleteNote(this.noteInfo);
      },
        () => {
          this.editNote(this.noteInfo);
        }),ResponseType.LongPress)
      .border({ radius: 15, width: 0, color: "#fff" })
      .padding({left:15,top:15,bottom:5})
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.SpaceBetween)
      // .shadow({radius:20,offsetX:-15,offsetY:-15,color:"#37292929"})
      .width("100%")
      .height(130)
      .opacity(this.opacityAnim)
      .translate({x:0,y:this.yAnim})
      .transform3D(this.transformMatrix)
      // .height(this.state == State.NONE ? 120 : 800)
      .shadow(
        // ShadowStyle.OUTER_DEFAULT_LG
        {radius:this.touched ? 50: 20,color:"#ffe2dbdb",offsetX:this.shadowX,offsetY:this.shadowY}
        // this.uiShadow(30 + this.angle,this.depth,20,0.25)
      )

      .animation({
        duration:100,
        delay:0,
        iterations:1,
        curve:Curve.EaseInOut,
      })
      // .gesture(
      //   // 设置长按手势识别器识别的手势的最大移动距离为200px
      //   LongPressGesture({ repeat: true, allowableMovement: 200 })
      //   // 由于repeat设置为true，长按动作存在时会连续触发，触发间隔为duration（默认值500ms）
      //     .onAction((event: GestureEvent) => {
      //       // this.setCardState();
      //       // this.state = State.SELECTED;
      //     })
      //     // 长按动作一结束触发
      //     .onActionEnd((event: GestureEvent) => {
      //
      //     })
      // )
      .onTouch((event) => {
        if(event.type == TouchType.Down){
          this.touched = true;
        }else if(event.type == TouchType.Move){
          this.handleTouch(event);
        }else if(event.type == TouchType.Up){
          this.transformMatrix = matrix4.identity();
          this.shadowX = 0;
          this.shadowY = 0;
          this.touched = false;
        }
      })
      .id("card")

      .backgroundColor(this.themeState.tokens.primaryContainer)
      .onClick(() => {
        // if(this.cardState == CardState.SELECTION){
        //   if(this.state == State.NONE){
        //     this.state = State.SELECTED;
        //   }else {
        //     this.state = State.NONE;
        //   }
        // }else{
        //   this.editNote(this.noteInfo);
        // }
      })
  }


  /**
   * 构建倾斜变换矩阵
   */
  private getTiltMatrix(): matrix4.Matrix4Transit {
    const rx = this.rotateX
    const ry = this.rotateY

    // 旋转矩阵计算
    const cosX = Math.cos(rx)
    const sinX = Math.sin(rx)
    const cosY = Math.cos(ry)
    const sinY = Math.sin(ry)

    // 透视因子
    const p = 1 / this.perspective

    // 组合旋转矩阵：先Y轴旋转，再X轴旋转，加入透视
    // 矩阵乘法：RotateX * RotateY * Perspective
    // 简化后的矩阵参数
    const m00 = cosY
    const m01 = 0
    const m02 = sinY
    const m03 = p * sinY

    const m10 = sinX * sinY
    const m11 = cosX
    const m12 = -sinX * cosY
    const m13 = -p * sinX * cosY

    const m20 = -cosX * sinY
    const m21 = sinX
    const m22 = cosX * cosY
    const m23 = p * cosX * cosY

    const m30 = 0
    const m31 = 0
    const m32 = -400
    const m33 = 1

    return matrix4.init([
      m00, m01, m02, m03,
      m10, m11, m12, m13,
      m20, m21, m22, m23,
      m30, m31, m32, m33
    ])
  }

  private handleTouch(event: TouchEvent) {
    const touchX = this.getUIContext().vp2px(event.touches[0].x);
    const touchY = this.getUIContext().vp2px(event.touches[0].y);

    let info = this.getUIContext().getComponentUtils().getRectangleById("card");

    // 计算相对于卡片中心的偏移（-1 到 1）
    const centerX = (info.size.width / 2);
    const centerY = (info.size.height / 2);
    console.info("touchx:" + touchX + '/' + "touchy" + touchY + "/OFFSETX:" + info.windowOffset.x + "/offsetY:"  + info.windowOffset.y
    + "size:" + info.size.width + " size: " + info.size.height);
    const offsetX = clipNum((touchX - centerX) / info.size.width * 2, -1, 1);  // -1 到 1
    const offsetY = clipNum((touchY - centerY) / info.size.height * 2, -1, 1);  // -1 到 1
    this.shadowX = offsetX * 20;
    this.shadowY = offsetY * 20;
    if (event.type === TouchType.Down || event.type === TouchType.Move) {
      // 触摸按下或移动时，计算倾斜角度
      // 注意：Y轴偏移影响X轴旋转，X轴偏移影响Y轴旋转
      this.rotateX = -offsetY * this.degToRad(this.maxTilt)  // 反转Y使上方向上倾斜
      this.rotateY = offsetX * this.degToRad(this.maxTilt)
    } else if (event.type === TouchType.Up) {
      // 触摸抬起时，恢复原位
      this.rotateX = 0
      this.rotateY = 0
    }
    this.transformMatrix = this.getTiltMatrix();
  }

  private degToRad(deg: number): number {
    return deg * Math.PI / 180
  }
}