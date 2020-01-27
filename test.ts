import * as THREE from 'three';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls';
import { FontLoader } from 'three/src/loaders/FontLoader';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader';
import { Component, OnInit, OnDestroy, AfterContentInit, Input, ViewChild, ElementRef, NgZone } from '@angular/core';

@Component({
  selector: 'app-car2d-model',
  templateUrl: './car2d-model.component.html',
  styleUrls: ['./car2d-model.component.scss']
})
export class Car2dModelComponent implements OnInit, OnDestroy, AfterContentInit {
  @Input() sensorPosition: number;  // 初期値（外から渡して来る）
  @Input() wheelBase: number;       // 初期値（外から渡して来る）
  private newpd: number;
  private newwb: number;

  @ViewChild('rendererCanvas', { static: true }) public rendererCanvas: ElementRef<HTMLCanvasElement>;

  // 初期状態
  private pos1: THREE.Vector3;
  private pos2: THREE.Vector3;
  private pos3: THREE.Vector3;

  private canvas: HTMLCanvasElement;
  private renderer: THREE.WebGLRenderer;
  private camera: THREE.PerspectiveCamera;
  private scene: THREE.Scene;
  private light: THREE.AmbientLight;
  private lightDirec: THREE.DirectionalLight;
  private controls: OrbitControls;

  private mouseVector: THREE.Vector2;
  private containerWidth: number;
  private containerHeight: number;

  private fontLoader: FontLoader;
  private gltfLoader: GLTFLoader;

  private objGroup: THREE.Group;
  private carGroup: THREE.Group;
  private text1: THREE.Mesh;
  private text2: THREE.Mesh;
  private matLite: THREE.MeshBasicMaterial;
  private font: THREE.Font;
  private arrow1: THREE.Mesh;
  private initPDWidth = 18;
  private initPDPos = 9;
  private initWBWidth = 47;
  private initWBPos = -6;

  private frameId: number = null;
  private isShowMainAxis = false;

  constructor (private ngZone: NgZone) {
    console.log('car-model constructor.');
    this.fontLoader = new FontLoader();
    this.gltfLoader = new GLTFLoader();
  }

  ngOnInit () {
    this.newpd = this.sensorPosition;
    this.newwb = this.wheelBase;
  }

  ngOnDestroy () {
    if (this.frameId != null) {
      cancelAnimationFrame(this.frameId);
    }
  }

  ngAfterContentInit (): void {
    // this.rotate();
    this.createScene();
    this.render();
  }

  createScene (): void {
    this.canvas = this.rendererCanvas.nativeElement;

    if (!this.renderer) {
      this.renderer = new THREE.WebGLRenderer({
        canvas: this.canvas,
        alpha: true,    // transparent background
        antialias: true // smooth edges
      });
      this.containerWidth = this.canvas.clientWidth;
      this.containerHeight = this.canvas.clientHeight;
      this.renderer.setPixelRatio(window.devicePixelRatio);
      this.renderer.setSize(this.canvas.clientWidth, this.canvas.clientHeight);

      // create the scene
      this.scene = new THREE.Scene();

      this.objGroup = new THREE.Group();
      this.carGroup = new THREE.Group();

      // カメラの配置
      this.camera = new THREE.PerspectiveCamera(
        75, this.canvas.clientWidth / this.canvas.clientHeight, 0.1, 1000
      );
      this.camera.position.z = 40;
      // this.camera.position.set(1,300, 500);
      this.scene.add(this.camera);

      // 平行光源
      this.lightDirec = new THREE.DirectionalLight(0xFFFFFF, 1);
      this.lightDirec.position.set(9, 20, 20);
      this.scene.add(this.lightDirec);

      // マウス操作
      this.controls = new OrbitControls(this.camera, this.renderer.domElement);
      this.controls.enableZoom = true;
      this.controls.enableRotate = false;
      this.controls.zoomSpeed = 0.5;

      // 3Dモデル読込み
      this.gltfLoader.load('assets/model/IPhone_Car2D4.glb', (gltf) => {
        const gltfScene = gltf.scene;
        if (gltfScene) {
          while (gltfScene.children.length > 0) {
            this.objGroup.add(gltfScene.children[gltfScene.children.length - 1]);
          }
          const geometry = new THREE.BoxGeometry(this.initPDWidth, 0.5, 0.1);
          const material = new THREE.MeshStandardMaterial({ color: 0xFFD700 });
          this.arrow1 = new THREE.Mesh(geometry, material);
          this.arrow1.position.x = this.initPDPos;
          this.objGroup.add(this.arrow1);

          const geometry2 = new THREE.BoxGeometry(this.initWBWidth, 0.5, 0.1);
          const material2 = new THREE.MeshStandardMaterial({ color: 0xFFD700 });
          const arrow2 = new THREE.Mesh(geometry2, material2);
          arrow2.position.x = this.initWBPos;
          arrow2.position.y = -17;
          this.carGroup.add(arrow2);

          this.fontLoader.load('assets/font/helvetiker_regular.typeface.json', (font) => {
            const color = 0xFA8072;
            this.matLite = new THREE.MeshBasicMaterial({
              color,
              transparent: true,
              opacity: 0.9,
              side: THREE.DoubleSide
            });
            this.font = font;

            this.changeValue1(font, this.sensorPosition);
            this.text1.position.x = 10;
            this.text1.position.y = 1;
            this.text1.position.z = 5;
            this.scene.add(this.text1);
            this.pos3 = this.text1.position.clone();

            this.changeValue2(font, this.wheelBase);
            this.text2.position.x = 0;
            this.text2.position.y = -18;
            this.text2.position.z = 5;
            this.scene.add(this.text2);

            this.modifyDistance();
          });

          for (const obj of this.objGroup.children) {
            if (obj.name === 'car') {
              this.carGroup.add(obj);
              // this.carGroup.scale.x = 1;
              gltfScene.add(this.carGroup);
              break;
            }
          }

          this.scene.add(gltfScene);
          this.objGroup.position.set(0, 0, 0);

          this.scene.add(this.objGroup);

          this.pos1 = this.objGroup.position.clone();
          this.pos2 = this.carGroup.position.clone();
        }
      },
      undefined,
      (error) => {
        console.error('Error', error, error.message);
      });
      if (this.isShowMainAxis) {
        const axis = new THREE.AxesHelper(1000);
        this.scene.add(axis);
      }
    }
  }

