pub enum UpgradeEffect {
  AddBaseDamageFlat(Double)
  MultiplyBaseDamage(Double)
  MultiplyAttackCooldown(Double)
  AddMaxHPFlat(Double)           // 注意: MaxHP 需要特殊处理
  AddCritRateFlat(Double)
  MultiplyBaseEffectDuration(Double) 
  MultiplySpeedPercent(Double)
  MultiplyStaminaRegenRate(Double)
  MultiplyStaminaCostRate(Double)
  // ... 其他类型 ...
} derive(Show, Eq)
/// 持续性效果卡牌
pub enum UpgradeType {
  // 伤害类 (示例分 3 级)
  DamageUp_1          // +基础伤害
  DamageUp_2
  DamageUp_3
  DamagePercentUp_1   // *基础伤害%
  DamagePercentUp_2
  DamagePercentUp_3

  // 攻速类 (示例分 3 级)
  AttackSpeedUp_1     // *攻击速度% (冷却 * 1/x)
  AttackSpeedUp_2
  AttackSpeedUp_3

  // 生命类 (示例分 3 级)
  MaxHPUp_1           // +最大生命
  MaxHPUp_2
  MaxHPUp_3

  // 暴击类 (示例分 3 级)
  CritRateUp_1        // +暴击率%
  CritRateUp_2
  CritRateUp_3

  // 移速类 (示例分 3 级)
  MoveSpeedPercentUp_1 // *移动速度%
  MoveSpeedPercentUp_2
  MoveSpeedPercentUp_3
  // MoveSpeedFlatUp_1 // 如果需要固定值加速，可以添加

  // 效果持续时间类 (示例分 3 级)
  EffectDurationUp_1  // *效果持续时间%
  EffectDurationUp_2
  EffectDurationUp_3

  // 体力恢复速率
  StaminaRegenUp_1
  StaminaRegenUp_2
  StaminaRegenUp_3

  // 体力消耗速率
  StaminaCostDown_1
  StaminaCostDown_2
  StaminaCostDown_3

  // 瞬时效果卡
  InstantHeal_1 // 命名仍带等级，但 is_repeatable=true
  InstantScore_1 // 命名仍带等级，但 is_repeatable=true
} derive(Eq, Show, Hash) // 加上 Hash 以便在 Set 或 Map 中使用
/// 瞬时效果卡牌
pub enum InstantAction {
  FullHeal        // 瞬间满血
  AddScore(Int)   // 瞬间加分
} derive(Show, Eq)
/// 定义一张升级卡牌的属性
pub struct UpgradeDefinition {
  name: String
  description: String
  effect: Option[UpgradeEffect]       // 【修改】效果变为可选，因为瞬时卡可能没有永久效果
  instant_action: Option[InstantAction] // 【新增】瞬时动作，可选
  base_type: String
  level: Int
  is_repeatable: Bool                 // 【新增】标记是否可重复获取 (用于瞬时卡)
  // 可以添加 rarity, icon_path 等字段
}

/// 全局的升级数据库
pub let upgrade_database: Map[UpgradeType, UpgradeDefinition] = Map::new()

/// 初始化升级数据库 (这个函数需要在游戏启动时调用，例如在 init_game 中)
// src/upgrades.mbt (修改 setup_upgrade_database 函数)

