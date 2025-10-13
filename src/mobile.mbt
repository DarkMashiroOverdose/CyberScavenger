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

fn setup_joystick_ui() -> Unit {
  let base_pos = @math.Vec2D(200.0, 550.0)
  let base_radius = 80.0
  let handle_radius = 40.0

  let base_entity = @system.Entity::new()
  @position.positions.set(base_entity, base_pos)
  let base_shape = @sprite.ColoredShape::new(
    @sprite.Shape::circle(base_radius),
    @sprite.DrawStyle::fill("rgba(128, 128, 128, 0.5)")
  )
  let base_sprite = @sprite.Sprite::from_shape(base_shape, 90, layer=@sprite.RenderLayer::ui())
  @sprite.sprites.set(base_entity, base_sprite)
  ui_entities.val.push(base_entity)

  let handle_entity = @system.Entity::new()
  @position.positions.set(handle_entity, base_pos)
  let handle_shape = @sprite.ColoredShape::new(
    @sprite.Shape::circle(handle_radius),
    @sprite.DrawStyle::fill("rgba(200, 200, 200, 0.7)")
  )
  let handle_sprite = @sprite.Sprite::from_shape(handle_shape, 91, layer=@sprite.RenderLayer::ui())
  @sprite.sprites.set(handle_entity, handle_sprite)
  ui_entities.val.push(handle_entity)

  joystick.val = Some({
    base_entity,
    handle_entity,
    base_pos,
    base_radius,
    handle_radius,
    active_touch_id: None,
    direction: @math.Vec2D::zero(),
  })
}
pub fn joystick_system(_backend: &@system.Backend) -> Unit {
  //安全性检查：确保摇杆存在且当前为摇杆模式
  guard joystick.val is Some(joy) && current_control_scheme.val == ControlScheme::Joystick else {
    return
  }

  let is_joystick_active = joy.active_touch_id is Some(_)

  //处理手指抬起（停用摇杆）
  if is_joystick_active {
    let active_id = joy.active_touch_id.unwrap()
    if @system.just_ended_touches.get(active_id) is Some(_) {
      // 控制摇杆的手指抬起了
      joy.active_touch_id = None
      joy.direction = @math.Vec2D::zero()
      // 摇杆归位
      @position.positions.set(joy.handle_entity, joy.base_pos)
      return // 本帧处理完毕
    }
  }

  //处理手指按下
  if !is_joystick_active {
    for touch in @system.just_began_touches.values() {
      // 检查手指是否按在了摇杆底盘范围内
      if joy.base_pos.distance_to(touch.pos) <= joy.base_radius {
        // 捕获这个手指
        joy.active_touch_id = Some(touch.id)
        // 立即处理一次位置更新，避免延迟
        break // 只捕获第一个按下的手指
      }
    }
  }

  // 更新摇杆位置和方向
  if joy.active_touch_id is Some(active_id) {
    if @system.active_touches.get(active_id) is Some(active_touch) {
      let vec_from_center = active_touch.pos - joy.base_pos
      let distance = vec_from_center.distance_to(@math.Vec2D::zero())

      // 使用 if/else 表达式来初始化变量，避免多次赋值
      let final_handle_pos = if distance <= joy.base_radius {
        // 手指在底盘内，摇杆跟随
        active_touch.pos
      } else {
        // 手指超出底盘，限制在边缘
        joy.base_pos + vec_from_center.normalize().scalar_mul(joy.base_radius)
      }

      // 同样使用 if/else 表达式来计算方向
      let new_direction = if distance <= joy.base_radius {
        vec_from_center.scalar_div(joy.base_radius)
      } else {
        vec_from_center.normalize()
      }

      // 在计算完毕后，一次性更新可变字段
      joy.direction = new_direction
      @position.positions.set(joy.handle_entity, final_handle_pos)
    }
  }
}
