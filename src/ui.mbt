// ---------------------------
// 1. 状态与组件定义
// ---------------------------
pub enum UIState {
  MainMenu
  InGame
  Settings
} derive(Eq)

let current_ui_state: Ref[UIState] = Ref::new(UIState::MainMenu)
let prev_ui_state: Ref[UIState] = Ref::new(UIState::MainMenu)
let ui_entities: Ref[Array[@system.Entity]] = Ref::new([])

pub struct Button {
  area: @math.Rect
  on_click_state: UIState
  normal_picture: @sprite.Picture
  hover_picture: @sprite.Picture
  mut is_hovered: Bool
}

pub let buttons : Map[@system.Entity, Button] = Map::new()

// ---------------------------
// 2. UI 元素创建与销毁
// ---------------------------


fn cleanup_ui() -> Unit {
  println("【调试日志 A】: 检测到状态切换，开始清理旧的UI...")
  
  for entity in ui_entities.val {
    println("【调试日志 B】: 正在处理实体 {entity}...")
    
    // 关键修正：使用 `get(key) is Some` 来检查键是否存在
    if @sprite.sprites.get(entity) is Some {
      let _ = @sprite.sprites.remove(entity)
      println("  - Sprite组件被立即移除。")
    }
    
    @system.Entity::destroy(entity)
    println("  - 实体已被标记为销毁。")
  }
  
  // 清空我们的追踪列表
  ui_entities.val = []
  buttons.clear()
  println("【调试日志 C】: 旧UI清理完毕！")
}
let title_frames: Array[@sprite.AnimationFrame] = @sprite.frames_from_atlas(
  "assets/gui/start_menu/title_animated.png",
  79, 
  width=765,
  height=275.0,
)
let title_animation: @sprite.Animation = @sprite.Animation::new(title_frames, loop_=true, rate=0.4)