pub fn setup_upgrade_database() -> Unit {
  // --- 清空旧数据 (如果需要重复调用) ---
  // upgrade_database.clear() // 取消注释以防万一

  // --- 伤害类 ---
  upgrade_database.set(UpgradeType::DamageUp_1, {
    name: "基础火力增强 I", description: "所有单位的基础攻击力 +2",
    effect: Some( UpgradeEffect::AddBaseDamageFlat(2.0)), // 等级1：总加值 +2
    base_type: "DamageUp", level: 1, instant_action: None, is_repeatable: false,
  })
  upgrade_database.set(UpgradeType::DamageUp_2, {
    name: "基础火力增强 II", description: "所有单位的基础攻击力 +5", // 描述写总和
    effect: Some( UpgradeEffect::AddBaseDamageFlat(3.0)), // 等级2：增量 +3 (2+3=5)
    base_type: "DamageUp", level: 2, instant_action: None, is_repeatable: false,
  })
  upgrade_database.set(UpgradeType::DamageUp_3, {
    name: "基础火力增强 III", description: "所有单位的基础攻击力 +9",
    effect: Some( UpgradeEffect::AddBaseDamageFlat(4.0)), // 等级3：增量 +4 (5+4=9)
    base_type: "DamageUp", level: 3, instant_action: None, is_repeatable: false,
  })

  upgrade_database.set(UpgradeType::DamagePercentUp_1, {
    name: "火力倍增 I", description: "所有单位的基础攻击力提升 10%",
    effect: Some( UpgradeEffect::MultiplyBaseDamage(1.10)), // 等级1：乘数 1.1
    base_type: "DamagePercentUp", level: 1, instant_action: None, is_repeatable: false,
  })
  upgrade_database.set(UpgradeType::DamagePercentUp_2, {
    name: "火力倍增 II", description: "所有单位的基础攻击力提升 20% ", // 描述写近似总和
    effect: Some( UpgradeEffect::MultiplyBaseDamage(1.09)), // 等级2：再乘 1.05 (总共约 1.1 * 1.09 ~ 1.20)
    base_type: "DamagePercentUp", level: 2, instant_action: None, is_repeatable: false,
  })
  upgrade_database.set(UpgradeType::DamagePercentUp_3, {
    name: "火力倍增 III", description: "所有单位的基础攻击力提升 30% ",
    effect: Some( UpgradeEffect::MultiplyBaseDamage(1.09)), // 等级3：再乘 1.08 (总共约 1.188 * 1.09 ~ 1.30)
    base_type: "DamagePercentUp", level: 3, instant_action: None, is_repeatable: false,
  })

  // --- 攻速类 ---
  upgrade_database.set(UpgradeType::AttackSpeedUp_1, {
    name: "射速强化 I", description: "所有单位的攻击速度提升 15%",
    effect: Some( UpgradeEffect::MultiplyAttackCooldown(1.0 / 1.15)), // 冷却 * (1/1.15)
    base_type: "AttackSpeedUp", level: 1, instant_action: None, is_repeatable: false,
  })
  upgrade_database.set(UpgradeType::AttackSpeedUp_2, {
    name: "射速强化 II", description: "所有单位的攻击速度提升 28%", // 1.15 * 1.12 ≈ 1.288
    effect: Some( UpgradeEffect::MultiplyAttackCooldown(1.0 / 1.12)), // 冷却再 * (1/1.12)
    base_type: "AttackSpeedUp", level: 2, instant_action: None, is_repeatable: false,
  })
  upgrade_database.set(UpgradeType::AttackSpeedUp_3, {
    name: "射速强化 III", description: "所有单位的攻击速度提升 44%", // 1.288 * 1.12 ≈ 1.44
    effect: Some( UpgradeEffect::MultiplyAttackCooldown(1.0 / 1.12)), // 冷却再 * (1/1.12)
    base_type: "AttackSpeedUp", level: 3, instant_action: None, is_repeatable: false,
  })

  // --- 生命类 (按增量定义，计算时累加) ---
  upgrade_database.set(UpgradeType::MaxHPUp_1, {
    name: "装甲加固 I", description: "所有单位的最大生命值 +5",
    effect: Some( UpgradeEffect::AddMaxHPFlat(5.0)), // 增量 +5
    base_type: "MaxHPUp", level: 1, instant_action: None, is_repeatable: false,
  })
  upgrade_database.set(UpgradeType::MaxHPUp_2, {
    name: "装甲加固 II", description: "所有单位的最大生命值 +12",
    effect: Some( UpgradeEffect::AddMaxHPFlat(7.0)), // 增量 +7
    base_type: "MaxHPUp", level: 2, instant_action: None, is_repeatable: false,
  })
  upgrade_database.set(UpgradeType::MaxHPUp_3, {
    name: "装甲加固 III", description: "所有单位的最大生命值 +22",
    effect: Some( UpgradeEffect::AddMaxHPFlat(10.0)), // 增量 +10
    base_type: "MaxHPUp", level: 3, instant_action: None, is_repeatable: false,
  })

  // --- 暴击类 (按增量定义，计算时累加) ---
  upgrade_database.set(UpgradeType::CritRateUp_1, {
    name: "精准瞄准 I", description: "所有单位的暴击率 +5%",
    effect: Some( UpgradeEffect::AddCritRateFlat(0.05)), // 增量 +5%
    base_type: "CritRateUp", level: 1, instant_action: None, is_repeatable: false,
  })
  upgrade_database.set(UpgradeType::CritRateUp_2, {
    name: "精准瞄准 II", description: "所有单位的暴击率 +10%",
    effect: Some( UpgradeEffect::AddCritRateFlat(0.05)), // 增量 +5%
    base_type: "CritRateUp", level: 2, instant_action: None, is_repeatable: false,
  })
  upgrade_database.set(UpgradeType::CritRateUp_3, {
    name: "精准瞄准 III", description: "所有单位的暴击率 +15%",
    effect: Some( UpgradeEffect::AddCritRateFlat(0.05)), // 增量 +5%
    base_type: "CritRateUp", level: 3, instant_action: None, is_repeatable: false,
  })

  // --- 移速类 (百分比按乘数因子定义) ---
   upgrade_database.set(UpgradeType::MoveSpeedPercentUp_1, {
     name: "引擎优化 I", description: "所有单位的移动速度提升 10%",
     effect: Some( UpgradeEffect::MultiplySpeedPercent(1.10)), // 乘数 1.1
     base_type: "MoveSpeedPercentUp", level: 1, instant_action: None, is_repeatable: false,
   })
   upgrade_database.set(UpgradeType::MoveSpeedPercentUp_2, {
     name: "引擎优化 II", description: "所有单位的移动速度提升 20%",
     effect: Some( UpgradeEffect::MultiplySpeedPercent(1.09)), // 再乘 1.08
     base_type: "MoveSpeedPercentUp", level: 2, instant_action: None, is_repeatable: false,
   })
   upgrade_database.set(UpgradeType::MoveSpeedPercentUp_3, {
     name: "引擎优化 III", description: "所有单位的移动速度提升 30%",
     effect: Some( UpgradeEffect::MultiplySpeedPercent(1.09)), // 再乘 1.08
     base_type: "MoveSpeedPercentUp", level: 3, instant_action: None, is_repeatable: false,
   })

  // --- 效果持续时间 (百分比按乘数因子定义) ---
  upgrade_database.set(UpgradeType::EffectDurationUp_1, {
    name: "持续效应 I", description: "所有单位施加的效果持续时间延长 20%",
    effect: Some( UpgradeEffect::MultiplyBaseEffectDuration(1.20)), // 乘数 1.2
    base_type: "EffectDurationUp", level: 1, instant_action: None, is_repeatable: false,
  })
  upgrade_database.set(UpgradeType::EffectDurationUp_2, {
    name: "持续效应 II", description: "所有单位施加的效果持续时间延长 40% ",
    effect: Some( UpgradeEffect::MultiplyBaseEffectDuration(1.17)), // (总共约 1.2 * 1.17 = 1.40)
    base_type: "EffectDurationUp", level: 2, instant_action: None, is_repeatable: false,
  })
  upgrade_database.set(UpgradeType::EffectDurationUp_3, {
    name: "持续效应 III", description: "所有单位施加的效果持续时间额外 60% ",
    effect: Some( UpgradeEffect::MultiplyBaseEffectDuration(1.15)), // 再乘 1.15(总共约 1.38 * 1.15 = 1.61)
    base_type: "EffectDurationUp", level: 3, instant_action: None, is_repeatable: false,
  })


   // --- 体力相关卡牌 ---
  upgrade_database.set(UpgradeType::StaminaRegenUp_1, {
    name: "能量回收 I", description: "体力恢复速度提升 5%",
    effect: Some(UpgradeEffect::MultiplyStaminaRegenRate(1.05)),
    instant_action: None, base_type: "StaminaRegenUp", level: 1, is_repeatable: false, 
  })
  upgrade_database.set(UpgradeType::StaminaRegenUp_1, {
    name: "能量回收 II", description: "体力恢复速度提升 15%",
    effect: Some(UpgradeEffect::MultiplyStaminaRegenRate(1.0952)), //1.05*1.0952 ~ 1.15
    instant_action: None, base_type: "StaminaRegenUp", level: 1, is_repeatable: false,
  })
  upgrade_database.set(UpgradeType::StaminaRegenUp_1, {
    name: "能量回收 III", description: "体力恢复速度提升 25%",
    effect: Some(UpgradeEffect::MultiplyStaminaRegenRate(1.087)), //1.05*1.0952*1.087 ~ 1.25
    instant_action: None, base_type: "StaminaRegenUp", level: 1, is_repeatable: false,
  })
  upgrade_database.set(UpgradeType::StaminaCostDown_1, {
    name: "节能冲刺 I", description: "冲刺体力消耗降低 5%",
    effect: Some(UpgradeEffect::MultiplyStaminaCostRate(0.95)),
    instant_action: None, base_type: "StaminaCostDown", level: 1, is_repeatable: false,
  })
  upgrade_database.set(UpgradeType::StaminaCostDown_1, {
    name: "节能冲刺 I", description: "冲刺体力消耗降低 15%",
    effect: Some(UpgradeEffect::MultiplyStaminaCostRate(0.895)), //0.95*0.895 ~ 0.85 
    instant_action: None, base_type: "StaminaCostDown", level: 1, is_repeatable: false,
  })
  upgrade_database.set(UpgradeType::StaminaCostDown_1, {
    name: "节能冲刺 I", description: "冲刺体力消耗降低 25%",
    effect: Some(UpgradeEffect::MultiplyStaminaCostRate(0.882)), //0.95*0.895*0.882 ~ 0.75
    instant_action: None, base_type: "StaminaCostDown", level: 1, is_repeatable: false,
  })

  // --- 瞬时效果卡牌 ---
  upgrade_database.set(UpgradeType::InstantHeal_1, {
    name: "紧急维修", description: "立即恢复所有单位至满血状态",
    effect: None, // 没有永久数值效果
    instant_action: Some(InstantAction::FullHeal), // 指定瞬时动作
    base_type: "InstantHeal", level: 1, // base_type 唯一, level 设为 1
    is_repeatable: true,
  })
  upgrade_database.set(UpgradeType::InstantScore_1, {
    name: "数据 windfall", description: "立即获得 1000 分",
    effect: None,
    instant_action: Some(InstantAction::AddScore(1000)), // 指定瞬时动作及分数
    base_type: "InstantScore", level: 1, // base_type 唯一, level 设为 1
    is_repeatable: true,
  })
  println("【数据库】: 升级数据库已初始化 (分级)，包含 \{upgrade_database.length()} 个升级。")
}

