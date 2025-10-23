// 用一个 Map 来存储拥有该组件的实体
// ---------------------------------
//  主函数 (Main Function)
// ---------------------------------
fn main {
  @system.App::new(@canvas.CanvasBackend::new())
    .with_canvas_width(1280.0)
    .with_canvas_height(720.0)
    .with_fps(60)
    .add_system(init_game, schedule=@system.Schedule::Startup)    
    
    // 注册UI逻辑更新
    .add_system(button_system, schedule=@system.Schedule::Update)
    .add_system(joystick_system, schedule=@system.Schedule::Update)
    .add_system(update_ui_system, schedule=@system.Schedule::Update)
    //游戏运行
    
    .add_system(update_logic_system, schedule=@system.Schedule::Update)
    
    .add_system(@system.advanced_touch_system, schedule=@system.Schedule::Update) 
    .add_system(@system.advanced_key_system, schedule=@system.Schedule::Update)
    .add_system(@system.advanced_mouse_system, schedule=@system.Schedule::Update)
    .add_system(pause_toggle_system, schedule=@system.Schedule::Update)

    .add_system(update_health_bars_system, schedule=@system.Schedule::Update)

    .add_system(@sprite.render_world_system, schedule=@system.Schedule::Render(0)) // 先画世界
    .add_system(@sprite.render_ui_system, schedule=@system.Schedule::Render(1)) // 再画UI
    .add_system(audio_spawner_system, schedule=@system.Schedule::Update)
    .run()
}
let is_paused: Ref[Bool] = Ref::new(false)

// --- 暂停控制系统 ---

// 这个系统专门监听暂停键，并且不应该被暂停
pub fn pause_toggle_system(_backend: &@system.Backend) -> Unit {
  // 检查玩家是否“刚刚按下”了 P 键
  if @system.is_just_pressed(@system.KeyP) {
    // 对 is_paused 的值进行取反 (true -> false, false -> true)
    is_paused.val = !is_paused.val
    
    if is_paused.val {
      println("[Game] Paused")
    } else {
      println("[Game] Resumed")
    }
  }
}
// 游戏逻辑总管系统
fn update_logic_system(backend: &@system.Backend) -> Unit {
  // 检查当前的UI状态
  match current_ui_state.val {
    // 只有当我们在 InGame 状态时
    UIState::InGame => {
      // 才执行游戏世界的更新
      // 假设您有这样一个总的更新函数
      check_game_over_system(backend)
      update_game_world_system(backend) 
    }
    // 在主菜单、设置等其他任何界面，我们什么都不做，游戏世界自然就“暂停”了
    _ => ()
  }
}

// 这是所有“可暂停”的游戏逻辑系统的总入口
pub fn update_game_world_system(backend: &@system.Backend) -> Unit {
  guard !is_paused.val else { return }

  // 管理玩家小火车的连接状态
  player_train_management_system(backend)
  // 玩家输入，决定火车头的移动方向
  player_control_system(backend)
  stamina_system(backend)
  dash_touch_system(backend)
  wall_bounce_system(backend, MAP_WIDTH, MAP_HEIGHT)
  // AI输入，决定敌人的移动方向
  enemy_movement_system(backend)
  // AI索敌，决定攻击目标
  aggro_system(backend)
  // 战斗结算，根据攻击目标和冷却，触发攻击效果
  combat_system(backend)
  // 拾取系统
  pickup_system(backend)
  // 生成拾取物系统
  pickup_spawner_system(backend)
  // 拾取物生命周期
  pickup_lifecycle_system(backend)
  // 处理团队技能的触发和效果应用
  team_ability_system(backend)  
  // 更新所有飞行中的抛射物（子弹）的位置和方向
  projectile_system(backend)
  // 更新单位的视觉朝向（让Sprite朝向目标或移动方向）
  unit_orientation_system(backend)
  // 更新所有需要动态旋转/缩放的单位
  dynamic_transform_system(backend)
  // 更新所有持续伤害/效果区域
  hazardous_area_system(backend)
  // 更新所有Buff的持续时间
  buff_system(backend)
  // 根据时间生成新的敌人
  endless_spawner_system(backend)
  // 显示波次
  update_wave_display_system(backend)
  
  // 处理所有VFX的生成请求和生命周期
  vfx_spawner_system(backend)
  vfx_update_system(backend)
  vfx_movement_system(backend)
  vfx_follow_system(backend)
  // 将所有单位的`velocity`应用到它们的`position`上
  apply_velocity_system(backend)
  // 为玩家小火车记录轨迹点
  path_history_system(backend)
  // 让车厢根据轨迹点进行跟随
  train_snake_follow_system(backend)
  // 次数盾可视化
  update_shield_display_system(backend)
  // 分数可视化
  update_score_display_system(backend)
  // 体力条
  stamina_bar_update_system(backend)
  // 移除所有被标记为“死亡”的实体和它们的组件
  cleanup_system(backend)
}