fn setup_main_menu_ui() -> Unit {
  println("【调试日志 D】: 正在创建【主菜单】UI...")
  let title_entity =  @system.Entity::new()
  @position.positions.set(title_entity, @math.Vec2D(450.0, 200.0))
  //let title_picture = @sprite.Picture::new(@math.Vec2D(800.0, 300.0), "assets/gui/start_menu/title.png")
  let title_sprite = @sprite.Sprite::from_animation(title_animation, 1, layer=@sprite.RenderLayer::ui(), offset = @math.Vec2D(-400.0, -150.0))
  @sprite.sprites.set(title_entity, title_sprite)
  @ui.uis.set(title_entity, @ui.Ui::new())
  ui_entities.val.push(title_entity)

  let start_button_entity = @system.Entity::new()
  @position.positions.set(start_button_entity, @math.Vec2D(230.0, 400.0))
  //let start_text = @sprite.Text::new("[Start Game]", font="32px Arial")
  //let start_sprite = @sprite.Sprite::from_text(start_text, 1, layer=@sprite.RenderLayer::ui())
  let start_normal_pic = @sprite.Picture::new(@math.Vec2D(220.0, 60.0), "assets/gui/start_menu/start.png")
  let start_hover_pic = @sprite.Picture::new(@math.Vec2D(220.0, 60.0), "assets/gui/start_menu/start_light.png")

  let start_sprite = @sprite.Sprite::from_picture(start_normal_pic, 1, layer=@sprite.RenderLayer::ui(), offset = @math.Vec2D(-110.0, -30.0))
  @sprite.sprites.set(start_button_entity, start_sprite)
  @ui.uis.set(start_button_entity, @ui.Ui::new())
  let start_button_component = Button::{
    area: @math.Rect::{ 
      position: @math.Vec2D(230.0, 400.0), 
      size: @math.Vec2D(220.0, 60.0)
    },
    normal_picture: start_normal_pic,
    hover_picture: start_hover_pic,
    is_hovered: false, 
    on_click_state: UIState::InGame,
  }
  buttons.set(start_button_entity, start_button_component)
  ui_entities.val.push(start_button_entity)
  
  let archive_button_entity = @system.Entity::new()
  @position.positions.set(archive_button_entity, @math.Vec2D(180.0, 470.0))
  //let settings_text = @sprite.Text::new("[Settings]", font="32px Arial")
  //let settings_sprite = @sprite.Sprite::from_text(settings_text, 1, layer=@sprite.RenderLayer::ui())
  let archive_normal_pic = @sprite.Picture::new(@math.Vec2D(110.0, 60.0), "assets/gui/start_menu/archive.png")
  let archive_hover_pic = @sprite.Picture::new(@math.Vec2D(110.0, 60.0), "assets/gui/start_menu/archive_light.png")
  let archive_sprite = @sprite.Sprite::from_picture(archive_normal_pic, 1, layer=@sprite.RenderLayer::ui(), offset = @math.Vec2D(-60.0, -30.0))
  @sprite.sprites.set(archive_button_entity, archive_sprite)
  @ui.uis.set(archive_button_entity, @ui.Ui::new())
  let archive_button_component = Button::{
    area: @math.Rect::{ 
      position: @math.Vec2D(180.0, 470.0), 
      size: @math.Vec2D(110.0, 60.0) 
    },
    normal_picture: archive_normal_pic,
    hover_picture: archive_hover_pic,
    is_hovered: false, 
    on_click_state: UIState::Settings,
  }
  buttons.set(archive_button_entity, archive_button_component)
  ui_entities.val.push(archive_button_entity)


  let settings_button_entity = @system.Entity::new()
  @position.positions.set(settings_button_entity, @math.Vec2D(180.0, 540.0))
  let settings_normal_pic = @sprite.Picture::new(@math.Vec2D(110.0, 60.0), "assets/gui/start_menu/settings.png")
  let settings_hover_pic = @sprite.Picture::new(@math.Vec2D(120.0, 60.0), "assets/gui/start_menu/settings_light.png")
  let settings_sprite = @sprite.Sprite::from_picture(settings_normal_pic, 1, layer=@sprite.RenderLayer::ui(), offset = @math.Vec2D(-60.0, -30.0))
  @sprite.sprites.set(settings_button_entity, settings_sprite)
  @ui.uis.set(settings_button_entity, @ui.Ui::new())
  let settings_button_component = Button::{
    area: @math.Rect::{ 
      position: @math.Vec2D(180.0, 540.0), 
      size: @math.Vec2D(110.0, 60.0) 
    },
    normal_picture: settings_normal_pic,
    hover_picture: settings_hover_pic,
    is_hovered: false, 
    on_click_state: UIState::Settings,
  }
  buttons.set(settings_button_entity, settings_button_component)
  ui_entities.val.push(settings_button_entity)

  let about_button_entity = @system.Entity::new()
  @position.positions.set(about_button_entity, @math.Vec2D(180.0, 610.0))
  let about_normal_pic = @sprite.Picture::new(@math.Vec2D(110.0, 60.0), "assets/gui/start_menu/about.png")
  let about_hover_pic = @sprite.Picture::new(@math.Vec2D(120.0, 60.0), "assets/gui/start_menu/about_light.png")
  let about_sprite = @sprite.Sprite::from_picture(about_normal_pic, 1, layer=@sprite.RenderLayer::ui(), offset = @math.Vec2D(-60.0, -30.0))
  @sprite.sprites.set(about_button_entity, about_sprite)
  @ui.uis.set(about_button_entity, @ui.Ui::new())
  let about_button_component = Button::{
    area: @math.Rect::{ 
      position: @math.Vec2D(180.0, 610.0), 
      size: @math.Vec2D(110.0, 60.0) 
    },
    normal_picture: about_normal_pic,
    hover_picture: about_hover_pic,
    is_hovered: false, 
    on_click_state: UIState::Settings,
  }
  buttons.set(about_button_entity, about_button_component)
  ui_entities.val.push(about_button_entity)


}

fn setup_ingame_hud() -> Unit {
  println("【调试日志 E】: 正在创建【游戏内HUD】...")
  // --- 分数显示 ---
  let score_label = @system.Entity::new()
  @position.positions.set(score_label, @math.Vec2D(100.0, 50.0))
  let score_text = @sprite.Text::new("Score: 0", font="24px Arial")
  let score_sprite = @sprite.Sprite::from_text(score_text, 1, layer=@sprite.RenderLayer::ui())
  @sprite.sprites.set(score_label, score_sprite)
  @ui.uis.set(score_label, @ui.Ui::new())
  ui_entities.val.push(score_label)
}

