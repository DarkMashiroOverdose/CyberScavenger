pub enum BuffType {
  AddDamage(Double)          // 增加固定数值的伤害
  MultiplyDamage(Double)       // 按百分比增加伤害 (例如 1.2 代表增加20%)
  AddCritRate(Double)          // 增加暴击率 (例如 0.1 代表增加10%)
  MultiplyEffectDuration(Double) //增加技能效果持续时间，不论是buff时长还是圈子持续时间
  MultiplyCooldown(Double)     // 乘以一个系数来改变攻击冷却 (例如 0.8 代表冷却缩短20%)
  AddAttackRange(Double)       // 增加攻击范围
  MultiplySpeed(Double) // 改变移动速度 (例如 1.5 代表速度提高50%)
} derive(Show)

// 定义一个 Buff 实例
pub struct BuffInstance {
  buff_type: BuffType
  remaining_duration: Double
}

// 创建一个全局的 Map 来存储所有单位的 Buff
pub let active_buffs: Map[@system.Entity, Array[BuffInstance]] = Map::new()

////管理buff Map，更新buff持续时长
fn buff_system(_backend: &@system.Backend) -> Unit {
  let delta_seconds = 1.0 / 60.0
  
  for unit in active_buffs.keys() {
    if active_buffs.get(unit) is Some(buff_list) {
      
      let updated_buff_list = buff_list.filter_map(fn(buff) {
        let new_duration = buff.remaining_duration - delta_seconds
        if new_duration > 0.0 {
          Some({ ..buff, remaining_duration: new_duration })
        } else {
          None
        }
      })

      if updated_buff_list.length() == 0 {
        active_buffs.remove(unit)
      } else {
        active_buffs.set(unit, updated_buff_list)
      }
    }
  }
}

///对单位施加增益
pub fn add_buff(target: @system.Entity, buff_type: BuffType, duration: Double) -> Unit {
  let new_buff = { buff_type: buff_type, remaining_duration: duration }
  
  if active_buffs.get(target) is Some(existing_buffs) {
    let new_buff_list = existing_buffs
    new_buff_list.push(new_buff)
    active_buffs.set(target, new_buff_list)
  } else {
    active_buffs.set(target, [new_buff])
  }

}
///计算增益后的战斗数值
fn get_computed_stats(unit: @system.Entity) -> Option[CombatStats] {
  if combat_stats.get(unit) is Some(base_stats) { // 1. 获取基础属性

    // 计算永久 Buff 卡牌 + 羁绊
    let unit_permanent_effects: Array[UpgradeEffect] = match permanent_buffs.get(unit) {
      Some(pb) => pb.effects 
      None => []            
    }
    let global_synergy_effects = active_synergies.val.effects
    let permanently_buffed_stats = calculate_permanently_buffed_stats(
      base_stats,
      unit_permanent_effects,
      global_synergy_effects
    ) // 这是应用了所有永久效果后的“中间属性”

    // 应用临时 Buff
    if active_buffs.get(unit) is Some(buff_list) { // 使用您原来的变量名 buff_list

      // 收集临时 Modifiers
      let mut temp_damage_multiplier = 1.0
      let mut temp_damage_addition = 0.0
      let mut temp_crit_rate_addition = 0.0
      let mut temp_attack_cooldown_multiplier = 1.0
      let mut temp_effect_duration_multiplier = 1.0
      let mut temp_attack_range_addition = 0.0 // 临时 Buff 里的攻击范围加值

      for buff in buff_list {
        match buff.buff_type {
          // 收集乘法类
          BuffType::MultiplyDamage(factor) => temp_damage_multiplier *= factor
          BuffType::MultiplyCooldown(factor) => temp_attack_cooldown_multiplier *= factor
          BuffType::MultiplyEffectDuration(factor) => temp_effect_duration_multiplier *= factor
          // 收集加法类
          BuffType::AddDamage(value) => temp_damage_addition += value
          BuffType::AddCritRate(value) => temp_crit_rate_addition += value
          BuffType::AddAttackRange(value) => temp_attack_range_addition += value // 收集临时攻击范围加值
          // 忽略 BuffType::MultiplySpeed
          _ => ()
        }
      }

      // 应用收集到的临时 Modifiers
      // 从永久 Buff 计算后的结果开始
      let mut final_stats = permanently_buffed_stats

      // 应用临时伤害修正 (递归)
      // 注意：输入是 final_stats.on_hit_effects
      let temp_damage_modified_effects = apply_damage_mods_to_effects(
        final_stats.on_hit_effects,
        temp_damage_multiplier,
        temp_damage_addition
      )

      // 应用临时持续时间修正 (递归)
      // 注意：输入是上一步的结果 temp_damage_modified_effects
      let temp_duration_modified_effects = apply_duration_mods_to_effects(
        temp_damage_modified_effects,
        temp_effect_duration_multiplier
      )
      // 更新最终效果列表
      final_stats = { ..final_stats, on_hit_effects: temp_duration_modified_effects }

      // 应用临时暴击率修正
      final_stats = { ..final_stats, crit_rate: final_stats.crit_rate + temp_crit_rate_addition }

      // 应用临时冷却修正
      final_stats = { ..final_stats, attack_cooldown: final_stats.attack_cooldown * temp_attack_cooldown_multiplier }

      // 应用临时攻击范围修正
      final_stats = { ..final_stats, attack_range: final_stats.attack_range + temp_attack_range_addition }

      return Some(final_stats) // 返回最终结果

    } else {
      // 没有临时 Buff，直接返回永久 Buff 作用后的属性
      return Some(permanently_buffed_stats)
    }

  } else {
    return None // 没有基础属性
  }
}

