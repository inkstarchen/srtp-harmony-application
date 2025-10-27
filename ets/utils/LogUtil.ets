import { Aabb, Geometry, Node } from "@kit.ArkGraphics3D";

export class LogUtil{
  static LogResource(res:Resource){
    console.info('res test info : bundleName' + res.bundleName + '\n'
      + 'moudleName:' + res.moduleName + '\n'
      + 'id:' + res.id + '\n'
      + 'type:' + res.type + '\n'
      + 'params:' + res.params?.toString());
  }

  static AabbLog(geom:Geometry | undefined = undefined,ab:Aabb | undefined = undefined){
    if(geom?.mesh.aabb){
      console.info(geom.name + ' aabb: \n' +
      'Max | x: ' + geom.mesh.aabb.aabbMax.x + '/y: ' + geom.mesh.aabb.aabbMax.y + '/z: ' + geom.mesh.aabb.aabbMax.z + '\n' +
      'Min | x: ' + geom.mesh.aabb.aabbMin.x + '/y: ' + geom.mesh.aabb.aabbMin.y + '/z: ' + geom.mesh.aabb.aabbMin.z);
    }
    if(ab){
      console.info(' aabb: \n' +
        'Max | x: ' + ab.aabbMax.x + '/y: ' + ab.aabbMax.y + '/z: ' + ab.aabbMax.z + '\n' +
        'Min | x: ' + ab.aabbMin.x + '/y: ' + ab.aabbMin.y + '/z: ' + ab.aabbMin.z);
    }
    return;
  }

  static LogNode(node:Node){
    console.info('parent position: ' + node.position.x);
    let child = node.children.get(0);
    if(child){
      console.info('child position: ' + child.position.x);
    }
  }

}