fn setup_settings_ui() -> Unit {

  let about_normal_pic = @sprite.Picture::new(@math.Vec2D(110.0, 60.0), "assets/gui/start_menu/about.png")
  let about_hover_pic = @sprite.Picture::new(@math.Vec2D(110.0, 60.0), "assets/gui/start_menu/about_light.png")

  let back_button_entity = @system.Entity::new()
  @position.positions.set(back_button_entity, @math.Vec2D(400.0, 450.0))
  let back_text = @sprite.Text::new("[Back to Main Menu]", font="32px Arial")
  let back_sprite = @sprite.Sprite::from_text(back_text, 1, layer=@sprite.RenderLayer::ui())
  @sprite.sprites.set(back_button_entity, back_sprite)
  @ui.uis.set(back_button_entity, @ui.Ui::new())
  let back_button_component = Button::{
    area: @math.Rect::{ 
      position: @math.Vec2D(250.0, 425.0), 
      size: @math.Vec2D(300.0, 50.0) 
    },
    normal_picture: about_normal_pic,
    hover_picture: about_hover_pic,
    is_hovered: false, 
    on_click_state: UIState::MainMenu,
  }
  buttons.set(back_button_entity, back_button_component)
  ui_entities.val.push(back_button_entity)
}

// ---------------------------
// 3. UI 逻辑更新与状态切换
// ---------------------------

// 在 ui.mbt 文件中

pub fn button_system(_backend: &@system.Backend) -> Unit {
  // 1. 获取实时鼠标位置
  let mouse_pos = @system.mouse.pos

  // 2. 遍历所有按钮
  for entry in buttons.iter() {
    let entity = entry.0
    let button = entry.1
    
    let rect_pos = button.area.position
    let rect_size = button.area.size
    
    // 3. 判断鼠标当前是否在按钮区域内
    let is_inside = 
      mouse_pos.0 >= rect_pos.0 - (rect_size.0)/2 && 
      mouse_pos.0 <= rect_pos.0 + (rect_size.0)/2 &&
      mouse_pos.1 >= rect_pos.1 - (rect_size.1)/2 &&
      mouse_pos.1 <= rect_pos.1 + (rect_size.1)/2
    
    // 4. 核心：只在“悬停状态”发生改变时，才更新Sprite
    if is_inside != button.is_hovered {
      button.is_hovered = is_inside
      
      let new_picture_to_show = if is_inside {
        button.hover_picture
      } else {
        button.normal_picture
      }

      // 获取实体当前的Sprite组件，以便读取它的zindex, offset等属性
      if @sprite.sprites.get(entity) is Some(current_sprite) {
          // 关键修正：不使用 ..current_sprite 复制语法，
          // 而是调用构造函数 Sprite::from_picture 创建一个全新的 Sprite
          let new_sprite = @sprite.Sprite::from_picture(
              new_picture_to_show,
              current_sprite.zindex,
              layer = current_sprite.layer,
              offset = current_sprite.offset,
          )
          // 用创建好的新 Sprite 替换掉旧的
          @sprite.sprites.set(entity, new_sprite)
      }
    }

    // 5. 处理点击事件
    if is_inside && @system.is_mouse_just_pressed(@system.MouseButton::Left) {
      current_ui_state.val = button.on_click_state
      return
    }
  }
}

pub fn update_ui_system(_backend: &@system.Backend) -> Unit {
  if current_ui_state.val != prev_ui_state.val {
    cleanup_ui()
    
    match current_ui_state.val {
      UIState::MainMenu => setup_main_menu_ui()
      UIState::InGame => setup_ingame_hud()
      UIState::Settings => setup_settings_ui()
    }
    prev_ui_state.val = current_ui_state.val
  }
  
  match current_ui_state.val {
    UIState::MainMenu => {
      if @system.is_just_pressed(@system.KeyS) {
        current_ui_state.val = UIState::Settings
      }
    }
    UIState::Settings => {
      if @system.is_just_pressed(@system.Escape) {
        current_ui_state.val = UIState::MainMenu
      }
    }
    _ => ()
  }
}