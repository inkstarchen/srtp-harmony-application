// index.d.ts
export class PhysicsSystem {
  constructor( capacity: number );
  removeNode:(id:number) => boolean;
  addNode:(object:object) => number;
  addNodeInLayoutSys:(object:object) => number;
  update:(eventCommands:EventCommand[][],dt:number) => ReturnData | undefined;
  release:() => void;
  enableLayout:(object:object)=> void;
}