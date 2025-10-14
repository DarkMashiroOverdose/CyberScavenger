pub let tutorial_joystick_entities: Ref[Array[@system.Entity]] = Ref::new([])

pub struct Joystick {
  base_entity: @system.Entity   
  handle_entity: @system.Entity 
  base_pos: @math.Vec2D
  base_radius: Double
  handle_radius: Double
  
  mut active_touch_id: Option[Int]
  mut direction: @math.Vec2D
}
pub let joystick: Ref[Option[Joystick]] = Ref::new(None)

let joystick_activation_zone: @math.Rect = { 
  position: @math.Vec2D(1280.0 * 0.25, 720.0 / 2.0),
  size: @math.Vec2D(1280.0 * 0.5, 720.0),
}
fn setup_joystick_ui(center_pos: @math.Vec2D) -> Joystick {
  let base_radius = 80.0
  let handle_radius = 40.0

  let base_entity = @system.Entity::new()
  @position.positions.set(base_entity, center_pos)
  let base_shape = @sprite.ColoredShape::new(
    @sprite.Shape::circle(base_radius),
    @sprite.DrawStyle::fill("rgba(128, 128, 128, 0.5)")
  )
  let base_sprite = @sprite.Sprite::from_shape(base_shape, 90, layer=@sprite.RenderLayer::ui())
  @sprite.sprites.set(base_entity, base_sprite)
  ui_entities.val.push(base_entity)

  let handle_entity = @system.Entity::new()
  @position.positions.set(handle_entity, center_pos)
  let handle_shape = @sprite.ColoredShape::new(
    @sprite.Shape::circle(handle_radius),
    @sprite.DrawStyle::fill("rgba(200, 200, 200, 0.7)")
  )
  let handle_sprite = @sprite.Sprite::from_shape(handle_shape, 91, layer=@sprite.RenderLayer::ui())
  @sprite.sprites.set(handle_entity, handle_sprite)
  ui_entities.val.push(handle_entity)

  return {
    base_entity,
    handle_entity,
    base_pos: center_pos, // base_pos 现在是动态的
    base_radius,
    handle_radius,
    active_touch_id: None,
    direction: @math.Vec2D::zero(),
  }
}
pub fn joystick_system(_backend: &@system.Backend) -> Unit {
  if current_ui_state.val == UIState::InGame && current_control_scheme.val == ControlScheme::Joystick {
    // 确保当前是摇杆模式
    guard current_control_scheme.val == ControlScheme::Joystick else {
      // 如果不是摇杆模式但摇杆还存在（模式切换导致），则清理掉
      if joystick.val is Some(joy) {
        cleanup_joystick_ui(joy)
        joystick.val = None
      }
      return
    }

    // 销毁摇杆
    if joystick.val is Some(joy) && joy.active_touch_id is Some(active_id) {
      if @system.just_ended_touches.get(active_id) is Some(_) {
        cleanup_joystick_ui(joy)
        joystick.val = None
        return // 销毁后，本帧操作结束
      }
    }

    //处理手指按下（创建摇杆）
    if joystick.val is None {
      for touch in @system.just_began_touches.values() {
        // 检查手指是否按在了右侧的激活区域内
        if is_point_inside_centered_rect(touch.pos, joystick_activation_zone) {
          //在创建真摇杆之前，先销毁假的
          cleanup_tutorial_joystick()
          // 在手指按下的地方创建摇杆
          let new_joy = setup_joystick_ui(touch.pos)
          // 捕获这个手指
          new_joy.active_touch_id = Some(touch.id)
          joystick.val = Some(new_joy)
          break // 只处理第一个在区域内按下的手指
        }
      }
    }

    // 3. 处理拖动（更新摇杆位置）
    if joystick.val is Some(joy) && joy.active_touch_id is Some(active_id) {
      if @system.active_touches.get(active_id) is Some(active_touch) {
        // 这部分的拖动和限制逻辑与之前完全一样！
        let vec_from_center = active_touch.pos - joy.base_pos
        let distance = vec_from_center.distance_to(@math.Vec2D::zero())
        
        let final_handle_pos = if distance <= joy.base_radius {
          active_touch.pos
        } else {
          joy.base_pos + vec_from_center.normalize().scalar_mul(joy.base_radius)
        }
        
        let new_direction = if distance <= joy.base_radius {
          vec_from_center.scalar_div(joy.base_radius)
        } else {
          vec_from_center.normalize()
        }

        joy.direction = new_direction
        @position.positions.set(joy.handle_entity, final_handle_pos)
      }
    }
  }
}
fn cleanup_joystick_ui(joy: Joystick) -> Unit {
  ui_entities.val = ui_entities.val.filter(fn(e) {
    e != joy.base_entity && e != joy.handle_entity
  })

  @sprite.sprites.remove(joy.base_entity)
  @sprite.sprites.remove(joy.handle_entity)

  @system.Entity::destroy(joy.base_entity)
  @system.Entity::destroy(joy.handle_entity)
}

fn create_tutorial_joystick_visuals() -> Unit {
  let base_pos = @math.Vec2D(200.0, 550.0) // 固定在左下角
  let base_radius = 80.0
  let handle_radius = 40.0

  // 1. 创建底盘
  let base_entity = @system.Entity::new()
  @position.positions.set(base_entity, base_pos)
  let base_shape = @sprite.ColoredShape::new(
    @sprite.Shape::circle(base_radius),
    @sprite.DrawStyle::fill("rgba(128, 128, 128, 0.3)") // 让它更透明一些
  )
  let base_sprite = @sprite.Sprite::from_shape(base_shape, 80, layer=@sprite.RenderLayer::ui())
  @sprite.sprites.set(base_entity, base_sprite)
  
  // 2. 创建摇杆
  let handle_entity = @system.Entity::new()
  @position.positions.set(handle_entity, base_pos)
  let handle_shape = @sprite.ColoredShape::new(
    @sprite.Shape::circle(handle_radius),
    @sprite.DrawStyle::fill("rgba(200, 200, 200, 0.5)")
  )
  let handle_sprite = @sprite.Sprite::from_shape(handle_shape, 81, layer=@sprite.RenderLayer::ui())
  @sprite.sprites.set(handle_entity, handle_sprite)

  // 为摇杆添加脉冲缩放动画，吸引玩家注意
  dynamic_transforms.set(handle_entity, {
    is_pulsing_scale: true,
    rotation_speed: 0.0,
    scale_speed: 2.0, // 较慢的呼吸频率
    scale_amplitude: 0.1, // 10%的缩放幅度
    _current_angle: 0.0,
    _time_elapsed: 0.0,
  })

  // 加入列表
  tutorial_joystick_entities.val = [base_entity, handle_entity]
  ui_entities.val.push(base_entity)
  ui_entities.val.push(handle_entity)
}
fn cleanup_tutorial_joystick() -> Unit {
  if tutorial_joystick_entities.val.is_empty() {
    return // 如果已经被销毁，就什么都不做
  }
  
  println("【引导】: 玩家已开始操作，销毁教学摇杆。")

  for entity in tutorial_joystick_entities.val {
    // 从各类组件和列表中移除
    @sprite.sprites.remove(entity)
    dynamic_transforms.remove(entity)
    ui_entities.val = ui_entities.val.filter(fn(e) { e != entity })
    @system.Entity::destroy(entity)
  }
  
  // 清空追踪列表
  tutorial_joystick_entities.val.clear()
}