
// index.d.ts
export class PhysicsSystem {
  constructor( capacity: number );
  addNode:(object:object) => number;
  update:(eventCommands:EventCommand[][],dt:number) => ArrayBuffer | undefined;
  release:() => void;
}