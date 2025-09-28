// ---------------------------------
//      视觉特效 (VFX) 系统
// ---------------------------------

/// 注册视觉效果
pub enum VFX_Type {
  MeleeSlash
  BulletImpact
  PoisonCloud
  PoisonCloudRed
  SpeedLow
} derive(Eq, Show, Hash)

/// 用一个枚举来描述特效的【静态外观】
pub enum SpriteTemplate {
  Picture(String, @math.Vec2D)
  Shape(@sprite.Shape, @sprite.DrawStyle)
  Animation(@sprite.Animation, @math.Vec2D)
}
/// 用一个结构体来描述特效的【动态行为】
pub struct VFX_Behavior {
  lifecycle: VFX_Lifecycle
  dynamic_transform: Option[DynamicTransform]
}

/// 视觉特效模板结构体
pub struct VFX_Template {
  sprite_template: SpriteTemplate
  behavior: VFX_Behavior
  z_index: Int
}
/// 特效种类
pub enum VFX_Lifecycle {
  Timer(Double)         // 按计时器管理
  OnAnimationFinish     // 动画播放完毕后销毁
} derive(Show)
/// 特效模板库
pub let vfx_library: Map[VFX_Type, VFX_Template] = Map::new()

// ---------------------------------
//       注册并填充特效模板库
// ---------------------------------
///一个简单的爆炸动画
let explosion_frames: Array[@sprite.AnimationFrame] = @sprite.frames_from_atlas(
  "assets/explosion150xA.png",
  8, 
  width=184.5,
  height=150.0,
)

let explosion_animation: @sprite.Animation = @sprite.Animation::new(explosion_frames, loop_=false, rate=1)
fn setup_vfx_library() -> Unit {
  // 一个简单的子弹命中爆炸效果
  vfx_library.set(VFX_Type::BulletImpact, {
    sprite_template: SpriteTemplate::Animation(
      explosion_animation,
      @math.Vec2D(184.5, 150.0) 
    ),
    behavior: {
      lifecycle: VFX_Lifecycle::OnAnimationFinish,
      dynamic_transform: None,
    },
    z_index: 500,
  })

  vfx_library.set(VFX_Type::PoisonCloud, {
    sprite_template: SpriteTemplate::Shape(
        @sprite.Shape::circle(100.0), 
        @sprite.DrawStyle::fill("rgba(140, 255, 140, 0.5)")),
    behavior: {
      // 【核心】指定生命周期模式
      lifecycle: VFX_Lifecycle::Timer(5.0),
      dynamic_transform: Some({
        rotation_speed: 0.5,
        scale_speed: 1.0,
        scale_amplitude: 0.1,
        _current_angle: 0.0,
        _time_elapsed: 0.0,
      }),
    },
    z_index: 50,
  })

  vfx_library.set(VFX_Type::PoisonCloudRed, {
    sprite_template: SpriteTemplate::Shape(
        @sprite.Shape::circle(100.0), 
        @sprite.DrawStyle::fill("rgba(219, 3, 3, 0.19)")),
    behavior: {
      // 【核心】指定生命周期模式
      lifecycle: VFX_Lifecycle::Timer(5.0),
      dynamic_transform: Some({
        rotation_speed: 0.5,
        scale_speed: 1.0,
        scale_amplitude: 0.1,
        _current_angle: 0.0,
        _time_elapsed: 0.0,
      }),
    },
    z_index: 50,
  })

  vfx_library.set(VFX_Type::SpeedLow, {
    sprite_template: SpriteTemplate::Shape(
        @sprite.Shape::rect(5,5,0.775), 
        @sprite.DrawStyle::fill("rgba(17, 0, 255, 1)")),
    behavior: {
      // 【核心】指定生命周期模式
      lifecycle: VFX_Lifecycle::Timer(0.5),
      dynamic_transform: Some({
        rotation_speed: 0.5,
        scale_speed: 1.0,
        scale_amplitude: 0.1,
        _current_angle: 0.0,
        _time_elapsed: 0.0,
      }),
    },
    z_index: 120,
  })
}

// ---------------------------------
//       触发并更新视觉特效
// ---------------------------------
/// 存储待触发的特效事件
pub struct VFX_Request {
  vfx_type: VFX_Type
  position: @math.Vec2D
  rotation: Double
}

pub let vfx_requests: Ref[Array[VFX_Request]] = Ref::new([])

/// 瞬时特效
pub struct VFX_Instance {
  total_duration: Double
  remaining_duration: Double
}
pub let vfx_instances: Map[@system.Entity, VFX_Lifecycle] = Map::new()

// 特效生成器，根据VFX_Request在特定地点触发特定效果
pub fn vfx_spawner_system(_backend: &@system.Backend) -> Unit {
  for request in vfx_requests.val {
    if vfx_library.get(request.vfx_type) is Some(template) {
      let vfx_entity = @system.Entity::new()
      @position.positions.set(vfx_entity, request.position)
      let sprite_component = match template.sprite_template {
        SpriteTemplate::Picture(path, dims) => {
          let pic = @sprite.Picture::new(dims, path)
          @sprite.Sprite::from_picture(pic, template.z_index, offset=dims.scalar_div(-2.0), layer=@sprite.RenderLayer::game_world())
        }
        SpriteTemplate::Shape(shape, style) => {
          let graphic = @sprite.ColoredShape::new(shape, style)
          @sprite.Sprite::from_shape(graphic, template.z_index, layer=@sprite.RenderLayer::game_world())
        }
        SpriteTemplate::Animation(anim, dims) => {
          let offset_to_center = dims.scalar_div(-2.0)
          @sprite.Sprite::from_animation(anim, template.z_index, offset=offset_to_center, layer=@sprite.RenderLayer::game_world())
        }
      }

      @sprite.sprites.set(vfx_entity, sprite_component)
      if template.sprite_template is Animation(anim, _) {
        @sprite.play_animation(vfx_entity, anim)
      }
      
      vfx_instances.set(vfx_entity, template.behavior.lifecycle)
      if template.behavior.dynamic_transform is Some(dt) {
        dynamic_transforms.set(vfx_entity, dt)
      }
    }
  }
  vfx_requests.val.clear()
}

