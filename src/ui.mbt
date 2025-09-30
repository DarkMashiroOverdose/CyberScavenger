// ---------------------------
// 1. 状态与组件定义
// ---------------------------
pub enum UIState {
  MainMenu
  InGame
  SquadBuilder
  Settings
} derive(Eq)

let current_ui_state: Ref[UIState] = Ref::new(UIState::MainMenu)
let prev_ui_state: Ref[UIState] = Ref::new(UIState::MainMenu)
let ui_entities: Ref[Array[@system.Entity]] = Ref::new([])
let current_synergy_filter: Ref[Option[SynergyTag]] = Ref::new(Some(SynergyTag::Orange))
let current_shape_filter: Ref[Option[UnitShape]] = Ref::new(None)

let selected_unit_for_detail_view: Ref[Option[UnitType]] = Ref::new(None)

let hovered_unit_for_detail_view: Ref[Option[UnitType]] = Ref::new(None)

// 新增 #2: 专门用来存放“详情面板”UI实体的列表
let detail_panel_entities: Ref[Array[@system.Entity]] = Ref::new([])
let squad_builder_grid_entities: Ref[Array[@system.Entity]] = Ref::new([])
pub enum ButtonAction {
  SwitchState(UIState)
  SelectUnit(UnitType)
  DeselectUnit(Int)
  SetSynergyFilter(Option[SynergyTag]) // 设置颜色筛选
  SetShapeFilter(Option[UnitShape])   // 设置形状筛选
}

pub struct Button {
  area: @math.Rect
  action: ButtonAction
  normal_appearance: ButtonAppearance
  hover_appearance: ButtonAppearance
  mut is_hovered: Bool
}
pub enum ButtonAppearance {
  FromPicture(String,@math.Vec2D)
  FromAnimation(@sprite.Animation)
  FromText(@sprite.Text)
  FromShape(@sprite.ColoredShape, @math.Vec2D)
}
pub let buttons : Map[@system.Entity, Button] = Map::new()

// ---------------------------
// 2. UI 元素创建与销毁
// ---------------------------


