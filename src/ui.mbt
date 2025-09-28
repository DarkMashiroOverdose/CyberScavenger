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

fn setup_main_menu_ui() -> Unit {
  println("【调试日志 D】: 正在创建【主菜单】UI...")
  let start_button_entity = @system.Entity::new()
  @position.positions.set(start_button_entity, @math.Vec2D(400.0, 300.0))
  let start_text = @sprite.Text::new("[Start Game]", font="32px Arial")
  let start_sprite = @sprite.Sprite::from_text(start_text, 1, layer=@sprite.RenderLayer::ui())
  @sprite.sprites.set(start_button_entity, start_sprite)
  @ui.uis.set(start_button_entity, @ui.Ui::new())
  let start_button_component = Button::{
    area: @math.Rect::{ 
      position: @math.Vec2D(300.0, 275.0), 
      size: @math.Vec2D(200.0, 50.0) 
    },
    on_click_state: UIState::InGame,
  }
  buttons.set(start_button_entity, start_button_component)
  ui_entities.val.push(start_button_entity)
  
  let settings_button_entity = @system.Entity::new()
  @position.positions.set(settings_button_entity, @math.Vec2D(400.0, 350.0))
  let settings_text = @sprite.Text::new("[Settings]", font="32px Arial")
  let settings_sprite = @sprite.Sprite::from_text(settings_text, 1, layer=@sprite.RenderLayer::ui())
  @sprite.sprites.set(settings_button_entity, settings_sprite)
  @ui.uis.set(settings_button_entity, @ui.Ui::new())
  let settings_button_component = Button::{
    area: @math.Rect::{ 
      position: @math.Vec2D(300.0, 325.0), 
      size: @math.Vec2D(200.0, 50.0) 
    },
    on_click_state: UIState::Settings,
  }
  buttons.set(settings_button_entity, settings_button_component)
  ui_entities.val.push(settings_button_entity)
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
    on_click_state: UIState::MainMenu,
  }
  buttons.set(back_button_entity, back_button_component)
  ui_entities.val.push(back_button_entity)
}

// ---------------------------
// 3. UI 逻辑更新与状态切换
// ---------------------------

pub fn button_system(_backend: &@system.Backend) -> Unit {
  // 调试点 1: 检查鼠标点击事件是否被引擎检测到
  if @system.is_mouse_just_pressed(@system.MouseButton::Left) {
    // 如果您在浏览器控制台看到这条日志，说明Selene引擎成功检测到了您的点击动作
    println("【调试日志 1】: 鼠标左键点击事件被检测到!")

    // 调试点 2: 检查鼠标的坐标
    let mouse_pos = @system.mouse.pos
    println("【调试日志 2】: 鼠标当前坐标为 {mouse_pos})")

    // 调试点 3: 检查按钮列表（Map）是否为空
    if buttons.is_empty() {
        println("【调试日志 3 - 警告】: `buttons` 列表是空的！没有任何按钮可以检测。")
    }

    // 遍历所有已注册的按钮
    for entry in buttons.iter() {
      let button = entry.1
      
      // 调试点 4: 打印出正在检查的按钮的响应区域
      // 这样我们可以用肉眼对比鼠标坐标和按钮区域，看看是否可能重合
      println("【调试日志 4】: 正在检测按钮，其响应区域为: {button.area})")

      let rect_pos = button.area.position
      let rect_size = button.area.size
      
      let is_inside = 
        mouse_pos.0 >= rect_pos.0 && 
        mouse_pos.0 <= rect_pos.0 + rect_size.0 &&
        mouse_pos.1 >= rect_pos.1 &&
        mouse_pos.1 <= rect_pos.1 + rect_size.1
      
      // 调试点 5: 打印出碰撞检测的结果
      if is_inside {
        println("【调试日志 5 - 成功】: 点击位置在按钮内部！准备切换状态...")
        current_ui_state.val = button.on_click_state
        // 成功点击一个按钮后，就没必要再检查其他按钮了
        return
      } else {
        // 这条日志会告诉我们，程序检查了这个按钮，但判定点击位置在区域之外
        println("【调试日志 5 - 失败】: 点击位置不在此按钮区域内。")
      }
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