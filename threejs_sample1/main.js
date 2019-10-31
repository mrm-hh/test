var camera
  , scene
  , renderer
  , geometry
  , materials
  , mesh
  ;

function init() {
  scene  = new THREE.Scene();
  camera = new THREE.PerspectiveCamera( 75, window.innerWidth / window.innerHeight, 1, 10000 );
  camera.position.x = 300;
  camera.position.y = 300;
  camera.position.z = 1000;
  scene.add( camera );
  
  var load_material = function(file)
  { return new THREE.MeshBasicMaterial({map: THREE.ImageUtils.loadTexture('textures/' + file)}); };
  
  materials = 
    [ load_material('right.png')
    , load_material('left.png')
    , load_material('top.png')
    , load_material('bottom.png')
    , load_material('front.png')
    , load_material('back.png')
    ];
  
  geometry = new THREE.CubeGeometry
    ( 200
    , 400
    , 100
    , 1
    , 1
    , 1
    , materials
    );

  mesh = new THREE.Mesh( geometry, new THREE.MeshFaceMaterial() );
  //mesh.useQuaternion = true;
  scene.add( mesh );

  renderer = new THREE.CanvasRenderer();
  renderer.setSize( window.innerWidth, window.innerHeight );

  document.body.appendChild( renderer.domElement );
}

function animate(){
  requestAnimationFrame( animate );
  render();
}

function render(){
  renderer.render( scene, camera );
}

// function rotate(x,y,z){
//   var u = 90;
//   // var v = new THREE.Vector3(x,y.z).normalize();
//   var axis = new THREE.Vector3(x,y,z).multiplyScalar(u);
//   var q = new THREE.Quaternion().setFromEuler(axis);
//   // var vector = new THREE.Vector3( x, y, z );
//   // vector.applyQuaternion( q );

//   // mesh.lookAt( new THREE.Vector3(y,z,x).normalize() );

//   var m = new THREE.Matrix4().setRotationFromQuaternion(q);
//   // q.setFromAxisAngle(v,Math.PI / 2)
//   for(var n = 0; n < mesh.geometry.vertices.length; ++n)
//     m.multiplyVector3(mesh.geometry.vertices[n]);

// }

// function rotate(x,y,z){
//   var u = 90;
//   // var v = new THREE.Vector3(x,y.z).normalize();
//   // let _z = Math.cos(x);
//   // let _x = Math.sin(x) * Math.cos(z);
//   // let _y = Math.sin(x) * Math.sin(z)
//   // var axis = new THREE.Vector3(_x,_y,_z).multiplyScalar(u);
//   var axis = new THREE.Vector3(x,y,z).multiplyScalar(u);
//   var q = new THREE.Quaternion().setFromEuler(axis);
//   // var vector = new THREE.Vector3( x, y, z );
//   // vector.applyQuaternion( q );

//   mesh.lookAt( axis );
  
//   // var m = new THREE.Matrix4().setRotationFromQuaternion(q);
//   // // q.setFromAxisAngle(v,Math.PI / 2)
//   // for(var n = 0; n < mesh.geometry.vertices.length; ++n)
//   //   m.multiplyVector3(mesh.geometry.vertices[n]);
//   let quaternion1 = new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(x, y, z), Math.PI/2);
//   mesh.quaternion.multiply(quaternion1);

// }

// var axisX = 0;
// var axisY = 0;
// var axisZ = 0;
// function rotate(x,y,z) {
//   var u = Math.PI / 2;
//   axisX += (x * u);
//   axisY += (y * u);
//   axisZ += (z * u);

//   var axis = new THREE.Vector3(x,y.z).normalize();
//   mesh.rotation.x = (x * u);
//   mesh.rotation.y = (y * u);
//   mesh.rotation.z = (z * u);
// }



// function makeRotationAxis ( rm, axis, angle ) {
//   var c = Math.cos( angle );
//    var s = Math.sin( angle );
//   var t = 1 - c;
//   var x = axis.x, y = axis.y, z = axis.z;
//   var tx = t * x, ty = t * y;
//   rm.set(
//       tx * x + c, tx * y - s * z, tx * z + s * y, 0,
//       tx * y + s * z, ty * y + c, ty * z - s * x, 0,
//       tx * z - s * y, ty * z + s * x, t * z * z + c, 0,
//       0, 0, 0, 1
//   );
//    return rm;
// }