fn get_computed_movement_stats(unit: @system.Entity) -> Option[MovementStats] {
  if movement_stats.get(unit) is Some(base_stats) { // 获取基础属性

    // 计算永久 Buff 卡牌 + 羁绊
    let unit_permanent_effects: Array[UpgradeEffect] = match permanent_buffs.get(unit) {
      Some(pb) => pb.effects 
      None => []            
    }
    let global_synergy_effects = active_synergies.val.effects // 获取羁绊效果（虽然目前没有影响移动的）
    let permanently_buffed_stats = calculate_permanently_buffed_movement_stats(
      base_stats,
      unit_permanent_effects,
      global_synergy_effects
    ) // 这是应用了所有永久效果后的“中间属性”

    // 应用临时 Buff
    if active_buffs.get(unit) is Some(buff_list) { // 使用您原来的变量名 buff_list

      // 收集临时速度 Modifiers
      let mut temp_speed_multiplier = 1.0

      for buff in buff_list {
        match buff.buff_type {
          BuffType::MultiplySpeed(factor) => {
             temp_speed_multiplier *= factor // 收集乘法因子
             println("[Log] Unit \{unit} has MultiplySpeed buff! Factor: \{factor}")
          }
          // 如果有其他影响速度的临时 BuffType，在这里收集
          _ => ()
        }
      }

      let mut final_stats = permanently_buffed_stats

      // 应用临时速度乘数
      final_stats = { ..final_stats, speed: final_stats.speed * temp_speed_multiplier }
      println("[Log] Unit \{unit} final computed speed after temp buffs: \{final_stats.speed}")

      return Some(final_stats) // 返回最终结果

    } else {
      // 没有临时 Buff，直接返回永久 Buff 作用后的属性
      return Some(permanently_buffed_stats)
    }
  } else {
    return None // 没有基础属性
  }
}
///让减少冷却的buff无法作用于冷却辅助单位
pub struct CooldownAbilityUnit {
}
pub let cooldown_ability_units: Map[@system.Entity, CooldownAbilityUnit] = Map::new()

///羁绊buff系统
pub struct ActiveSynergies {
  effects: Array[UpgradeEffect] 
  hp_multiplier: Double
}