// 记录玩家已获得的升级
pub let acquired_upgrades: Ref[Array[UpgradeType]] = Ref::new([])

//应用升级的核心逻辑 
pub fn apply_upgrade(upgrade_type: UpgradeType) -> Unit {
  match upgrade_database.get(upgrade_type) {
    None => {
      println("[错误] 在升级数据库中未找到 UpgradeType: \{upgrade_type}")
    }
    Some(upgrade_def) => { 
      // 处理瞬时动作
      if upgrade_def.instant_action is Some(action) {
        println("【升级应用】: 执行瞬时动作 [\{action}]")
        match action {
          InstantAction::FullHeal => heal_all_player_units()
          InstantAction::AddScore(amount) => add_score(amount)
        }
        // 如果是可重复的瞬时动作，执行后直接结束
        if upgrade_def.is_repeatable {
          println("  -> 此为可重复瞬时动作，不记录获取。")
          return // 【重要】直接返回，不执行后续逻辑
        }
        // 【不可重复】的，会继续往下走进行记录
      }

      // 处理永久效果 
      if upgrade_def.effect is Some(effect_to_apply) {
        println("【升级应用】: 正在应用永久效果 [\{effect_to_apply}] 到所有玩家单位...")
        for unit in all_units.val {
          if unit.is_alive() && teams.get(unit) == Some(Team::Player) { // 检查单位状态

            // 获取或创建 PermanentBuffs 组件
            let current_pb = match permanent_buffs.get(unit) {
                Some(existing_pb) => existing_pb
                None => {
                    let new_pb = PermanentBuffs::{ effects: [] }
                    permanent_buffs.set(unit, new_pb)
                    new_pb
                }
            }
            current_pb.effects.push(effect_to_apply) // 添加效果
            println("  -> 单位 \{unit} 添加了效果 [\{effect_to_apply}]")

            // 特殊处理 MaxHP
            if effect_to_apply is UpgradeEffect::AddMaxHPFlat(hp_bonus) {
                if healths.get(unit) is Some(health_comp) { // 使用 is Some 检查
                    let new_max_hp = health_comp.max + hp_bonus
                    let current_hp_ratio = if health_comp.max == 0.0 { 1.0 } else { health_comp.current / health_comp.max }
                    let new_current_hp = new_max_hp * current_hp_ratio
                    healths.set(unit, { ..health_comp, max: new_max_hp, current: new_current_hp })
                    println("  -> 单位 \{unit} 最大生命值已更新为 \{new_max_hp}，当前生命值调整为 \{new_current_hp}")
                }
            } // MaxHP 处理结束
          } // if is player unit 结束
        } // for 循环结束
      } else if upgrade_def.instant_action is None { 
          println("[警告] 升级 [\{upgrade_type}] 既没有永久效果也没有瞬时动作！")
      } // 永久效果处理结束

      // 记录获取 
      if !upgrade_def.is_repeatable {
        acquired_upgrades.val.push(upgrade_type)
        println("【升级记录】: 玩家已获得永久升级 [\{upgrade_type}]，当前获得列表: \{acquired_upgrades.val}")
      }

    } // Some(upgrade_def) 分支结束
  } // match upgrade_database.get 结束
} // 函数结束

