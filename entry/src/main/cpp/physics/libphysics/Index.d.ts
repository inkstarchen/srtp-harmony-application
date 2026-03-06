
// index.d.ts
import { Vec3, Vec4 } from "@kit.ArkGraphics3D";

export class PhysicsSystem {
  constructor( capacity: number );
  addNode:(object:object) => number;
  update:(dt:number) => ArrayBuffer | undefined;
  getMass:(id:number) => number;
  getVel:(id:number) => Vec3;
  getFric:(id:number) => number;
  getNormal:(angle:Vec3) => void;
  setPosition:(id:number, position:Vec3) => void;
  setRotation:(id:number, rotation:Vec4) => void;
  setVelocity:(id:number, velocity:Vec3) => void;
  setForce:(id:number, force:Vec3) => void;
  setScale:(id:number, scale:Vec3) => void;
  setExtent:(id:number, extent:Vec3) => void;
  setMass:(id:number, mass:number) => void;
  setRestitution:(id:number, restitution:number) => void;
  setFriction:(id:number, friction:number) => void;
  setShapeType:(id:number, shapeType:number) => void;
  setIsStatic:(id:number, isStatic:number) => void;
}