// ---------------------------------
//  初始化 (Initialization)
// ---------------------------------
fn init_game(backend: &@system.Backend) -> Unit {
  add_map()
  setup_vfx_library()
  setup_sfx_library()
  setup_pickup_library()
  setup_upgrade_database()

  spawn_timer.val = INITIAL_SPAWN_INTERVAL
  wave_count.val = 0

  setup_main_menu_ui()
  is_paused.val = false
  
  //let _ = add_new_orange_square(@math.Vec2D(350.0, 500.0))
  //let _ = add_new_orange_triangle(@math.Vec2D(350.0, 500.0))
  //let _ = add_new_orange_circle(@math.Vec2D(350.0, 500.0))
  //let _ = add_new_purple_square(@math.Vec2D(350.0, 500.0))
  //let _ = add_new_green_triangle(@math.Vec2D(350.0, 500.0))
  //let _ = add_new_purple_circle(@math.Vec2D(350.0, 500.0))

  //let _ = add_new_green_square(@math.Vec2D(350.0, 500.0))
}
fn init_game_world() -> Unit {
    println("【主逻辑】: 初始化游戏世界...")
    
    // TODO: 在这里添加清理上一局游戏的代码
    // 比如 all_units.val.clear(), 清理所有敌人、子弹等
    
    println("【主逻辑】: 读取已选队伍 `selected_squad` 并生成单位...")
    println("         当前队伍是: {selected_squad.val}")

    cleanup_game_world()
    score.val = 0
    wave_count.val = 0
    spawn_timer.val = INITIAL_SPAWN_INTERVAL
    calculate_active_synergies()

    // 1. 遍历玩家在组队界面选择的单位列表 `selected_squad`
    for unit_type_to_spawn in selected_squad.val {
        let spawn_pos = @math.Vec2D(350.0, 500.0) // 暂时都生成在一个点
        spawn_player_unit_by_type(unit_type_to_spawn, spawn_pos)
    }

    // TODO: 在这里添加其他游戏开始时的逻辑
    // 比如重置分数、重置敌人生成计时器等
    println("【主逻辑】: 单位生成完毕！")
}


fn add_map() -> Unit {
  let map_entity = @system.Entity::new()
  @position.positions.set(map_entity, @math.Vec2D(-2.0, -2.0))
  //let map_picture = @sprite.Picture::new(
  //  @math.Vec2D(1048.0, 768.0), "assets/gray_map.png")
  //let map_sprite = @sprite.Sprite::from_picture(map_picture, 0)
  //let map_color = @sprite.ColoredShape::new(@sprite.Shape::rect(1048, 768, 0), @sprite.DrawStyle::fill("#000000"))
  //let map_sprite = @sprite.Sprite::from_shape(map_color, 100, layer=@sprite.RenderLayer::game_world())

  let background_entity = @system.Entity::new()

  @position.positions.set(background_entity, @math.Vec2D::zero())

  let background_picture = @sprite.Picture::new(
    @math.Vec2D(1975, 1095),
    "assets/gfx/background_tile.png",
    repeat=@system.RepeatMode::Repeat,
  )

  let map_sprite = @sprite.Sprite::from_picture(
    background_picture, 
    -100, 
  )
  
  @sprite.sprites.set(map_entity, map_sprite)
}
pub fn check_game_over_system(_backend: &@system.Backend) -> Unit {
  if current_ui_state.val != UIState::InGame {
    return
  }
  
  // 2. 统计场上还存活的玩家单位数量
  let mut living_player_units = 0
  for unit in all_units.val {
    if unit.is_alive() {
      if teams.get(unit) == Some(Team::Player) {
        living_player_units = living_player_units + 1
      }
    }
  }

  // 3. 如果存活的玩家单位为 0，就切换到“游戏结束”场景
  if living_player_units == 0 {
    println("【游戏逻辑】: 所有玩家单位已阵亡，游戏结束！")
    current_ui_state.val = UIState::GameOver
  }
}