let current_upgrade_options: Ref[Array[UpgradeType]] = Ref::new([]) 
let selected_upgrade_for_confirmation: Ref[Option[UpgradeType]] = Ref::new(None)
let selected_card_overlay_entity: Ref[Option[@system.Entity]] = Ref::new(None)
let confirm_upgrade_button_entity: Ref[Option[@system.Entity]] = Ref::new(None)
///随机发牌
fn get_random_upgrades(count: Int) -> Array[UpgradeType] {
  let all_upgrade_keys_array: Array[UpgradeType] = upgrade_database.keys().to_array()
  let acquired_upgrades_array: Array[UpgradeType] = acquired_upgrades.val // 获取已拥有的列表

  let acquired_set: Set[UpgradeType] = Set::from_array(acquired_upgrades_array)

  // 创建玩家对每种基础类型拥有的最高等级 Map
  let max_acquired_level_by_type: Map[String, Int] = Map::new()
  for acquired_type in acquired_upgrades_array {
    if upgrade_database.get(acquired_type) is Some(acquired_def) {
      let current_max = max_acquired_level_by_type.get(acquired_def.base_type).unwrap_or(0)
      if acquired_def.level > current_max {
        max_acquired_level_by_type.set(acquired_def.base_type, acquired_def.level)
      }
    }
  }
  println("【发卡调试】: 玩家已拥有各类型最高等级: \{max_acquired_level_by_type}")


  let available_upgrades = all_upgrade_keys_array.filter(fn(candidate_type) -> Bool {
    if acquired_set.contains(candidate_type) {
      return false
    }

    match upgrade_database.get(candidate_type) {
      Some(candidate_def) => {
        match max_acquired_level_by_type.get(candidate_def.base_type) {
          Some(max_level_owned) => {
            candidate_def.level == max_level_owned + 1
          }
          None => {
            candidate_def.level == 1
          }
        }
      }
      None => {
        println("[警告] 候选升级 \{candidate_type} 在数据库中未找到定义！")
        false
      }
    }
  })

  println("【发卡调试】: 所有卡: \{all_upgrade_keys_array.length()} 张, 玩家已拥有: \{acquired_set.length()} 张, 过滤低级后可选: \{available_upgrades.length()} 张")

  if available_upgrades.length() <= count {
    println("【发卡调试】: 过滤后数量不足，返回所有可选卡。")
    return available_upgrades
  }

  let shuffled_keys = available_upgrades
  let selected_keys : Array[UpgradeType] = []
  let used_indices : Set[Int] = Set::new()

  while selected_keys.length() < count {
     let random_index = global_rng.int(limit = shuffled_keys.length()) 
     if !used_indices.contains(random_index) {
        selected_keys.push(shuffled_keys[random_index]) 
        used_indices.add(random_index)
     }
     if used_indices.length() >= shuffled_keys.length() { break } 
  }

  return selected_keys
}