fn cleanup_ui() -> Unit {
  println("【调试日志 A】: 检测到状态切换，开始清理旧的UI...")
  
  //清理静态UI
  for entity in ui_entities.val {
    if @sprite.sprites.get(entity) is Some(_) { let _ = @sprite.sprites.remove(entity) }
    @system.Entity::destroy(entity)
  }
  
  //清理动态生成的“已选单位肖像”
  for entity in selected_squad_display_entities.val {
    if @sprite.sprites.get(entity) is Some(_) { let _ = @sprite.sprites.remove(entity) }
    @system.Entity::destroy(entity)
  }

  //清理动态生成的“单位选择网格”
  for entity in squad_builder_grid_entities.val {
    if @sprite.sprites.get(entity) is Some(_) { let _ = @sprite.sprites.remove(entity) }
    @system.Entity::destroy(entity)
  }

  //关键修正：同时清理动态生成的“详情面板”
  for entity in detail_panel_entities.val {
    if @sprite.sprites.get(entity) is Some(_) { let _ = @sprite.sprites.remove(entity) }
    @system.Entity::destroy(entity)
  }
  
  //清空所有追踪列表
  ui_entities.val = []
  selected_squad_display_entities.val = []
  squad_builder_grid_entities.val = []
  detail_panel_entities.val = []
  buttons.clear()
  
  //重置所有筛选和查看状态
  current_synergy_filter.val = Some(SynergyTag::Orange)
  current_shape_filter.val = None
  selected_unit_for_detail_view.val = None

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
  let start_sprite = @sprite.Sprite::from_picture(start_normal_pic, 1, layer=@sprite.RenderLayer::ui(), offset = @math.Vec2D(-110.0, -30.0))
  @sprite.sprites.set(start_button_entity, start_sprite)
  @ui.uis.set(start_button_entity, @ui.Ui::new())
  
  //关键修正：使用新的 Button 结构和 ButtonAppearance 枚举
  let start_button_component = Button::{
    area: @math.Rect::{ 
      position: @math.Vec2D(230.0, 400.0), 
      size: @math.Vec2D(220.0, 60.0)
    },
    action: ButtonAction::SwitchState(UIState::SquadBuilder),
    normal_appearance: ButtonAppearance::FromPicture(
      "assets/gui/start_menu/start.png", 
      @math.Vec2D(220.0, 60.0),
    ),
    hover_appearance: ButtonAppearance::FromPicture(
      "assets/gui/start_menu/start_light.png",
      @math.Vec2D(220.0, 60.0),
    ),
    is_hovered: false, 
  }
  buttons.set(start_button_entity, start_button_component)
  ui_entities.val.push(start_button_entity)
  
  let archive_button_entity = @system.Entity::new()
  @position.positions.set(archive_button_entity, @math.Vec2D(180.0, 470.0))
  //let settings_text = @sprite.Text::new("[Settings]", font="32px Arial")
  //let settings_sprite = @sprite.Sprite::from_text(settings_text, 1, layer=@sprite.RenderLayer::ui())
  let archive_normal_pic = @sprite.Picture::new(@math.Vec2D(110.0, 60.0), "assets/gui/start_menu/archive.png")
  let archive_sprite = @sprite.Sprite::from_picture(archive_normal_pic, 1, layer=@sprite.RenderLayer::ui(), offset = @math.Vec2D(-60.0, -30.0))
  @sprite.sprites.set(archive_button_entity, archive_sprite)
  @ui.uis.set(archive_button_entity, @ui.Ui::new())
  let archive_button_component = Button::{
    area: @math.Rect::{ 
      position: @math.Vec2D(180.0, 470.0), 
      size: @math.Vec2D(110.0, 60.0) 
    },
    normal_appearance: ButtonAppearance::FromPicture(
      "assets/gui/start_menu/archive.png", 
      @math.Vec2D(110.0, 60.0),
    ),
    hover_appearance: ButtonAppearance::FromPicture(
      "assets/gui/start_menu/archive_light.png",
      @math.Vec2D(110.0, 60.0),
    ),
    is_hovered: false, 
    action: ButtonAction::SwitchState(UIState::Settings),
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
    normal_appearance: ButtonAppearance::FromPicture(
      "assets/gui/start_menu/settings.png", 
      @math.Vec2D(110.0, 60.0),
    ),
    hover_appearance: ButtonAppearance::FromPicture(
      "assets/gui/start_menu/settings_light.png",
      @math.Vec2D(110.0, 60.0),
    ),
    is_hovered: false, 
    action: ButtonAction::SwitchState(UIState::Settings),
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
    normal_appearance: ButtonAppearance::FromPicture(
      "assets/gui/start_menu/about.png", 
      @math.Vec2D(110.0, 60.0),
    ),
    hover_appearance: ButtonAppearance::FromPicture(
      "assets/gui/start_menu/about_light.png",
      @math.Vec2D(110.0, 60.0),
    ),
    is_hovered: false, 
    action: ButtonAction::SwitchState(UIState::Settings),
  }
  buttons.set(about_button_entity, about_button_component)
  ui_entities.val.push(about_button_entity)


}

fn setup_ingame_hud() -> Unit {
  println("【调试日志 E】: 正在创建【游戏内HUD】...")
  // --- 分数显示 ---
  let score_label = @system.Entity::new()
  @position.positions.set(score_label, @math.Vec2D(100.0, 50.0))
  let score_text = @sprite.Text::new("Score: 0", font="24px mplus_hzk")
  let score_sprite = @sprite.Sprite::from_text(score_text, 1, layer=@sprite.RenderLayer::ui())
  @sprite.sprites.set(score_label, score_sprite)
  @ui.uis.set(score_label, @ui.Ui::new())
  ui_entities.val.push(score_label)
}

