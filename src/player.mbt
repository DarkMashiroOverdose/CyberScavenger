/// ----------------
///   玩家相关系统 
/// ----------------

// --- 核心数据定义 ---

/// 组件：为单位附加一条历史轨迹，用于被其他单位跟随。
struct PathHistory {
  points: Array[@math.Vec2D]
}

/// 组件：将单位定义为“小火车”的一部分，通过双向链表连接。
struct TrainCar {
  prev: Option[@system.Entity] // 前一节车厢
  next: Option[@system.Entity] // 后一节车厢
}

// --- 全局状态与常量 ---

// 玩家小火车的全局状态
let player_head: Ref[Option[@system.Entity]] = Ref::new(None) // 火车头
let player_tail: Ref[Option[@system.Entity]] = Ref::new(None) // 火车尾
let player_facing_vector: Ref[@math.Vec2D] = Ref::new(@math.Vec2D(0.0, -1.0)) // 火车头的前进方向

// 小火车机制的核心数据
let path_histories: Map[@system.Entity, PathHistory] = Map::new() // 存储所有单位的轨迹
let train_cars: Map[@system.Entity, TrainCar] = Map::new()     // 存储所有车厢组件

// 玩家移动相关的常量
const PLAYER_SPEED: Double = 3.0       // 火车头的固定前进速度
const PLAYER_TURN_SPEED: Double = 4.0  // 火车头的转向速度（弧度/秒）
const TRAIN_SPACING: Double = 40.0     // 车厢之间的理想间距
const MAX_HISTORY_LENGTH: Int = 500    // 单个单位轨迹的最大记录长度

// -----------------------------------------------------------------------------
// 核心系统 (Core Systems)
// -----------------------------------------------------------------------------

/// 系统：处理玩家输入（A/D键），控制火车头的移动和朝向。
pub fn player_control_system(_backend: &@system.Backend) -> Unit {
  let delta_seconds = 1.0 / 60.0
  if player_head.val is Some(head_entity) {
    // 1. 读取转向输入
    let mut turn_input = 0.0
    if @system.is_pressed(@system.KeyA) || @system.is_pressed(@system.ArrowLeft) {
      turn_input = -1.0
    }
    if @system.is_pressed(@system.KeyD) || @system.is_pressed(@system.ArrowRight) {
      turn_input = 1.0
    }

    // 2. 根据输入更新朝向向量
    if turn_input != 0.0 {
      let turn_angle = PLAYER_TURN_SPEED * turn_input * delta_seconds
      player_facing_vector.val = rotate_vec2d(player_facing_vector.val, turn_angle)
    }

    // 3. 应用最终速度（自动前进）
    let final_velocity = player_facing_vector.val.normalize().scalar_mul(PLAYER_SPEED)
    @velocity.velocities.set(head_entity, final_velocity)
  }
}

/// 系统：为每个拥有 PathHistory 组件的单位录制其历史轨迹点。
fn path_history_system(_backend: &@system.Backend) -> Unit {
  for unit in path_histories.keys() {
    if path_histories.get(unit) is Some(history) {
      if @position.positions.get(unit) is Some(pos) {
        history.points.push(pos.0)

        // 移除过旧的轨迹点，防止内存无限增长
        if history.points.length() > MAX_HISTORY_LENGTH {
          let _ = history.points.remove(0)
        }
        path_histories.set(unit, history)
      }
    }
  }
}

