///一个可拾取物组件
pub struct Pickup {
  effects: Array[OnHitEffect] // 拾取后对玩家队伍施加的效果
  pickup_sfx: Option[SFX_Type]  // 拾取时的音效
  pickup_vfx: Option[VFX_Type]  // 拾取时的视觉特效
  mut remaining_duration: Double 
}
pub let pickups: Map[@system.Entity, Pickup] = Map::new()

pub fn pickup_system(_backend: &@system.Backend) -> Unit {
  // 所有玩家单位用于碰撞检测
  let player_cars: Array[@system.Entity] = []
  if player_head.val is Some(head) {
    let mut current_car_opt = Some(head)
    while current_car_opt is Some(car_entity) {
      player_cars.push(car_entity)
      if train_cars.get(car_entity) is Some(car_data) {
        current_car_opt = car_data.next
      } else {
        current_car_opt = None
      }
    }
  }

  // 遍历所有可拾取物
  for pickup_entity, pickup_data in pickups {
    if !pickup_entity.is_alive() { continue }

    if @position.positions.get(pickup_entity) is Some(pickup_pos) &&
       sizes.get(pickup_entity) is Some(pickup_size) {
      
      // 玩家车厢是否与该拾取物发生了碰撞
      for car_entity in player_cars {
        if @position.positions.get(car_entity) is Some(car_pos) &&
           sizes.get(car_entity) is Some(car_size) {

          let distance = pickup_pos.0.distance_to(car_pos.0)
          let combined_radius = pickup_size.radius + car_size.radius

          if distance < combined_radius {

            println("【拾取】: 玩家拾取了 \{pickup_entity}")

            // 对玩家单位应用拾取效果
            if player_head.val is Some(head_entity) {
              apply_all_effects(pickup_entity, head_entity, pickup_data.effects)
            }

            // 触发拾取时的音效和视觉特效
            if pickup_data.pickup_sfx is Some(sfx) {
              sfx_requests.val.push({ sfx_type: sfx, position: Some(pickup_pos.0) })
            }
            if pickup_data.pickup_vfx is Some(vfx) {
              vfx_requests.val.push({ vfx_type: vfx, position: pickup_pos.0, rotation: 0.0, parent_entity: None, to_position: None})
            }

            // 将拾取物加入清理队列
            entities_to_cleanup.val.push(pickup_entity)
            pickups.remove(pickup_entity) // 立即从 pickups 移除，防止一帧内被多次拾取

            break // 一个车厢拾取后，就跳出车厢循环，检查下一个拾取物
          }
        }
      }
    }
  }
}



pub enum PickupType {
  ChargeShield
  HealthPack
} derive(Eq, Show, Hash)
///可拾取物种类
pub enum PickupData {
  ShieldData(Int)    // 次数盾，包含要增加的次数
  HealthData(Double) // 血包，包含要恢复的血量
}

///定义拾取物的生成请求
pub struct PickupRequest {
  pickup_type: PickupType
  position: @math.Vec2D
  data: PickupData // 携带自定义数据
}

///全局的拾取物请求队列
pub let pickup_requests: Ref[Array[PickupRequest]] = Ref::new([])

///【新增】定义拾取物的“模板”
/// 模板只包含静态信息，如外观、音效等
pub struct PickupTemplate {
  sprite_template: SpriteTemplate // 复用VFX的Sprite模板！
  pickup_sfx: Option[SFX_Type]
  pickup_vfx: Option[VFX_Type]
  radius: Double
  duration: Double 
  dynamic_transform: Option[DynamicTransform]
}

// 创建全局的拾取物模板库
pub let pickup_library: Map[PickupType, PickupTemplate] = Map::new()

