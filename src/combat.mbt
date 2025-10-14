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

  /// 治疗
  Heal(Double, Option[VFX_Type])

  /// 连锁效果
  Chain(
    Array[OnHitEffect], // 对下一个目标施加的效果列表
    Int,                // 最多能连锁的次数
    Double,             // 寻找下一个目标的范围
    Double,              // 每次连锁后，伤害的衰减系数 (例如 0.5)
    Option[VFX_Type] 
  )

  /// 一次性对多攻击
  Fork(
    Array[OnHitEffect],      // 对额外目标施加的效果
    Int,           // 最多寻找多少个额外目标
    Double,                    // 在多大范围内寻找
    Option[VFX_Type]        // 从【攻击者】到【额外目标】的光束特效
  )

  GainChargeShield(Int) // 获得一个有 N 次抵挡次数的护盾

  SpawnPickup(PickupType, PickupData)// 生成可拾取物
}
fn combat_system(backend: &@system.Backend) -> Unit {
  let delta_seconds = 1.0 / 60.0

  // 攻击冷却循环
  for unit in combat_stats.keys() {
    if combat_stats.get(unit) is Some(stats) {
      if stats.current_cooldown > 0.0 {
        
        // 计算当前单位的冷却速度乘数
        let mut current_cooldown_multiplier = 1.0
        if active_buffs.get(unit) is Some(buff_list) {
          for buff in buff_list {
            if buff.buff_type is MultiplyCooldown(factor) {
              current_cooldown_multiplier *= factor
            }
          }
        }
        
        // 根据乘数，加快冷却倒数速度
        let new_cooldown = stats.current_cooldown - (delta_seconds / current_cooldown_multiplier)
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
            if combat_stats.get(attacker) is Some(base_stats) {
              combat_stats.set(attacker, { ..base_stats, current_cooldown: attacker_stats.attack_cooldown })
            }

            
            //添加攻击动画
            if attacker_stats.attack_cast_vfx is Some(vfx) {
              vfx_requests.val.push({
                vfx_type: vfx,
                position: attacker_pos.0, // 特效在攻击者身上产生
                rotation: 0.0,
                parent_entity: None,
                to_position: None,
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
                if attacker_stats.attack_cast_vfx is Some(vfx) {
                  vfx_requests.val.push({
                    vfx_type: vfx,
                    position: attacker_pos.0,
                    to_position: Some(target_pos.0),
                    rotation: 0.0,
                    parent_entity: None,
                  })
                }
                apply_all_effects(attacker, target, attacker_stats.on_hit_effects)
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
        sfx_requests.val.push({sfx_type: Dead, position: None})
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
      
      let mut target_is_valid = true
      if attack_targets.get(unit_a) is Some(current_target) {
        //目标是否还活着
        if !current_target.is_alive() {
          target_is_valid = false
        } else if combat_stats.get(unit_a) is Some(stats) &&
                  @position.positions.get(unit_a) is Some(pos_a) &&
                  @position.positions.get(current_target) is Some(pos_target) {
          //目标是否还在警戒范围内
          if pos_a.0.distance_to(pos_target.0) > stats.aggro_range {
            target_is_valid = false
          }
        } else {
          //如果获取不到位置信息，也视为目标无效
          target_is_valid = false
        }
        // 如果目标无效，就清除它
        if !target_is_valid {
          let _ = attack_targets.remove(unit_a)
          println("【索敌】: 单位 \{unit_a} 的目标已失效，已清除。")
        }
      }
      if attack_targets.get(unit_a) is None {
        // (这部分寻找最近目标的逻辑，玩家和敌人是共通的，我们可以合并)
        let mut closest_target = None
        let mut min_distance = 99999.0

        if @position.positions.get(unit_a) is Some(pos_a) {
          for unit_b in all_units.val {
            if unit_b.is_alive() && teams.get(unit_b) is Some(team_b) {
              // 寻找不同阵营的目标
              if team_a != team_b {
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
        }
        
        // 如果找到了新目标，就设置它
        if closest_target is Some(target) {
          attack_targets.set(unit_a, target)
          println("【索敌】: 单位 \{unit_a} 锁定了新目标 \{target}")
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
              parent_entity: None,
              to_position: None,
            })
          }
        }
      }

      ApplyBuff(buff_type, duration, vfx_opt) => {
        if buff_type is MultiplyCooldown(_) {
          // 如果目标是冷却辅助的单位，则直接跳过，不施加此Buff
          if cooldown_ability_units.get(target) is Some(_) {
              println("【技能豁免】: 单位 \{target} 是一个冷却技能单位，豁免了冷却缩减Buff。")
              continue
          }
        }
        // 调用我们现有的 Buff 添加函数
        add_buff(target, buff_type, duration)
        if vfx_opt is Some(vfx_type) {
          if @position.positions.get(target) is Some(target_pos) {
            vfx_requests.val.push({
              vfx_type: vfx_type,
              position: target_pos.0,
              rotation: 0.0,
              parent_entity: Some(target),
              to_position: None,
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
              parent_entity: None,
              to_position: None,
            })
          }
          apply_effects_in_area(source, target_pos.0, radius, effects_in_area, source_team)
        }
      }

      Knockback(strength) => {
        apply_knockback(source, target, strength)
      }
      Heal(amount, vfx_opt) => {
        if teams.get(source) == teams.get(target) {
          apply_heal(target, amount)
        }
        if vfx_opt is Some(vfx_type) {
            if @position.positions.get(target) is Some(target_pos) {
              vfx_requests.val.push({
                vfx_type: vfx_type,
                position: target_pos.0,
                rotation: 0.0,
                parent_entity: Some(target),
                to_position: None,
              })
            }
          }
      }
      Chain(next_effects, max_jumps, jump_range, falloff, beam_vfx) => {
        let initial_hit_list = [source, target]
        execute_chain_recursive(
          source,
          target, // 第一次跳跃的起点
          next_effects,
          max_jumps,
          jump_range,
          falloff,
          beam_vfx,
          initial_hit_list,
        )
      }
      Fork(fork_effects, max_extra_targets, range, beam_vfx) => {
        execute_fork(
          source,
          target,
          fork_effects,
          max_extra_targets,
          range,
          beam_vfx,
        )
      }
      GainChargeShield(charges_to_add) => {
        if team_charge_shield.val is Some(shield) {
          // 如果已有护盾，则增加次数
          shield.charges += charges_to_add
        } else {
          // 如果没有，则创建一个新的
          team_charge_shield.val = Some(ChargeShield::{ charges: charges_to_add })
        }
        println("【护盾】: 获得了 \{charges_to_add} 次护盾，当前总次数: \{team_charge_shield.val.unwrap().charges}")
      }

       SpawnPickup(pickup_type, data) => {
        // 获取一个随机的地图位置
        let spawn_pos = get_random_map_position() // 我们需要创建这个辅助函数

        // 创建一个拾取物生成请求
        pickup_requests.val.push({
          pickup_type,
          position: spawn_pos,
          data,
        })
        
        println("【技能效果】: 已请求在 \{spawn_pos} 生成一个 \{pickup_type}。")
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
  
  //如果是玩家则触发次数盾计算机制
  if teams.get(target) == Some(Team::Player) {
    if team_charge_shield.val is Some(shield) && shield.charges > 0 {
      // 护盾存在且有次数
      shield.charges -= 1
      println("【护盾】: 抵挡了一次伤害，剩余次数: \{shield.charges}")

      // TODO: 在这里可以触发一个护盾抵挡的音效和视觉特效
      // sfx_requests.val.push(...)
      // vfx_requests.val.push(...)

      if shield.charges <= 0 {
        // 如果次数用完了，就移除护盾
        team_charge_shield.val = None
        println("【护盾】: 护盾已破碎！")
      }
      return //跳过伤害计算
    }
  }

  if healths.get(target) is Some(health) {
    let mut final_damage = base_damage
    if combat_stats.get(attacker) is Some(stats) {
      let roll = global_rng.double()
      if roll < stats.crit_rate {
        final_damage = base_damage * 2.0
        println("[Log] Critical Hit!")
      }
    }
    //受击闪白
    vfx_requests.val.push({
      vfx_type: VFX_Type::HitFlash,
      position: @math.Vec2D::zero(),
      rotation: 0.0,
      parent_entity: Some(target),
      to_position: None,
    })

    if @position.positions.get(target) is Some(target_pos) {
      sfx_requests.val.push({
        sfx_type: SFX_Type::EnemyHit,
        position: Some(target_pos.0),
      })
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
      parent_entity: None,
      to_position: None,
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

fn apply_heal(target: @system.Entity, amount: Double) -> Unit {
  if healths.get(target) is Some(health) {
    let new_current_hp = min_double(health.max, health.current + amount)
    healths.set(target, { ..health, current: new_current_hp })
  }
}
fn execute_chain_recursive(
  source: @system.Entity,
  current_target: @system.Entity,
  effects: Array[OnHitEffect],
  jumps_left: Int,
  jump_range: Double,
  damage_falloff: Double,
  beam_vfx: Option[VFX_Type],
  already_hit: Array[@system.Entity],
) -> Unit {
  if jumps_left <= 0 {
    return
  }

  let mut next_target_opt: Option[@system.Entity] = None
  let mut min_distance = jump_range

  if @position.positions.get(current_target) is Some(current_pos) {
    for unit in all_units.val {
      if teams.get(unit) == Some(Team::Enemy) && !already_hit.contains(unit) {
        if @position.positions.get(unit) is Some(next_pos) {
          let distance = current_pos.0.distance_to(next_pos.0)
          if distance < min_distance {
            min_distance = distance
            next_target_opt = Some(unit)
          }
        }
      }
    }
  }

  if next_target_opt is Some(actual_next_target) {
    already_hit.push(actual_next_target)

    if beam_vfx is Some(vfx_type) {
      if @position.positions.get(current_target) is Some(from_pos) &&
         @position.positions.get(actual_next_target) is Some(to_pos) {
        
        vfx_requests.val.push({
          vfx_type: vfx_type,
          position: from_pos.0,
          to_position: Some(to_pos.0),
          rotation: 0.0,
          parent_entity: None,
        })
      }
    }
    
    let fallen_off_effects = effects.map(fn(eff) {
      match eff {
        DealDamage(dmg, vfx) => OnHitEffect::DealDamage(dmg * damage_falloff, vfx)
        _ => eff
      }
    })
    apply_all_effects(source, actual_next_target, fallen_off_effects)
    execute_chain_recursive(
      source,
      actual_next_target,
      fallen_off_effects,
      jumps_left - 1,
      jump_range,
      damage_falloff,
      beam_vfx,
      already_hit,
    )
  }
}
fn execute_fork(
  source: @system.Entity,
  primary_target: @system.Entity,
  effects: Array[OnHitEffect],
  max_extra_targets: Int,
  range: Double,
  beam_vfx: Option[VFX_Type],
) -> Unit {
  let mut extra_targets_found = 0
  let already_hit = [source, primary_target] 

  if @position.positions.get(source) is Some(source_pos) {
    for unit in all_units.val {
      if extra_targets_found >= max_extra_targets {
        break 
      }
      
      if teams.get(unit) == Some(Team::Enemy) && !already_hit.contains(unit) {
        if @position.positions.get(unit) is Some(unit_pos) {
          
          if source_pos.0.distance_to(unit_pos.0) < range {
            extra_targets_found += 1
            already_hit.push(unit)

            if beam_vfx is Some(vfx_type) {
              vfx_requests.val.push({
                vfx_type,
                position: source_pos.0,
                to_position: Some(unit_pos.0),
                rotation: 0.0,
                parent_entity: None,
              })
            }

            apply_all_effects(source, unit, effects)
          }
        }
      }
    }
  }
}