/// 系统：实现贪吃蛇式的跟随，根据历史轨迹直接设置车厢位置。
pub fn train_snake_follow_system(_backend: &@system.Backend) -> Unit {
  // 1. 从火车头的下一节车厢开始遍历
  let mut current_car_opt = if player_head.val is Some(h) { train_cars.get(h)?.next } else { None }
  let mut car_index = 1

  while current_car_opt is Some(car_entity) {
    if train_cars.get(car_entity) is Some(car_data) && car_data.prev is Some(leader) {
      if path_histories.get(leader) is Some(leader_history) {
        let path = leader_history.points
        if path.length() < 1 { continue }

        // 2. 计算这节车厢与【火车头】的理想距离
        let desired_distance = car_index.to_double() * TRAIN_SPACING
        
        // 3. 沿着【火车头】的轨迹，向后回溯，通过插值找到那个精确的目标点
        let head_path = if player_head.val is Some(h) { path_histories.get(h)?.points } else { [] }
        if head_path.length() > 1 {
            let mut target_pos = head_path[head_path.length() - 1]
            let mut distance_travelled = 0.0
            for i = head_path.length() - 2; i >= 0; i = i - 1 {
                let p_new = head_path[i + 1]
                let p_old = head_path[i]
                let segment_length = p_new.distance_to(p_old)

                if (distance_travelled + segment_length) >= desired_distance {
                    let needed = desired_distance - distance_travelled
                    let ratio = if segment_length == 0.0 { 0.0 } else { needed / segment_length }
                    target_pos = vec2d_lerp(p_new, p_old, ratio)
                    break
                }
                distance_travelled += segment_length
            }
            // 4. 直接将车厢的位置“瞬移”到目标点
            @position.positions.set(car_entity, target_pos)
        }
      }
    }
    // 移动到链表的下一个节点
    car_index += 1
    current_car_opt = if train_cars.get(car_entity) is Some(car_data) { car_data.next } else { None }
  }
}

/// 系统：自动管理新加入的玩家单位，将它们连接到火车尾部。
pub fn player_train_management_system(_backend: &@system.Backend) -> Unit {
  for unit, team in teams {
    if team == Team::Player {
      let is_in_train = player_head.val == Some(unit) || train_cars.get(unit) is Some(_)
      if !is_in_train {
        _connect_player_unit_to_train(unit)
      }
    }
  }
}

// ----------------------------
// 辅助函数 (Utility Functions)
// ----------------------------

/// 辅助函数：将一个新单位连接到小火车链表的末尾。
fn _connect_player_unit_to_train(new_unit: @system.Entity) -> Unit {
  // a. 为新单位创建轨迹历史组件
  path_histories.set(new_unit, { points: [] })

  // b. 将新单位连接到双向链表上
  if player_head.val is None {
    // 如果是第一个单位，它就是火车头
    player_head.val = Some(new_unit)
    player_tail.val = Some(new_unit)
    train_cars.set(new_unit, { prev: None, next: None })
  } else {
    // 否则，连接到车尾
    let current_tail_entity = player_tail.val.unwrap()
    if train_cars.get(current_tail_entity) is Some(tail_car_comp) {
      train_cars.set(current_tail_entity, { ..tail_car_comp, next: Some(new_unit) })
    }
    train_cars.set(new_unit, { prev: Some(current_tail_entity), next: None })
    player_tail.val = Some(new_unit)
  }
}

/// 辅助函数：当车厢被摧毁时，处理断链重连的逻辑。
fn relink_train_chain(dead_unit: @system.Entity) -> Unit {
  if train_cars.get(dead_unit) is Some(dead_car_data) {
    let prev_opt = dead_car_data.prev
    let next_opt = dead_car_data.next
    
    // 情况1: 中间车厢死亡，将前后车厢连接
    if prev_opt is Some(prev_entity) && next_opt is Some(next_entity) {
      if train_cars.get(prev_entity) is Some(prev_comp) {
        train_cars.set(prev_entity, { ..prev_comp, next: Some(next_entity) })
      }
      if train_cars.get(next_entity) is Some(next_comp) {
        train_cars.set(next_entity, { ..next_comp, prev: Some(prev_entity) })
      }
    }
    
    // 情况2: 处理边界（车头或车尾）死亡
    if player_head.val == Some(dead_unit) { // 车头死亡
      player_head.val = next_opt
      if next_opt is Some(new_head) && train_cars.get(new_head) is Some(comp) {
        train_cars.set(new_head, {..comp, prev: None})
      }
    }
    if player_tail.val == Some(dead_unit) { // 车尾死亡
      player_tail.val = prev_opt
      if prev_opt is Some(new_tail) && train_cars.get(new_tail) is Some(comp) {
        train_cars.set(new_tail, {..comp, next: None})
      }
    }
  }
}