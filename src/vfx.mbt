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
  AoEMeeleRed
  AoEMeeleOrange
  AoEMeelePurple
  Healing
  CooldownUp
  PrimaryBeam
  ChainBeam 
  PrimaryBeamBoom
  ChainBeamBoom
  ForkBeam
  ForkBeamBoom
  HitFlash
  ChargeShieldEffect
} derive(Eq, Show, Hash)
///光束类型特效
pub struct BeamTemplate {
  color: String
  thickness: Double
}
/// 用一个枚举来描述特效的【静态外观】
pub enum SpriteTemplate {
  Picture(String, @math.Vec2D)
  Shape(@sprite.Shape, @sprite.DrawStyle)
  Animation(@sprite.Animation, @math.Vec2D)
  TextLayout(@system.TextLayout) 
  Beam(BeamTemplate)
  FromParent(ParentCloneTemplate)
}

// 从父实体克隆并修改 Sprite
pub struct ParentCloneTemplate {
  color_override: String // 覆盖的颜色
  size_padding: Double   // 在父实体尺寸基础上增加的像素值
  z_index_offset: Int    // 相对于父实体 Sprite 的 Z 轴偏移
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
  "assets/gfx/explosion150xA.png",
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
        is_pulsing_scale: true,
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
        is_pulsing_scale: true,
        rotation_speed: 0.5,
        scale_speed: 1.0,
        scale_amplitude: 0.1,
        _current_angle: 0.0,
        _time_elapsed: 0.0,
      }),
    },
    z_index: 50,
  })
  vfx_library.set(VFX_Type::AoEMeeleRed, {
    sprite_template: SpriteTemplate::Shape(
        @sprite.Shape::circle(100.0), 
        @sprite.DrawStyle::stroke("rgba(219, 3, 3, 0.19)",5.0)),
    behavior: {
      // 【核心】指定生命周期模式
      lifecycle: VFX_Lifecycle::Timer(0.5),
      dynamic_transform: Some({
        is_pulsing_scale: true,
        rotation_speed: 0.5,
        scale_speed: 10.0,
        scale_amplitude: 0.1,
        _current_angle: 0.0,
        _time_elapsed: 0.0,
      }),
    },
    z_index: 50,
  })
  vfx_library.set(VFX_Type::AoEMeeleOrange, {
    sprite_template: SpriteTemplate::Shape(
        @sprite.Shape::circle(120.0), 
        @sprite.DrawStyle::stroke("rgba(255, 137, 2, 0.66)",5.0)),
    behavior: {
      // 【核心】指定生命周期模式
      lifecycle: VFX_Lifecycle::Timer(0.5),
      dynamic_transform: Some({
        is_pulsing_scale: true,
        rotation_speed: 0.5,
        scale_speed: 10.0,
        scale_amplitude: 0.1,
        _current_angle: 0.0,
        _time_elapsed: 0.0,
      }),
    },
    z_index: 50,
  })
  vfx_library.set(VFX_Type::AoEMeelePurple, {
    sprite_template: SpriteTemplate::Shape(
        @sprite.Shape::circle(160.0), 
        @sprite.DrawStyle::stroke("#DDA0DD",4.0)),
    behavior: {
      // 【核心】指定生命周期模式
      lifecycle: VFX_Lifecycle::Timer(0.5),
      dynamic_transform: Some({
        is_pulsing_scale: true,
        rotation_speed: 0.5,
        scale_speed: 10.0,
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
        is_pulsing_scale: true,
        rotation_speed: 0.5,
        scale_speed: 1.0,
        scale_amplitude: 0.1,
        _current_angle: 0.0,
        _time_elapsed: 0.0,
      }),
    },
    z_index: 120,
  })
  vfx_library.set(VFX_Type::Healing, {
    sprite_template: SpriteTemplate::Shape(
        @sprite.Shape::cross(20.0,4.0,90.0), 
        @sprite.DrawStyle::fill("rgba(3, 180, 0, 1)")),
    behavior: {
      // 【核心】指定生命周期模式
      lifecycle: VFX_Lifecycle::Timer(0.5),
      dynamic_transform: Some({
        is_pulsing_scale: false,
        rotation_speed: 1.0,
        scale_speed: 1.0,
        scale_amplitude: 0.1,
        _current_angle: 0.0,
        _time_elapsed: 0.0,
      }),
    },
    z_index: 120,
  })
  vfx_library.set(VFX_Type::CooldownUp, {
    sprite_template: SpriteTemplate::Shape(
        @sprite.Shape::ellipse(20.0,6.0,0.0), 
        @sprite.DrawStyle::stroke("rgba(152, 0, 218, 1)",1.0)),
    behavior: {
      // 【核心】指定生命周期模式
      lifecycle: VFX_Lifecycle::Timer(8.0),
      dynamic_transform: Some({
        is_pulsing_scale: false,
        rotation_speed: 0.3,
        scale_speed: 0,
        scale_amplitude: 0.1,
        _current_angle: 0.0,
        _time_elapsed: 0.0,
      }),
    },
    z_index: 120,
  })
  vfx_library.set(VFX_Type::PrimaryBeamBoom, {
    sprite_template: SpriteTemplate::Shape(
        @sprite.Shape::circle(20.0), 
        @sprite.DrawStyle::stroke("#6495ED",4.0)),
    behavior: {
      // 【核心】指定生命周期模式
      lifecycle: VFX_Lifecycle::Timer(0.15),
      dynamic_transform: Some({
        is_pulsing_scale: true,
        rotation_speed: 0.5,
        scale_speed: 10.0,
        scale_amplitude: 1.0,
        _current_angle: 0.0,
        _time_elapsed: 0.0,
      }),
    },
    z_index: 50,
  })
  vfx_library.set(VFX_Type::ChainBeamBoom, {
    sprite_template: SpriteTemplate::Shape(
        @sprite.Shape::circle(15.0), 
        @sprite.DrawStyle::stroke("#87CEEB",3.0)),
    behavior: {
      // 【核心】指定生命周期模式
      lifecycle: VFX_Lifecycle::Timer(0.15),
      dynamic_transform: Some({
        is_pulsing_scale: true,
        rotation_speed: 0.5,
        scale_speed: 10.0,
        scale_amplitude: 1.0,
        _current_angle: 0.0,
        _time_elapsed: 0.0,
      }),
    },
    z_index: 50,
  })
  vfx_library.set(VFX_Type::ForkBeamBoom, {
    sprite_template: SpriteTemplate::Shape(
        @sprite.Shape::circle(15.0), 
        @sprite.DrawStyle::stroke("#DDA0DD",3.0)),
    behavior: {
      // 【核心】指定生命周期模式
      lifecycle: VFX_Lifecycle::Timer(0.15),
      dynamic_transform: Some({
        is_pulsing_scale: true,
        rotation_speed: 0.5,
        scale_speed: 10.0,
        scale_amplitude: 1.0,
        _current_angle: 0.0,
        _time_elapsed: 0.0,
      }),
    },
    z_index: 50,
  })
  vfx_library.set(VFX_Type::PrimaryBeam, {
    sprite_template: SpriteTemplate::Beam({
      color: "#6495ED",
      thickness: 5.0,
    }),
    behavior: { lifecycle: VFX_Lifecycle::Timer(0.15), dynamic_transform: None },
    z_index: 300,
  })
  vfx_library.set(VFX_Type::ChainBeam, {
    sprite_template: SpriteTemplate::Beam({
      color: "#87CEEB",
      thickness: 3.5,
    }),
    behavior: { lifecycle: VFX_Lifecycle::Timer(0.12), dynamic_transform: None },
    z_index: 300,
  })
  vfx_library.set(VFX_Type::ForkBeam, {
    sprite_template: SpriteTemplate::Beam({
      color: "#DDA0DD",
      thickness: 5.0,
    }),
    behavior: { lifecycle: VFX_Lifecycle::Timer(0.12), dynamic_transform: None },
    z_index: 300,
  })
  vfx_library.set(VFX_Type::HitFlash, {
    sprite_template: SpriteTemplate::FromParent({
      color_override: "#FFFFFF", // 白色
      size_padding: 0.0,         // 尺寸不变
      z_index_offset: 300,       // 显示在最上层
    }),
    behavior: { lifecycle: VFX_Lifecycle::Timer(0.08), dynamic_transform: None },
    z_index: 0,
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
  parent_entity: Option[@system.Entity] 
  to_position: Option[@math.Vec2D]
}
pub let vfx_follows: Map[@system.Entity, VFX_Follow] = Map::new()
pub struct VFX_Follow {
  parent: @system.Entity // 被跟随的父级实体
  offset: @math.Vec2D   // 相对于父级实体的偏移量（例如，在头顶）
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

       if request.parent_entity is Some(parent) {
        vfx_follows.set(vfx_entity, { parent: parent, offset: @math.Vec2D::zero() })
        if @position.positions.get(parent) is Some(parent_pos) {
          @position.positions.set(vfx_entity, parent_pos.0 + @math.Vec2D::zero())
        }
      } else {
        @position.positions.set(vfx_entity, request.position)
      }

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
        SpriteTemplate::TextLayout(layout) => {
          @sprite.Sprite::from_text_layout(
            layout, 
            template.z_index, 
            layer=@sprite.RenderLayer::ui()
          )
        }
        SpriteTemplate::Beam(beam_template) => {
          if request.to_position is Some(to_pos) {
            let from_pos = request.position
            let delta = to_pos - from_pos
            let distance = delta.distance()
            let angle = @kmath.atan2(delta[Y], delta[X])
            let center_pos = vec2d_lerp(from_pos, to_pos, 0.5)

            let beam_shape = @sprite.ColoredShape::new(
              @sprite.Shape::rect(distance, beam_template.thickness, 0.0),
              @sprite.DrawStyle::fill(beam_template.color)
            )
            
            @position.positions.set(vfx_entity, center_pos)

            let sprite = @sprite.Sprite::from_shape(
              beam_shape, 
              template.z_index, 
              offset= @math.Vec2D(-distance / 2.0, -beam_template.thickness / 2.0),
              layer=@sprite.RenderLayer::game_world(),
            )
            sprite.transform = @math.Transform::from_rotation_rad(angle)
            sprite
          } else {
            @sprite.Sprite::from_shape(@sprite.ColoredShape::new(@sprite.Shape::rect(0.0,0.0,0.0),@sprite.DrawStyle::fill("transparent")),0)
          }
        }
        SpriteTemplate::FromParent(clone_template) => {
          if request.parent_entity is Some(parent_entity) {
            if @sprite.sprites.get(parent_entity) is Some(parent_sprite) {
              // 尝试从父Sprite中复制形状信息
              let original_shape_opt = match parent_sprite.sprite_type {
                @sprite.SpriteType::ColoredShape(cs) => {
                  Some(cs.shape)
                }
                @sprite.SpriteType::Picture(pic) => {
                  Some(@sprite.Shape::rect(pic.size[X], pic.size[Y], 0.0))
                }
                @sprite.SpriteType::Animation(anim, ..) => {
                  if anim.frames.length() > 0 {
                    let frame_size = anim.frames[0].size
                    Some(@sprite.Shape::rect(frame_size[X], frame_size[Y], 0.0))
                  } else {
                    None
                  }
                }
                @sprite.SpriteType::ColorRect(rect) => {
                  Some(@sprite.Shape::rect(rect.size[X], rect.size[Y], 0.0))
                }
                _ => None
              }

              if original_shape_opt is Some(shape) {

                let (new_shape, new_offset) = match shape {
                  @sprite.Shape::Circle(r) => {
                    let new_radius = r + clone_template.size_padding
                    (
                      @sprite.Shape::circle(new_radius), 
                      parent_sprite.offset 
                    )
                  }
                  @sprite.Shape::Rect(w, h, corner_radius) => {
                    let new_w = w + clone_template.size_padding * 2.0
                    let new_h = h + clone_template.size_padding * 2.0
                    (
                      @sprite.Shape::rect(new_w, new_h, corner_radius),
                      @math.Vec2D(-new_w / 2.0, -new_h / 2.0) 
                    )
                  }
                  @sprite.Shape::Triangle(s, rotation) => {
                    let new_s = s + clone_template.size_padding * 2.0
                    (
                      @sprite.Shape::triangle(new_s, rotation),
                      parent_sprite.offset 
                    )
                  }
                  _ => (shape, parent_sprite.offset) 
                }

                let new_graphic = @sprite.ColoredShape::new(
                  new_shape,
                  @sprite.DrawStyle::fill(clone_template.color_override)
                )
                let new_z_index = parent_sprite.zindex + clone_template.z_index_offset

                let new_sprite = @sprite.Sprite::from_shape(
                  new_graphic,
                  new_z_index,
                  offset=new_offset,
                  layer=@sprite.RenderLayer::game_world(),
                )
                // 继承父级的旋转和缩放
                new_sprite.transform = parent_sprite.transform 
                new_sprite
              } else { // 这些else都是处理空情况的
                @sprite.Sprite::from_shape(@sprite.ColoredShape::new(@sprite.Shape::rect(0.0,0.0,0.0),@sprite.DrawStyle::fill("transparent")),0)
              }
            } else {
              @sprite.Sprite::from_shape(@sprite.ColoredShape::new(@sprite.Shape::rect(0.0,0.0,0.0),@sprite.DrawStyle::fill("transparent")),0)
            }
          } else {
            @sprite.Sprite::from_shape(@sprite.ColoredShape::new(@sprite.Shape::rect(0.0,0.0,0.0),@sprite.DrawStyle::fill("transparent")),0)
          }
        }
      }

      @sprite.sprites.set(vfx_entity, sprite_component)
      if template.sprite_template is Animation(anim, _) {
        @sprite.play_animation(vfx_entity, anim)
      }

      if template.sprite_template is Beam(_) && request.to_position is Some(to_pos) {
        let center_pos = vec2d_lerp(request.position, to_pos, 0.5)
        @position.positions.set(vfx_entity, center_pos)
      } else {
        if request.parent_entity is Some(parent) {
          vfx_follows.set(vfx_entity, { parent, offset: @math.Vec2D::zero() })
          if @position.positions.get(parent) is Some(parent_pos) {
              @position.positions.set(vfx_entity, parent_pos.0)
          }
        } else {
          @position.positions.set(vfx_entity, request.position)
        }
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
  is_pulsing_scale: Bool
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
        let current_scale = if transform_data.is_pulsing_scale {
          // 旧的脉冲逻辑
          1.0 + @kmath.sin(new_time * transform_data.scale_speed) * transform_data.scale_amplitude
        } else {
          // 新的持续放大逻辑
          1.0 + new_time * transform_data.scale_speed
        }
        
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

pub struct VFX_Movement {
  velocity: @math.Vec2D
}

pub let vfx_movements: Map[@system.Entity, VFX_Movement] = Map::new()

pub fn vfx_movement_system(_backend: &@system.Backend) -> Unit {
  let delta_seconds = 1.0 / 60.0

  for entry in vfx_movements.iter() {
    let entity = entry.0
    let movement = entry.1

    if entity.is_alive() {
      if @position.positions.get(entity) is Some(pos) {
        let new_pos = pos.0 + movement.velocity.scalar_mul(delta_seconds)
        @position.positions.set(entity, @position.Position(new_pos))
      }
    }
  }
}
pub fn spawn_kill_score_vfx(score: Int, position: @math.Vec2D) -> Unit {
  let vfx_entity = @system.Entity::new()
  @position.positions.set(vfx_entity, position)
  
  let layout = @system.TextLayout::new(
    "+\{score}", 
    font="bold 24px mplus_hzk", 
    color="#FFD700"
  )
  let sprite = @sprite.Sprite::from_text_layout(layout, 999, layer=@sprite.RenderLayer::ui())
  @sprite.sprites.set(vfx_entity, sprite)
  vfx_movements.set(vfx_entity, { 
    velocity: @math.Vec2D(-150.0, -250.0) 
  })
  dynamic_transforms.set(vfx_entity, {
    rotation_speed: 0.0, 
    scale_speed: 0.2,
    scale_amplitude: 0.0,
    is_pulsing_scale: false,
    _current_angle: 0.0,
    _time_elapsed: 0.0,
  })

  vfx_instances.set(vfx_entity, VFX_Lifecycle::Timer(1.2))
}

pub fn vfx_follow_system(_backend: &@system.Backend) -> Unit {
  for vfx_entity, follow_data in vfx_follows {
    if follow_data.parent.is_alive() {
      if @position.positions.get(follow_data.parent) is Some(parent_pos) {
        @position.positions.set(vfx_entity, parent_pos.0 + follow_data.offset)
      }
    } else {
      entities_to_cleanup.val.push(vfx_entity)
      vfx_follows.remove(vfx_entity)
    }
  }
}