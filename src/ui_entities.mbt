
///----------------
///     血条
///----------------

///血量系统
struct Health {
  current: Double
  max: Double
  bar_bg_entity: @system.Entity
  bar_fg_entity: @system.Entity
  shield_frame_entity: @system.Entity
}

let healths: Map[@system.Entity, Health] = Map::new()
const HEALTH_BAR_WIDTH: Double = 50.0
const HEALTH_BAR_HEIGHT: Double = 5.0
const HEALTH_BAR_Y_OFFSET: Double = 3.0

///为单位附加血条
fn attach_health_bar() -> (@system.Entity, @system.Entity, @system.Entity) {
  let bar_bg = @system.Entity::new()
  let bar_fg = @system.Entity::new()
  let shield_frame = @system.Entity::new() 

  let bg_color_rect = @sprite.ColorRect::new(@math.Vec2D(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT), "red")
  let fg_color_rect = @sprite.ColorRect::new(@math.Vec2D(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT), "lime")

  let bg_sprite = @sprite.Sprite::from_color_rect(
    bg_color_rect, 8, layer=@sprite.RenderLayer::ui())
  let fg_sprite = @sprite.Sprite::from_color_rect(
    fg_color_rect, 9, layer=@sprite.RenderLayer::ui())
    
  @sprite.sprites.set(bar_bg, bg_sprite)
  @sprite.sprites.set(bar_fg, fg_sprite)
  
  let frame_width = HEALTH_BAR_WIDTH + 10.0
  let frame_height = HEALTH_BAR_HEIGHT + 2.0
  let shield_frame_rect = @sprite.ColorRect::new(@math.Vec2D(frame_width, frame_height), "#00FFFF")
  let frame_sprite = @sprite.Sprite::from_color_rect(
    shield_frame_rect,
    7,
    layer=@sprite.RenderLayer::ui()
  )
  frame_sprite.visible = false
  @sprite.sprites.set(shield_frame, frame_sprite)
  
  return (bar_bg, bar_fg, shield_frame)
}
///更新血条UI
fn update_health_bars_system(_backend: &@system.Backend) -> Unit {
  for unit in healths.keys() {
    if @position.positions.get(unit) is Some(unit_pos) && 
       @sprite.sprites.get(unit) is Some(unit_sprite){
      if healths.get(unit) is Some(health) {
        // 更新血条位置
        let (unit_width, unit_height) = match unit_sprite.sprite_type {
        Picture(pic) => (pic.size[X], pic.size[Y])
        Animation(anim, ..) => (anim.frames[0].size[X], anim.frames[0].size[Y])
        ColorRect(rect) => (rect.size[X], rect.size[Y])
        _ => (64.0, 64.0) // 提供一个默认尺寸
      }

        let bar_width = unit_width * 1.0
        let bar_pos_x = unit_pos.0[X] - bar_width / 2.0
        let bar_pos_y = unit_pos.0[Y] - (unit_height / 2.0) - HEALTH_BAR_Y_OFFSET
        let bar_pos = @math.Vec2D(bar_pos_x, bar_pos_y)
        @position.positions.set(health.bar_bg_entity, bar_pos)
        @position.positions.set(health.bar_fg_entity, bar_pos)
        @position.positions.set(health.shield_frame_entity, bar_pos) 

        //更新前景条宽度
        let health_percentage = health.current / health.max
        if @sprite.sprites.get(health.bar_fg_entity) is Some(fg_sprite) {
          match fg_sprite.sprite_type {
            ColorRect(rect) => {
              //创建一个具有新尺寸的 ColorRect
              let new_rect_size = @math.Vec2D(bar_width * health_percentage, HEALTH_BAR_HEIGHT)
              let new_rect = { ..rect, size: new_rect_size }
              
              //继承 zindex 和 offset
              let new_fg_sprite = @sprite.Sprite::from_color_rect(
                new_rect, 
                fg_sprite.zindex, 
                offset=fg_sprite.offset,
                layer=fg_sprite.layer,
                )
              
              @sprite.sprites.set(health.bar_fg_entity, new_fg_sprite)
            }
            //匹配类型
            _ => ()
          }
        }
        if @sprite.sprites.get(health.bar_bg_entity) is Some(bg_sprite) {
         match bg_sprite.sprite_type {
          ColorRect(rect) => {
            let new_size = @math.Vec2D(bar_width, HEALTH_BAR_HEIGHT)
            let new_rect = { ..rect, size: new_size }
            let new_sprite = @sprite.Sprite::from_color_rect(new_rect, bg_sprite.zindex, offset=bg_sprite.offset, layer=bg_sprite.layer)
            @sprite.sprites.set(health.bar_bg_entity, new_sprite)
          }
          _ => ()
          }
        }
        if @sprite.sprites.get(health.shield_frame_entity) is Some(frame_sprite) {
          let is_player = teams.get(unit) == Some(Team::Player)
          let is_shield_active = team_charge_shield.val is Some(s) && s.charges > 0

          frame_sprite.visible = is_player && is_shield_active
          
          match frame_sprite.sprite_type {
            ColorRect(rect) => {
              let new_width = bar_width
              let new_height = HEALTH_BAR_HEIGHT + 3.0
              if rect.size[X] != new_width || rect.size[Y] != new_height {
                let new_size = @math.Vec2D(new_width, new_height)
                let new_rect = { ..rect, size: new_size }
                let new_sprite = @sprite.Sprite::from_color_rect(new_rect, frame_sprite.zindex, offset=@math.Vec2D(0, -3), layer=frame_sprite.layer)
                
                new_sprite.visible = frame_sprite.visible
                @sprite.sprites.set(health.shield_frame_entity, new_sprite)
              }
            }
            _ => ()
          }
        }
      }
    }
  }
}

