/// ------------------------
///      战斗与寻敌系统
/// ------------------------

///战斗相关定义
pub struct CombatStats {
  attack_range: Double                //攻击范围
  on_hit_effects: Array[OnHitEffect]
  attack_cooldown: Double
  current_cooldown: Double
  aggro_range: Double
  attack_type: AttackType
  aoe_radius: Double
  crit_rate: Double
  attack_cast_vfx: Option[VFX_Type]
  area_effect_vfx: Option[VFX_Type] 
  attack_sfx: Option[SFX_Type]
  bullet_color: Option[String]
}
/// Map绑定单位与战斗系统
let combat_stats: Map[@system.Entity, CombatStats] = Map::new()

/// 存储攻击对象
let attack_targets: Map[@system.Entity, @system.Entity] = Map::new()

///攻击模板
pub enum AttackType {
  Melee   // 近战
  Bullet  // 子弹攻击
  Ranged  // 长距离直接攻击
  AoE     // 近战范围伤害
} derive(Show)

pub enum OnHitEffect {
  /// 造成伤害
  DealDamage(Double, Option[VFX_Type])              // 造成 xx 点伤害

  /// 施加buff
  ApplyBuff(BuffType, Double, Option[VFX_Type])     // 施加 xx Buff，持续 yy 秒

  /// 生成区域
  CreateHazardousArea(
    Array[OnHitEffect], // 该区域每次触发时的效果
    Double,             // 区域半径
    Double, 
    Option[VFX_Type]    // 区域持续时间
  )
  
  /// 范围效果
  AreaOfEffect(
    Array[OnHitEffect], // 范围内的“效果工具箱”
    Double,             // 范围的半径
    Option[VFX_Type]    // 这个范围效果本身的视觉特效
  )

  /// 击退单位
  Knockback(Double)
}
fn combat_system(backend: &@system.Backend) -> Unit {
  let delta_seconds = 1.0 / 60.0

  // 攻击冷却循环
  for unit in combat_stats.keys() {
    if combat_stats.get(unit) is Some(stats) {
      if stats.current_cooldown > 0.0 {
        let new_cooldown = stats.current_cooldown - delta_seconds
        combat_stats.set(unit, { ..stats, current_cooldown: new_cooldown })
      }
    }
  }

  //选择攻击对象和执行攻击
  attack_targets.each(fn(attacker, target) {
    if target.is_alive() && healths.get(target) is Some(_) {
      if get_computed_stats(attacker) is Some(attacker_stats) && 
       @position.positions.get(attacker) is Some(attacker_pos) &&
       @position.positions.get(target) is Some(target_pos) {

        let distance = attacker_pos.0.distance_to(target_pos.0)
        if distance > attacker_stats.attack_range {
          destinations.set(attacker, target_pos.0)
        } else {
          destinations.remove(attacker)

          if attacker_stats.current_cooldown <= 0.0 {
            
            if attacker_stats.attack_sfx is Some(sfx) {
              sfx_requests.val.push({ 
                sfx_type: sfx, 
                position: Some(attacker_pos.0) // 传递攻击者的位置，为未来空间音效做准备
              })
            }
            // 重置冷却
            combat_stats.set(attacker, { ..attacker_stats, current_cooldown: attacker_stats.attack_cooldown })

            
            //添加攻击动画
            if attacker_stats.attack_cast_vfx is Some(vfx) {
              vfx_requests.val.push({
                vfx_type: vfx,
                position: attacker_pos.0, // 特效在攻击者身上产生
                rotation: 0.0,
              })
            }


            //根据攻击类型进行调度
            match attacker_stats.attack_type {
              AttackType::Melee => {
                execute_melee_attack(attacker, target, attacker_stats)
              }
              AttackType::Bullet => {
                execute_bullet_attack(attacker, target, attacker_stats)
              }
              AttackType::Ranged => {
                //TODO: 实现远程瞬间伤害逻辑
                execute_bullet_attack(attacker, target, attacker_stats)
                println("[Log] Ranged Attack not implemented yet.")
              }
              AttackType::AoE => {
                execute_aoe_melee_attack(attacker, attacker_stats)
                println("[Log] AoE Attack not implemented yet.")
              }
            }
          }
        }
      }
    } else {
      attack_targets.remove(attacker)
    }
  })

  // 处理死亡单位
  for unit in all_units.val {
    if unit.is_alive() {
      if healths.get(unit) is Some(health) && health.current <= 0.0 {
        // 将死亡单位加入待清理列表，交由 cleanup_system 处理。
        entities_to_cleanup.val.push(unit)
        // 将血量设为-1，防止下一帧被重复添加。
        healths.set(unit, {..health, current: -1.0})
        //杀死一个敌人计分
        if teams.get(unit) == Some(Team::Enemy) {
          if score_values.get(unit) is Some(score_comp) {
            let points_to_add = score_comp.value
            add_score(points_to_add)
            // 在敌人的位置生成一个分数特效
            if @position.positions.get(unit) is Some(pos) {
              spawn_kill_score_vfx(points_to_add, pos.0)
            }
          }
        }
      }
    }
  }
}

