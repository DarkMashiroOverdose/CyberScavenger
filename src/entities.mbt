// ---------------------------------
//        实体基础管理系统
// ---------------------------------

/// 单位注册
let all_units : Ref[Array[@system.Entity]] = Ref::new([])

/// 单位的目的地
let destinations: Map[@system.Entity, @math.Vec2D] = Map::new()

/// 单位大小
pub struct Size {
  radius: Double
}
pub let sizes: Map[@system.Entity, Size] = Map::new()

///单位阵营
enum Team {
  Player
  Enemy
} derive(Eq, Show)

let teams: Map[@system.Entity, Team] = Map::new()

///---------------------------------
///         实体清理系统
///---------------------------------

/// 实体清理队列
let entities_to_cleanup: Ref[Array[@system.Entity]] = Ref::new([])

/// 实体清理系统
fn cleanup_system(_backend: &@system.Backend) -> Unit {
  if entities_to_cleanup.val.length() > 0 {
    // 1. 在清理组件前，先处理所有可能的断链逻辑
    for dead_unit in entities_to_cleanup.val {
      if teams.get(dead_unit) is Some(Team::Player) {
        relink_train_chain(dead_unit)
      }
    }

    // 2. 执行通用的、彻底的清理逻辑
    for dead_unit in entities_to_cleanup.val {
      println("[Log] Cleanup System is processing: \{dead_unit}")

      // 销毁所有视觉实体
      @system.Entity::destroy(dead_unit)
      if healths.get(dead_unit) is Some(health) {
        @system.Entity::destroy(health.bar_bg_entity)
        @system.Entity::destroy(health.bar_fg_entity)
      }

      // 从所有渲染相关的 Map 中移除组件
      @sprite.sprites.remove(dead_unit)
      if healths.get(dead_unit) is Some(health) {
        @sprite.sprites.remove(health.bar_bg_entity)
        @sprite.sprites.remove(health.bar_fg_entity)
      }

      // 从所有逻辑相关的 Map 中移除组件
      healths.remove(dead_unit)
      combat_stats.remove(dead_unit)
      teams.remove(dead_unit)
      destinations.remove(dead_unit)
      attack_targets.remove(dead_unit)
      @position.positions.remove(dead_unit)
      @velocity.velocities.remove(dead_unit)
      train_cars.remove(dead_unit) // 移除 TrainCar 组件
    }

    // 3. 更新主逻辑列表
    all_units.val = all_units.val.filter(fn(unit) {
      !entities_to_cleanup.val.contains(unit)
    })

    // 4. 清空垃圾回收列表
    entities_to_cleanup.val.clear()
  }
}