// ---------------------------------
//  附加朝向指示器 (Debug)
// ---------------------------------

let unit_to_orientation_indicator: Map[@system.Entity, @system.Entity] = Map::new()
fn attach_orientation_indicator(
  parent_unit: @system.Entity, 
  parent_pos: @math.Vec2D,
  parent_dims: @math.Vec2D,
) -> @system.Entity {
  let indicator_entity = @system.Entity::new()

  @position.positions.set(indicator_entity, parent_pos)

  let indicator_width = 4.0
  let indicator_height = parent_dims[Y]// 长度是单位高度的一半

  let indicator_graphic = @sprite.ColoredShape::new(
    @sprite.Shape::rect(indicator_width, indicator_height, 90.0),
    @sprite.DrawStyle::fill("cyan"),
  )

  let indicator_sprite = @sprite.Sprite::from_shape(
    indicator_graphic, 
    150, 
    offset=@math.Vec2D(indicator_width / -2.0, -indicator_height), 
    layer=@sprite.RenderLayer::ui(),
  )
  @sprite.sprites.set(indicator_entity, indicator_sprite)

  return indicator_entity
}
fn update_orientation_indicators_system(_backend: &@system.Backend) -> Unit {
  // 遍历所有拥有指示器的单位
  unit_to_orientation_indicator.each(fn(unit, indicator_entity) {
    // 1. 安全地获取单位和指示器都需要的所有组件
    if @position.positions.get(unit) is Some(unit_pos) &&
       @sprite.sprites.get(unit) is Some(unit_sprite) &&
       @sprite.sprites.get(indicator_entity) is Some(indicator_sprite) {

      @position.positions.set(indicator_entity, unit_pos.0)
      indicator_sprite.transform = unit_sprite.transform
    }
  })
}


// ---------------------------------
//  次数盾剩余次数
// ---------------------------------

let team_shield_display_entity: Ref[Option[@system.Entity]] = Ref::new(None)

pub fn update_shield_display_system(_backend: &@system.Backend) -> Unit {
  if team_charge_shield.val is Some(shield) && shield.charges > 0 {
    let display_text = "x\{shield.charges}"

    if team_shield_display_entity.val is Some(entity) {
      if @sprite.sprites.get(entity) is Some(old_sprite) {
        if old_sprite.sprite_type is @sprite.SpriteType::TextLayout(old_layout) {
          if old_layout.content != display_text {
            
            let new_layout = @system.TextLayout::new(
              display_text, // 新的 content
              font=old_layout.font,
              color=old_layout.color,
              max_width=old_layout.max_width,
              align=old_layout.align,
              line_height=old_layout.line_height
            )
            
            let new_sprite = @sprite.Sprite::from_text_layout(new_layout, old_sprite.zindex, layer=old_sprite.layer)
            @sprite.sprites.set(entity, new_sprite)
          }
        }
      }
      if player_head.val is Some(head) {
        if @position.positions.get(head) is Some(head_pos) {
          let new_pos = head_pos.0 + @math.Vec2D(-10.0, -10.0)
          @position.positions.set(entity, new_pos)
        }
      }
    } else {
      println("【UI】: 首次获得护盾，创建显示UI...")
      let new_entity = @system.Entity::new()
      
      let layout = @system.TextLayout::new(
        display_text,
        font="bold 24px mplus_hzk",
        color="#00FFFF"
      )
      let sprite = @sprite.Sprite::from_text_layout(layout, 200, layer=@sprite.RenderLayer::ui())
      @sprite.sprites.set(new_entity, sprite)
      
      team_shield_display_entity.val = Some(new_entity)
    }

  } else {
    if team_shield_display_entity.val is Some(entity) {
      println("【UI】: 护盾消失，销毁显示UI...")
      @sprite.sprites.remove(entity)
      @system.Entity::destroy(entity)
      team_shield_display_entity.val = None
    }
  }
}