fn execute_aoe_melee_attack(attacker: @system.Entity, stats: CombatStats) -> Unit {
  if @position.positions.get(attacker) is Some(attacker_pos) && teams.get(attacker) is Some(attacker_team) {
    println("[Log] Executing AoE Melee Attack from \{attacker}")
    
    apply_effects_in_area(
      attacker, 
      attacker_pos.0, 
      stats.aoe_radius, 
      stats.on_hit_effects, 
      attacker_team
    )
  }
}
fn execute_melee_attack(attacker: @system.Entity, target: @system.Entity, stats: CombatStats) -> Unit {
  println("[Log] Executing Melee Attack from \{attacker} to \{target}")
  apply_all_effects(attacker, target, stats.on_hit_effects)
}


///寻敌系统
fn aggro_system(_backend: &@system.Backend) -> Unit {
  for unit_a in all_units.val {
    if unit_a.is_alive() && teams.get(unit_a) is Some(team_a) {
      
      //根据阵营执行不同的索敌逻辑
      if team_a == Team::Player {

        // --- 玩家单位的索敌逻辑 ---
        if attack_targets.get(unit_a) is None {
          let mut closest_target = None
          let mut min_distance = 99999.0

          if @position.positions.get(unit_a) is Some(pos_a) {
            for unit_b in all_units.val {
              if teams.get(unit_b) is Some(Team::Enemy) {
                if @position.positions.get(unit_b) is Some(pos_b) {
                  let distance = pos_a.0.distance_to(pos_b.0)
                  if combat_stats.get(unit_a) is Some(stats) && 
                     distance < stats.aggro_range && 
                     distance < min_distance {
                    min_distance = distance
                    closest_target = Some(unit_b)
                  }
                }
              }
            }
          }
          if closest_target is Some(target) {
            attack_targets.set(unit_a, target)
          }
        }
      } else if team_a == Team::Enemy {
        // --- 敌人单位的索敌逻辑 ---
        // 敌人只有在空闲时才会寻找新目标
        let is_idle = attack_targets.get(unit_a) is None && destinations.get(unit_a) is None
        if is_idle {
          let mut closest_target = None
          let mut min_distance = 99999.0
          if @position.positions.get(unit_a) is Some(pos_a) {
             for unit_b in all_units.val {
                if teams.get(unit_b) is Some(Team::Player) {
                  if @position.positions.get(unit_b) is Some(pos_b) {
                    let distance = pos_a.0.distance_to(pos_b.0)
                    if combat_stats.get(unit_a) is Some(stats) && 
                       distance < stats.aggro_range && 
                       distance < min_distance {
                      min_distance = distance
                      closest_target = Some(unit_b)
                    }
                  }
                }
             }
          }
          if closest_target is Some(target) {
            attack_targets.set(unit_a, target)
          }
        }
      }
    }
  }
}
///处理所有战斗效果效果
fn apply_all_effects(source: @system.Entity, target: @system.Entity, effects: Array[OnHitEffect]) -> Unit {
  for effect in effects {
    match effect {

      DealDamage(damage, vfx_opt) => {
        // 调用我们现有的伤害函数
        apply_damage(source, target, damage)
        if vfx_opt is Some(vfx_type) {
          if @position.positions.get(target) is Some(target_pos) {
            vfx_requests.val.push({
              vfx_type: vfx_type,
              position: target_pos.0,
              rotation: 0.0,
            })
          }
        }
      }

      ApplyBuff(buff_type, duration, vfx_opt) => {
        // 调用我们现有的 Buff 添加函数
        add_buff(target, buff_type, duration)
        if vfx_opt is Some(vfx_type) {
          if @position.positions.get(target) is Some(target_pos) {
            vfx_requests.val.push({
              vfx_type: vfx_type,
              position: target_pos.0,
              rotation: 0.0,
            })
          }
        }
      }

      CreateHazardousArea(tick_effects, radius, duration, vfx_opt) => {
        if @position.positions.get(target) is Some(target_pos) && teams.get(source) is Some(source_team) {
            spawn_hazardous_area(
                source, 
                target_pos.0, 
                radius, 
                duration, 
                source_team, 
                vfx_opt,
                tick_effects
            )
        }
      }

      AreaOfEffect(effects_in_area, radius, vfx) => {
        if @position.positions.get(target) is Some(target_pos) && teams.get(source) is Some(source_team) {
          if vfx is Some(vfx_type) {
            vfx_requests.val.push({
              vfx_type: vfx_type,
              position: target_pos.0,
              rotation: 0.0,
            })
          }
          apply_effects_in_area(source, target_pos.0, radius, effects_in_area, source_team)
        }
      }

      Knockback(strength) => {
        apply_knockback(source, target, strength)
      }
      // ... 未来在这里扩展 ...
    }
  }
}
fn apply_effects_in_area(
    source: @system.Entity,          // 效果的来源 (攻击者/区域制造者)
    origin_pos: @math.Vec2D,         // 效果的中心点
    radius: Double,                  // 效果的半径
    effects: Array[OnHitEffect],     // 要施加的“效果工具箱”
    source_team: Team                // 来源的阵营
) -> Unit {
  // 遍历所有单位，检查是否在范围内且为敌方
  for unit in all_units.val {
    if teams.get(unit) is Some(unit_team) && unit_team != source_team {
      if @position.positions.get(unit) is Some(unit_pos) {
        // 检查是否在伤害半径内
        if unit_pos.0.distance_to(origin_pos) <= radius {
          // 对范围内的每个敌人，应用全套效果
          apply_all_effects(source, unit, effects)
        }
      }
    }
  }
}