fn setup_settings_ui() -> Unit {

  let back_button_entity = @system.Entity::new()
  @position.positions.set(back_button_entity, @math.Vec2D(400.0, 450.0))
  let back_text = @sprite.Text::new("[Back to Main Menu]", font="32px mplus_hzk")
  let back_sprite = @sprite.Sprite::from_text(back_text, 1, layer=@sprite.RenderLayer::ui())
  @sprite.sprites.set(back_button_entity, back_sprite)
  @ui.uis.set(back_button_entity, @ui.Ui::new())
  let back_button_component = Button::{
    area: @math.Rect::{ 
      position: @math.Vec2D(250.0, 425.0), 
      size: @math.Vec2D(300.0, 50.0) 
    },
    normal_appearance: ButtonAppearance::FromPicture(
      "assets/gui/start_menu/about.png", 
      @math.Vec2D(110.0, 60.0),
    ),
    hover_appearance: ButtonAppearance::FromPicture(
      "assets/gui/start_menu/about_light.png",
      @math.Vec2D(110.0, 60.0),
    ),
    is_hovered: false, 
    action: ButtonAction::SwitchState(UIState::MainMenu)
  }
  buttons.set(back_button_entity, back_button_component)
  ui_entities.val.push(back_button_entity)
}

fn setup_squad_builder_ui() -> Unit {
  let squad_background = @system.Entity::new()
  @position.positions.set(squad_background, @math.Vec2D(0.0, 0.0))
  let squad_background_pic = @sprite.Picture::new(@math.Vec2D(1280.0, 720.0), "assets/gui/squad/squad_background.png")
  let squad_background_sprite = @sprite.Sprite::from_picture(squad_background_pic, 1, layer=@sprite.RenderLayer::ui())
  @sprite.sprites.set(squad_background, squad_background_sprite)
  @ui.uis.set(squad_background, @ui.Ui::new())
  ui_entities.val.push(squad_background)

  let title = @system.Entity::new()
  @position.positions.set(title, @math.Vec2D(955.0, 20.0))
  let title_pic = @sprite.Picture::new(@math.Vec2D(400.0, 80.0), "assets/gui/squad/squad_title.png")
  let title_sprite = @sprite.Sprite::from_picture(title_pic, 1, layer=@sprite.RenderLayer::ui())
  @sprite.sprites.set(title, title_sprite)
  @ui.uis.set(title, @ui.Ui::new())
  ui_entities.val.push(title)
  
  let confirm_entity = @system.Entity::new()
  @position.positions.set(confirm_entity, @math.Vec2D(300.0, 450.0))
  let confirm_text = @sprite.Text::new("[确认队伍并开始]", font="32px mplus_hzk")
  let confirm_sprite = @sprite.Sprite::from_text(confirm_text, 1, layer=@sprite.RenderLayer::ui())
  @sprite.sprites.set(confirm_entity, confirm_sprite)
  @ui.uis.set(confirm_entity, @ui.Ui::new())
  let confirm_button_comp = Button::{
      area: @math.Rect::{ position: @math.Vec2D(300.0, 450.0), size: @math.Vec2D(300.0, 50.0) },
      action: ButtonAction::SwitchState(UIState::InGame),
      normal_appearance: ButtonAppearance::FromText(confirm_text),
      hover_appearance: ButtonAppearance::FromText(confirm_text),
      is_hovered: false,
  }
  buttons.set(confirm_entity, confirm_button_comp)
  ui_entities.val.push(confirm_entity)

  setup_filter_tabs()

}