pub let active_synergies: Ref[ActiveSynergies] = Ref::new({ effects: [], hp_multiplier: 1.0 })
pub fn calculate_active_synergies() -> Unit {
  let counts: Map[SynergyTag, Int] = Map::new()
  for unit_type in selected_squad.val {
    if unit_definitions.get(unit_type) is Some(def) {
      let current_count = counts.get(def.color_tag).unwrap_or(0)
      counts.set(def.color_tag, current_count + 1)
    }
  }
  println("【羁绊计算】: 队伍单位统计: \{counts}")

  let calculated_effects: Array[UpgradeEffect] = []
  let mut calculated_hp_multiplier = 1.0

  for color in [SynergyTag::Orange, SynergyTag::Purple, SynergyTag::Green, SynergyTag::Blue] {
    let unit_count = counts.get(color).unwrap_or(0)
    if synergy_database.get(color) is Some(synergy_info) {

      let mut best_tier: Option[SynergyTier] = None
      for tier in synergy_info.tiers {
        if unit_count >= tier.count {
          best_tier = Some(tier)
        }
      }

      if best_tier is Some(activated_tier) {
        println("  -> 已激活 `\{synergy_info.name}` 等级: \{activated_tier.count} 个单位")
        if color == SynergyTag::Orange {
          calculated_hp_multiplier = activated_tier.bonus_value
        } else if activated_tier.effect is Some(buff_type) {
          if synergy_buff_to_upgrade_effect(buff_type) is Some(upgrade_effect) {
            calculated_effects.push(upgrade_effect)
          }
        }
      }
    }
  }

  active_synergies.val = {
    effects: calculated_effects,
    hp_multiplier: calculated_hp_multiplier,
  }
  println("【羁绊】: 最终激活的永久效果: \{active_synergies.val.effects}")
  println("【羁绊】: 最终HP乘数: \{active_synergies.val.hp_multiplier}")
}

pub struct PermanentBuffs {
  effects: Array[UpgradeEffect]
}
pub let permanent_buffs: Map[@system.Entity, PermanentBuffs] = Map::new()
fn synergy_buff_to_upgrade_effect(buff: BuffType) -> Option[UpgradeEffect] {
  match buff {
    BuffType::AddCritRate(v) => Some(UpgradeEffect::AddCritRateFlat(v)) // 紫色羁绊
    BuffType::MultiplyEffectDuration(f) => Some(UpgradeEffect::MultiplyBaseEffectDuration(f))
    BuffType::MultiplyDamage(f) => Some(UpgradeEffect::MultiplyBaseDamage(f)) // 蓝色羁绊
    // 注：HP特殊处理
    _ => {
      println("[警告] 未处理的羁绊 BuffType 转换: \{buff}")
      None
    }
  }
}

fn calculate_permanently_buffed_stats(
  base_stats: CombatStats,
  unit_permanent_effects: Array[UpgradeEffect],
  global_synergy_effects: Array[UpgradeEffect]
) -> CombatStats {
  let mut computed_stats = base_stats
  let all_effects = unit_permanent_effects + global_synergy_effects

  // 收集所有伤害相关的永久增益
  let mut total_damage_multiplier = 1.0
  let mut total_damage_addition = 0.0
  let mut total_crit_rate_addition = 0.0
  let mut final_attack_cooldown_multiplier = 1.0
  let mut final_effect_duration_multiplier = 1.0

  for effect in all_effects {
    match effect {
      UpgradeEffect::MultiplyBaseDamage(factor) => {
        total_damage_multiplier *= factor
      }
      UpgradeEffect::AddBaseDamageFlat(value) => {
        total_damage_addition += value
      }
      UpgradeEffect::AddCritRateFlat(value) => {
        total_crit_rate_addition += value
      }
      UpgradeEffect::MultiplyAttackCooldown(factor) => {
         final_attack_cooldown_multiplier *= factor
      }
      UpgradeEffect::MultiplyBaseEffectDuration(factor) => {
       final_effect_duration_multiplier *= factor
      }
      _ => ()
    }
  }


  // 递归修改DealDamage
  let damage_modified_effects = apply_damage_mods_to_effects(
    base_stats.on_hit_effects,
    total_damage_multiplier,
    total_damage_addition
  )

  // 基础暴击率
  computed_stats = { ..computed_stats, crit_rate: base_stats.crit_rate + total_crit_rate_addition } // 直接加在基础值上

  // 基础攻击冷却
  computed_stats = { ..computed_stats, attack_cooldown: base_stats.attack_cooldown * final_attack_cooldown_multiplier }

  // 递归修改 效果持续时间
  let duration_and_damage_modified_effects = apply_duration_mods_to_effects(
    damage_modified_effects, // << 输入是上一步的结果 >>
    final_effect_duration_multiplier
  )
  computed_stats = { ..computed_stats, on_hit_effects: duration_and_damage_modified_effects }


  return computed_stats
}
fn calculate_permanently_buffed_movement_stats(
    base_stats: MovementStats, // 假设 MovementStats 定义在 move.mbt
    unit_permanent_effects: Array[UpgradeEffect],
    global_synergy_effects: Array[UpgradeEffect]
) -> MovementStats {
    let mut computed_stats = base_stats
    let all_effects = unit_permanent_effects + global_synergy_effects

    for effect in all_effects {
        match effect {
            UpgradeEffect::MultiplySpeedPercent(factor) => {
                computed_stats = { ..computed_stats, speed: computed_stats.speed * factor }
            }
            _ => ()
        }
    }
    return computed_stats
}