// var rotWorldMatrix
// function rotateAroundWorldAxis(object, axis, radians) {
//   rotWorldMatrix = new THREE.Matrix4();
//   rotWorldMatrix.makeRotationAxis(axis.normalize(), radians);
//   object.matrix.multiplySelf(rotWorldMatrix);                // pre-multiply
//   object.rotation.getRotationFromMatrix(object.matrix, object.scale);

//   // var m = new THREE.Matrix4().setRotationFromQuaternion(q);
//   // q.setFromAxisAngle(v,Math.PI / 2)
//   object.matrix = rotWorldMatrix;
//   for(var n = 0; n < object.geometry.vertices.length; ++n)
//   rotWorldMatrix.multiplyVector3(object.geometry.vertices[n]);

  
//   // object.rotation.setFromRotationMatrix(object.matrix);

// }

// Rotate an object around an arbitrary axis in object space
var rotObjectMatrix;
function rotateAroundObjectAxis(object, axis, radians) {
    rotObjectMatrix = new THREE.Matrix4();
    rotObjectMatrix.makeRotationAxis(axis.normalize(), radians);
    object.matrix.multiplySelf(rotObjectMatrix);      // post-multiply
    object.rotation.getRotationFromMatrix(object.matrix, object.scale);
}

var rotWorldMatrix;
// Rotate an object around an arbitrary axis in world space       
function rotateAroundWorldAxis(object, axis, radians) {
    rotWorldMatrix = new THREE.Matrix4();
    rotWorldMatrix.makeRotationAxis(axis.normalize(), radians);
    rotWorldMatrix.multiplySelf(object.matrix);        // pre-multiply
    object.matrix = rotWorldMatrix;
    object.rotation.getRotationFromMatrix(object.matrix, object.scale);
}

function rotate(x,y,z) {
  var rad = Math.PI / 4;
  var axis = new THREE.Vector3(x,y,z);
  rotateAroundObjectAxis(mesh, axis, rad);
  // mesh.rotation.x += (x * rad); 
  // mesh.rotation.y += (y * rad); 
  // mesh.rotation.z += (z * rad); 

  // rotateAroundWorldAxis(mesh, axis, rad);
}
// function rotate(x,y,z) {
//   var axis = new THREE.Vector3(x,y.z).normalize(),
//   rotateQuaternion = new THREE.Quaternion();

// 		var angle = Math.PI / 2;

// 		if (angle)
// 		{
// 			// axis.crossVectors(rotateStart, rotateEnd).normalize();
// 			// angle *= rotationSpeed;
// 			rotateQuaternion.setFromAxisAngle(axis, angle);
//     }
    
//     var curQuaternion = mesh.quaternion;
// 		curQuaternion.multiplyQuaternions(rotateQuaternion, curQuaternion);
// 		curQuaternion.normalize();
// 		mesh.setRotationFromQuaternion(curQuaternion);
// }

// function rotate(x,y,z) {
//   var quaternion = mesh.quaternion;
//   var target = new THREE.Quaternion();
//   var axis = new THREE.Vector3(x, y, z).normalize(); // 絶対値が1なので、normalize()はなくてもOK
//   target.setFromAxisAngle(axis, Math.PI / 2);
//   // quaternion.multiply(target);
//   var m = new THREE.Matrix4().setRotationFromQuaternion(target);
//   // q.setFromAxisAngle(v,Math.PI / 2)
//   for(var n = 0; n < mesh.geometry.vertices.length; ++n)
//     m.multiplyVector3(mesh.geometry.vertices[n]);
// }

window.addEventListener
  ( 'load'
  , function(){
      init();
      animate();
    }
  );

window.addEventListener
  ( 'keydown'
  , function(e){
      switch(e.keyCode){
      case 83: rotate(  0,  1,  0); break; // s y+
      case 87: rotate(  0, -1,  0); break; // w y-
      case 68: rotate(  1,  0,  0); break; // d x+
      case 65: rotate( -1,  0,  0); break; // a x-
      case 69: rotate(  0,  0, -1); break; // e z-
      case 81: rotate(  0,  0,  1); break; // q z+
      }
    }
  );