fn setup_filter_tabs() -> Unit {
  // --- 创建颜色筛选标签 ---
  let synergy_tags_to_show = [
    (SynergyTag::Orange, "assets/gui/squad/tabs/orange_normal.png", "assets/gui/squad/tabs/orange_light.png"), 
    (SynergyTag::Purple, "assets/gui/squad/tabs/purple_normal.png", "assets/gui/squad/tabs/purple_light.png"), 
    (SynergyTag::Green,  "assets/gui/squad/tabs/green_normal.png",  "assets/gui/squad/tabs/green_light.png"), 
    (SynergyTag::Blue,   "assets/gui/squad/tabs/blue_normal.png",   "assets/gui/squad/tabs/blue_light.png")
  ]
  let button_size = @math.Vec2D(150.0, 60.0)
  
  for i in 0 ..< synergy_tags_to_show.length() {
    let (tag, normal_path, hover_path) = synergy_tags_to_show[i]
    
    let pos = @math.Vec2D(150 - i.to_double() * 2, 70.0 + i.to_double() * 55.0)
    
    let entity = @system.Entity::new()
    @position.positions.set(entity, pos)
    
    let initial_path = if current_synergy_filter.val == Some(tag) {
      hover_path
    } else {
      normal_path
    }
    let picture = @sprite.Picture::new(button_size, initial_path)
    let offset = @math.Vec2D(-button_size.0 / 2.0, -button_size.1 / 2.0)
    let sprite = @sprite.Sprite::from_picture(picture, 1, layer=@sprite.RenderLayer::ui(), offset=offset)
    @sprite.sprites.set(entity, sprite)
    @ui.uis.set(entity, @ui.Ui::new())
    
    let button_comp = Button::{
      area: @math.Rect::{ position: pos, size: button_size },
      action: ButtonAction::SetSynergyFilter(Some(tag)),
      
      normal_appearance: ButtonAppearance::FromPicture(
        normal_path,
        button_size,
      ),
      hover_appearance: ButtonAppearance::FromPicture(
        hover_path,
        button_size,
      ),
      is_hovered: false,
    }
    buttons.set(entity, button_comp)
    ui_entities.val.push(entity)
  }
}
// ---------------------------
// 3. UI 逻辑更新与状态切换
// ---------------------------
fn update_squad_builder_grid() -> Unit {
  //清理上一帧的旧网格
  for entity in squad_builder_grid_entities.val {
    if buttons.get(entity) is Some(_) { let _ = buttons.remove(entity) }
    if @sprite.sprites.get(entity) is Some(_) { let _ = @sprite.sprites.remove(entity) }
    @system.Entity::destroy(entity)
  }
  squad_builder_grid_entities.val = []

  //根据筛选条件，过滤出要显示的单位
  let filtered_units = Array::new()
  for entry in unit_definitions.iter() {
    let (unit_type, def) = entry
    let synergy_match = match current_synergy_filter.val {
      None => true
      Some(filter) => def.color_tag == filter
    }
    let shape_match = match current_shape_filter.val {
      None => true
      Some(filter) => def.shape_tag == filter
    }
    if synergy_match && shape_match {
      filtered_units.push((unit_type, def))
    }
  }

  //循环创建被筛选出来的单位
  let start_x = 400.0
  let start_y = 90.0
  let spacing_x = 230.0
  let spacing_y = 120.0
  let per_row = 4
  for i in 0 ..< filtered_units.length() {
    let (unit_type, def) = filtered_units[i]
    let row = (i / per_row).to_double()
    let col = (i % per_row).to_double()
    let pos = @math.Vec2D(start_x + col * spacing_x, start_y + row * spacing_y)
    
    let entity = @system.Entity::new()
    @position.positions.set(entity, pos)
    
    let (base_shape, offset, _) = match def.shape_tag {
      UnitShape::Square =>   (@sprite.Shape::rect(50.0, 50.0, 0.0), @math.Vec2D(-25, -25), 0.0)
      UnitShape::Triangle => (@sprite.Shape::triangle(55.0, 0.0), @math.Vec2D(0.0, 0.0), 18.0)
      UnitShape::Circle =>   (@sprite.Shape::circle(25.0), @math.Vec2D(0.0, 0.0), 0.0)
    }
    let color_str = gdd_color_palette.get(def.color_tag).unwrap_or("#FFFFFF")
    let colored_shape = @sprite.ColoredShape::new(base_shape, @sprite.DrawStyle::fill(color_str))
    let sprite = @sprite.Sprite::from_shape(colored_shape, 1, layer=@sprite.RenderLayer::ui(), offset=offset)
    @sprite.sprites.set(entity, sprite)
    @ui.uis.set(entity, @ui.Ui::new())
    
    let button_comp = Button::{
      area: @math.Rect::{ position: pos, size: @math.Vec2D(125.0, 125.0) },
      action: ButtonAction::SelectUnit(unit_type),
      normal_appearance: ButtonAppearance::FromShape(colored_shape,offset),
      hover_appearance: ButtonAppearance::FromShape(colored_shape,offset),
      is_hovered: false,
    }
    buttons.set(entity, button_comp)
    //关键：将动态生成的实体加入专门的列表
    squad_builder_grid_entities.val.push(entity)
  }
}
fn update_detail_panel() -> Unit {
  //先清理掉上一帧的旧详情
  for entity in detail_panel_entities.val {
    //检查并移除它在 buttons map 中的条目
    if buttons.get(entity) is Some(_) {
      let _ = buttons.remove(entity)
    }
    //移除 sprite 组件
    if @sprite.sprites.get(entity) is Some(_) { 
      let _ = @sprite.sprites.remove(entity) 
    }
    //销毁实体
    @system.Entity::destroy(entity)
  }
  detail_panel_entities.val = []

  //检查是否有单位被选中查看详情
  match hovered_unit_for_detail_view .val {
    None => {
      //如果没有单位被选中，显示默认的占位符文本
      let placeholder = @system.Entity::new()
      @position.positions.set(placeholder, @math.Vec2D(370.0, 630.0))
      let text = @sprite.Text::new("（鼠标悬浮在上方单位，可在此处查看详情）", font="18px mplus_hzk")
      let sprite = @sprite.Sprite::from_text(text, 1, layer=@sprite.RenderLayer::ui())
      @sprite.sprites.set(placeholder, sprite)
      @ui.uis.set(placeholder, @ui.Ui::new())
      detail_panel_entities.val.push(placeholder)
    }
    Some(unit_type) => {
      //如果有单位被选中，就显示它的详细信息
      let def = unit_definitions.get(unit_type).unwrap()
      
      //显示单位名称
      let name_entity = @system.Entity::new()
      @position.positions.set(name_entity, @math.Vec2D(370.0, 565.0))
      let name_text = @system.TextLayout::new(def.name, font="italic bold 24px mplus_hzk", max_width=Some(480.0), align=@system.TextAlign::center(), )
      let name_sprite = @sprite.Sprite::from_text_layout(name_text, 5, layer=@sprite.RenderLayer::ui())
      @sprite.sprites.set(name_entity, name_sprite)
      @ui.uis.set(name_entity, @ui.Ui::new())
      detail_panel_entities.val.push(name_entity)

      //显示单位生命值      
      let desc_hp_pic = @system.Entity::new()
      @position.positions.set(desc_hp_pic, @math.Vec2D(380.0, 580.0))
      let desc_health_text = @sprite.Picture::new(@math.Vec2D(26.0, 26.0), "assets/gui/squad/desc/desc_hp.png")
      let desc_hp_pic_sprite = @sprite.Sprite::from_picture(desc_health_text, 5, layer=@sprite.RenderLayer::ui())
      @sprite.sprites.set(desc_hp_pic, desc_hp_pic_sprite)
      @ui.uis.set(desc_hp_pic, @ui.Ui::new())
      detail_panel_entities.val.push(desc_hp_pic) 

      let desc_hp = @system.Entity::new()
      @position.positions.set(desc_hp, @math.Vec2D(410.0, 600.0))
      let desc_hp_text = @system.TextLayout::new("HP: \{def.hp}", max_width=Some(480.0),line_height=20.0, font="italic bold 20px mplus_hzk")
      let desc_hp_sprite = @sprite.Sprite::from_text_layout(desc_hp_text, 5, layer=@sprite.RenderLayer::ui())
      @sprite.sprites.set(desc_hp, desc_hp_sprite)
      @ui.uis.set(desc_hp, @ui.Ui::new())
      detail_panel_entities.val.push(desc_hp) 
      
      //显示单位攻击力   
      let desc_atk_pic = @system.Entity::new()
      @position.positions.set(desc_atk_pic, @math.Vec2D(730.0, 575.0))
      let desc_health_text = @sprite.Picture::new(@math.Vec2D(26.0, 40.0), "assets/gui/squad/desc/desc_atk.png")
      let desc_atk_pic_sprite = @sprite.Sprite::from_picture(desc_health_text, 5, layer=@sprite.RenderLayer::ui())
      @sprite.sprites.set(desc_atk_pic, desc_atk_pic_sprite)
      @ui.uis.set(desc_atk_pic, @ui.Ui::new())
      detail_panel_entities.val.push(desc_atk_pic) 

      let desc_atk = @system.Entity::new()
      @position.positions.set(desc_atk, @math.Vec2D(760.0, 600.0))
      let desc_atk_text = @system.TextLayout::new("ATK: \{def.atk}", max_width=Some(480.0),line_height=20.0, font="italic bold 20px mplus_hzk")
      let desc_atk_sprite = @sprite.Sprite::from_text_layout(desc_atk_text, 5, layer=@sprite.RenderLayer::ui())
      @sprite.sprites.set(desc_atk, desc_atk_sprite)
      @ui.uis.set(desc_atk, @ui.Ui::new())
      detail_panel_entities.val.push(desc_atk) 

      //显示单位职位 
      let (shape_image_path, shape_name) = match def.shape_tag {
        UnitShape::Square => 
          ("assets/gui/squad/desc/desc_shape_square.png", "近战单位")
        UnitShape::Triangle => 
          ("assets/gui/squad/desc/desc_shape_triangle.png", "远程单位")
        UnitShape::Circle => 
          ("assets/gui/squad/desc/desc_shape_circle.png", "辅助单位")
      }
      let desc_shape_pic = @system.Entity::new()
      @position.positions.set(desc_shape_pic, @math.Vec2D(550.0, 580.0))
      let desc_shape_picture = @sprite.Picture::new(@math.Vec2D(26.0, 40.0), shape_image_path)
      let desc_shape_pic_sprite = @sprite.Sprite::from_picture(desc_shape_picture, 5, layer=@sprite.RenderLayer::ui())
      @sprite.sprites.set(desc_shape_pic, desc_shape_pic_sprite)
      @ui.uis.set(desc_shape_pic, @ui.Ui::new())
      detail_panel_entities.val.push(desc_shape_pic) 

      let desc_shape = @system.Entity::new()
      @position.positions.set(desc_shape, @math.Vec2D(580.0, 600.0))
      let desc_shape_text = @system.TextLayout::new(
        shape_name, 
        max_width=Some(480.0),
        line_height=20.0, 
        font="italic bold 20px mplus_hzk"
      )
      let desc_shape_sprite = @sprite.Sprite::from_text_layout(desc_shape_text, 5, layer=@sprite.RenderLayer::ui())
      @sprite.sprites.set(desc_shape, desc_shape_sprite)
      @ui.uis.set(desc_shape, @ui.Ui::new())
      detail_panel_entities.val.push(desc_shape) 
      
      //显示单位描述
      let desc_entity = @system.Entity::new()
      @position.positions.set(desc_entity, @math.Vec2D(370.0, 630.0))
      let desc_text = @system.TextLayout::new("【技能】\{def.gdd}", max_width=Some(480.0),line_height=22.0, font="italic 20px mplus_hzk")
      let desc_sprite = @sprite.Sprite::from_text_layout(desc_text, 5, layer=@sprite.RenderLayer::ui())
      @sprite.sprites.set(desc_entity, desc_sprite)
      @ui.uis.set(desc_entity, @ui.Ui::new())
      detail_panel_entities.val.push(desc_entity) 
      
    }
  }
}
fn update_selected_squad_display() -> Unit {
  //清理上一帧的旧肖像和旧的删除按钮
  for entity in selected_squad_display_entities.val {
    if buttons.get(entity) is Some(_) { 
      let _ = buttons.remove(entity)
    }
    if @sprite.sprites.get(entity) is Some(_) { 
      let _ = @sprite.sprites.remove(entity) 
    }
    @system.Entity::destroy(entity)
  }
  selected_squad_display_entities.val = []

  //创建新肖像和对应的删除按钮
  let start_x_1 = 1000.0
  let start_y_1 = 350.0
  let start_x_2 = 1150.0
  let start_y_2 = 650.0
  let spacing = 150.0
  let mut i = 0
  for unit_type in selected_squad.val {
    let def = unit_definitions.get(unit_type).unwrap()
    let i_double = i.to_double()
    let mut pos = @math.Vec2D(start_x_1 , start_y_1 + i_double * spacing)
    if i >=3 { pos = @math.Vec2D(start_x_2 , start_y_2 - (i_double-3) * spacing) }

    //创建单位肖像
    let portrait_entity = @system.Entity::new()
    @position.positions.set(portrait_entity, pos)
    
    let (base_shape, offset, _) = match def.shape_tag {
      UnitShape::Square =>   (@sprite.Shape::rect(40.0, 40.0, 0), @math.Vec2D(-20, -20), 0.0)
      UnitShape::Triangle => (@sprite.Shape::triangle(40.0, 0.0), @math.Vec2D(0.0, 0.0), 13.0)
      UnitShape::Circle =>   (@sprite.Shape::circle(20.0), @math.Vec2D(0.0, 0.0), 0.0)
    }
    let color_str = gdd_color_palette.get(def.color_tag).unwrap_or("#FFFFFF")
    let colored_shape = @sprite.ColoredShape::new(base_shape, @sprite.DrawStyle::fill(color_str))
    let sprite = @sprite.Sprite::from_shape(colored_shape, 2, layer=@sprite.RenderLayer::ui(), offset=offset)
    
    @sprite.sprites.set(portrait_entity, sprite)
    @ui.uis.set(portrait_entity, @ui.Ui::new())
    selected_squad_display_entities.val.push(portrait_entity)
    
    //为每个肖像创建一个删除按钮
    let delete_button_entity = @system.Entity::new()
    let delete_button_pos = @math.Vec2D(pos.0 + 35.0, pos.1 - 15.0)
    @position.positions.set(delete_button_entity, delete_button_pos)
    let delete_text = @sprite.Text::new("X", font="bold 20px mplus_hzk", color="pink")
    let delete_sprite = @sprite.Sprite::from_text(delete_text, 10, layer=@sprite.RenderLayer::ui())
    @sprite.sprites.set(delete_button_entity, delete_sprite)
    @ui.uis.set(delete_button_entity, @ui.Ui::new())
    let delete_button_comp = Button::{
      area: @math.Rect::{ position: delete_button_pos, size: @math.Vec2D(100.0, 100.0) },
      action: ButtonAction::DeselectUnit(i),
      normal_appearance: ButtonAppearance::FromText(delete_text),
      hover_appearance: ButtonAppearance::FromText(delete_text),
      is_hovered: false,
    }
    buttons.set(delete_button_entity, delete_button_comp)
    selected_squad_display_entities.val.push(delete_button_entity)
    
    i = i + 1
  }
}