/// ------------------------
/// 伤害计算模块
/// ------------------------

///计算最终伤害(涉及暴击)
fn apply_damage(attacker: @system.Entity, target: @system.Entity, base_damage: Double) -> Unit {
  if healths.get(target) is Some(health) {
    let mut final_damage = base_damage
    if combat_stats.get(attacker) is Some(stats) {
      let roll = global_rng.double()
      if roll < stats.crit_rate {
        final_damage = base_damage * 2.0
        println("[Log] Critical Hit!")
      }
    }
    let new_health = { ..health, current: health.current - final_damage }
    healths.set(target, new_health)
  }
}

///击退
fn apply_knockback(source: @system.Entity, target: @system.Entity, strength: Double) -> Unit {
  if @position.positions.get(source) is Some(source_pos) &&
     @position.positions.get(target) is Some(target_pos) {
    
    //计算效果发起方的方向连线，实现击退效果
    let direction = (target_pos.0 - source_pos.0).normalize()

    @velocity.velocities.set(target, direction.scalar_mul(strength))
  }
}


/// ------------------------
///     范围效果系统
/// ------------------------

pub struct HazardousArea {
  source: @system.Entity
  source_team: Team 
  on_tick_effects: Array[OnHitEffect] 
  radius: Double
  remaining_duration: Double
  tick_timer: Double
}

pub let hazardous_areas: Map[@system.Entity, HazardousArea] = Map::new()

fn spawn_hazardous_area(
    source: @system.Entity,
    pos: @math.Vec2D, 
    radius: Double, 
    duration: Double, 
    team: Team, 
    vfx_type_opt: Option[VFX_Type],
    tick_effects: Array[OnHitEffect] 
) -> Unit {
  println("[Log Spawning] Spawning hazardous area at (\{pos[X]}, \{pos[Y]})")
  let area_entity = @system.Entity::new()
  @position.positions.set(area_entity, pos)

  if vfx_type_opt is Some(vfx_type) {
    vfx_requests.val.push({
      vfx_type: vfx_type,
      position: pos,
      rotation: 0.0,
    })
  }

  hazardous_areas.set(area_entity, {
    source: source,
    source_team: team,
    on_tick_effects: tick_effects, 
    radius: radius,
    remaining_duration: duration,
    tick_timer: 1.0, 
  })
}
pub fn hazardous_area_system(_backend: &@system.Backend) -> Unit {
  let delta_seconds = 1.0 / 60.0
  
  for area_entity in hazardous_areas.keys() {
    if hazardous_areas.get(area_entity) is Some(area_data) {
      
      let new_duration = area_data.remaining_duration - delta_seconds
      let new_tick_timer = area_data.tick_timer - delta_seconds
      
      if new_duration <= 0.0 {
        entities_to_cleanup.val.push(area_entity)
        hazardous_areas.remove(area_entity)
        continue
      }

      if new_tick_timer <= 0.0 {
        if @position.positions.get(area_entity) is Some(area_pos) {
          apply_effects_in_area(
            area_data.source,
            area_pos.0,
            area_data.radius,
            area_data.on_tick_effects, 
            area_data.source_team
          )
        }
        let final_updated_data = {
          ..area_data,
          remaining_duration: new_duration,
          tick_timer: 1.0,
        }
        hazardous_areas.set(area_entity, final_updated_data)

      } else {
        let final_updated_data = {
          ..area_data,
          remaining_duration: new_duration,
          tick_timer: new_tick_timer,
        }
        hazardous_areas.set(area_entity, final_updated_data)
      }
    }
  }
}