///拾取物库
pub fn setup_pickup_library() -> Unit {
  // 定义次数盾拾取物的外观和音效
  pickup_library.set(PickupType::ChargeShield, {
    sprite_template: SpriteTemplate::Picture(
      "assets/gfx/pickups/ChargeShield.png", 
      @math.Vec2D(40.0, 40.0)           
    ),
    pickup_sfx: Some(SFX_Type::PowerUp),
    pickup_vfx: None,
    radius: 15.0,
    duration: 10.0,
    dynamic_transform: Some({
      is_pulsing_scale: true,
      rotation_speed: 0.0,    // 不旋转
      scale_speed: 3.0,       // 呼吸频率
      scale_amplitude: 0.1,   // 缩放幅度 (90% to 110%)
      _current_angle: 0.0,
      _time_elapsed: 0.0,
    }),
  })

  // 定义血包拾取物的外观和音效
  pickup_library.set(PickupType::HealthPack, {
    sprite_template: SpriteTemplate::Shape(
      @sprite.Shape::cross(20.0, 8.0, 90.0), // 一个简单的十字形状
      @sprite.DrawStyle::fill("#FF4500")   // 橙红色
    ),
    pickup_sfx: Some(SFX_Type::PowerUp),
    pickup_vfx: None,
    radius: 20.0,
    duration: 10.0,
    dynamic_transform: Some({
      is_pulsing_scale: false, // 不缩放
      rotation_speed: 1.0,     // 缓慢旋转
      scale_speed: 0.0,
      scale_amplitude: 0.0,
      _current_angle: 0.0,
      _time_elapsed: 0.0,
    }),
  })
}
// /生成拾取物系统
pub fn pickup_spawner_system(_backend: &@system.Backend) -> Unit {
  // 遍历本帧的所有生成请求
  for request in pickup_requests.val {
    // 在库中查找对应的模板
    if pickup_library.get(request.pickup_type) is Some(template) {
      
      // 根据数据，动态地创建 Pickup 组件
      let pickup_component = {
        effects: match request.data {
          ShieldData(charges) => [OnHitEffect::GainChargeShield(charges)]
          HealthData(amount) => [OnHitEffect::Heal(amount, Some(VFX_Type::Healing))]
        },
        pickup_sfx: template.pickup_sfx,
        pickup_vfx: template.pickup_vfx,
        remaining_duration: template.duration, 
      }

      // 创建实体并附加所有通用组件
      let pickup_entity = @system.Entity::new()
      @position.positions.set(pickup_entity, request.position)
      sizes.set(pickup_entity, { radius: template.radius })

      // 根据模板创建 Sprite
      let sprite = match template.sprite_template {
        SpriteTemplate::Shape(shape, style) => {
          @sprite.Sprite::from_shape(@sprite.ColoredShape::new(shape, style), 10, layer=@sprite.RenderLayer::game_world())
        }
        SpriteTemplate::Picture(path, size) => {
          let pic = @sprite.Picture::new(size, path)
          let offset = @math.Vec2D(-size[X] / 2.0, -size[Y] / 2.0)
          @sprite.Sprite::from_picture(
            pic, 
            10, 
            offset=offset, // 
            layer=@sprite.RenderLayer::game_world()
          )
        }
        
        SpriteTemplate::Animation(anim, _size) => {
          let frame_size = if anim.frames.length() > 0 { anim.frames[0].size } else { @math.Vec2D::zero() }
          let offset = @math.Vec2D(-frame_size[X] / 2.0, -frame_size[Y] / 2.0)
          @sprite.Sprite::from_animation(
            anim, 
            10, 
            offset=offset, // <-- 应用正确的偏移量
            layer=@sprite.RenderLayer::game_world()
          )
        }
        _ => { @sprite.Sprite::from_shape(@sprite.ColoredShape::new(@sprite.Shape::rect(0.0,0.0,0.0),@sprite.DrawStyle::fill("transparent")),0) }
      }
      @sprite.sprites.set(pickup_entity, sprite)
      if template.dynamic_transform is Some(dt) {
        dynamic_transforms.set(pickup_entity, dt)
      }
      pickups.set(pickup_entity, pickup_component)
    }
  }

  if pickup_requests.val.length() > 0 {
    pickup_requests.val.clear()
  }
}

pub fn pickup_lifecycle_system(_backend: &@system.Backend) -> Unit {
  let delta_seconds = 1.0 / 60.0

  for pickup_entity, pickup_data in pickups {
    // duration <= 0 说明永远存在
    guard pickup_data.remaining_duration > 0.0 else {
      continue
    }

    // 倒计时
    pickup_data.remaining_duration -= delta_seconds

    // 检查生命周期是否结束
    if pickup_data.remaining_duration <= 0.0 {
      println("【清理】: 拾取物 \{pickup_entity} 因超时而被移除。")
      
      // TODO: 在这里可以触发一个“消失”的VFX
      // vfx_requests.val.push(...)

      // 将其加入清理队列
      entities_to_cleanup.val.push(pickup_entity)
      pickups.remove(pickup_entity) // 立即移除，防止被重复处理
    }
  }
}

/// 次数盾
pub struct ChargeShield {
  mut charges: Int // 剩余抵挡次数
}
/// 定义单位有多少次数盾
pub let team_charge_shield: Ref[Option[ChargeShield]] = Ref::new(None)