// 递归辅助函数：应用伤害乘数到 OnHitEffect 及其嵌套效果
fn apply_damage_mods_to_effects(
  effects: Array[OnHitEffect],
  multiplier: Double,
  addition: Double
) -> Array[OnHitEffect] {
  effects.map(fn(effect) -> OnHitEffect {
    match effect {
      OnHitEffect::DealDamage(dmg, vfx) => {
        // 应用乘法和加法
        OnHitEffect::DealDamage((dmg * multiplier) + addition, vfx)
      }
      OnHitEffect::AreaOfEffect(nested_effects, radius, vfx) => {
        // 递归调用
        OnHitEffect::AreaOfEffect(apply_damage_mods_to_effects(nested_effects, multiplier, addition), radius, vfx)
      }
      OnHitEffect::Chain(nested_effects, jumps, range, falloff, vfx) => {
         // 注意：falloff 可能需要额外考虑如何与永久增益交互，暂时只修改初始伤害
         OnHitEffect::Chain(apply_damage_mods_to_effects(nested_effects, multiplier, addition), jumps, range, falloff, vfx)
      }
      OnHitEffect::Fork(nested_effects, targets, range, vfx) => {
         OnHitEffect::Fork(apply_damage_mods_to_effects(nested_effects, multiplier, addition), targets, range, vfx)
      }
       OnHitEffect::CreateHazardousArea(nested_effects, radius, duration, vfx) => {
         OnHitEffect::CreateHazardousArea(apply_damage_mods_to_effects(nested_effects, multiplier, addition), radius, duration, vfx)
       }
      // 其他非伤害或非嵌套效果保持不变
      _ => effect
    }
  })
}

fn apply_duration_mods_to_effects(
  effects: Array[OnHitEffect],
  duration_multiplier: Double
) -> Array[OnHitEffect] {
  effects.map(fn(effect) -> OnHitEffect {
    match effect {
      // --- 修改持续时间 ---
      OnHitEffect::ApplyBuff(bt, dur, vfx) => {
        OnHitEffect::ApplyBuff(bt, dur * duration_multiplier, vfx)
      }
      OnHitEffect::CreateHazardousArea(nested_effects, radius, dur, vfx) => {
        // 修改区域本身的持续时间，并递归修改 Tick 效果的持续时间（如果 Tick 效果本身也带持续时间的话，虽然目前没有）
        OnHitEffect::CreateHazardousArea(
            apply_duration_mods_to_effects(nested_effects, duration_multiplier), // 递归
            radius,
            dur * duration_multiplier, // 修改区域持续时间
            vfx
        )
      }

      // --- 递归处理嵌套效果 ---
      OnHitEffect::AreaOfEffect(nested_effects, radius, vfx) => {
        OnHitEffect::AreaOfEffect(apply_duration_mods_to_effects(nested_effects, duration_multiplier), radius, vfx)
      }
      OnHitEffect::Chain(nested_effects, jumps, range, falloff, vfx) => {
         OnHitEffect::Chain(apply_duration_mods_to_effects(nested_effects, duration_multiplier), jumps, range, falloff, vfx)
      }
      OnHitEffect::Fork(nested_effects, targets, range, vfx) => {
         OnHitEffect::Fork(apply_duration_mods_to_effects(nested_effects, duration_multiplier), targets, range, vfx)
      }

      // 其他效果保持不变
      _ => effect
    }
  })
}