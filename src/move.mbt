/// 用速度计算移动位置的系统
fn apply_velocity_system(_backend: &@system.Backend) -> Unit {
  for entity in @velocity.velocities.keys() {
    if @position.positions.get(entity) is Some(pos) {
      if @velocity.velocities.get(entity) is Some(vel) {
        let new_pos = pos.0 + vel.0
        @position.positions.set(entity, new_pos)
      }
    }
  }
}


///--------------------
///    敌人移动系统
///--------------------

///移动相关量:
///Speed-单位基础速度
struct MovementStats {
  speed: Double
}

/// 绑定单位与移动相关量
let movement_stats: Map[@system.Entity, MovementStats] = Map::new()

///单位防堆叠相关常数
const ENEMY_AVOIDANCE_STRENGTH: Double = 1.5

///处理敌人的所有移动逻辑：追击 + 互相避让
pub fn enemy_movement_system(_backend: &@system.Backend) -> Unit {
  let final_velocities: Map[@system.Entity, @math.Vec2D] = Map::new()
  for entity in all_units.val {
    if teams.get(entity) is Some(Team::Enemy) {
      //计算“意图方向”(追击敌人的方向)
      let mut intent_direction = @math.Vec2D::zero()
      if attack_targets.get(entity) is Some(target) {
          if @position.positions.get(entity) is Some(enemy_pos) &&
             @position.positions.get(target) is Some(target_pos) &&
             combat_stats.get(entity) is Some(combat_stats) {
            
            if enemy_pos.0.distance_to(target_pos.0) > combat_stats.attack_range {
            
                intent_direction = (target_pos.0 - enemy_pos.0).normalize()
            }
          }
      }
      //计算“避障方向”(被其他敌人推开的方向)
      let mut avoidance_direction = @math.Vec2D::zero()
      if @position.positions.get(entity) is Some(pos_a) && sizes.get(entity) is Some(size_a) {
        
        for other_enemy in all_units.val {
          //遍历找到另一个敌人
          if entity != other_enemy && 
             teams.get(other_enemy) is Some(Team::Enemy) && 
             sizes.get(other_enemy) is Some(size_b) {
            
            if @position.positions.get(other_enemy) is Some(pos_b) {
              let distance = pos_a.0.distance_to(pos_b.0)
              //碰撞距离是两个单位的半径之和
              let combined_radius = size_a.radius + size_b.radius
              
              if distance < combined_radius {
                let direction = (pos_a.0 - pos_b.0).normalize()
                //计算推挤力度(与堆叠程度成比例)
                let strength = (combined_radius - distance) / combined_radius
                let push_force = direction.scalar_mul(strength)
                avoidance_direction = avoidance_direction + push_force
              }
            }
          }
        }
      }
      //计算最终要移动的方向
      let final_direction = intent_direction + avoidance_direction.scalar_mul(ENEMY_AVOIDANCE_STRENGTH)

      let mut final_velocity = @math.Vec2D::zero()
      //叠加移速BUFF
      if get_computed_movement_stats(entity) is Some(move_stats) { 
          if final_direction.distance() > 0.001 {
            final_velocity = final_direction.normalize().scalar_mul(move_stats.speed)
          }
      }
      
      final_velocities.set(entity, final_velocity)
    }
  }

  for entity, final_vel in final_velocities {
    @velocity.velocities.set(entity, final_vel)
  }
}