pub fn update_ui_system(_backend: &@system.Backend) -> Unit {
  if current_ui_state.val != prev_ui_state.val {
    if prev_ui_state.val == UIState::SquadBuilder && current_ui_state.val == UIState::InGame {
        init_game_world()
    }

    cleanup_ui()
    
    match current_ui_state.val {
      UIState::MainMenu => setup_main_menu_ui()
      UIState::SquadBuilder => setup_squad_builder_ui()
      UIState::InGame => setup_ingame_hud()
      UIState::Settings => setup_settings_ui()
    }
    
    //进入组队界面时，清空上一局的队伍
    if current_ui_state.val == UIState::SquadBuilder {
        selected_squad.val = []
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

  if current_ui_state.val == UIState::SquadBuilder {
    update_squad_builder_grid()
    update_selected_squad_display()
    update_detail_panel() 
  }
}

pub fn button_system(_backend: &@system.Backend) -> Unit {
  //获取实时鼠标位置
  let mouse_pos = @system.mouse.pos
  let mut found_hovered_unit = false

  //遍历所有按钮
  for entry in buttons.iter() {
    let entity = entry.0
    let button = entry.1
    
    let rect_pos = button.area.position
    let rect_size = button.area.size
    
    //判断鼠标当在按钮内
    let is_inside = 
      mouse_pos.0 >= rect_pos.0 - (rect_size.0)/2 && 
      mouse_pos.0 <= rect_pos.0 + (rect_size.0)/2 &&
      mouse_pos.1 >= rect_pos.1 - (rect_size.1)/2 &&
      mouse_pos.1 <= rect_pos.1 + (rect_size.1)/2
    
    //只在悬停状态发生改变时，才更新Sprite
    if is_inside != button.is_hovered {
      button.is_hovered = is_inside
      
      let new_appearance_to_show = if is_inside {
        button.hover_appearance
      } else {
        button.normal_appearance
      }

      if @sprite.sprites.get(entity) is Some(current_sprite) {
          let new_sprite = match new_appearance_to_show {
            ButtonAppearance::FromPicture(path, size) => {
              let picture = @sprite.Picture::new(size, path)
              @sprite.Sprite::from_picture(
                picture,
                current_sprite.zindex,
                layer = current_sprite.layer,
                offset = current_sprite.offset,
              )
            }
            ButtonAppearance::FromAnimation(animation) => {
              @sprite.Sprite::from_animation(
                animation,
                current_sprite.zindex,
                layer = current_sprite.layer,
                offset = current_sprite.offset,
              )
            }
            ButtonAppearance::FromText(text) => {
              @sprite.Sprite::from_text(
                text,
                current_sprite.zindex,
                layer = current_sprite.layer,
                offset = current_sprite.offset,
              )
            }
            ButtonAppearance::FromShape(shape, offset) => {
              @sprite.Sprite::from_shape(
                shape,
                current_sprite.zindex,
                layer = current_sprite.layer,
                offset = offset,
              )
            }
          }
          @sprite.sprites.set(entity, new_sprite)
      }
    }
    if is_inside {
      match button.action {
        ButtonAction::SelectUnit(unit_type) => {
          hovered_unit_for_detail_view.val = Some(unit_type)
          found_hovered_unit = true
        }
        _ => {
          println("【动作】: 切换场景到 {target_state}")
        }
      }
    }
    if is_inside && @system.is_mouse_just_pressed(@system.MouseButton::Left) {
      match button.action {
        ButtonAction::SwitchState(target_state) => {
          current_ui_state.val = target_state
          println("【动作】: 切换场景到 {target_state}")
          return
        }
        ButtonAction::SelectUnit(unit_type) => {
          if selected_squad.val.length() < 6 {
            selected_squad.val.push(unit_type)
            println("【动作】: 已选择单位 \{unit_type}, 当前队伍: \{selected_squad.val}")
          } else {
            println("【动作】: 队伍已满！")
          }
          return 
        }
        ButtonAction::DeselectUnit(index) => {
          if index < selected_squad.val.length() {
             let _ = selected_squad.val.remove(index)
             println("【动作】: 已移除单位, 当前队伍: \{selected_squad.val}")
          }
          return
        }
        ButtonAction::SetSynergyFilter(synergy_tag) => {
          current_synergy_filter.val = synergy_tag
          println("【筛选】: 颜色筛选已设置为 \{synergy_tag}")
          return 
        }
        ButtonAction::SetShapeFilter(shape_tag) => {
          current_shape_filter.val = shape_tag
          println("【筛选】: 形状筛选已设置为 \{shape_tag}")
          return
        }
      }
    }
    if !found_hovered_unit {
      hovered_unit_for_detail_view.val = None
    }
  }
}
        