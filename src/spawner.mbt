const MAP_WIDTH: Double = 1280.0
const MAP_HEIGHT: Double = 720.0
// 敌人生成在屏幕外的一个缓冲距离
const SPAWN_PADDING: Double = 50.0
const UPGRADE_WAVE_INTERVAL: Int = 4
const HEAL_WAVE_INTERVAL: Int = 5
// --- 敌人生成器状态 ---
// 两波敌人之间的间隔时间（秒）
const INITIAL_SPAWN_INTERVAL: Double = 10.0 
let spawn_timer: Ref[Double] = Ref::new(INITIAL_SPAWN_INTERVAL)
let wave_count: Ref[Int] = Ref::new(0)

fn get_random_edge_position() -> @math.Vec2D {
  // 随机选择一条边：0=上, 1=下, 2=左, 3=右
  let side = global_rng.int(limit=4)
  
  let mut x = 0.0
  let mut y = 0.0

  match side {
    0 => { // 上边
      x = global_rng.double() * MAP_WIDTH
      y = -SPAWN_PADDING
    }
    1 => { // 下边
      x = global_rng.double() * MAP_WIDTH
      y = MAP_HEIGHT + SPAWN_PADDING
    }
    2 => { // 左边
      x = -SPAWN_PADDING
      y = global_rng.double() * MAP_HEIGHT
    }
    _ => { // 右边 (用 _ 来处理 side == 3 的情况)
      x = MAP_WIDTH + SPAWN_PADDING
      y = global_rng.double() * MAP_HEIGHT
    }
  }
  return @math.Vec2D(x, y)
}

pub fn endless_spawner_system(_backend: &@system.Backend) -> Unit {
  let delta_seconds = 1.0 / 60.0

  // 升级选择界面冻结刷怪计时器
  guard current_ui_state.val != UIState::UpgradeSelection else {
    return
  }

  spawn_timer.val -= delta_seconds

  if spawn_timer.val <= 0.0 {

    let should_offer_upgrade = wave_count.val > 0 && (wave_count.val % UPGRADE_WAVE_INTERVAL == 0)

    if should_offer_upgrade {
      // 立即触发升级
      println("【游戏】: 第 \{wave_count.val} 波时间到，触发升级选择！")
      current_ui_state.val = UIState::UpgradeSelection
    } 
    // 条件不满足
    wave_count.val += 1
    spawn_timer.val = INITIAL_SPAWN_INTERVAL 
    println("[Game] Wave \{wave_count.val} starting!")
    // 治疗逻辑
    if wave_count.val > 0 && wave_count.val % HEAL_WAVE_INTERVAL == 0 {
       heal_all_player_units()
    }

    // 刷怪逻辑 
    let num_to_spawn = 8 + wave_count.val * 1
    let enemy_pool = [
      EnemyType::Grunt, EnemyType::Grunt, EnemyType::Grunt,
      EnemyType::Archer, EnemyType::Archer,
      EnemyType::TankEnemy,
    ]
    for _i = 0; _i < num_to_spawn; _i = _i + 1 {
      let random_index = global_rng.int(limit=enemy_pool.length())
      let enemy_to_spawn = enemy_pool[random_index]
      let spawn_pos = get_random_edge_position()
      spawn_enemy(enemy_to_spawn, spawn_pos)
    }
  } // if spawn_timer.val <= 0.0 结束
}

fn heal_all_player_units() -> Unit {
  println("【游戏逻辑】: 触发全队治疗！")
  
  for unit in all_units.val {
    if unit.is_alive() && teams.get(unit) == Some(Team::Player) {
      if healths.get(unit) is Some(current_health) {
        
        if current_health.current < current_health.max {
          
          let full_health_component = {
            ..current_health, 
            current: current_health.max,
          }
          healths.set(unit, full_health_component)
          println("  - 单位 \{unit} 已恢复至满血。")
        }
      }
    }
  }
}

pub fn get_random_map_position() -> @math.Vec2D {
  // 增加一点内边距，避免生成在最边缘
  let padding = 50.0 
  
  let x = global_rng.double() * (MAP_WIDTH - padding * 2.0) + padding
  let y = global_rng.double() * (MAP_HEIGHT - padding * 2.0) + padding

  return @math.Vec2D(x, y)
}