  render () {
    this.frameId = requestAnimationFrame(() => {
      this.render();
    });

    this.renderer.render(this.scene, this.camera);
  }

  recover () {
    this.objGroup.matrixAutoUpdate = false;
    this.objGroup.position.set(this.pos1.x, this.pos1.y, this.pos1.z);
    this.arrow1.scale.x = 1;
    this.carGroup.position.set(this.pos2.x, this.pos2.y, this.pos2.z);
    this.carGroup.scale.x = 1;
    if (this.text1) {
      this.text1.position.set(this.pos3.x, this.pos3.y, this.pos3.z);
    }
    this.objGroup.matrixAutoUpdate = true;
  }

  changePD () {
    const val1 = prompt('Please input the value of phone-distance:');
    // this.newpd = (+val1 > 0) ? +val1 : this.sensorPosition;
    this.newpd = +val1;
    this.modifyDistance();
  }

  changeWB () {
    const val2 = prompt('Please input the value of wheel-base:');
    // this.newwb = (+val2 > 0) ? +val2 : this.wheelBase;
    this.newwb = +val2;
    this.modifyDistance();
  }

  private changeValue1 (font: THREE.Font, val: number) {
    const message = val + 'cm';
    const shapes = font.generateShapes(message, 1.5, 1);
    const geometry = new THREE.ShapeBufferGeometry(shapes);
    geometry.computeBoundingBox();
    const xMid = - 0.5 * (geometry.boundingBox.max.x - geometry.boundingBox.min.x);
    geometry.translate(xMid, 0, 0);

    if (!this.text1) {
      this.text1 = new THREE.Mesh(geometry, this.matLite);
    } else {
      this.updateText(this.text1, geometry);
    }
  }
  private changeValue2 (font: THREE.Font, val: number) {
    const message = val + 'cm';
    const shapes = font.generateShapes(message, 1.5, 1);
    const geometry = new THREE.ShapeBufferGeometry(shapes);
    geometry.computeBoundingBox();
    const xMid = - 0.5 * (geometry.boundingBox.max.x - geometry.boundingBox.min.x);
    geometry.translate(xMid, 0, 0);
    if (!this.text2) {
      this.text2 = new THREE.Mesh(geometry, this.matLite);
    } else {
      this.updateText(this.text2, geometry);
    }
  }
  private updateText (mesh: THREE.Mesh, geometry: THREE.ShapeBufferGeometry) {
    mesh.geometry.dispose();
    mesh.geometry = geometry;
  }

  modifyDistance () {
    this.recover();

    // 初期の2つ距離の比例
    const radbase = this.initPDWidth / this.initWBWidth;

    const radwb = this.newpd / this.newwb;
    const radcalc = radwb - radbase;
    // const radpd = this.sensorPosition / this.wheelBase;

    // phone の移動距離を計算
    const mv = radcalc * this.initWBWidth;
    // let mv = this.initPDWidth * (radwb - 1);
    // mv -= this.initPDWidth * (radpd - 1);
    // const mv = (radpd - radwb) * this.sensorPosition;

    this.carGroup.matrixAutoUpdate = false;
    // carの長さを固定するように
    // this.carGroup.scale.x = radwb;
    // if (mv > 0) {
    //   this.objGroup.position.x -= mv;
    //   this.arrow1.position.x -= mv;
    // } else {
    //   this.objGroup.position.x -= (this.newpd + mv);
    //   this.arrow1.position.x = this.sensorPosition;
    // }
    // this.arrow1.scale.x = radwb / radpd;
    this.objGroup.position.x -= mv;

    // if ((this.initPDWidth + mv) > 0) {
    //   this.arrow1.scale.x = (this.initPDWidth + mv) / this.initPDWidth;
    // } else {
    //   this.arrow1.scale.x = -1 * (this.initPDWidth + mv) / this.initPDWidth;
    // }
    if (this.newpd >= 0) {
      this.arrow1.scale.x = (this.initPDWidth + mv) / this.initPDWidth;
      this.arrow1.position.x -= (mv / 2);
    } else {
      this.arrow1.scale.x = (this.newpd * -1) / this.initPDWidth;
      console.log('arrow1.scale.x: ' + this.arrow1.scale.x);
      this.arrow1.position.x = this.initPDWidth + (this.newpd * -1 / 2);
      console.log('arrow1.position.x: ' + this.arrow1.position.x);
    }

    this.text1.position.x += mv;
    this.changeValue1(this.font, this.newpd);
    this.changeValue2(this.font, this.newwb);
    this.carGroup.matrixAutoUpdate = true;
  }

}
