// 用一个 Map 来存储拥有该组件的实体
// ---------------------------------
//  主函数 (Main Function)
// ---------------------------------
fn main {
  @system.App::new(@canvas.CanvasBackend::new())
    .with_canvas_width(800.0)
    .with_canvas_height(600.0)
    .with_fps(60)
    .add_system(init_game, schedule=@system.Schedule::Startup)
    
    //游戏运行
    .add_system(update_game_world_system, schedule=@system.Schedule::Update)
    
    .add_system(@system.advanced_key_system, schedule=@system.Schedule::Update)
    .add_system(@system.advanced_mouse_system, schedule=@system.Schedule::Update)

    .add_system(pause_toggle_system, schedule=@system.Schedule::Update)

    .add_system(update_health_bars_system, schedule=@system.Schedule::Update)

    .add_system(@sprite.render_world_system, schedule=@system.Schedule::Render(0)) // 先画世界
    .add_system(@sprite.render_ui_system, schedule=@system.Schedule::Render(1)) // 再画UI
    
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

// --- 游戏世界总管系统 ---

// 这是所有“可暂停”的游戏逻辑系统的总入口
pub fn update_game_world_system(backend: &@system.Backend) -> Unit {
  guard !is_paused.val else { return }

  // 管理玩家小火车的连接状态
  player_train_management_system(backend)
  // 玩家输入，决定火车头的移动方向
  player_control_system(backend)
  // AI输入，决定敌人的移动方向
  enemy_movement_system(backend)
  // AI索敌，决定攻击目标
  aggro_system(backend)
  // 战斗结算，根据攻击目标和冷却，触发攻击效果
  combat_system(backend)
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
  
  // 处理所有VFX的生成请求和生命周期
  vfx_spawner_system(backend)
  vfx_update_system(backend)

  // 将所有单位的`velocity`应用到它们的`position`上
  apply_velocity_system(backend)
  // 为玩家小火车记录轨迹点
  path_history_system(backend)
  // 让车厢根据轨迹点进行跟随
  train_snake_follow_system(backend)

  // 移除所有被标记为“死亡”的实体和它们的组件
  cleanup_system(backend)
}


// ---------------------------------
//  初始化 (Initialization)
// ---------------------------------
fn init_game(backend: &@system.Backend) -> Unit {
  add_map()
  setup_vfx_library()

  // 在游戏开始时播放并保存 BGM 句柄
  let handle = @audio.play_audio(
    backend,
    "../assets/sfx/inst.mp3", // BGM 文件路径
    volume=0.1,               // 背景音乐音量通常小一些
    loop_=true,               // 背景音乐需要循环播放
  )
  bgm_handle.val = Some(handle)

  spawn_timer.val = INITIAL_SPAWN_INTERVAL
  wave_count.val = 0
  let _ = add_new_orange_square(@math.Vec2D(350.0, 500.0))
  let _ = add_new_orange_triangle(@math.Vec2D(350.0, 500.0))
  let _ = add_new_orange_circle(@math.Vec2D(350.0, 500.0))
  let _ = add_new_purple_square(@math.Vec2D(350.0, 500.0))
  let _ = add_new_green_triangle(@math.Vec2D(350.0, 500.0))
  let _ = add_new_purple_circle(@math.Vec2D(350.0, 500.0))

  let _ = add_new_green_square(@math.Vec2D(350.0, 500.0))
}

fn add_map() -> Unit {
  let map_entity = @system.Entity::new()
  @position.positions.set(map_entity, @math.Vec2D(-5.0, -5.0))
  //let map_picture = @sprite.Picture::new(
  //  @math.Vec2D(1048.0, 768.0), "assets/gray_map.png")
  //let map_sprite = @sprite.Sprite::from_picture(map_picture, 0)
  //let map_color = @sprite.ColoredShape::new(@sprite.Shape::rect(1048, 768, 0), @sprite.DrawStyle::fill("#000000"))
  //let map_sprite = @sprite.Sprite::from_shape(map_color, 100, layer=@sprite.RenderLayer::game_world())

  let background_entity = @system.Entity::new()

  @position.positions.set(background_entity, @math.Vec2D::zero())

  let background_picture = @sprite.Picture::new(
    @math.Vec2D(1965, 1085),
    "assets/gfx/background_tile.png",
    repeat=@system.RepeatMode::Repeat,
  )

  let map_sprite = @sprite.Sprite::from_picture(
    background_picture, 
    -100, 
  )
  
  @sprite.sprites.set(map_entity, map_sprite)
}