/// 特效更新器,计算剩余时间
pub fn vfx_update_system(_backend: &@system.Backend) -> Unit {
  let delta_seconds = 1.0 / 60.0

  for entity in vfx_instances.keys() {
    if vfx_instances.get(entity) is Some(instance_lifecycle) {

      let mut should_destroy = false

      // 【核心】使用 match 语句，为不同类型的生命周期执行不同逻辑
      match instance_lifecycle {
        VFX_Lifecycle::Timer(remaining) => {
          let new_duration = remaining - delta_seconds
          if new_duration <= 0.0 {
            should_destroy = true
          } else {
            vfx_instances.set(entity, VFX_Lifecycle::Timer(new_duration))
          }
        }
        VFX_Lifecycle::OnAnimationFinish => {
          // 【核心】在这里，我们整合了您之前成功的 cleanup_effects_system 的逻辑！
          if @sprite.is_animation_finished(entity) {
            should_destroy = true
          }
        }
      }

      if should_destroy {
        entities_to_cleanup.val.push(entity)
        vfx_instances.remove(entity)
      }
    }
  }
}


// ---------------------
//  精灵动态变换系统
// ---------------------
pub struct DynamicTransform {
  rotation_speed: Double // 每秒旋转的弧度
  scale_speed: Double    // 缩放脉冲的速度
  scale_amplitude: Double // 缩放脉冲的幅度 (e.g., 0.2 表示在 80% 到 120% 之间缩放)

  // 内部状态，用于动画计算
  _current_angle: Double
  _time_elapsed: Double
}

/// 绑定有动态变换精灵的实体
pub let dynamic_transforms: Map[@system.Entity, DynamicTransform] = Map::new()
/// 更新动态变换精灵
pub fn dynamic_transform_system(_backend: &@system.Backend) -> Unit {
  let delta_seconds = 1.0 / 60.0

  for entity in dynamic_transforms.keys() {
    if dynamic_transforms.get(entity) is Some(transform_data) {
      if entity.is_alive() {
        // 更新内部动画状态
        let new_angle = transform_data._current_angle + transform_data.rotation_speed * delta_seconds
        let new_time = transform_data._time_elapsed + delta_seconds
        
        let updated_transform_data = {
            ..transform_data,
            _current_angle: new_angle,
            _time_elapsed: new_time,
        }

        // 计算当前的缩放值
        let scale_pulse = @kmath.sin(new_time * transform_data.scale_speed)
        let current_scale = 1.0 + scale_pulse * transform_data.scale_amplitude
        
        // 直接获取Sprite并修改它
        if @sprite.sprites.get(entity) is Some(sprite) {
          
          //创建独立的缩放和旋转变换
          let scale_transform = @math.Transform::from_scale(current_scale, current_scale)
          let rotation_transform = @math.Transform::from_rotation_rad(new_angle)
          
          //将它们相乘得到最终的变换矩阵
          let final_transform = rotation_transform * scale_transform
          //println("[Log  DynamicTransform]: Entity \{entity}, New Angle: \{new_angle}, Transform A: \{final_transform.a}")
          sprite.transform = final_transform
        }
        
        //返回变换后的状态
        dynamic_transforms.set(entity, updated_transform_data)
      }
    }
  }
}
// ---------------------
//  单位朝向系统
// ---------------------
/// 更新一个单位的 Sprite，使其朝向指定的方向向量
pub fn unit_orientation_system(_backend: &@system.Backend) -> Unit {
  for unit in all_units.val {
    if unit.is_alive() {
      let mut new_direction: Option[@math.Vec2D] = None

      if attack_targets.get(unit) is Some(target) {
        if @position.positions.get(unit) is Some(unit_pos) &&
           @position.positions.get(target) is Some(target_pos) {
          
          let direction_vec = target_pos.0 - unit_pos.0
          if direction_vec.distance_to(@math.Vec2D::zero()) > 1.0 {
            new_direction = Some(direction_vec.normalize())
          }
        }
      } else if player_head.val != Some(unit) { // 火车头由 player_control_system 控制朝向
        if @velocity.velocities.get(unit) is Some(vel) {
          if vel.0.distance_to(@math.Vec2D::zero()) > 0.1 {
            new_direction = Some(vel.0.normalize())
          }
        }
      }

      if new_direction is Some(dir) {
        update_unit_orientation(unit, dir)
      }
    }
  }
}
/// 更新一个单位的 Sprite，使其朝向指定的方向向量
pub fn update_unit_orientation(entity: @system.Entity, direction: @math.Vec2D) -> Unit {
  if @sprite.sprites.get(entity) is Some(sprite) {
    //计算出相应的transform矩阵
    let target_angle = @kmath.atan2(direction[Y], direction[X])
    
    let base_rotation = sprite.transform.get_rotation_rad()

    let angle_to_apply = target_angle - base_rotation

    sprite.transform = sprite.transform * @math.Transform::from_rotation_rad(angle_to_apply)
    
  }
}