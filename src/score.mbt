let score: Ref[Int] = Ref::new(0)

pub fn add_score(amount: Int) -> Unit {
  score.val = score.val + amount
  println("【得分】: 增加了 \{amount} 分, 当前总分: \{score.val}")
}
pub fn update_score_display_system(_backend: &@system.Backend) -> Unit {
  if current_ui_state.val == UIState::InGame {
    if score_display_entity.val is Some(entity) {
      if @sprite.sprites.get(entity) is Some(old_sprite) {
        if old_sprite.sprite_type is @sprite.SpriteType::TextLayout(old_layout) {
          
          let new_score_text = "Score: \{score.val}"
          
          if old_layout.content != new_score_text {
            let new_layout = @system.TextLayout::new(
              new_score_text,
              font=old_layout.font,
              color=old_layout.color,
              max_width=old_layout.max_width,
              align=old_layout.align,
              line_height=old_layout.line_height,
            )
            
            let new_sprite = @sprite.Sprite::from_text_layout(
              new_layout,
              old_sprite.zindex,           // <-- 复用旧的 zindex
              layer=old_sprite.layer,      // <-- 复用旧的 layer
              offset=old_sprite.offset,    // <-- 复用旧的 offset
            )
            @sprite.sprites.set(entity, new_sprite)
          }
        }
      }
    }
  }
}